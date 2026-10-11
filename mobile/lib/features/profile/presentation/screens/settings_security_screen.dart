import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
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
        title: const Text(
          'Sécurité & Confidentialité',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildActionTile(
            Icons.lock_rounded,
            'Changer de mot de passe',
            'Modifier votre mot de passe de connexion',
            onTap: () => _showChangePasswordDialog(context, ref),
          ),
          const SizedBox(height: 16),
          _buildActionTile(
            Icons.download_rounded,
            'Télécharger mes données',
            'Exporter l\'ensemble de vos données (Loi CDP)',
            onTap: () => _exportUserData(context, ref),
          ),
          const SizedBox(height: 16),
          _buildActionTile(
            Icons.delete_forever_rounded,
            'Supprimer mon compte',
            'Suppression définitive et irréversible',
            color: Colors.red,
            onTap: () => _showDeleteAccountDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String subtitle, {
    Color color = Colors.black87,
    required VoidCallback onTap,
  }) {
    final bool isDanger = color == Colors.red;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDanger ? Colors.red.withValues(alpha: 0.1) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isDanger ? Colors.red : AppColors.primary),
          ),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Changer de mot de passe', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPasswordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe actuel',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le nouveau mot de passe',
                    prefixIcon: Icon(Icons.check_circle_outline),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final oldPass = oldPasswordCtrl.text.trim();
                      final newPass = newPasswordCtrl.text.trim();
                      final confirmPass = confirmPasswordCtrl.text.trim();

                      if (oldPass.isEmpty || newPass.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Veuillez renseigner tous les champs.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      if (newPass.length < 8) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Le nouveau mot de passe doit comporter au moins 8 caractères.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      if (newPass != confirmPass) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Les deux nouveaux mots de passe ne correspondent pas.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      setState(() => isSubmitting = true);
                      try {
                        final response = await ref.read(apiClientProvider).post(
                          AppConstants.changePasswordEndpoint,
                          data: {
                            'old_password': oldPass,
                            'new_password': newPass,
                          },
                        );

                        if (response.statusCode == 204 || response.statusCode == 200) {
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Mot de passe changé avec succès ! Veuillez vous reconnecter.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            await ref.read(authStateProvider.notifier).logout();
                          }
                        }
                      } catch (e) {
                        setState(() => isSubmitting = false);
                        String errorMsg = 'Impossible de modifier le mot de passe.';
                        if (e is DioException && e.response?.data != null) {
                          final data = e.response!.data;
                          if (data is Map) {
                            if (data['new_password'] is List && (data['new_password'] as List).isNotEmpty) {
                              errorMsg = (data['new_password'] as List).first.toString();
                            } else if (data['old_password'] is List && (data['old_password'] as List).isNotEmpty) {
                              errorMsg = (data['old_password'] as List).first.toString();
                            } else if (data['error'] != null) {
                              errorMsg = data['error'].toString();
                            }
                          }
                        } else if (e is DioException && e.type == DioExceptionType.connectionError) {
                          errorMsg = 'Connexion réseau impossible. Veuillez réessayer.';
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    final passwordCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Supprimer mon compte', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cette action est irréversible. Toutes vos parcelles, cultures, ventes et historiques seront définitivement effacés.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmez avec votre mot de passe',
                  prefixIcon: Icon(Icons.lock_outline, color: Colors.red),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final password = passwordCtrl.text.trim();
                      if (password.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Veuillez saisir votre mot de passe.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      setState(() => isSubmitting = true);
                      try {
                        final response = await ref.read(apiClientProvider).post(
                          AppConstants.deleteAccountEndpoint,
                          data: {'password': password},
                        );

                        if (response.statusCode == 204 || response.statusCode == 200) {
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Votre compte a été supprimé définitivement.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            await ref.read(authStateProvider.notifier).logout();
                          }
                        }
                      } catch (e) {
                        setState(() => isSubmitting = false);
                        String errorMsg = 'Échec de la suppression du compte.';
                        if (e is DioException && e.response?.data != null) {
                          final data = e.response!.data;
                          if (data is Map && data['error'] != null) {
                            errorMsg = data['error'].toString();
                          }
                        } else if (e is DioException && e.type == DioExceptionType.connectionError) {
                          errorMsg = 'Connexion réseau impossible. Veuillez réessayer.';
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Supprimer définitivement'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportUserData(BuildContext context, WidgetRef ref) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Préparation de vos données personnelles...')),
      );

      final response = await ref.read(apiClientProvider).get(AppConstants.exportDataEndpoint);

      if (response.statusCode == 200 && context.mounted) {
        final data = response.data as Map<String, dynamic>;
        final cropsCount = (data['crops'] as List?)?.length ?? 0;
        final salesCount = (data['sales'] as List?)?.length ?? 0;

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Données prêtes', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Vos données rattachées au compte sont prêtes :\n'
              '• $cropsCount culture(s) enregistrée(s)\n'
              '• $salesCount vente(s) / transaction(s)\n'
              '• Historique IA et profil sécurisé\n\n'
              'Toutes vos données restent sous votre contrôle exclusif (Loi CDP).',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du téléchargement des données.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
