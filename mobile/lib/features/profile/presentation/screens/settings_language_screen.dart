import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SettingsLanguageScreen extends StatefulWidget {
  const SettingsLanguageScreen({super.key});

  @override
  State<SettingsLanguageScreen> createState() => _SettingsLanguageScreenState();
}

class _SettingsLanguageScreenState extends State<SettingsLanguageScreen> {
  String _selectedLanguage = 'fr';

  final List<Map<String, String>> _languages = [
    {'code': 'fr', 'name': 'Français'},
    {'code': 'wo', 'name': 'Wolof (Prochainement)'},
    {'code': 'pu', 'name': 'Pulaar (Prochainement)'},
  ];

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
        title: const Text('Langue', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _languages.length,
        itemBuilder: (context, index) {
          final lang = _languages[index];
          final isSelected = _selectedLanguage == lang['code'];
          final isAvailable = lang['code'] == 'fr';
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: RadioListTile<String>(
                title: Text(lang['name']!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isAvailable ? Colors.black87 : Colors.grey)),
                value: lang['code']!,
                groupValue: _selectedLanguage,
                activeColor: AppColors.primary,
                onChanged: isAvailable ? (val) {
                  if (val != null) setState(() => _selectedLanguage = val);
                } : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          );
        },
      ),
    );
  }
}
