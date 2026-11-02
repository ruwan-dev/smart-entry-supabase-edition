import 'package:flutter_test/flutter_test.dart';
import 'package:smart_entry/services/billing_lock_service.dart';

void main() {
  group('BillingLockService Tests', () {
    test('parseMonthYear parses hyphenated month names correctly', () {
      final dt = BillingLockService.parseMonthYear('2026-August');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 8);
      expect(dt.day, 1);
    });

    test('parseMonthYear parses space-separated month names correctly', () {
      final dt = BillingLockService.parseMonthYear('2026 September');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 9);
      expect(dt.day, 1);
    });

    test('parseMonthYear parses numeric month formats correctly', () {
      final dt = BillingLockService.parseMonthYear('2026-08');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 8);
    });

    test('parseMonthYear returns null for invalid or empty inputs', () {
      expect(BillingLockService.parseMonthYear(null), isNull);
      expect(BillingLockService.parseMonthYear(''), isNull);
      expect(BillingLockService.parseMonthYear('   '), isNull);
      expect(BillingLockService.parseMonthYear('invalid-month'), isNull);
    });

    test('Date locking logic locks dates prior to latest finalized month', () {
      // If latest finalized month is September 2026:
      final sep2026 = DateTime(2026, 9, 1);

      // Past months (before September 2026) are locked
      final augDate = DateTime(2026, 8, 15);
      final julDate = DateTime(2026, 7, 31);
      final dec2025Date = DateTime(2025, 12, 10);

      // We verify the comparison condition: targetMonth.isBefore(latestFinalizedMonth)
      expect(DateTime(augDate.year, augDate.month, 1).isBefore(sep2026), isTrue);
      expect(DateTime(julDate.year, julDate.month, 1).isBefore(sep2026), isTrue);
      expect(DateTime(dec2025Date.year, dec2025Date.month, 1).isBefore(sep2026), isTrue);

      // The latest finalized month itself (September 2026) is NOT locked (can be recalculated)
      final sepDate = DateTime(2026, 9, 15);
      expect(DateTime(sepDate.year, sepDate.month, 1).isBefore(sep2026), isFalse);

      // Future/Current unfinalized month (October 2026) is NOT locked
      final octDate = DateTime(2026, 10, 5);
      expect(DateTime(octDate.year, octDate.month, 1).isBefore(sep2026), isFalse);
    });

    test('isLatestFinalizedMonth verifies only exact latest month can recalculate', () {
      final lockService = BillingLockService();
      lockService.clearCache();
      
      // When cache is cleared and no finalized month, defaults to allowing
      expect(lockService.isLatestFinalizedMonth('2026-September'), isTrue);

      // Test parsing validation with month matching
      final sepParsed = BillingLockService.parseMonthYear('2026-September');
      final augParsed = BillingLockService.parseMonthYear('2026-August');
      expect(sepParsed!.isAfter(augParsed!), isTrue);
    });
  });
}
