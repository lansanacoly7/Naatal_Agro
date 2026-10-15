import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../features/profile/data/profile_provider.dart';
import 'app_strings.dart';

const String _prefLocaleKey = 'selected_app_locale';

final localeProvider = StateNotifierProvider<LocaleNotifier, String>((ref) {
  return LocaleNotifier(ref);
});

class LocaleNotifier extends StateNotifier<String> {
  final Ref _ref;

  LocaleNotifier(this._ref) : super('fr') {
    _initLocale();
  }

  void _initLocale() {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final savedLocale = prefs.getString(_prefLocaleKey);
      if (savedLocale != null && savedLocale.isNotEmpty) {
        state = savedLocale.toLowerCase();
        return;
      }
      final profile = _ref.read(profileNotifierProvider).valueOrNull;
      if (profile != null && profile.language.isNotEmpty) {
        final code = profile.language.toLowerCase();
        state = code.startsWith('w') ? 'wo' : 'fr';
      }
    } catch (_) {
      state = 'fr';
    }
  }

  Future<void> setLocale(String langCode) async {
    final normalized = langCode.toLowerCase().startsWith('w') ? 'wo' : 'fr';
    state = normalized;
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      await prefs.setString(_prefLocaleKey, normalized);
    } catch (_) {}

    try {
      await _ref.read(profileNotifierProvider.notifier).updateProfile(
        language: normalized.toUpperCase(),
      );
    } catch (_) {}
  }

  bool get isWolof => state == 'wo';
}

final stringsProvider = Provider<String Function(String key)>((ref) {
  final locale = ref.watch(localeProvider);
  return (String key) => AppStrings.get(key, locale: locale);
});
