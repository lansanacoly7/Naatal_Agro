import 'package:flutter/material.dart';

class OfflineCacheBanner extends StatelessWidget {
  final DateTime cachedAt;

  const OfflineCacheBanner({super.key, required this.cachedAt});

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month à $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.orange.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.offline_bolt, size: 16, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Données enregistrées le ${_formatDate(cachedAt)} (hors connexion)',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
