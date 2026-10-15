import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/data/notifications_provider.dart';
import '../../ui/ui.dart';

/// Alertes reçues (météo, cultures, stock, marchés), les non lues en tête.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    final items = [...state.items]..sort((a, b) {
        if (a.isRead != b.isRead) return a.isRead ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });

    return LargeTitleScaffold(
      title: 'Notifications',
      eyebrow: state.unreadCount == 0 ? null : '${state.unreadCount} non lue${state.unreadCount > 1 ? 's' : ''}',
      reserveNav: false,
      onRefresh: notifier.fetchNotifications,
      actions: [
        if (state.unreadCount > 0)
          IntrinsicWidth(child: PillButton(label: 'Tout lire', variant: PillVariant.secondary, compact: true, onPressed: notifier.markAllAsRead)),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Builder(builder: (context) {
            if (state.isLoading && items.isEmpty) {
              return const Padding(padding: EdgeInsets.all(Space.gutter), child: Skeleton(height: 220, radius: 20));
            }
            if (state.error != null && items.isEmpty) {
              return ErrorState(message: 'Vos notifications n\'ont pas pu être chargées.', onRetry: notifier.fetchNotifications);
            }
            if (items.isEmpty) {
              return const EmptyState(icon: Icons.notifications_none_rounded, title: 'Aucune notification', message: 'Les alertes sur vos cultures, votre stock et les prix apparaîtront ici.');
            }
            return GroupedList(
              children: [
                for (var i = 0; i < items.length; i++)
                  Reveal(
                    index: i,
                    child: GroupedRow(
                      leading: IconTile(icon: _icon(items[i].type), color: items[i].isRead ? c.ink2 : _tint(c, items[i].type)),
                      title: items[i].message,
                      subtitle: items[i].timeAgo,
                      trailing: items[i].isRead ? null : Container(width: 10, height: 10, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
                      onTap: items[i].isRead ? null : () => notifier.markAsRead(items[i].id),
                    ),
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }

  IconData _icon(String type) => switch (type) {
        'weather' => Icons.cloud_rounded,
        'stock' => Icons.inventory_2_rounded,
        'price' || 'market' => Icons.trending_up_rounded,
        'crop' || 'pest' => Icons.eco_rounded,
        _ => Icons.notifications_rounded,
      };

  Color _tint(NaatalColors c, String type) => switch (type) {
        'weather' => c.slate,
        'stock' || 'pest' => c.clay,
        _ => c.accent,
      };
}
