import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_provider.dart';
import '../../ui/ui.dart';
import 'auth_widgets.dart';

const _regions = ['Dakar', 'Thiès', 'Saint-Louis', 'Louga', 'Diourbel', 'Fatick', 'Kaolack', 'Kaffrine', 'Tambacounda', 'Kédougou', 'Kolda', 'Sédhiou', 'Ziguinchor', 'Matam'];
const _crops = ['Riz', 'Oignon', 'Arachide', 'Maïs', 'Tomate', 'Mil', 'Maraîchage'];

/// Inscription en 4 étapes : identité, mot de passe, exploitation, code de vérification.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  int _step = 0;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  bool _hidden = true;
  bool _consent = false;
  String? _region;
  final Set<String> _selectedCrops = {};
  bool _busy = false;
  String? _error;
  String? _demoCode;

  @override
  void dispose() {
    for (final c in [_name, _phone, _password, _confirm, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  static const _titles = ['Créer votre compte', 'Sécurisez votre compte', 'Votre exploitation', 'Vérification'];
  static const _subtitles = [
    'Quelques informations pour commencer.',
    'Choisissez un mot de passe d\'au moins 8 caractères.',
    'Pour des conseils adaptés à votre région.',
    'Entrez le code à 4 chiffres reçu par SMS.',
  ];

  String? _validate() {
    switch (_step) {
      case 0:
        if (_name.text.trim().isEmpty) return 'Saisissez votre nom complet.';
        if (_phone.text.replaceAll(RegExp(r'\D'), '').length < 9) return 'Saisissez un numéro de téléphone valide.';
      case 1:
        if (_password.text.length < 8) return 'Le mot de passe doit contenir au moins 8 caractères.';
        if (_password.text != _confirm.text) return 'Les deux mots de passe sont différents.';
        if (!_consent) return 'Acceptez la politique de confidentialité pour continuer.';
      case 2:
        if (_region == null) return 'Choisissez votre région.';
    }
    return null;
  }

  Future<void> _next() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() => _error = null);
    if (_step < 2) {
      setState(() => _step++);
    } else if (_step == 2) {
      await _sendCode();
    } else {
      await _finish();
    }
  }

  Future<void> _sendCode() async {
    setState(() => _busy = true);
    try {
      final res = await ref.read(authRepositoryProvider).sendOtp(_phone.text.trim(), purpose: 'register');
      if (!mounted) return;
      setState(() {
        _demoCode = res['demo'] == true ? res['code']?.toString() : null;
        _step = 3;
      });
    } catch (e) {
      if (mounted) setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_code.text.trim().length != 4) {
      setState(() => _error = 'Saisissez le code à 4 chiffres.');
      return;
    }
    setState(() => _busy = true);
    try {
      final ok = await ref.read(authRepositoryProvider).verifyOtp(_phone.text.trim(), _code.text, purpose: 'register');
      if (!ok) throw Exception('Code invalide ou expiré.');
      await ref.read(authStateProvider.notifier).register(
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            password: _password.text,
            location: '${_region!}, Sénégal',
            mainCrops: _selectedCrops.toList(),
            privacyAccepted: _consent,
            otpCode: _code.text.trim(),
          );
      final state = ref.read(authStateProvider);
      if (mounted && state.hasError) setState(() => _error = authError(state.error!));
    } catch (e) {
      if (mounted) setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() {
    if (_step == 0) {
      context.canPop() ? context.pop() : context.go('/login');
    } else {
      setState(() {
        _step--;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AuthScaffold(
        title: _titles[_step],
        subtitle: _subtitles[_step],
        onBack: _back,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(value: (_step + 1) / 4, minHeight: 6, backgroundColor: c.line, color: c.accent),
          ),
          const SizedBox(height: Space.l),
          if (_error != null) AuthMessage(_error!),
          AnimatedSwitcher(
            duration: Motion.base,
            switchInCurve: Motion.out,
            child: KeyedSubtree(key: ValueKey(_step), child: _stepBody(c)),
          ),
          const SizedBox(height: Space.xl),
          PillButton(
            label: switch (_step) {
              2 => 'Recevoir le code',
              3 => 'Créer mon compte',
              _ => 'Continuer',
            },
            expand: true,
            loading: _busy || (_step == 3 && ref.watch(authStateProvider).isLoading),
            onPressed: _next,
          ),
          if (_step == 0) ...[
            const SizedBox(height: Space.m),
            Center(
              child: TextButton(
                onPressed: () => context.go('/login'),
                child: Text('J\'ai déjà un compte', style: T.caption(color: c.accent, weight: 700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepBody(NaatalColors c) {
    switch (_step) {
      case 0:
        return Column(children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.person_rounded)),
          ),
          const SizedBox(height: Space.m),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Numéro de téléphone', prefixText: '+221  ', prefixIcon: Icon(Icons.phone_rounded)),
          ),
        ]);
      case 1:
        return Column(children: [
          TextField(
            controller: _password,
            obscureText: _hidden,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                icon: Icon(_hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
            ),
          ),
          const SizedBox(height: Space.m),
          TextField(
            controller: _confirm,
            obscureText: _hidden,
            decoration: const InputDecoration(labelText: 'Confirmer le mot de passe', prefixIcon: Icon(Icons.lock_outline_rounded)),
          ),
          const SizedBox(height: Space.m),
          GroupedList(children: [
            GroupedRow(
              title: 'J\'accepte la politique de confidentialité',
              subtitle: 'Vos données servent uniquement à vous conseiller.',
              trailing: Switch(value: _consent, onChanged: (v) => setState(() => _consent = v)),
              onTap: () => setState(() => _consent = !_consent),
            ),
          ]),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Région', style: T.body(color: c.ink, weight: 700)),
          const SizedBox(height: Space.s),
          _chips(_regions, (v) => _region == v, (v) => setState(() => _region = v)),
          const SizedBox(height: Space.l),
          Text('Cultures principales (facultatif)', style: T.body(color: c.ink, weight: 700)),
          const SizedBox(height: Space.s),
          _chips(
            _crops,
            _selectedCrops.contains,
            (v) => setState(() => _selectedCrops.contains(v) ? _selectedCrops.remove(v) : _selectedCrops.add(v)),
          ),
        ]);
      default:
        return Column(children: [
          if (_demoCode != null) DemoCodeCard(code: _demoCode!, onUse: () => setState(() => _code.text = _demoCode!)),
          OtpField(controller: _code),
          TextButton(onPressed: _busy ? null : _sendCode, child: Text('Renvoyer le code', style: T.caption(color: c.accent, weight: 700))),
        ]);
    }
  }

  Widget _chips(List<String> values, bool Function(String) selected, void Function(String) onTap) {
    final c = context.c;
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        for (final v in values)
          PressScale(
            onTap: () => onTap(v),
            child: AnimatedContainer(
              duration: Motion.base,
              padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: 12),
              decoration: BoxDecoration(
                color: selected(v) ? c.accent : c.surface,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: selected(v) ? c.accent : c.line),
              ),
              child: Text(v, style: T.caption(color: selected(v) ? c.onAccent : c.ink, weight: 700)),
            ),
          ),
      ],
    );
  }
}
