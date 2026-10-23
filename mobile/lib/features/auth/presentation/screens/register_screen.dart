import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../ui/ui.dart';
import '../../data/auth_provider.dart';

/// Inscription en trois gestes : qui je suis, mon mot de passe, mon code.
///
/// Pensée pour des producteurs qui lisent peu : une seule chose par écran, de gros boutons, peu de texte,
/// une phrase à écouter à chaque étape. Aucun champ inutile (ni e-mail, ni date de naissance, ni région :
/// la région est trouvée toute seule ensuite, avec la suggestion de culture).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const _lastStep = 2;

  int _step = 0;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _accepted = false;

  String _code = '';
  bool _demoCode = false;
  bool _sendingCode = false;
  bool _submitting = false;

  String? _nameError;
  String? _phoneError;
  String? _passwordError;
  String? _termsError;
  String? _submitError;
  String? _codeNote;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  String get _phoneDigits => _phone.text.replaceAll(RegExp(r'\D'), '');

  bool get _passwordHasLength => _password.text.length >= 8;
  bool get _passwordHasLetter => RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(_password.text);

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    if (step == _lastStep) _sendCode();
  }

  void _back() {
    if (_step > 0) {
      _goTo(_step - 1);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  void _next() {
    if (_step == 0) {
      final nameError = _name.text.trim().length < 2 ? 'Écrivez votre nom.' : null;
      final phoneError = _phoneDigits.length != 9 ? 'Le numéro a 9 chiffres.' : null;
      setState(() {
        _nameError = nameError;
        _phoneError = phoneError;
      });
      if (nameError == null && phoneError == null) _goTo(1);
    } else if (_step == 1) {
      final passwordError = !_passwordHasLength || !_passwordHasLetter ? 'Complétez les deux points ci-dessous.' : null;
      final termsError = _accepted ? null : 'Touchez ici pour accepter.';
      setState(() {
        _passwordError = passwordError;
        _termsError = termsError;
      });
      if (passwordError == null && termsError == null) _goTo(2);
    } else {
      _submit();
    }
  }

  /// Demande le code. En l'absence de SMS réel, le serveur renvoie le code d'essai : on l'écrit à la place de l'utilisateur.
  Future<void> _sendCode() async {
    setState(() {
      _sendingCode = true;
      _codeNote = null;
      _submitError = null;
    });
    try {
      final res = await ref.read(authRepositoryProvider).sendOtp(_phoneDigits, purpose: 'register');
      if (!mounted) return;
      setState(() {
        final code = res['code']?.toString();
        _demoCode = code != null && code.isNotEmpty;
        if (_demoCode) {
          _code = code!;
        } else {
          _code = '';
          _codeNote = 'Un SMS vous a été envoyé au $_phoneDigits.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _codeNote = 'Le code n\'est pas arrivé. Touchez « Renvoyer le code ».');
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    // La suggestion de culture est la première chose demandée : on le note avant que la connexion ne déclenche la navigation
    await setCropSetupPending(ref, true);
    await ref.read(authStateProvider.notifier).register(
          fullName: _name.text.trim(),
          phone: _phoneDigits,
          password: _password.text,
          language: 'fr',
          privacyAccepted: true,
          otpCode: _code,
        );
    if (!mounted) return; // inscription réussie : le routeur a déjà changé d'écran
    final auth = ref.read(authStateProvider);
    if (!auth.hasError) return;

    await setCropSetupPending(ref, false);
    if (!mounted) return;
    final message = auth.error.toString().replaceFirst('Exception: ', '');
    final lower = message.toLowerCase();
    setState(() {
      _submitting = false;
      if (lower.contains('mot de passe') || lower.contains('password')) {
        _passwordError = message;
        _step = 1;
      } else if (lower.contains('numéro') || lower.contains('numero') || lower.contains('téléphone') || lower.contains('telephone')) {
        _phoneError = message;
        _step = 0;
      } else {
        _submitError = message;
      }
    });
  }

  String get _spokenHelp {
    switch (_step) {
      case 0:
        return 'Bienvenue sur Naatal Agro. Écrivez votre nom, puis votre numéro de téléphone. Ensuite, touchez le gros bouton vert.';
      case 1:
        return 'Choisissez un mot de passe. Il faut au moins huit signes, avec des lettres. Puis touchez la case pour accepter les règles.';
      default:
        return _demoCode
            ? 'Voici votre code. Il est déjà écrit pour vous. Touchez le gros bouton vert pour créer votre compte.'
            : 'Écrivez le code reçu par SMS, puis touchez le gros bouton vert pour créer votre compte.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.gutter, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _submitting ? null : _back,
                        tooltip: 'Retour',
                        iconSize: 28,
                        constraints: const BoxConstraints(minWidth: Hit.primary, minHeight: Hit.primary),
                        icon: Icon(Icons.arrow_back_rounded, color: c.ink),
                      ),
                      const Spacer(),
                      ReadAloudButton(key: ValueKey('listen$_step$_demoCode'), text: _spokenHelp),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s, Space.gutter, Space.xl),
                    child: Column(
                      children: [
                        AnimatedSize(
                          duration: Motion.base,
                          curve: Motion.out,
                          child: BrandLogo(height: _step == 0 ? 240 : 170),
                        ),
                        const SizedBox(height: Space.xl),
                        _StepDots(current: _step, total: _lastStep + 1),
                        const SizedBox(height: Space.xl),
                        AnimatedSwitcher(
                          duration: Motion.base,
                          switchInCurve: Motion.out,
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(animation),
                              child: child,
                            ),
                          ),
                          child: KeyedSubtree(key: ValueKey(_step), child: _stepBody(context)),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s, Space.gutter, Space.l),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_submitError != null) _Notice(text: _submitError!, error: true),
                      PillButton(
                        label: _step == _lastStep ? 'Créer mon compte' : 'Continuer',
                        icon: _step == _lastStep ? Icons.check_rounded : Icons.arrow_forward_rounded,
                        expand: true,
                        loading: _submitting,
                        onPressed: _submitting ? null : _next,
                      ),
                      if (_step == 0) ...[
                        const SizedBox(height: Space.s),
                        PressScale(
                          onTap: () => context.go('/login'),
                          child: SizedBox(
                            height: Hit.primary,
                            child: Center(
                              child: Text.rich(
                                TextSpan(
                                  text: 'J\'ai déjà un compte  ',
                                  style: T.body(color: c.ink2),
                                  children: [TextSpan(text: 'Me connecter', style: T.body(color: c.accent, weight: 700))],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepBody(BuildContext context) {
    final c = context.c;
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepTitle(title: 'Bienvenue', subtitle: 'Dites-nous qui vous êtes'),
            _Labeled(
              icon: Icons.person_rounded,
              color: c.domainCultures,
              label: 'Votre nom',
              child: TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                style: T.title(color: c.ink),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
                decoration: InputDecoration(hintText: 'Ex : Awa Diop', errorText: _nameError, errorMaxLines: 2),
              ),
            ),
            const SizedBox(height: Space.xl),
            _Labeled(
              icon: Icons.phone_android_rounded,
              color: c.domainMeteo,
              label: 'Votre téléphone',
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: [_SenegalPhoneFormatter()],
                style: T.title(color: c.ink),
                onChanged: (_) {
                  if (_phoneError != null) setState(() => _phoneError = null);
                },
                onSubmitted: (_) => _next(),
                decoration: InputDecoration(
                  hintText: '77 123 45 67',
                  errorText: _phoneError,
                  errorMaxLines: 3,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 18, right: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('+221', style: T.title(color: c.ink2)),
                        const SizedBox(width: 10),
                        Container(width: 1.5, height: 26, color: c.line),
                      ],
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
              ),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepTitle(title: 'Mot de passe', subtitle: 'Pour garder votre compte à vous'),
            _Labeled(
              icon: Icons.lock_rounded,
              color: c.domainStock,
              label: 'Votre mot de passe',
              child: TextField(
                controller: _password,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                style: T.title(color: c.ink),
                onChanged: (_) => setState(() => _passwordError = null),
                decoration: InputDecoration(
                  hintText: 'Au moins 8 signes',
                  errorText: _passwordError,
                  errorMaxLines: 3,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                    tooltip: _showPassword ? 'Cacher' : 'Voir',
                    iconSize: 28,
                    constraints: const BoxConstraints(minWidth: Hit.primary, minHeight: Hit.primary),
                    icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: c.ink2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.m),
            _Rule(ok: _passwordHasLength, text: '8 signes ou plus'),
            _Rule(ok: _passwordHasLetter, text: 'Des lettres (pas que des chiffres)'),
            const SizedBox(height: Space.xl),
            _TermsTile(
              accepted: _accepted,
              error: _termsError,
              onToggle: () => setState(() {
                _accepted = !_accepted;
                _termsError = null;
              }),
              onRead: () => showNaatalSheet<void>(
                context,
                builder: (ctx) => _PolicySheet(onAccept: () {
                  setState(() {
                    _accepted = true;
                    _termsError = null;
                  });
                  Navigator.pop(ctx);
                }),
              ),
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepTitle(title: 'Votre code', subtitle: 'Dernière étape'),
            if (_sendingCode)
              const Padding(
                padding: EdgeInsets.only(bottom: Space.l),
                child: Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3))),
              )
            else if (_demoCode)
              _Notice(text: 'Code d\'essai : ${_code.split('').join(' ')}  (déjà écrit pour vous)')
            else if (_codeNote != null)
              _Notice(text: _codeNote!),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: Space.m),
                  _CodeBox(char: i < _code.length ? _code[i] : '', active: i == _code.length),
                ],
              ],
            ),
            const SizedBox(height: Space.xl),
            NumericKeypad(
              onDigit: (d) {
                if (_code.length < 4) setState(() => _code += d);
              },
              onDelete: () => setState(() => _code = _code.isEmpty ? '' : _code.substring(0, _code.length - 1)),
            ),
            const SizedBox(height: Space.m),
            Center(
              child: PressScale(
                onTap: _sendingCode ? null : _sendCode,
                child: SizedBox(
                  height: Hit.primary,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, color: c.accent),
                      const SizedBox(width: Space.s),
                      Text('Renvoyer le code', style: T.body(color: c.accent, weight: 700)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }
}

/// Numéro sénégalais : 9 chiffres au plus, écrits « 77 123 45 67 », sans l'indicatif collé par l'utilisateur.
class _SenegalPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 9 && digits.startsWith('221')) digits = digits.substring(3);
    if (digits.length > 9) digits = digits.substring(0, 9);
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 5 || i == 7) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: Motion.base,
            curve: Motion.out,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 36 : 12,
            height: 12,
            decoration: BoxDecoration(
              color: i <= current ? c.accent : c.line,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
          ),
      ],
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Column(
        children: [
          Text(title, textAlign: TextAlign.center, style: T.largeTitle(color: c.ink)),
          const SizedBox(height: Space.xs),
          Text(subtitle, textAlign: TextAlign.center, style: T.body(color: c.ink2).copyWith(fontSize: 17)),
        ],
      ),
    );
  }
}

/// Un champ avec une grande icône de couleur et un libellé de deux ou trois mots.
class _Labeled extends StatelessWidget {
  const _Labeled({required this.icon, required this.color, required this.label, required this.child});

  final IconData icon;
  final Color color;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(Radii.s)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: Space.m),
            Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.title(color: c.ink))),
          ],
        ),
        const SizedBox(height: Space.s),
        child,
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: Motion.fast,
            child: Icon(
              ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              key: ValueKey(ok),
              size: 26,
              color: ok ? c.accent : c.ink2,
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(child: Text(text, style: T.body(color: ok ? c.ink : c.ink2, weight: 600))),
        ],
      ),
    );
  }
}

class _TermsTile extends StatelessWidget {
  const _TermsTile({required this.accepted, required this.error, required this.onToggle, required this.onRead});

  final bool accepted;
  final String? error;
  final VoidCallback onToggle;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final borderColor = error != null ? c.clay : (accepted ? c.accent : c.line);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PressScale(
          onTap: onToggle,
          scale: 0.99,
          semanticLabel: 'Accepter les règles d\'utilisation',
          child: AnimatedContainer(
            duration: Motion.fast,
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
            decoration: BoxDecoration(
              color: accepted ? c.accent.withValues(alpha: 0.08) : c.surface,
              borderRadius: BorderRadius.circular(Radii.l),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Row(
              children: [
                Icon(accepted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 36, color: accepted ? c.accent : c.ink2),
                const SizedBox(width: Space.m),
                Expanded(child: Text('J\'accepte les règles d\'utilisation', style: T.body(color: c.ink, weight: 700))),
                PressScale(
                  onTap: onRead,
                  child: Container(
                    height: Hit.min,
                    padding: const EdgeInsets.symmetric(horizontal: Space.l),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.pill)),
                    child: Text('Lire', style: T.body(color: c.accent, weight: 700)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.s, left: Space.s),
            child: Text(error!, style: T.body(color: c.clay, weight: 700)),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = error ? c.clay : c.accent;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.l),
      padding: const EdgeInsets.all(Space.l),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(Radii.m)),
      child: Row(
        children: [
          Icon(error ? Icons.error_rounded : Icons.info_rounded, color: color, size: 26),
          const SizedBox(width: Space.m),
          Expanded(child: Text(text, style: T.body(color: c.ink, weight: 700))),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.char, required this.active});

  final String char;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AnimatedContainer(
      duration: Motion.fast,
      width: 64,
      height: 78,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.m),
        border: Border.all(color: active ? c.accent : c.line, width: active ? 2.5 : 1.5),
      ),
      child: Text(char, style: T.number(36, color: c.ink)),
    );
  }
}

/// Règles d'utilisation, lues depuis le serveur (jamais recopiées ici).
class _PolicySheet extends ConsumerStatefulWidget {
  const _PolicySheet({required this.onAccept});

  final VoidCallback onAccept;

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
            child: Text('Règles d\'utilisation', style: T.title(color: c.ink)),
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
                  padding: const EdgeInsets.fromLTRB(Space.xxl, 0, Space.xxl, Space.l),
                  child: SelectableText(snap.data!, style: T.body(color: c.ink).copyWith(height: 1.5)),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xxl, Space.s, Space.xxl, Space.l),
            child: PillButton(label: 'J\'accepte', icon: Icons.check_rounded, expand: true, onPressed: widget.onAccept),
          ),
        ],
      ),
    );
  }
}
