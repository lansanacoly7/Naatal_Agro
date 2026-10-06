import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/auth_provider.dart';

class SettingsSecurityScreen extends ConsumerWidget {
  const SettingsSecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          _buildActionTile(Icons.lock_rounded, 'Changer de mot de passe', 'Dernière modification : il y a 3 mois', onTap: () {
            _showChangePasswordDialog(context, ref);
          }),
          const SizedBox(height: 16),
          _buildActionTile(Icons.devices_rounded, 'Appareils connectés', '1 appareil actif', onTap: () {}),
          const SizedBox(height: 16),
          _buildActionTile(Icons.delete_forever_rounded, 'Supprimer mon compte', 'Action irréversible', color: Colors.red, onTap: () {
            _showDeleteAccountDialog(context, ref);
          }),
        ],
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle, {Color color = Colors.black87, required VoidCallback onTap}) {
    final bool isDanger = color == Colors.red;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: isDanger ? Colors.red.withValues(alpha: 0.1) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: isDanger ? Colors.red : AppColors.primary),
          ),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          subtitle: Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Changer de mot de passe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Ancien mot de passe'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(apiClientProvider).post(
                  '/users/auth/change-password/',
                  data: {
                    'old_password': oldPasswordCtrl.text,
                    'new_password': newPasswordCtrl.text,
                  },
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe changé avec succès !'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le compte', style: TextStyle(color: Colors.red)),
        content: const Text('Êtes-vous sûr de vouloir supprimer définitivement votre compte ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ref.read(apiClientProvider).post('/privacy/account/delete/');
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ref.read(authStateProvider.notifier).logout();
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
