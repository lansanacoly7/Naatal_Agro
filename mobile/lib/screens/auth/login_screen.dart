import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_provider.dart';
import '../../ui/ui.dart';
import 'auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_phone.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Saisissez votre numéro et votre mot de passe.');
      return;
    }
    setState(() => _error = null);
    await ref.read(authStateProvider.notifier).login(_phone.text.trim(), _password.text);
    final state = ref.read(authStateProvider);
    if (mounted && state.hasError) setState(() => _error = authError(state.error!));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loading = ref.watch(authStateProvider).isLoading;
    return AuthScaffold(
      title: 'Bon retour',
      subtitle: 'Connectez-vous pour retrouver vos cultures.',
      children: [
        if (_error != null) AuthMessage(_error!),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: const InputDecoration(labelText: 'Numéro de téléphone', hintText: '77 123 45 67', prefixText: '+221  ', prefixIcon: Icon(Icons.phone_rounded)),
        ),
        const SizedBox(height: Space.m),
        TextField(
          controller: _password,
          obscureText: _hidden,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            prefixIcon: const Icon(Icons.lock_rounded),
            suffixIcon: IconButton(
              icon: Icon(_hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded),
              tooltip: _hidden ? 'Afficher' : 'Masquer',
              onPressed: () => setState(() => _hidden = !_hidden),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => showForgotPasswordSheet(context, initialPhone: _phone.text),
            child: Text('Mot de passe oublié ?', style: T.caption(color: c.accent, weight: 700)),
          ),
        ),
        const SizedBox(height: Space.s),
        PillButton(label: 'Se connecter', expand: true, loading: loading, onPressed: _submit),
        const SizedBox(height: Space.l),
        PillButton(label: 'Créer un compte', expand: true, variant: PillVariant.secondary, onPressed: () => context.push('/register')),
      ],
    );
  }
}

/// Réinitialisation du mot de passe : numéro, code reçu par SMS, nouveau mot de passe.
Future<void> showForgotPasswordSheet(BuildContext context, {String initialPhone = ''}) {
  return showNaatalSheet<void>(context, builder: (_) => _ForgotSheet(initialPhone: initialPhone));
}

class _ForgotSheet extends ConsumerStatefulWidget {
  const _ForgotSheet({required this.initialPhone});

  final String initialPhone;

  @override
  ConsumerState<_ForgotSheet> createState() => _ForgotSheetState();
}

class _ForgotSheetState extends ConsumerState<_ForgotSheet> {
  late final _phone = TextEditingController(text: widget.initialPhone);
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _demoCode;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = 'Saisissez votre numéro de téléphone.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref.read(authRepositoryProvider).sendOtp(_phone.text.trim(), purpose: 'password_reset');
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _demoCode = res['demo'] == true ? res['code']?.toString() : null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_code.text.trim().length != 4) {
      setState(() => _error = 'Saisissez le code à 4 chiffres.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resetPassword(_phone.text.trim(), _code.text, _password.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Mot de passe modifié. Connectez-vous.')));
    } catch (e) {
      if (mounted) setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Mot de passe oublié', style: T.title(color: c.ink)),
          const SizedBox(height: Space.xs),
          Text(
            _codeSent ? 'Entrez le code reçu puis choisissez un nouveau mot de passe.' : 'Nous envoyons un code de vérification à votre numéro.',
            style: T.body(color: c.ink2),
          ),
          const SizedBox(height: Space.l),
          if (_error != null) AuthMessage(_error!),
          if (!_codeSent) ...[
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Numéro de téléphone', prefixText: '+221  '),
            ),
            const SizedBox(height: Space.l),
            PillButton(label: 'Recevoir le code', expand: true, loading: _busy, onPressed: _send),
          ] else ...[
            if (_demoCode != null) DemoCodeCard(code: _demoCode!, onUse: () => setState(() => _code.text = _demoCode!)),
            OtpField(controller: _code),
            const SizedBox(height: Space.m),
            TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Nouveau mot de passe')),
            const SizedBox(height: Space.l),
            PillButton(label: 'Changer le mot de passe', expand: true, loading: _busy, onPressed: _reset),
            TextButton(onPressed: _busy ? null : _send, child: Text('Renvoyer le code', style: T.caption(color: c.accent, weight: 700))),
          ],
        ],
      ),
    );
  }
}
