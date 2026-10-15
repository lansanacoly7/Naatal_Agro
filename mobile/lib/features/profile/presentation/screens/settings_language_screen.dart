import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/locale_provider.dart';

class SettingsLanguageScreen extends ConsumerStatefulWidget {
  const SettingsLanguageScreen({super.key});

  @override
  ConsumerState<SettingsLanguageScreen> createState() => _SettingsLanguageScreenState();
}

class _SettingsLanguageScreenState extends ConsumerState<SettingsLanguageScreen> {
  final List<Map<String, String>> _languages = [
    {'code': 'fr', 'name': 'Français (Sénégal)', 'subtitle': 'Langue par défaut'},
    {'code': 'wo', 'name': 'Wolof (Senegaal)', 'subtitle': 'Làkku réew mi'},
  ];

  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(localeProvider);
    final tr = ref.watch(stringsProvider);

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
        title: Text(
          tr('language_title'),
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _languages.length,
        itemBuilder: (context, index) {
          final lang = _languages[index];
          final isSelected = currentLocale == lang['code'];

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    lang['code'] == 'wo' ? Icons.record_voice_over_rounded : Icons.language_rounded,
                    color: isSelected ? AppColors.primary : Colors.grey,
                    size: 22,
                  ),
                ),
                title: Text(
                  lang['name']!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isSelected ? AppColors.primary : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  lang['subtitle']!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onTap: () async {
                  await ref.read(localeProvider.notifier).setLocale(lang['code']!);
                  if (context.mounted) {
                    final msg = lang['code'] == 'wo'
                        ? 'Làkk bi soppee na ci Wolof'
                        : 'Langue configurée : Français';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
                    );
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
