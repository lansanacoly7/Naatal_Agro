import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Liste statique pour l'UI, à remplacer plus tard par des données de l'API
    final List<Map<String, dynamic>> notifications = [
      {
        'title': 'Alerte Prix Atteinte',
        'message': 'Le prix de l\'Oignon Local a dépassé 450 FCFA/kg.',
        'time': 'Il y a 10 min',
        'icon': Icons.trending_up_rounded,
        'color': Colors.green,
        'isRead': false,
      },
      {
        'title': 'Conseil Météo',
        'message': 'Risque de pluie forte demain, protégez vos cultures.',
        'time': 'Il y a 2 heures',
        'icon': Icons.water_drop_rounded,
        'color': Colors.blue,
        'isRead': false,
      },

    ];

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
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: AppColors.primary),
            tooltip: 'Tout marquer comme lu',
            onPressed: () {
              // Action pour tout marquer comme lu
            },
          ),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return _buildNotificationCard(notif);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(
            'Aucune notification',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          Text(
            'Vous êtes à jour !',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final bool isRead = notif['isRead'];
    final Color iconColor = notif['color'];
    final IconData icon = notif['icon'];

    return Container(
      decoration: BoxDecoration(
        color: isRead ? Colors.white : iconColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: isRead ? Border.all(color: Colors.grey.shade200) : Border.all(color: iconColor.withOpacity(0.3)),
        boxShadow: isRead ? [] : [
          BoxShadow(
            color: iconColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif['title'],
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        notif['time'],
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
                    notif['message'],
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!isRead) ...[
              const SizedBox(width: 12),
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
