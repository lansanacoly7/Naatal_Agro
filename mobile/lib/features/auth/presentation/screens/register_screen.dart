import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constantes locales
// ─────────────────────────────────────────────────────────────────────────────
const _kPrimary = AppColors.primary;
const _kBg = AppColors.background;
const _kSurface = AppColors.surface;
const _kTextPrimary = AppColors.textPrimary;
const _kTextSecondary = AppColors.textSecondary;

const List<Map<String, String>> _kRegions = [
  {'value': 'dakar', 'label': 'Dakar'},
  {'value': 'thies', 'label': 'Thiès'},
  {'value': 'saint_louis', 'label': 'Saint-Louis'},
  {'value': 'kaolack', 'label': 'Kaolack'},
  {'value': 'ziguinchor', 'label': 'Ziguinchor'},
  {'value': 'tambacounda', 'label': 'Tambacounda'},
  {'value': 'kolda', 'label': 'Kolda'},
  {'value': 'matam', 'label': 'Matam'},
  {'value': 'kaffrine', 'label': 'Kaffrine'},
  {'value': 'kedougou', 'label': 'Kédougou'},
  {'value': 'louga', 'label': 'Louga'},
  {'value': 'fatick', 'label': 'Fatick'},
  {'value': 'sedhiou', 'label': 'Sédhiou'},
  {'value': 'diourbel', 'label': 'Diourbel'},
];

const List<Map<String, dynamic>> _kCrops = [
  {'value': 'riz', 'label': 'Riz', 'emoji': '🌾'},
  {'value': 'arachide', 'label': 'Arachide', 'emoji': '🥜'},
  {'value': 'mais', 'label': 'Maïs', 'emoji': '🌽'},
  {'value': 'maraichage', 'label': 'Maraîchage', 'emoji': '🥬'},
  {'value': 'mil', 'label': 'Mil', 'emoji': '🌱'},
  {'value': 'coton', 'label': 'Coton', 'emoji': '🪴'},
  {'value': 'niebe', 'label': 'Niébé', 'emoji': '🫘'},
  {'value': 'manioc', 'label': 'Manioc', 'emoji': '🌿'},
];

// ─────────────────────────────────────────────────────────────────────────────
// Widget principal
// ─────────────────────────────────────────────────────────────────────────────
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 5;

  // Contrôleurs
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // État
  String _selectedRole = 'farmer';
  String? _selectedRegion;
  final List<String> _selectedCrops = [];
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _termsAccepted = false;

  // Animation
  late final AnimationController _progressAnimController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1 / _totalSteps)
        .animate(CurvedAnimation(parent: _progressAnimController, curve: Curves.easeOutCubic));
    _progressAnimController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _progressAnimController.dispose();
    super.dispose();
  }

  // ──────────────────── Navigation ────────────────────

  void _animateProgress(int targetStep) {
    final begin = _progressAnimation.value;
    final end = (targetStep + 1) / _totalSteps;
    _progressAnimation = Tween<double>(begin: begin, end: end)
        .animate(CurvedAnimation(parent: _progressAnimController, curve: Curves.easeOutCubic));
    _progressAnimController
      ..reset()
      ..forward();
  }

  void _goToStep(int step) {
    _animateProgress(step);
    _pageController.animateToPage(step,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    FocusScope.of(context).unfocus();
    final next = _currentStep + 1;
    if (next < _totalSteps) _goToStep(next);
  }

  void _prevStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    } else {
      context.pop();
    }
  }

  // ──────────────────── Validation ────────────────────

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 1: // Identité
        if (_nameController.text.trim().isEmpty) {
          _showError('Veuillez entrer votre prénom et nom.');
          return false;
        }
        if (_phoneController.text.trim().isEmpty) {
          _showError('Veuillez entrer votre numéro de téléphone.');
          return false;
        }
        return true;
      case 2: // Sécurité
        if (_passwordController.text.length < 8) {
          _showError('Le mot de passe doit comporter au moins 8 caractères.');
          return false;
        }
        if (!RegExp(r'[0-9]').hasMatch(_passwordController.text)) {
          _showError('Le mot de passe doit contenir au moins un chiffre.');
          return false;
        }
        if (_passwordController.text != _confirmPasswordController.text) {
          _showError('Les mots de passe ne correspondent pas.');
          return false;
        }
        if (!_termsAccepted) {
          _showError('Veuillez accepter les conditions d\'utilisation.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ──────────────────── Soumission ────────────────────

  Future<void> _handleRegister() async {
    if (!_validateCurrentStep()) return;
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    await ref.read(authStateProvider.notifier).register(
      name,
      phone,
      password,
      'fr',
      '',
      role: _selectedRole,
      confirmPassword: confirm,
      region: _selectedRegion,
      primaryCrops: _selectedCrops,
    );

    if (!mounted) return;
    final authState = ref.read(authStateProvider);
    authState.when(
      data: (isAuthenticated) {
        if (isAuthenticated) {
          context.go('/');
        } else {
          _showError('Inscription échouée, veuillez réessayer.');
        }
      },
      error: (e, _) {
        _showError(e.toString().replaceFirst('Exception: ', ''));
      },
      loading: () {},
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authStateProvider).isLoading;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildStepRole(),
                  _buildStepIdentity(),
                  _buildStepSecurity(isLoading),
                  _buildStepFarmDetails(),
                  _buildStepConfirmation(isLoading),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────── Header avec progress ────────────────────

  Widget _buildHeader() {
    final stepLabels = ['Profil', 'Identité', 'Sécurité', 'Exploitation', 'Confirmation'];
    final label = stepLabels[_currentStep];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _prevStep,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _kTextPrimary),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Inscription',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Étape ${_currentStep + 1} sur $_totalSteps',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _kPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progressAnimation.value,
                minHeight: 4,
                backgroundColor: _kTextSecondary.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(_kPrimary),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ─────────────────── Étape 1 : Rôle ───────────────────────────

  Widget _buildStepRole() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Qui êtes-vous ?',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Choisissez votre profil pour une expérience personnalisée.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 40),
          _roleCard(
            value: 'farmer',
            label: 'Agriculteur',
            subtitle: 'Gérez vos cultures, la météo et l\'IA',
            icon: Icons.agriculture_rounded,
          ),
          const SizedBox(height: 16),
          _roleCard(
            value: 'buyer',
            label: 'Acheteur B2B',
            subtitle: 'Accédez au marché des producteurs',
            icon: Icons.storefront_rounded,
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _nextStep,
            child: const Text('Continuer →'),
          ),
        ],
      ),
    );
  }

  Widget _roleCard({required String value, required String label, required String subtitle, required IconData icon}) {
    final isSelected = _selectedRole == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary.withValues(alpha: 0.06) : _kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _kPrimary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: isSelected ? _kPrimary : _kTextSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : _kTextSecondary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isSelected ? _kPrimary : _kTextPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: _kTextSecondary)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: _kPrimary, size: 22),
          ],
        ),
      ),
    );
  }

  // ─────────────────── Étape 2 : Identité ────────────────────────

  Widget _buildStepIdentity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Votre identité',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Ces informations personnalisent votre espace Naatal Agro.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 36),
          _inputLabel('Prénom et Nom'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Ex: Mamadou Diallo',
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: _kTextSecondary),
              filled: true,
              fillColor: _kSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 20),
          _inputLabel('Numéro de téléphone'),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '77 123 45 67',
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🇸🇳', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text('+221', style: TextStyle(fontWeight: FontWeight.w600, color: _kTextPrimary)),
                    const SizedBox(width: 10),
                    Container(width: 1, height: 22, color: _kTextSecondary.withValues(alpha: 0.3)),
                  ],
                ),
              ),
              filled: true,
              fillColor: _kSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => _nextStep(),
          ),
          const SizedBox(height: 40),
          ElevatedButton(onPressed: _nextStep, child: const Text('Continuer →')),
        ],
      ),
    );
  }

  // ─────────────────── Étape 3 : Sécurité ────────────────────────

  Widget _buildStepSecurity(bool isLoading) {
    final pw = _passwordController.text;
    final has8chars = pw.length >= 8;
    final hasNumber = RegExp(r'[0-9]').hasMatch(pw);
    final hasSymbol = RegExp(r'[!@#\$&*~]').hasMatch(pw);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(pw);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: _kPrimary, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 20),
          Text('Protégez votre compte',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Choisissez un mot de passe robuste pour sécuriser vos données agricoles.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 28),
          _inputLabel('Mot de passe'),
          const SizedBox(height: 8),
          StatefulBuilder(
            builder: (_, setLocalState) => TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: _kTextSecondary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20, color: _kTextSecondary,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: _kSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Indicateurs de robustesse
          Wrap(
            spacing: 12, runSpacing: 8,
            children: [
              _pwRequirement('8+ caractères', has8chars),
              _pwRequirement('Un chiffre', hasNumber),
              _pwRequirement('Un symbole', hasSymbol),
              _pwRequirement('Une majuscule', hasUpper),
            ],
          ),
          const SizedBox(height: 20),
          _inputLabel('Confirmer le mot de passe'),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20, color: _kTextSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20, color: _kTextSecondary,
                ),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              filled: true,
              fillColor: _kSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => setState(() => _termsAccepted = !_termsAccepted),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: _termsAccepted ? _kPrimary : Colors.transparent,
                    border: Border.all(color: _termsAccepted ? _kPrimary : _kTextSecondary, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _termsAccepted
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 13, color: _kTextSecondary),
                      children: [
                        const TextSpan(text: 'J\'accepte les '),
                        TextSpan(
                          text: 'Conditions d\'utilisation',
                          style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(text: ' et la '),
                        TextSpan(
                          text: 'Politique de confidentialité',
                          style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: isLoading ? null : _nextStep,
            child: const Text('Continuer →'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _prevStep,
            child: const Text('← Retour à l\'étape précédente'),
          ),
        ],
      ),
    );
  }

  Widget _pwRequirement(String label, bool met) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 14,
          color: met ? _kPrimary : _kTextSecondary,
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: met ? _kPrimary : _kTextSecondary)),
      ],
    );
  }

  // ─────────────────── Étape 4 : Détails exploitation ────────────

  Widget _buildStepFarmDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Détails de l\'exploitation',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Aidez-nous à personnaliser vos recommandations selon votre région et vos cultures.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          _inputLabel('Région principale'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRegion,
                isExpanded: true,
                hint: const Text('Sélectionnez une région', style: TextStyle(color: _kTextSecondary)),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kTextSecondary),
                onChanged: (val) => setState(() => _selectedRegion = val),
                items: _kRegions.map((r) => DropdownMenuItem<String>(
                      value: r['value'],
                      child: Text(r['label']!),
                    )).toList(),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _inputLabel('Cultures principales'),
          const SizedBox(height: 4),
          Text('Sélectionnez tout ce qui s\'applique',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: _kCrops.map((crop) {
              final val = crop['value'] as String;
              final isSelected = _selectedCrops.contains(val);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedCrops.remove(val);
                  } else {
                    _selectedCrops.add(val);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? _kPrimary : _kSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _kPrimary : _kTextSecondary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(crop['emoji'] as String, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        crop['label'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : _kTextPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: _kPrimary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ces informations nous permettent de vous envoyer des alertes météo et des conseils agronomiques spécifiques à vos cultures.',
                    style: TextStyle(fontSize: 12, color: _kPrimary.withValues(alpha: 0.85)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _prevStep,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: const BorderSide(color: _kPrimary),
                  ),
                  child: const Text('Retour', style: TextStyle(color: _kPrimary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  child: const Text('Suivant →'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────── Étape 5 : Confirmation ────────────────────

  Widget _buildStepConfirmation(bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: _kPrimary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: _kPrimary, size: 44),
            ),
          ),
          const SizedBox(height: 24),
          Text('Tout est prêt !',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Vérifiez vos informations avant de finaliser votre inscription.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          _summaryCard(
            children: [
              _summaryRow(Icons.person_rounded, 'Nom', _nameController.text.isNotEmpty ? _nameController.text : '—'),
              _summaryRow(Icons.phone_rounded, 'Téléphone', _phoneController.text.isNotEmpty ? '+221 ${_phoneController.text}' : '—'),
              _summaryRow(
                _selectedRole == 'farmer' ? Icons.agriculture_rounded : Icons.storefront_rounded,
                'Rôle',
                _selectedRole == 'farmer' ? 'Agriculteur' : 'Acheteur B2B',
              ),
              if (_selectedRegion != null)
                _summaryRow(Icons.location_on_rounded, 'Région',
                    _kRegions.firstWhere((r) => r['value'] == _selectedRegion)['label']!),
              if (_selectedCrops.isNotEmpty)
                _summaryRow(Icons.grass_rounded, 'Cultures',
                    _selectedCrops.map((c) => _kCrops.firstWhere((k) => k['value'] == c)['label']).join(', ')),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text('S\'inscrire ✓'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: isLoading ? null : _prevStep,
            child: const Text('← Retour'),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: List.generate(children.length, (i) => Column(
          children: [
            children[i],
            if (i < children.length - 1) Divider(height: 24, color: _kTextSecondary.withValues(alpha: 0.1)),
          ],
        )),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _kPrimary),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: _kTextSecondary, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(color: _kTextPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  // ──────────────── Helpers UI ────────────────────────────────

  Widget _inputLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _kTextPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }
}
