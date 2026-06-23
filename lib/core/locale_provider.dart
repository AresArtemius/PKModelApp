import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale';

const _ruLocale = Locale('ru');
const _enLocale = Locale('en');

const _supportedLanguageCodes = {'ru', 'en'};

final localeProvider = StateNotifierProvider<LocaleController, Locale?>((ref) {
  return LocaleController();
});

class LocaleController extends StateNotifier<Locale?> {
  LocaleController() : super(null) {
    _load();
  }

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  bool _userOverrodeDuringLoad = false;

  Future<void> _load() async {
    final prefs = await _prefs;
    final saved = prefs.getString(_kLocaleKey);
    if (saved == null || saved.isEmpty) return;

    if (_userOverrodeDuringLoad) return;
    final parsed = _parseLocaleTag(saved);
    if (parsed == null) return;
    state = parsed;
  }

  Future<void> setLocale(Locale? locale) async {
    _userOverrodeDuringLoad = true;
    state = locale;
    final prefs = await _prefs;
    if (locale == null) {
      await prefs.remove(_kLocaleKey);
    } else {
      await prefs.setString(_kLocaleKey, locale.toLanguageTag());
    }
  }

  Future<void> toggle() async {
    final lang = state?.languageCode ?? _enLocale.languageCode;
    final next = (lang == _ruLocale.languageCode) ? _enLocale : _ruLocale;
    await setLocale(next);
  }

  Future<void> resetToSystem() => setLocale(null);

  Locale? _parseLocaleTag(String tag) {
    final cleaned = tag.trim();
    if (cleaned.isEmpty) return null;

    final parts = cleaned.split(RegExp('[-_]'));
    if (parts.isEmpty) return null;

    final languageCode = parts[0];
    if (!_supportedLanguageCodes.contains(languageCode)) return null;

    if (parts.length == 1) return Locale(languageCode);

    final countryCode = parts[1];
    return Locale(languageCode, countryCode);
  }
}
