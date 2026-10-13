import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (notifState.items.any((n) => !n.isRead))
            IconButton(
              icon: const Icon(Icons.done_all_rounded, color: AppColors.primary),
              tooltip: 'Tout marquer comme lu',
              onPressed: () {
                ref.read(notificationsProvider.notifier).markAllAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Toutes les notifications sont marquées comme lues'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(notificationsProvider.notifier).fetchNotifications(),
        child: notifState.isLoading && notifState.items.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : notifState.items.isEmpty
                ? _buildEmptyState(context, ref)
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: notifState.items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notif = notifState.items[index];
                      return _buildNotificationCard(context, ref, notif);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 20),
              Text(
                'Aucune notification pour le moment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                'Vous recevrez ici les alertes météo, de prix et de cultures.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(BuildContext context, WidgetRef ref, AppNotificationItem notif) {
    final isRead = notif.isRead;
    final meta = _resolveTypeMetadata(notif.type);

    return InkWell(
      onTap: () {
        if (!isRead) {
          ref.read(notificationsProvider.notifier).markAsRead(notif.id);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : meta.color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? Colors.grey.shade200 : meta.color.withValues(alpha: 0.3),
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: isRead
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))]
              : [BoxShadow(color: meta.color.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(meta.icon, color: meta.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            meta.title,
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          notif.timeAgo,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notif.message,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isRead) ...[
                const SizedBox(width: 10),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: meta.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  _TypeMeta _resolveTypeMetadata(String type) {
    switch (type.toLowerCase()) {
      case 'weather':
      case 'meteo':
        return _TypeMeta('Alerte Météo', Icons.water_drop_rounded, Colors.blue);
      case 'market':
      case 'price':
      case 'prix':
        return _TypeMeta('Alerte Marché', Icons.trending_up_rounded, Colors.orange.shade800);
      case 'crop':
      case 'culture':
      case 'harvest':
        return _TypeMeta('Conseil Agricole', Icons.eco_rounded, AppColors.primary);
      default:
        return _TypeMeta('Information', Icons.notifications_active_rounded, Colors.amber.shade800);
    }
  }
}

class _TypeMeta {
  final String title;
  final IconData icon;
  final Color color;

  const _TypeMeta(this.title, this.icon, this.color);
}
