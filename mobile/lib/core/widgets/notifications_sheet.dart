import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import '../../features/auth/data/auth_provider.dart';

/// Modèle local pour les notifications
class AppNotification {
  final String id;
  final String type;
  final String message;
  final bool isRead;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type'] ?? 'alert',
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}

/// Affiche la feuille modale des notifications avec synchronisation API Django
void showNotificationsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _NotificationsContent(ref: ref),
  );
}

class _NotificationsContent extends StatefulWidget {
  final WidgetRef ref;
  const _NotificationsContent({required this.ref});

  @override
  State<_NotificationsContent> createState() => _NotificationsContentState();
}

class _NotificationsContentState extends State<_NotificationsContent> {
  bool _isLoading = true;
  List<AppNotification> _notifications = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = widget.ref.read(apiClientProvider);
      final response = await apiClient.get(AppConstants.notificationsEndpoint);
      if (response.statusCode == 200 && response.data is List) {
        final list = (response.data as List)
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _notifications = list;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Impossible de charger les notifications';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      final apiClient = widget.ref.read(apiClientProvider);
      await apiClient.post('${AppConstants.notificationsEndpoint}$id/read/');
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == id);
        if (index != -1) {
          final n = _notifications[index];
          _notifications[index] = AppNotification(
            id: n.id,
            type: n.type,
            message: n.message,
            isRead: true,
            createdAt: n.createdAt,
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    try {
      final apiClient = widget.ref.read(apiClientProvider);
      await apiClient.post('${AppConstants.notificationsEndpoint}mark-all-read/');
      setState(() {
        _notifications = _notifications
            .map((n) => AppNotification(
                  id: n.id,
                  type: n.type,
                  message: n.message,
                  isRead: true,
                  createdAt: n.createdAt,
                ))
            .toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les notifications sont marquées comme lues.'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'weather':
        return Icons.cloud_outlined;
      case 'market':
        return Icons.trending_up_rounded;
      case 'crop':
        return Icons.eco_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'weather':
        return Colors.blue;
      case 'market':
        return Colors.orange;
      case 'crop':
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Notifications & Alertes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              if (_notifications.any((n) => !n.isRead))
                TextButton(
                  onPressed: _markAllAsRead,
                  child: const Text('Tout marquer lu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, style: TextStyle(color: Colors.grey.shade600)),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _fetchNotifications,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _notifications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'Aucune notification pour le moment',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _notifications.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                            itemBuilder: (ctx, index) {
                              final notif = _notifications[index];
                              final color = _getTypeColor(notif.type);
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(_getTypeIcon(notif.type), color: color, size: 22),
                                ),
                                title: Text(
                                  notif.message,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: notif.isRead ? FontWeight.normal : FontWeight.w600,
                                    color: notif.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                                    height: 1.3,
                                  ),
                                ),
                                trailing: !notif.isRead
                                    ? Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    : null,
                                onTap: notif.isRead ? null : () => _markAsRead(notif.id),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
