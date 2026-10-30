import 'package:flutter/material.dart';

import '../../../../ui/ui.dart';
class SettingsSupportScreen extends StatelessWidget {
  const SettingsSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.c.bg,
      appBar: AppBar(
        backgroundColor: context.c.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.c.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Aide & Support', style: TextStyle(color: context.c.ink, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Comment pouvons-nous vous aider ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: context.c.ink)),
          const SizedBox(height: 24),
          _buildContactCard(context, Icons.email_rounded, 'Nous contacter par email', 'support@naatalagro.sn', Colors.blue),
          const SizedBox(height: 16),
          _buildContactCard(context, Icons.phone_rounded, 'Appeler le service client', '+221 77 000 00 00', Colors.green),
          const SizedBox(height: 32),
          Text('Questions fréquentes (FAQ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: context.c.ink)),
          const SizedBox(height: 16),
          _buildFaqItem(context, 'Comment créer une alerte prix ?', 'Allez sur votre profil et cliquez sur "Ajouter" dans la section Mes Alertes Prix.'),
          _buildFaqItem(context, 'Comment modifier mes cultures ?', 'Dans l\'onglet Agriculture, vous pouvez gérer vos parcelles et vos cultures.'),
          _buildFaqItem(context, 'Comment utiliser l\'assistant IA ?', 'L\'assistant IA est disponible via le bouton flottant au milieu de la barre de navigation en bas.'),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, IconData icon, String title, String subtitle, Color color) {
    return Container(
      decoration: BoxDecoration(color: context.c.surface, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.c.ink)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(subtitle, style: TextStyle(color: context.c.ink2, fontSize: 14))),
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        collapsedBackgroundColor: context.c.surface,
        backgroundColor: context.c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        children: [
          Text(answer, style: TextStyle(color: context.c.ink2, height: 1.5)),
        ],
      ),
    );
  }
}
