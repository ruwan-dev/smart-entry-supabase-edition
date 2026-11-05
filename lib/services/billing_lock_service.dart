import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_state.dart';

class BillingLockService {
  static final BillingLockService _instance = BillingLockService._internal();
  factory BillingLockService() => _instance;
  BillingLockService._internal();

  DateTime? _latestFinalizedMonth;
  String? _cachedOrgId;

  DateTime? get latestFinalizedMonth => _latestFinalizedMonth;

  /// Parses a month-year string such as "2026-August", "2026 August", "2026-08",
  /// or org-scoped keys such as "<orgId>_2026-August" into a DateTime pointing to the 1st day of that month.
  static DateTime? parseMonthYear(String? str) {
    if (str == null || str.trim().isEmpty) return null;
    String toParse = str.trim();
    if (toParse.contains('_')) {
      toParse = toParse.split('_').last;
    }
    final clean = toParse.replaceAll('-', ' ');
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      int? y = int.tryParse(parts[0]);
      if (y != null) {
        int? m = int.tryParse(parts[1]);
        if (m != null && m >= 1 && m <= 12) {
          return DateTime(y, m, 1);
        }
        const monthNames = [
          'january', 'february', 'march', 'april', 'may', 'june',
          'july', 'august', 'september', 'october', 'november', 'december'
        ];
        int idx = monthNames.indexOf(parts[1].toLowerCase()) + 1;
        if (idx >= 1 && idx <= 12) {
          return DateTime(y, idx, 1);
        }
      }
    }
    return null;
  }

  /// Fetches the latest finalized month across all monthly summaries and bills for the organization
  Future<DateTime?> fetchLatestFinalizedMonth({bool forceRefresh = false}) async {
    final orgId = AppState.currentOrganizationId.value ?? '';
    if (orgId.isEmpty) {
      _latestFinalizedMonth = null;
      _cachedOrgId = null;
      return null;
    }

    if (!forceRefresh && _cachedOrgId == orgId && _latestFinalizedMonth != null) {
      return _latestFinalizedMonth;
    }

    try {
      DateTime? maxMonth;

      // 1. Fetch from monthly_summaries
      final summaries = await Supabase.instance.client
          .from('monthly_summaries')
          .select('id, finalizedAt')
          .eq('organization_id', orgId);

      for (var s in summaries) {
        final dt = parseMonthYear(s['id']?.toString());
        if (dt != null) {
          if (maxMonth == null || dt.isAfter(maxMonth)) {
            maxMonth = dt;
          }
        }
      }

      // 2. Also check finalized_bills for safety
      final bills = await Supabase.instance.client
          .from('finalized_bills')
          .select('billData')
          .eq('organization_id', orgId)
          .order('finalizedAt', ascending: false)
          .limit(20);

      for (var b in bills) {
        final dm = b['billData']?['displayMonth']?.toString();
        final dt = parseMonthYear(dm);
        if (dt != null) {
          if (maxMonth == null || dt.isAfter(maxMonth)) {
            maxMonth = dt;
          }
        }
      }

      _cachedOrgId = orgId;
      _latestFinalizedMonth = maxMonth;
      return maxMonth;
    } catch (e) {
      debugPrint('Error fetching latest finalized month: $e');
      return _latestFinalizedMonth;
    }
  }

  /// Checks if a date falls strictly before the latest finalized month.
  /// If true, the entries for this month are locked and read-only.
  bool isDateLocked(DateTime date) {
    if (_latestFinalizedMonth == null) return false;
    final targetMonth = DateTime(date.year, date.month, 1);
    return targetMonth.isBefore(_latestFinalizedMonth!);
  }

  /// Checks if a given month is the latest finalized month eligible for recalculation.
  /// (Older months before this month cannot be recalculated).
  bool isLatestFinalizedMonth(String? monthStr) {
    if (_latestFinalizedMonth == null) return true; // If no summaries exist, default to true
    final dt = parseMonthYear(monthStr);
    if (dt == null) return false;
    return dt.year == _latestFinalizedMonth!.year && dt.month == _latestFinalizedMonth!.month;
  }

  /// Reset cache (e.g. on logout or org switch)
  void clearCache() {
    _latestFinalizedMonth = null;
    _cachedOrgId = null;
  }
}
