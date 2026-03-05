import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/l10n/app_localizations.dart';

const _kLanguageKey = 'app_language';

final localeProvider =
    StateNotifierProvider<LocaleNotifier, AppLocalizations>(
  (ref) => LocaleNotifier(),
);

class LocaleNotifier extends StateNotifier<AppLocalizations> {
  LocaleNotifier() : super(const AppLocalizations()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLanguageKey);
    if (code == 'en') {
      state = const AppLocalizations(language: AppLanguage.en);
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    state = AppLocalizations(language: lang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguageKey, lang.name);
  }

  Future<void> toggle() async {
    final next = state.language == AppLanguage.th
        ? AppLanguage.en
        : AppLanguage.th;
    await setLanguage(next);
  }
}
