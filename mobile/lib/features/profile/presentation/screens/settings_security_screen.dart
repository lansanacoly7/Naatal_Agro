import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SettingsSecurityScreen extends StatelessWidget {
  const SettingsSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Sécurité & Confidentialité', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildActionTile(Icons.lock_rounded, 'Changer de mot de passe', 'Dernière modification : il y a 3 mois', onTap: () {}),
          const SizedBox(height: 16),
          _buildActionTile(Icons.devices_rounded, 'Appareils connectés', '1 appareil actif', onTap: () {}),
          const SizedBox(height: 16),
          _buildActionTile(Icons.delete_forever_rounded, 'Supprimer mon compte', 'Action irréversible', color: Colors.red, onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle, {Color color = Colors.black87, required VoidCallback onTap}) {
    final bool isDanger = color == Colors.red;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: isDanger ? Colors.red.withOpacity(0.1) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: isDanger ? Colors.red : AppColors.primary),
          ),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          subtitle: Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
        ),
      ),
    );
  }
}
