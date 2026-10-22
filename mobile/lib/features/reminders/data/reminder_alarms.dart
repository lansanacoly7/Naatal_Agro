import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Alarme programmée sur l'appareil. Seule la couche « plateforme » connaît le plugin de notifications :
/// la synchronisation des rappels ne dépend que de cette interface, ce qui la rend testable.
abstract class AlarmPlatform {
  /// Programme (ou remplace, si l'[id] existe déjà) une alarme qui sonnera à [when].
  Future<void> schedule({required int id, required String title, required String body, required DateTime when});

  Future<void> cancel(int id);

  /// Identifiants des alarmes encore en attente sur l'appareil.
  Future<Set<int>> pendingIds();

  Future<void> cancelAll();
}

/// Identifiant d'alarme stable (hachage FNV-1a 32 bits) déduit de l'identifiant serveur du rappel.
///
/// `String.hashCode` n'est pas garanti identique d'une exécution à l'autre : une alarme programmée hier
/// ne serait plus retrouvée aujourd'hui, et un rappel annulé continuerait de sonner.
int stableAlarmId(String serverId) {
  var hash = 0x811c9dc5;
  for (final unit in serverId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// Alerte à afficher dans l'application quand un rappel arrive à échéance.
class InAppAlert {
  const InAppAlert({required this.title, required this.body});

  final String title;
  final String body;
}

/// Alarmes « dans l'application » pour les plateformes sans notifications locales (navigateur, ordinateur) :
/// un minuteur par rappel, qui émet une [InAppAlert] à l'échéance. L'alerte n'est visible que tant que
/// l'application est ouverte — un navigateur ne peut pas faire sonner un onglet fermé.
class InAppAlarmPlatform implements AlarmPlatform {
  InAppAlarmPlatform({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<int, Timer> _timers = {};
  final StreamController<InAppAlert> _alerts = StreamController<InAppAlert>.broadcast();

  Stream<InAppAlert> get alerts => _alerts.stream;

  @override
  Future<void> schedule({required int id, required String title, required String body, required DateTime when}) async {
    _timers[id]?.cancel();
    final delay = when.difference(_clock());
    _timers[id] = Timer(delay.isNegative ? Duration.zero : delay, () {
      _timers.remove(id);
      _alerts.add(InAppAlert(title: title, body: body));
    });
  }

  @override
  Future<void> cancel(int id) async => _timers.remove(id)?.cancel();

  @override
  Future<Set<int>> pendingIds() async => _timers.keys.toSet();

  @override
  Future<void> cancelAll() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}

/// Alarmes réelles Android / iOS via `flutter_local_notifications`.
///
/// Le plugin est initialisé à la première utilisation, au moment où un rappel doit être programmé, pour que
/// l'autorisation de notifier soit demandée quand elle a un sens pour l'utilisateur.
class LocalNotificationsAlarmPlatform implements AlarmPlatform {
  LocalNotificationsAlarmPlatform({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'naatal_reminders';
  static const _channelName = 'Rappels Naatal IA';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialization;

  Future<void> _ensureInitialized() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    // Android 13+ : l'autorisation d'afficher des notifications doit être accordée explicitement
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    if (granted == false) {
      debugPrint('[Rappels] Notifications refusées par l\'utilisateur : les alarmes ne sonneront pas.');
    }
  }

  @override
  Future<void> schedule({required int id, required String title, required String body, required DateTime when}) async {
    await _ensureInitialized();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      // Un instant absolu : le fuseau choisi n'a pas d'incidence sur l'heure de sonnerie
      scheduledDate: tz.TZDateTime.from(when, tz.UTC),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Rappels programmés avec l\'assistant Naatal IA',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Marge de quelques minutes acceptable pour un rappel agricole ; évite la permission « alarme exacte »
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _ensureInitialized();
    await _plugin.cancel(id: id);
  }

  @override
  Future<Set<int>> pendingIds() async {
    await _ensureInitialized();
    final pending = await _plugin.pendingNotificationRequests();
    return {for (final request in pending) request.id};
  }

  @override
  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }
}

/// Notifications locales du système sur Android / iOS ; alarmes dans l'application ailleurs (navigateur, ordinateur).
AlarmPlatform defaultAlarmPlatform() {
  final mobile = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  return mobile ? LocalNotificationsAlarmPlatform() : InAppAlarmPlatform();
}
