import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  sinhala('si', 'සිංහල'),
  english('en', 'English');

  final String code;
  final String label;

  const AppLanguage(this.code, this.label);

  static AppLanguage fromCode(String? code) {
    if (code == 'en') return AppLanguage.english;
    return AppLanguage.sinhala;
  }
}

/// Service managing app-wide language selection and persistence.
class AppLanguageService {
  static const String _prefKey = 'app_language';

  /// Reactive notifier for the currently selected language.
  static final ValueNotifier<AppLanguage> currentLanguage =
      ValueNotifier<AppLanguage>(AppLanguage.sinhala);

  static bool get isSinhala => currentLanguage.value == AppLanguage.sinhala;
  static bool get isEnglish => currentLanguage.value == AppLanguage.english;

  /// Initializes the service by loading saved language from SharedPreferences.
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey);
      if (savedCode != null) {
        currentLanguage.value = AppLanguage.fromCode(savedCode);
      }
    } catch (e) {
      debugPrint('Error initializing AppLanguageService: $e');
    }
  }

  /// Sets and persists a new language.
  static Future<void> setLanguage(AppLanguage language) async {
    if (currentLanguage.value == language) return;
    currentLanguage.value = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language.code);
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }
}
