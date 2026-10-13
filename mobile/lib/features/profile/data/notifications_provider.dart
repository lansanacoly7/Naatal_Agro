import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../auth/data/auth_provider.dart';

class AppNotificationItem {
  final String id;
  final String type;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const AppNotificationItem({
    required this.id,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return AppNotificationItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'alert',
      message: json['message']?.toString() ?? '',
      isRead: json['is_read'] == true,
      createdAt: parsedDate,
    );
  }

  AppNotificationItem copyWith({
    String? id,
    String? type,
    String? message,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return "Il y a ${diff.inMinutes} min";
    if (diff.inHours < 24) return "Il y a ${diff.inHours} h";
    if (diff.inDays < 7) return "Il y a ${diff.inDays} j";
    return "${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}";
  }
}

class NotificationsState {
  final List<AppNotificationItem> items;
  final bool isLoading;
  final String? error;

  const NotificationsState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  int get unreadCount => items.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    List<AppNotificationItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final ApiClient _apiClient;

  NotificationsNotifier(this._apiClient) : super(const NotificationsState()) {
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiClient.get(
        AppConstants.notificationsEndpoint,
        queryParams: {'page_size': 50},
      );

      if (response.statusCode == 200 && response.data != null) {
        List<dynamic> listData = [];
        if (response.data is Map<String, dynamic> && response.data['results'] is List) {
          listData = response.data['results'] as List<dynamic>;
        } else if (response.data is List) {
          listData = response.data as List<dynamic>;
        }

        final notifications = listData
            .map((item) => AppNotificationItem.fromJson(item as Map<String, dynamic>))
            .toList();

        state = state.copyWith(items: notifications, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> markAsRead(String id) async {
    // Mise à jour optimiste
    final updatedList = state.items.map((notif) {
      if (notif.id == id) {
        return notif.copyWith(isRead: true);
      }
      return notif;
    }).toList();
    state = state.copyWith(items: updatedList);

    try {
      await _apiClient.post('${AppConstants.notificationsEndpoint}$id/read/');
    } catch (_) {
      // Si échec réseau, on peut recharger
      fetchNotifications();
    }
  }

  Future<void> markAllAsRead() async {
    // Mise à jour optimiste
    final updatedList = state.items.map((notif) => notif.copyWith(isRead: true)).toList();
    state = state.copyWith(items: updatedList);

    try {
      await _apiClient.post('${AppConstants.notificationsEndpoint}mark-all-read/');
    } catch (_) {
      fetchNotifications();
    }
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  // Re-souscrire aux changements d'authentification pour rafraîchir les alertes
  ref.watch(authStateProvider);
  return NotificationsNotifier(apiClient);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});
