import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_provider.dart';
import 'reminder_alarms.dart';

/// Rappel à venir tel que le serveur le connaît.
class UpcomingReminder {
  const UpcomingReminder({required this.id, required this.message, required this.when});

  final String id;
  final String message;
  final DateTime when;

  static UpcomingReminder? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString();
    final when = DateTime.tryParse('${raw['scheduled_for']}')?.toLocal();
    if (id == null || id.isEmpty || when == null) return null;
    return UpcomingReminder(id: id, message: (raw['message'] ?? '').toString(), when: when);
  }
}

class ReminderSyncResult {
  const ReminderSyncResult({required this.scheduled, required this.cancelled});

  final int scheduled;
  final int cancelled;
}

/// Aligne les alarmes de l'appareil sur les rappels à venir du serveur, qui reste la source de vérité :
/// - un rappel à venir est programmé (ou reprogrammé s'il a été déplacé) ;
/// - une alarme dont le rappel a été annulé, délivré ou supprimé est retirée.
///
/// La synchronisation est idempotente : la rejouer ne change rien si rien n'a changé.
class ReminderSync {
  ReminderSync(this._api, this._platform, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// Une alarme qui devrait sonner dans moins de cette durée est inutile : le serveur la délivre déjà.
  static const _minimumLead = Duration(seconds: 5);
  static const title = 'Rappel Naatal IA';

  final ApiClient _api;
  final AlarmPlatform _platform;
  final DateTime Function() _clock;

  Future<ReminderSyncResult> sync() async {
    final response = await _api.get(AppConstants.notificationsEndpoint, queryParams: {'scope': 'scheduled'});
    final body = response.data;
    final items = body is List ? body : (body is Map ? (body['results'] as List<dynamic>? ?? const []) : const []);

    final horizon = _clock().add(_minimumLead);
    final wanted = <int, UpcomingReminder>{};
    for (final raw in items) {
      final reminder = UpcomingReminder.tryParse(raw);
      if (reminder != null && reminder.when.isAfter(horizon)) {
        wanted[stableAlarmId(reminder.id)] = reminder;
      }
    }

    var cancelled = 0;
    for (final id in await _platform.pendingIds()) {
      if (!wanted.containsKey(id)) {
        await _platform.cancel(id);
        cancelled++;
      }
    }
    for (final entry in wanted.entries) {
      await _platform.schedule(id: entry.key, title: title, body: entry.value.message, when: entry.value.when);
    }
    return ReminderSyncResult(scheduled: wanted.length, cancelled: cancelled);
  }

  /// Comme [sync], sans jamais lever d'exception : une panne réseau ne doit pas gêner l'écran appelant.
  /// L'échec est journalisé (jamais ignoré) et la prochaine synchronisation réessaiera.
  Future<bool> syncQuietly() async {
    try {
      await sync();
      return true;
    } catch (e) {
      debugPrint('[Rappels] Synchronisation impossible pour l\'instant : $e');
      return false;
    }
  }

  /// Retire toutes les alarmes (déconnexion) : les rappels d'un compte ne doivent jamais sonner pour un autre.
  Future<void> clear() => _platform.cancelAll();
}

final alarmPlatformProvider = Provider<AlarmPlatform>((ref) => defaultAlarmPlatform());

final reminderSyncProvider = Provider<ReminderSync>((ref) {
  return ReminderSync(ref.watch(apiClientProvider), ref.watch(alarmPlatformProvider));
});
