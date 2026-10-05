import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SettingsSupportScreen extends StatelessWidget {
  const SettingsSupportScreen({super.key});

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
        title: const Text('Aide & Support', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Comment pouvons-nous vous aider ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
          const SizedBox(height: 24),
          _buildContactCard(Icons.email_rounded, 'Nous contacter par email', 'support@naatalagro.sn', Colors.blue),
          const SizedBox(height: 16),
          _buildContactCard(Icons.phone_rounded, 'Appeler le service client', '+221 77 000 00 00', Colors.green),
          const SizedBox(height: 32),
          const Text('Questions fréquentes (FAQ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
          const SizedBox(height: 16),
          _buildFaqItem('Comment créer une alerte prix ?', 'Allez sur votre profil et cliquez sur "Ajouter" dans la section Mes Alertes Prix.'),
          _buildFaqItem('Comment modifier mes cultures ?', 'Dans l\'onglet Agriculture, vous pouvez gérer vos parcelles et vos cultures.'),
          _buildFaqItem('Comment utiliser l\'assistant IA ?', 'L\'assistant IA est disponible via le bouton flottant au milieu de la barre de navigation en bas.'),
        ],
      ),
    );
  }

  Widget _buildContactCard(IconData icon, String title, String subtitle, Color color) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 14))),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        collapsedBackgroundColor: Colors.white,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        children: [
          Text(answer, style: TextStyle(color: Colors.grey.shade600, height: 1.5)),
        ],
      ),
    );
  }
}
