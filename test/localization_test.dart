import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_entry/core/localization/app_language.dart';
import 'package:smart_entry/core/localization/app_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AppLanguageService defaults to Sinhala and updates properly', () async {
    await AppLanguageService.initialize();
    expect(AppLanguageService.currentLanguage.value, AppLanguage.sinhala);
    expect(AppStrings.isSinhala, isTrue);
    expect(AppStrings.isEnglish, isFalse);

    // Verify Sinhala strings
    expect(AppStrings.save, 'සුරකින්න');
    expect(AppStrings.cancel, 'අවලංගු කරන්න');
    expect(AppStrings.customers, 'පාරිභෝගිකයින්');
    expect(AppStrings.overview, 'දළ විශ්ලේෂණය');

    // Switch to English
    await AppLanguageService.setLanguage(AppLanguage.english);
    expect(AppLanguageService.currentLanguage.value, AppLanguage.english);
    expect(AppStrings.isSinhala, isFalse);
    expect(AppStrings.isEnglish, isTrue);

    // Verify English strings
    expect(AppStrings.save, 'Save');
    expect(AppStrings.cancel, 'Cancel');
    expect(AppStrings.customers, 'Customers');
    expect(AppStrings.overview, 'Overview');
  });

  test('AppStrings returns localized month names', () async {
    await AppLanguageService.setLanguage(AppLanguage.sinhala);
    expect(AppStrings.getMonthName(1), 'ජනවාරි');
    expect(AppStrings.getMonthName(12), 'දෙසැම්බර්');
    expect(AppStrings.getMonthShortName(1), 'ජන');
    expect(AppStrings.getMonthShortName(11), 'නොවැ');

    await AppLanguageService.setLanguage(AppLanguage.english);
    expect(AppStrings.getMonthName(1), 'January');
    expect(AppStrings.getMonthName(12), 'December');
    expect(AppStrings.getMonthShortName(1), 'Jan');
    expect(AppStrings.getMonthShortName(11), 'Nov');
  });

  test('AppStrings formats display month and recalculation dialog strings in both languages', () async {
    await AppLanguageService.setLanguage(AppLanguage.sinhala);
    expect(AppStrings.formatDisplayMonth('2026 September'), '2026 සැප්තැම්බර්');
    expect(AppStrings.metric, 'මිණුම');
    expect(AppStrings.current, 'වත්මන්');
    expect(AppStrings.recalculated, 'නැවත සැකසූ');
    expect(AppStrings.difference, 'වෙනස');
    expect(AppStrings.confirmAndUpdateBill, 'තහවුරු කර බිල්පත යාවත්කාලීන කරන්න');
    expect(AppStrings.recalculateBillTitle('2026 සැප්තැම්බර්'), 'බිල්පත නැවත සකසන්න - 2026 සැප්තැම්බර්');
    expect(AppStrings.onlyLatestBillCanBeRecalculated, 'නැවත සකස් කළ හැක්කේ අවසන් මාසයේ බිල්පත පමණි.');
    expect(AppStrings.updatedBy, 'යාවත්කාලීන කළේ');
    expect(AppStrings.updatedByNameRequired, 'කරුණාකර ඔබගේ නම ඇතුළත් කරන්න.');
    expect(AppStrings.youHaveBillChanges, 'බිල්පතෙහි නව වෙනස්කම් ඇත!');
    expect(AppStrings.billChangesPrompt, 'දෛනික සටහන් හෝ ගාස්තු වල අලුත් වෙනස්කම් හමු විය. කරුණාකර බිල්පත නැවත සකසන්න.');
    expect(AppStrings.noBillChangesDetected, 'වෙනස්කම් කිසිවක් හමු නොවීය. මෙම බිල්පත දැනටමත් දෛනික සටහන් සමඟ සම්පූර්ණයෙන්ම යාවත්කාලීනයි.');
    expect(AppStrings.billUpToDate, 'බිල්පත යාවත්කාලීනයි');
    expect(AppStrings.billChangesDetected, 'නව වෙනස්කම් ඇත');

    await AppLanguageService.setLanguage(AppLanguage.english);
    expect(AppStrings.formatDisplayMonth('2026 September'), '2026 September');
    expect(AppStrings.metric, 'Metric');
    expect(AppStrings.current, 'Current');
    expect(AppStrings.recalculated, 'Recalculated');
    expect(AppStrings.difference, 'Difference');
    expect(AppStrings.confirmAndUpdateBill, 'Confirm & Update Bill');
    expect(AppStrings.recalculateBillTitle('2026 September'), 'Recalculate Bill - 2026 September');
    expect(AppStrings.onlyLatestBillCanBeRecalculated, 'Only the latest finalized monthly bill can be recalculated.');
    expect(AppStrings.updatedBy, 'Updated by');
    expect(AppStrings.updatedByNameRequired, 'Please enter your name.');
    expect(AppStrings.youHaveBillChanges, 'You have bill changes!');
    expect(AppStrings.billChangesPrompt, 'Daily entries or rates for this month have been updated. Please recalculate this bill.');
    expect(AppStrings.noBillChangesDetected, 'No changes detected. This bill is already fully up to date with daily entries.');
    expect(AppStrings.billUpToDate, 'Bill is up to date');
    expect(AppStrings.billChangesDetected, 'Changes Detected');
  });
}
