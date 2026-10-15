import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../features/auth/data/auth_provider.dart';
import '../../features/profile/data/notifications_provider.dart';
import '../../features/profile/data/profile_provider.dart';
import '../../features/profile/domain/profile_model.dart';
import '../../ui/ui.dart';

/// Profil : identité, exploitation, préférences, sécurité et données personnelles.
/// Rien n'est affiché qui ne soit réellement pris en charge par l'application.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final profile = ref.watch(profileNotifierProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);
    final reduced = ref.watch(effectsReducedProvider);

    return LargeTitleScaffold(
      title: 'Profil',
      reserveNav: false,
      onRefresh: () => ref.read(profileNotifierProvider.notifier).loadProfile(),
      slivers: [
        SliverToBoxAdapter(
          child: profile.when(
            loading: () => const Padding(padding: EdgeInsets.all(Space.gutter), child: Skeleton(height: 140, radius: 28)),
            error: (e, _) => ErrorState(
              message: 'Votre profil n\'a pas pu être chargé.',
              onRetry: () => ref.read(profileNotifierProvider.notifier).loadProfile(),
            ),
            data: (p) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: _IdentityCard(profile: p, onEdit: () => showNaatalSheet<void>(context, builder: (ctx) => _EditProfileSheet(profile: p))),
                ),
                const SectionHeader('Mon exploitation'),
                GroupedList(
                  children: [
                    GroupedRow(
                      leading: IconTile(icon: Icons.eco_rounded, color: c.accent),
                      title: 'Mes cultures',
                      value: '${p.cropsCount}',
                      chevron: true,
                      onTap: () => context.go('/agriculture'),
                    ),
                    GroupedRow(
                      leading: IconTile(icon: Icons.inventory_2_rounded, color: c.slate),
                      title: 'Mon stock',
                      chevron: true,
                      onTap: () => context.push('/stock'),
                    ),
                    GroupedRow(
                      leading: IconTile(icon: Icons.account_balance_wallet_rounded, color: c.clay),
                      title: 'Mes finances',
                      chevron: true,
                      onTap: () => context.push('/finances'),
                    ),
                  ],
                ),
                const SectionHeader('Préférences'),
                GroupedList(
                  children: [
                    GroupedRow(
                      leading: IconTile(icon: Icons.notifications_rounded, color: c.accent),
                      title: 'Notifications',
                      subtitle: 'Alertes dans l\'application',
                      value: unread > 0 ? '$unread non lue${unread > 1 ? 's' : ''}' : null,
                      valueColor: c.clay,
                      chevron: true,
                      onTap: () => context.push('/notifications'),
                    ),
                    GroupedRow(
                      leading: IconTile(icon: Icons.speed_rounded, color: c.slate),
                      title: 'Effets réduits',
                      subtitle: 'Moins de flou et d\'animations : plus fluide sur un téléphone modeste',
                      trailing: Switch.adaptive(
                        value: reduced,
                        activeTrackColor: c.accent,
                        onChanged: (v) => ref.read(effectsReducedProvider.notifier).set(v),
                      ),
                    ),
                    GroupedRow(
                      leading: IconTile(icon: Icons.language_rounded, color: c.slate),
                      title: 'Langue',
                      subtitle: 'Le wolof n\'est pas encore disponible',
                      value: 'Français',
                    ),
                  ],
                ),
                const SectionHeader('Sécurité et données'),
                GroupedList(
                  children: [
                    GroupedRow(
                      leading: IconTile(icon: Icons.lock_rounded, color: c.accent),
                      title: 'Changer le mot de passe',
                      chevron: true,
                      onTap: () => showNaatalSheet<void>(context, builder: (ctx) => const _ChangePasswordSheet()),
                    ),
                    GroupedRow(
                      leading: IconTile(icon: Icons.download_rounded, color: c.slate),
                      title: 'Récupérer mes données',
                      subtitle: 'Copie de toutes vos données (JSON)',
                      chevron: true,
                      onTap: () => _exportData(context, ref),
                    ),
                    GroupedRow(
                      leading: IconTile(icon: Icons.policy_rounded, color: c.slate),
                      title: 'Politique de confidentialité',
                      chevron: true,
                      onTap: () => showNaatalSheet<void>(context, builder: (ctx) => const _PolicySheet()),
                    ),
                    GroupedRow(
                      leading: IconTile(icon: Icons.delete_forever_rounded, color: c.clay),
                      title: 'Supprimer mon compte',
                      subtitle: 'Efface définitivement toutes vos données',
                      chevron: true,
                      onTap: () => showNaatalSheet<void>(context, builder: (ctx) => const _DeleteAccountSheet()),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: PillButton(
                    label: 'Se déconnecter',
                    icon: Icons.logout_rounded,
                    variant: PillVariant.danger,
                    expand: true,
                    onPressed: () async {
                      final ok = await confirmDialog(
                        context,
                        title: 'Se déconnecter ?',
                        message: 'Vous devrez saisir à nouveau votre numéro et votre mot de passe.',
                        confirmLabel: 'Se déconnecter',
                        destructive: true,
                      );
                      if (ok) await ref.read(authStateProvider.notifier).logout();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: Space.l),
                  child: Center(
                    child: Text('${AppConstants.appName} · version ${AppConstants.appVersion}', style: T.caption(color: c.ink2, weight: 500)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Préparation de vos données…')));
    try {
      final response = await ref.read(apiClientProvider).get(AppConstants.exportDataEndpoint);
      final data = response.data;
      if (data is! Map) throw Exception('format');
      final summary = '${(data['crops'] as List?)?.length ?? 0} culture(s), ${(data['sales'] as List?)?.length ?? 0} vente(s), ${(data['stock_items'] as List?)?.length ?? 0} produit(s) en stock';
      final json = const JsonEncoder.withIndent('  ').convert(Map<String, dynamic>.from(data));
      await Clipboard.setData(ClipboardData(text: json));
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Données copiées ($summary). Collez-les dans une note ou un e-mail.')));
    } catch (_) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('Impossible de récupérer vos données. Vérifiez votre réseau.')));
    }
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile, required this.onEdit});

  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AuroraBackground(
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [c.gold, const Color(0xFFF08A6A)])),
                  child: Text(profile.initials, style: T.number(24, color: const Color(0xFF2B1700))),
                ),
                const SizedBox(width: Space.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.fullName.isEmpty ? 'Producteur' : profile.fullName, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.title(color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(profile.phone, style: T.body(color: Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.l),
            Row(
              children: [
                Expanded(
                  child: Glass(
                    style: GlassStyle.onHero,
                    radius: Radii.pill,
                    padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: 9),
                    child: Row(
                      children: [
                        const Icon(Icons.place_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            profile.location.isEmpty ? 'Région non renseignée' : profile.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.caption(color: Colors.white, weight: 700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Space.s),
                PillButton(label: 'Modifier', variant: PillVariant.light, compact: true, onPressed: onEdit),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _location = TextEditingController(text: widget.profile.location);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Le nom ne peut pas être vide.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileNotifierProvider.notifier).updateProfile(
            fullName: _name.text.trim(),
            location: _location.text.trim(),
          );
      ref.invalidate(profileNotifierProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Modification impossible. Vérifiez votre réseau.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Modifier mon profil', style: T.title(color: c.ink)),
          const SizedBox(height: Space.l),
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nom complet')),
          const SizedBox(height: Space.m),
          TextField(
            controller: _location,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Région',
              helperText: 'Sert à la météo et aux prix près de chez vous.',
              errorText: _error,
            ),
          ),
          const SizedBox(height: Space.xl),
          PillButton(label: 'Enregistrer', expand: true, loading: _busy, onPressed: _busy ? null : _save),
        ],
      ),
    );
  }
}

String _apiError(Object e, String fallback) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      for (final v in data.values) {
        if (v is List && v.isNotEmpty) return v.first.toString();
        if (v is String && v.isNotEmpty) return v;
      }
    }
  }
  return fallback;
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_old.text.isEmpty || _new.text.length < 8) {
      setState(() => _error = 'Saisissez votre mot de passe actuel et un nouveau d\'au moins 8 caractères.');
      return;
    }
    if (_new.text != _confirm.text) {
      setState(() => _error = 'Les deux nouveaux mots de passe ne correspondent pas.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).post(AppConstants.changePasswordEndpoint, data: {'old_password': _old.text, 'new_password': _new.text}, queueWhenOffline: false);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe changé. Reconnectez-vous.')));
      await ref.read(authStateProvider.notifier).logout();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _apiError(e, 'Changement impossible. Vérifiez votre réseau.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Changer le mot de passe', style: T.title(color: c.ink)),
          const SizedBox(height: Space.xs),
          Text('Vous serez déconnecté de tous vos appareils.', style: T.body(color: c.ink2)),
          const SizedBox(height: Space.l),
          TextField(controller: _old, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe actuel')),
          const SizedBox(height: Space.m),
          TextField(controller: _new, obscureText: true, decoration: const InputDecoration(labelText: 'Nouveau mot de passe')),
          const SizedBox(height: Space.m),
          TextField(controller: _confirm, obscureText: true, decoration: InputDecoration(labelText: 'Confirmer le nouveau mot de passe', errorText: _error, errorMaxLines: 3)),
          const SizedBox(height: Space.xl),
          PillButton(label: 'Changer le mot de passe', expand: true, loading: _busy, onPressed: _busy ? null : _save),
        ],
      ),
    );
  }
}

class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();

  @override
  ConsumerState<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Saisissez votre mot de passe pour confirmer.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).post(AppConstants.deleteAccountEndpoint, data: {'password': _password.text}, queueWhenOffline: false);
      if (!mounted) return;
      Navigator.pop(context);
      await ref.read(authStateProvider.notifier).logout();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _apiError(e, 'Suppression impossible. Vérifiez votre réseau.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Supprimer mon compte', style: T.title(color: c.clay)),
          const SizedBox(height: Space.xs),
          Text(
            'Vos cultures, ventes, stocks, notifications et échanges avec l\'assistant seront effacés définitivement. Cette action ne peut pas être annulée.',
            style: T.body(color: c.ink2),
          ),
          const SizedBox(height: Space.l),
          TextField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: 'Votre mot de passe', errorText: _error, errorMaxLines: 3)),
          const SizedBox(height: Space.xl),
          PillButton(label: 'Supprimer définitivement', variant: PillVariant.danger, expand: true, loading: _busy, onPressed: _busy ? null : _delete),
        ],
      ),
    );
  }
}

class _PolicySheet extends ConsumerStatefulWidget {
  const _PolicySheet();

  @override
  ConsumerState<_PolicySheet> createState() => _PolicySheetState();
}

class _PolicySheetState extends ConsumerState<_PolicySheet> {
  late final Future<String> _text = _load();

  Future<String> _load() async {
    final response = await ref.read(apiClientProvider).get(AppConstants.privacyPolicyEndpoint);
    final data = response.data;
    if (data is Map) return '${data['content'] ?? ''}'.replaceAll('#', '').trim();
    throw Exception('format');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.m),
            child: Text('Politique de confidentialité', style: T.title(color: c.ink)),
          ),
          Expanded(
            child: FutureBuilder<String>(
              future: _text,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(Space.xxl), child: Skeleton(height: 200, radius: 16));
                }
                if (snap.hasError) {
                  return const ErrorState(compact: true, message: 'Le texte n\'a pas pu être chargé. Vérifiez votre réseau.');
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Space.xxl, 0, Space.xxl, Space.xxl),
                  child: SelectableText(snap.data!, style: T.body(color: c.ink).copyWith(height: 1.5)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
