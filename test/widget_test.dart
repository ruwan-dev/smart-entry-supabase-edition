import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_entry/core/localization/app_language.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('App smoke test: Language service initializes', () async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguageService.initialize();
    expect(AppLanguageService.currentLanguage.value, isNotNull);
  });
}
