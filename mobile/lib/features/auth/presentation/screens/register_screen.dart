import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 1;

  // Step 1: Infos
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();

  // Step 2: Security
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptTerms = false;

  // Step 3: Profil Agricole
  String? _selectedRegion;
  final List<String> _regions = ['Dakar', 'Thiès', 'Saint-Louis', 'Louga', 'Diourbel', 'Fatick', 'Kaolack', 'Kaffrine', 'Tambacounda', 'Kédougou', 'Kolda', 'Sédhiou', 'Ziguinchor', 'Matam'];
  
  final List<String> _availableCrops = ['Riz', 'Oignon', 'Arachide', 'Maïs', 'Maraîchage', 'Tomate', 'Mil'];
  final List<String> _selectedCrops = [];

  // Step 4: OTP
  final _otpController = TextEditingController();
  bool _isVerifying = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 1) {
      if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
        _showError('Veuillez remplir le nom et le numéro de téléphone.');
        return;
      }
    } else if (_currentStep == 2) {
      if (_passwordController.text.length < 8) {
        _showError('Le mot de passe doit contenir au moins 8 caractères.');
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        _showError('Les mots de passe ne correspondent pas.');
        return;
      }
      if (!_acceptTerms) {
        _showError('Veuillez accepter les conditions d\'utilisation.');
        return;
      }
    } else if (_currentStep == 3) {
      if (_selectedRegion == null) {
        _showError('Veuillez sélectionner une région.');
        return;
      }
      if (_selectedCrops.isEmpty) {
        _showError('Veuillez sélectionner au moins une culture.');
        return;
      }
      // Logique pour passer à l'OTP sans appeler l'API tout de suite (pour l'UI de la prez)
    }

    if (_currentStep < 4) {
      setState(() => _currentStep++);
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/login');
      }
    }
  }

  Future<void> _verifyAndRegister() async {
    if (_otpController.text.length < 4) {
      _showError('Veuillez entrer un code OTP valide.');
      return;
    }

    setState(() => _isVerifying = true);
    
    // Simulate OTP verification delay
    await Future.delayed(const Duration(seconds: 1));

    // Actually register via backend
    await ref.read(authStateProvider.notifier).register(
      _nameController.text.trim(),
      _phoneController.text.trim(),
      _passwordController.text,
      'fr',
      _selectedRegion ?? 'Sénégal',
    );

    final authState = ref.read(authStateProvider);
    if (authState.hasError && mounted) {
      setState(() => _isVerifying = false);
      _showError(authState.error.toString());
    }
    // Si succès, le routeur s'en chargera
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6), // Fond légèrement cassé
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _previousStep,
        ),
        title: const Text('Naatal Agro', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.blue.withValues(alpha: 0.2), // Ligne pointillée (simplifiée par une ligne bleue claire)
            height: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    String title = '';
    switch (_currentStep) {
      case 1: title = 'Informations personnelles'; break;
      case 2: title = 'Sécurité'; break;
      case 3: title = 'Profil agricole'; break;
      case 4: title = 'Vérification'; break;
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ÉTAPE $_currentStep SUR 4', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1.2)),
              Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _currentStep / 4,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primary), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5), textAlign: TextAlign.center),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildLabel(String label, {bool isOptional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13)),
          if (isOptional)
            const Text('Optionnel', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed, {bool showIcon = true, bool isVerifying = false}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isVerifying ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 0,
        ),
        child: isVerifying 
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (showIcon) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 20),
                ]
              ],
            ),
      ),
    );
  }

  // ==========================================
  // ETAPE 1: Infos
  // ==========================================
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('Faisons connaissance', 'Veuillez renseigner vos informations de base pour commencer à cultiver avec précision.'),
          
          _buildLabel('Nom complet'),
          _buildTextField(controller: _nameController, hint: 'Ex: Moussa Sidibé', icon: Icons.person_outline),

          _buildLabel('Numéro de téléphone'),
          _buildTextField(controller: _phoneController, hint: '+221 77 123 45 67', icon: Icons.phone_outlined, type: TextInputType.phone),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Nous l\'utiliserons pour la connexion et les alertes importantes.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),

          _buildLabel('Adresse e-mail', isOptional: true),
          _buildTextField(controller: _emailController, hint: 'moussa@exemple.com', icon: Icons.mail_outline, type: TextInputType.emailAddress),

          _buildLabel('Date de naissance'),
          _buildTextField(controller: _dobController, hint: 'jj/mm/aaaa', icon: Icons.calendar_today_outlined, type: TextInputType.datetime),

          const SizedBox(height: 16),
          _buildButton('Suivant', _nextStep),
        ],
      ),
    );
  }

  // ==========================================
  // ETAPE 2: Sécurité
  // ==========================================
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('Protégez votre compte', 'Choisissez un mot de passe robuste pour sécuriser vos données agricoles.'),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Mot de passe'),
                _buildTextField(
                  controller: _passwordController,
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Minimum 8 caractères, incluant lettres et chiffres.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ),

                _buildLabel('Confirmer le mot de passe'),
                _buildTextField(
                  controller: _confirmPasswordController,
                  hint: '••••••••',
                  icon: Icons.replay_outlined,
                  obscure: _obscureConfirm,
                  suffixIcon: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)),
                ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 24, width: 24,
                      child: Checkbox(
                        value: _acceptTerms,
                        onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                        activeColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'J\'accepte les ',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          children: [
                            TextSpan(text: 'conditions d\'utilisation', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                            TextSpan(text: ' et la '),
                            TextSpan(text: 'politique de confidentialité.', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ]
                        )
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildButton('Suivant', _nextStep),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ETAPE 3: Profil Agricole
  // ==========================================
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('Profil agricole', 'Aidez-nous à personnaliser vos recommandations en nous en disant plus sur votre exploitation.'),
          
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle), child: const Icon(Icons.map_outlined, color: Colors.white)),
                    const SizedBox(width: 16),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Localisation', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      Text('Région principale d\'activité', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ])),
                  ],
                ),
                const SizedBox(height: 24),
                _buildLabel('Sélectionnez une région'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedRegion,
                      hint: const Text('Choisir une région...', style: TextStyle(fontSize: 14)),
                      items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setState(() => _selectedRegion = v),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(Icons.grass_outlined, color: Colors.white)),
                    const SizedBox(width: 16),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Cultures', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      Text('Sélectionnez vos cultures principales', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ])),
                  ],
                ),
                const SizedBox(height: 24),
                _buildLabel('Plusieurs choix possibles'),
                Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  children: [
                    ..._availableCrops.map((crop) {
                      final isSelected = _selectedCrops.contains(crop);
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedCrops.remove(crop);
                            } else {
                              _selectedCrops.add(crop);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
                            border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(crop, style: TextStyle(color: isSelected ? AppColors.primary : Colors.grey[700], fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        ),
                      );
                    }),
                    InkWell(
                      onTap: () => _showAddCropDialog(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.3), style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('Autre', style: TextStyle(color: Colors.grey[700])),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildButton('S\'inscrire', _nextStep, showIcon: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCropDialog() {
    final customCropController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter une culture', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: customCropController,
          decoration: const InputDecoration(
            hintText: 'Ex: Coton, Manioc...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = customCropController.text.trim();
              if (val.isNotEmpty) {
                setState(() {
                  if (!_availableCrops.contains(val)) {
                    _availableCrops.add(val);
                  }
                  if (!_selectedCrops.contains(val)) {
                    _selectedCrops.add(val);
                  }
                });
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ETAPE 4: OTP
  // ==========================================
  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('Vérification', 'Un code de vérification à 4 chiffres a été envoyé au ${_phoneController.text}.'),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Code OTP'),
                _buildTextField(
                  controller: _otpController,
                  hint: '----',
                  icon: Icons.message_outlined,
                  type: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildButton('Vérifier', _verifyAndRegister, showIcon: false, isVerifying: _isVerifying),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
