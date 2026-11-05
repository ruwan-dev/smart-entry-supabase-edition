import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'outstanding_list_screen.dart';
import 'total_outstanding_balances_screen.dart';
import 'top_suppliers_screen.dart';
import 'customer_analysis_screen.dart';
import '../../core/widgets/skeleton_box.dart';
import 'package:smart_entry/core/app_state.dart';
import '../../core/items/item_service.dart';
import 'package:smart_entry/core/localization/app_strings.dart';
import 'package:smart_entry/core/localization/app_language.dart';
import 'package:smart_entry/services/billing_lock_service.dart';

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class DashboardItemSummary {
  final int slotIndex;
  final String name;
  final String code;
  final double qty;
  final double amount;
  final Color color;

  DashboardItemSummary({
    required this.slotIndex,
    required this.name,
    required this.code,
    required this.qty,
    required this.amount,
    required this.color,
  });
}

class WeeklyHarvestData {
  final int weekNumber;
  final String label;
  final String dateRange;
  final double normalWeight;
  final double superWeight;
  final double totalWeight;

  const WeeklyHarvestData({
    required this.weekNumber,
    required this.label,
    required this.dateRange,
    required this.normalWeight,
    required this.superWeight,
    required this.totalWeight,
  });
}

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  String _selectedFilter = 'This Month';
  bool _isLoading = true;
  bool _isSummaryLoading = true;

  bool _isMonthlySummaryExpanded = false;

  double _totalWeight = 0.0;
  int _totalCustomers = 0;

  // Today's Operational Telemetry
  double _todayTotalWeight = 0.0;
  double _todayNormalWeight = 0.0;
  double _todaySuperWeight = 0.0;
  int _todaySuppliersCount = 0;

  double _overallOutstandingAdvances = 0.0;

  // Organization Financial & Yield Analytics
  double _totalFactoryRevenue = 0.0;
  double _totalSupplierPayout = 0.0;
  double _netDealerIncome = 0.0;
  double _dealerMarginPerKg = 0.0;
  double _totalFactoryDeliveredWeight = 0.0;
  double _normalLeafWeight = 0.0;
  double _superLeafWeight = 0.0;
  double _superLeafPercentage = 0.0;
  int _activeSuppliersCount = 0;

  double _totalFertilizerQty = 0.0;
  double _totalTeaPacketQty = 0.0;
  double _totalOtherItemsQty = 0.0;
  double _totalItemsCost = 0.0;
  double _totalItemsQty = 0.0;
  List<DashboardItemSummary> _activeItemsSummary = [];
  Map<String, double> _itemBreakdownQuantities = {};
  Map<String, double> _itemBreakdownAmounts = {};

  static const List<Color> _itemSlotColors = [
    Color(0xFF059669), // Slot 1: Emerald Green (e.g. Fertilizer 1)
    Color(0xFF0D9488), // Slot 2: Teal (e.g. Fertilizer 2)
    Color(0xFF0284C7), // Slot 3: Sky Blue (e.g. Tea Packet 1)
    Color(0xFF6366F1), // Slot 4: Indigo (e.g. Tea Packet 2)
    Color(0xFF8B5CF6), // Slot 5: Purple
    Color(0xFFD946EF), // Slot 6: Fuchsia
    Color(0xFFF59E0B), // Slot 7: Amber
    Color(0xFFEF4444), // Slot 8: Rose Red
  ];

  Map<String, dynamic>? _latestSummaryData;
  String? _latestSummaryId;
  Map<String, dynamic>? _previousSummaryData;

  double fert1Price = 0, fert2Price = 0, teaPkt1Price = 0, teaPkt2Price = 0;

  List<Map<String, dynamic>> _topSuppliers = [];
  List<Map<String, dynamic>> _allSuppliers = [];
  List<Map<String, dynamic>> _allArrears = [];

  String _chartFilter = 'Monthly';
  bool _isChartLoading = true;
  List<double> _chartIncomeValues = [];
  List<double> _chartExpenseValues = [];
  List<String> _chartLabels = [];
  List<Map<String, dynamic>> _allMonthlySummaries = [];
  int _graphFocusedMonth = 0;
  int _lastAvailableDataMonth = 0;

  void _selectGraphMonth(int month) {
    if (month == _graphFocusedMonth) return;
    setState(() {
      _graphFocusedMonth = month;
    });
  }

  Map<int, double> _heatmapData = {}; // day -> weight
  Map<int, double> _heatmapNormalData = {}; // day -> normal leaf weight
  Map<int, double> _heatmapSuperData = {}; // day -> super leaf weight
  String _harvestChartMode = 'weekly'; // 'weekly' or 'suppliers'
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int get _heatmapMonth => _selectedMonth;
  int get _heatmapYear => _selectedYear;
  bool _isHeatmapLoading = true;
  double _heatmapMaxWeight = 0;

  final List<String> _chartFilterOptions = ['Monthly', 'Yearly'];

  final Color primaryAppColor = const Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    AppState.refreshTrigger.addListener(_onRefresh);
    AppLanguageService.currentLanguage.addListener(_onLanguageChanged);
    _fetchDashboardData(isFullRefresh: true);
    _fetchChartData();
    _fetchHeatmapData();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  void _onRefresh() {
    _fetchDashboardData(isFullRefresh: true);
    _fetchChartData();
    _fetchHeatmapData();
  }

  @override
  void dispose() {
    AppState.refreshTrigger.removeListener(_onRefresh);
    AppLanguageService.currentLanguage.removeListener(_onLanguageChanged);
    super.dispose();
  }

  /// Safely converts any DB value (num, String, int, double, null) to double.
  static double _toDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? fallback;
  }

  Future<void> _fetchHeatmapData() async {
    setState(() {
      _isHeatmapLoading = true;
      _heatmapData = {};
      _heatmapNormalData = {};
      _heatmapSuperData = {};
      _heatmapMaxWeight = 0;
    });

    final orgId = AppState.currentOrganizationId.value ?? '';
    final String monthStr = _selectedMonth.toString().padLeft(2, '0');
    final int lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final String startDateStr = '$_selectedYear-$monthStr-01';
    final String endDateStr =
        '$_selectedYear-$monthStr-${lastDay.toString().padLeft(2, '0')}';
    final DateTime startDt = DateTime(_selectedYear, _selectedMonth, 1);
    final DateTime endDt =
        DateTime(_selectedYear, _selectedMonth, lastDay, 23, 59, 59, 999);

    try {
      List<dynamic> snapshot = [];
      int offset = 0;
      int limit = 1000;

      // 1. Primary strategy: query by 'date' column (YYYY-MM-DD), standard across all app modules
      while (true) {
        var chunk = await Supabase.instance.client
            .from('daily_entries')
            .select('date, timestamp, netWeight, netWeight2')
            .eq('organization_id', orgId)
            .gte('date', startDateStr)
            .lte('date', endDateStr)
            .range(offset, offset + limit - 1);
        snapshot.addAll(chunk);
        if (chunk.length < limit) break;
        offset += limit;
      }

      // 2. Fallback strategy: if no rows found by 'date', query by 'timestamp'
      if (snapshot.isEmpty) {
        offset = 0;
        while (true) {
          var chunk = await Supabase.instance.client
              .from('daily_entries')
              .select('date, timestamp, netWeight, netWeight2')
              .eq('organization_id', orgId)
              .gte('timestamp', startDt.toIso8601String())
              .lte('timestamp', endDt.toIso8601String())
              .range(offset, offset + limit - 1);
          snapshot.addAll(chunk);
          if (chunk.length < limit) break;
          offset += limit;
        }
      }

      Map<int, double> data = {};
      Map<int, double> normData = {};
      Map<int, double> superData = {};
      double maxW = 0;

      for (var doc in snapshot) {
        int d = 0;

        // Try extracting day from 'date' (e.g. "2026-10-15")
        if (doc['date'] != null && doc['date'].toString().trim().isNotEmpty) {
          final parts = doc['date'].toString().trim().split('-');
          if (parts.length >= 3) {
            final dayPart = parts[2].trim();
            final cleanDay =
                dayPart.length >= 2 ? dayPart.substring(0, 2) : dayPart;
            d = int.tryParse(cleanDay) ?? 0;
          }
        }

        // Fallback: extract day from 'timestamp'
        if ((d <= 0 || d > 31) && doc['timestamp'] != null) {
          try {
            final ts = DateTime.parse(doc['timestamp'].toString()).toLocal();
            d = ts.day;
          } catch (_) {}
        }

        if (d >= 1 && d <= 31) {
          double nw = _toDouble(doc['netWeight']);
          double sw = _toDouble(doc['netWeight2']);
          double w = nw + sw;

          data[d] = (data[d] ?? 0.0) + w;
          normData[d] = (normData[d] ?? 0.0) + nw;
          superData[d] = (superData[d] ?? 0.0) + sw;
          if (data[d]! > maxW) maxW = data[d]!;
        }
      }

      if (mounted) {
        setState(() {
          _heatmapData = data;
          _heatmapNormalData = normData;
          _heatmapSuperData = superData;
          _heatmapMaxWeight = maxW;
          _isHeatmapLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading heatmap data: $e');
      if (mounted) setState(() => _isHeatmapLoading = false);
    }
  }

  bool _isInitialLoad = true;
  bool _hasFetchedLiveTodayAndArrears = false;

  Future<void> _fetchDashboardData({bool isFullRefresh = false}) async {
    setState(() {
      _isSummaryLoading = true;
      if (_isInitialLoad) _isLoading = true;
    });

    final orgId = AppState.currentOrganizationId.value ?? '';
    DateTime now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_selectedFilter == 'Today') {
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedFilter == 'This Week') {
      start = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(start.year, start.month, start.day);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedFilter == 'This Month') {
      int lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
      start = DateTime(_selectedYear, _selectedMonth, 1);
      end = DateTime(_selectedYear, _selectedMonth, lastDay, 23, 59, 59);
    } else if (_selectedFilter == 'Last 6 Months') {
      int lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
      start = DateTime(_selectedYear, _selectedMonth - 5, 1);
      end = DateTime(_selectedYear, _selectedMonth, lastDay, 23, 59, 59);
    } else {
      int lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
      start = DateTime(_selectedYear - 1, _selectedMonth, 1);
      end = DateTime(_selectedYear, _selectedMonth, lastDay, 23, 59, 59);
    }

    try {
      String selMonthName = DateFormat('MMMM', 'en_US').format(DateTime(_selectedYear, _selectedMonth, 1));
      String expectedSummaryId = "$_selectedYear-$selMonthName";

      var allSummaries = await Supabase.instance.client
          .from('monthly_summaries')
          .select()
          .eq('organization_id', orgId);

      var currentMonthSummary = allSummaries.where((s) {
        final parsedDt = BillingLockService.parseMonthYear(s['id']?.toString());
        if (parsedDt != null) {
          return parsedDt.year == _selectedYear && parsedDt.month == _selectedMonth;
        }
        return s['id']?.toString().toLowerCase() == expectedSummaryId.toLowerCase();
      }).firstOrNull;

      if (currentMonthSummary != null) {
        _latestSummaryData = currentMonthSummary;
        _latestSummaryId = currentMonthSummary['id'];
        DateTime prevMonthDate = DateTime(_selectedYear, _selectedMonth - 1, 1);
        _previousSummaryData = allSummaries.where((s) {
          final parsedDt = BillingLockService.parseMonthYear(s['id']?.toString());
          if (parsedDt != null) {
            return parsedDt.year == prevMonthDate.year && parsedDt.month == prevMonthDate.month;
          }
          return false;
        }).firstOrNull;
      } else {
        if (_selectedFilter == 'This Month') {
          _latestSummaryData = null;
          _latestSummaryId = null;
          _previousSummaryData = null;
        } else {
          var sortedSummaries = List<Map<String, dynamic>>.from(allSummaries)
            ..sort((a, b) => (b['finalizedAt'] ?? '').toString().compareTo((a['finalizedAt'] ?? '').toString()));
          _latestSummaryData = sortedSummaries.isNotEmpty ? sortedSummaries.first : null;
          _latestSummaryId = _latestSummaryData?['id'];
          _previousSummaryData = sortedSummaries.length > 1 ? sortedSummaries[1] : null;
        }
      }

      final orgItems = await ItemService.getItems(
        organizationId: orgId,
      );
      fert1Price = orgItems.where((it) => it.slotIndex == 1).firstOrNull?.unitPrice ?? 15500.0;
      fert2Price = orgItems.where((it) => it.slotIndex == 2).firstOrNull?.unitPrice ?? 18000.0;
      teaPkt1Price = orgItems.where((it) => it.slotIndex == 3).firstOrNull?.unitPrice ?? 650.0;
      teaPkt2Price = orgItems.where((it) => it.slotIndex == 4).firstOrNull?.unitPrice ?? 0.0;

      // Supplier rates
      var ratesSnap = await Supabase.instance.client
          .from('monthly_rates')
          .select()
          .eq('organization_id', orgId);
      Map<String, double> ratesMap = {};
      Map<String, double> superRatesMap = {};
      double fallbackNormalRate = 0.0;
      double fallbackSuperRate = 0.0;
      for (var doc in ratesSnap) {
        String rId = doc['id'].toString();
        double r1 = (doc['teaRate'] ?? 0.0).toDouble();
        double r2 = (doc['teaRate2'] ?? doc['teaRate'] ?? 0.0).toDouble();
        ratesMap[rId] = r1;
        superRatesMap[rId] = r2;
        if (r1 > 0) fallbackNormalRate = r1;
        if (r2 > 0) fallbackSuperRate = r2;
      }

      List<dynamic> customersSnapshot = [];
      int offset = 0;
      int limit = 1000;
      while (true) {
        var chunk = await Supabase.instance.client
            .from('customers')
            .select()
            .eq('organization_id', orgId)
            .range(offset, offset + limit - 1);
        customersSnapshot.addAll(chunk);
        if (chunk.length < limit) break;
        offset += limit;
      }

      Map<String, String> customerNames = {};
      for (var doc in customersSnapshot) {
        customerNames[doc['id']] = doc['name'] ?? 'Unknown';
      }

      List<dynamic> filteredEntries = [];
      final String monthStr = _selectedMonth.toString().padLeft(2, '0');
      final int lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
      final String startDateStr = '$_selectedYear-$monthStr-01';
      final String endDateStr =
          '$_selectedYear-$monthStr-${lastDay.toString().padLeft(2, '0')}';

      // 1. Primary query by 'date' column when 'This Month' is selected (matching all modules)
      if (_selectedFilter == 'This Month') {
        offset = 0;
        while (true) {
          var chunk = await Supabase.instance.client
              .from('daily_entries')
              .select()
              .eq('organization_id', orgId)
              .gte('date', startDateStr)
              .lte('date', endDateStr)
              .range(offset, offset + limit - 1);
          filteredEntries.addAll(chunk);
          if (chunk.length < limit) break;
          offset += limit;
        }

        // 2. Fallback to 'timestamp' if 'date' query returned nothing
        if (filteredEntries.isEmpty) {
          offset = 0;
          while (true) {
            var chunk = await Supabase.instance.client
                .from('daily_entries')
                .select()
                .eq('organization_id', orgId)
                .gte('timestamp', start.toIso8601String())
                .lte('timestamp', end.toIso8601String())
                .range(offset, offset + limit - 1);
            filteredEntries.addAll(chunk);
            if (chunk.length < limit) break;
            offset += limit;
          }
        }
      } else {
        offset = 0;
        while (true) {
          var chunk = await Supabase.instance.client
              .from('daily_entries')
              .select()
              .eq('organization_id', orgId)
              .gte('timestamp', start.toIso8601String())
              .lte('timestamp', end.toIso8601String())
              .range(offset, offset + limit - 1);
          filteredEntries.addAll(chunk);
          if (chunk.length < limit) break;
          offset += limit;
        }
      }

      // Fetch today's leaf intake for real-time operational KPI card (only on initial load or full refresh)
      double todayTot = _todayTotalWeight;
      double todayNorm = _todayNormalWeight;
      double todaySup = _todaySuperWeight;
      int todayCustCount = _todaySuppliersCount;

      if (!_hasFetchedLiveTodayAndArrears || isFullRefresh) {
        DateTime todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
        DateTime todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

        var todayEntriesSnapshot = await Supabase.instance.client
            .from('daily_entries')
            .select('netWeight, netWeight2, customerId')
            .eq('organization_id', orgId)
            .gte('timestamp', todayStart.toIso8601String())
            .lte('timestamp', todayEnd.toIso8601String());

        todayTot = 0.0;
        todayNorm = 0.0;
        todaySup = 0.0;
        Set<String> todayCustIds = {};

        for (var e in todayEntriesSnapshot) {
          double w1 = _toDouble(e['netWeight']);
          double w2 = _toDouble(e['netWeight2']);
          todayNorm += w1;
          todaySup += w2;
          todayTot += (w1 + w2);
          String cId = (e['customerId'] ?? '').toString();
          if (cId.isNotEmpty && (w1 + w2) > 0) {
            todayCustIds.add(cId);
          }
        }
        todayCustCount = todayCustIds.length;
      }

      double tw = 0.0, nw = 0.0, sw = 0.0;
      double calcSupplierPayout = 0.0;
      Set<String> activeSupplierIds = {};
      Map<String, double> supplierWeightMap = {};

      Map<int, double> slotQuantities = {for (int i = 1; i <= 8; i++) i: 0.0};
      Map<int, double> slotAmounts = {for (int i = 1; i <= 8; i++) i: 0.0};
      Map<int, String> slotNames = {};
      Map<int, String> slotCodes = {};

      for (var orgItem in orgItems) {
        if (orgItem.slotIndex >= 1 && orgItem.slotIndex <= 8) {
          slotNames[orgItem.slotIndex] = orgItem.name;
          slotCodes[orgItem.slotIndex] = orgItem.code;
        }
      }
      slotNames.putIfAbsent(1, () => AppStrings.fertilizer1);
      slotCodes.putIfAbsent(1, () => 'F1');
      slotNames.putIfAbsent(2, () => AppStrings.fertilizer2);
      slotCodes.putIfAbsent(2, () => 'F2');
      slotNames.putIfAbsent(3, () => AppStrings.teaPacket1);
      slotCodes.putIfAbsent(3, () => 'T1');
      slotNames.putIfAbsent(4, () => AppStrings.teaPacket2);
      slotCodes.putIfAbsent(4, () => 'T2');
      for (int i = 5; i <= 8; i++) {
        slotNames.putIfAbsent(i, () => 'ද්‍රව්‍ය 0$i');
        slotCodes.putIfAbsent(i, () => 'I$i');
      }

      double totFertQty = 0.0;
      double totTeaQty = 0.0;
      double totOtherQty = 0.0;
      double totItemsCost = 0.0;
      Map<String, double> itemBreakdownQ = {};
      Map<String, double> itemBreakdownA = {};

      for (var d in filteredEntries) {
        double w1 = _toDouble(d['netWeight']);
        double w2 = _toDouble(d['netWeight2']);
        double entryWeight = w1 + w2;
        nw += w1;
        sw += w2;
        tw += entryWeight;

        final parsed = ItemService.parseDailyEntryItems(
          d,
          f1Price: fert1Price,
          f2Price: fert2Price,
          t1Price: teaPkt1Price,
          t2Price: teaPkt2Price,
        );
        double fQ = parsed.f1Qty + parsed.f2Qty;
        double tQ = parsed.t1Qty + parsed.t2Qty;
        double oQ = parsed.otherDynamicQty;
        totFertQty += fQ;
        totTeaQty += tQ;
        totOtherQty += oQ;
        totItemsCost += (parsed.f1Amt + parsed.f2Amt + parsed.t1Amt + parsed.t2Amt + parsed.otherDynamicAmt);

        for (var item in parsed.itemsList) {
          int slot = int.tryParse(item['slot']?.toString() ?? '0') ?? 0;
          String code = (item['code'] ?? '').toString();
          String name = (item['desc'] ?? item['name'] ?? '').toString();
          double q = _toDouble(item['qty']);
          double a = _toDouble(item['amt']);

          if (slot < 1 || slot > 8) {
            final matchedItem = orgItems.where((it) => (it.code.isNotEmpty && it.code == code) || (name.isNotEmpty && it.name == name)).firstOrNull;
            if (matchedItem != null && matchedItem.slotIndex >= 1 && matchedItem.slotIndex <= 8) {
              slot = matchedItem.slotIndex;
            } else if (code == 'F1') {
              slot = 1;
            } else if (code == 'F2') {
              slot = 2;
            } else if (code == 'T1') {
              slot = 3;
            } else if (code == 'T2') {
              slot = 4;
            } else {
              slot = 1;
            }
          }

          if (name.isNotEmpty) slotNames[slot] = name;
          if (code.isNotEmpty) slotCodes[slot] = code;
          slotQuantities[slot] = (slotQuantities[slot] ?? 0.0) + q;
          slotAmounts[slot] = (slotAmounts[slot] ?? 0.0) + a;

          if (name.isNotEmpty && (q > 0 || a > 0)) {
            itemBreakdownQ[name] = (itemBreakdownQ[name] ?? 0.0) + q;
            itemBreakdownA[name] = (itemBreakdownA[name] ?? 0.0) + a;
          }
        }

        String cId = d['customerId'] ?? '';
        if (cId.isNotEmpty) {
          if (entryWeight > 0) activeSupplierIds.add(cId);
          supplierWeightMap[cId] = (supplierWeightMap[cId] ?? 0.0) + entryWeight;
        }

        // Calculate supplier payout
        String mKey = '';
        if (d['date'] != null && d['date'].toString().trim().isNotEmpty) {
          DateTime? dt = DateTime.tryParse(d['date'].toString().trim());
          if (dt != null) {
            mKey = "${dt.year}-${DateFormat('MMMM', 'en_US').format(dt)}";
          }
        }
        if (mKey.isEmpty && d['timestamp'] != null) {
          DateTime dt = DateTime.tryParse(d['timestamp'].toString()) ?? DateTime.now();
          mKey = "${dt.year}-${DateFormat('MMMM', 'en_US').format(dt)}";
        }
        double sR1 = ratesMap[mKey] ?? fallbackNormalRate;
        double sR2 = superRatesMap[mKey] ?? (fallbackSuperRate > 0 ? fallbackSuperRate : sR1);
        calcSupplierPayout += (w1 * sR1) + (w2 * sR2);
      }

      var sortedSuppliers = supplierWeightMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      _allSuppliers = sortedSuppliers
          .map(
            (e) => {
              'name': customerNames[e.key] ?? 'Unknown',
              'weight': e.value,
            },
          )
          .toList();
      _topSuppliers = _allSuppliers.take(5).toList();

      // Read from finalized_bills for true arrears (only on initial load or full refresh)
      double totalOverallOutstanding = _overallOutstandingAdvances;
      List<Map<String, dynamic>> finalArrears = _allArrears;

      if (!_hasFetchedLiveTodayAndArrears || isFullRefresh) {
        var allFinalizedBills = await Supabase.instance.client
            .from('finalized_bills')
            .select('customerId, customerName, refNumber, billData, finalizedAt')
            .eq('organization_id', orgId)
            .order('finalizedAt', ascending: false);

        Map<String, Map<String, dynamic>> latestBillPerCustomer = {};
        for (var bill in allFinalizedBills) {
          String cId = bill['customerId'] ?? '';
          if (cId.isEmpty) continue;
          if (!latestBillPerCustomer.containsKey(cId)) {
            latestBillPerCustomer[cId] = bill;
          }
        }

        totalOverallOutstanding = 0.0;
        Map<String, double> arrearsMap = {};

        for (var entry in latestBillPerCustomer.entries) {
          String cId = entry.key;
          var bill = entry.value;
          var billData = bill['billData'];
          if (billData is! Map) continue;

          double netPayable = _toDouble(billData['netPayable']);

          if (netPayable < 0) {
            double outstanding = netPayable.abs();
            arrearsMap[cId] = outstanding;
            totalOverallOutstanding += outstanding;
          }
        }

        finalArrears =
            arrearsMap.entries
                .toList()
                .map(
                  (e) => {
                    'id': e.key,
                    'name':
                        customerNames[e.key] ??
                        latestBillPerCustomer[e.key]?['customerName'] ??
                        'Unknown',
                    'customerNumber':
                        customersSnapshot.firstWhere(
                          (c) => c['id'] == e.key,
                          orElse: () => {'refNumber': ''},
                        )['refNumber'] ??
                        '',
                    'amount': e.value,
                  },
                )
                .toList()
              ..sort(
                (a, b) =>
                    _toDouble(b['amount']).compareTo(_toDouble(a['amount'])),
              );
        _hasFetchedLiveTodayAndArrears = true;
      }

      // --- Factory Revenue Calculations ---
      final String factoryStartStr = DateFormat('yyyy-MM-dd').format(start);
      final String factoryEndStr = DateFormat('yyyy-MM-dd').format(end);

      List<dynamic> factoryEntries = [];
      offset = 0;
      while (true) {
        var chunk = await Supabase.instance.client
            .from('factory_entries')
            .select()
            .eq('organization_id', orgId)
            .gte('date', factoryStartStr)
            .lte('date', factoryEndStr)
            .range(offset, offset + limit - 1);
        factoryEntries.addAll(chunk);
        if (chunk.length < limit) break;
        offset += limit;
      }

      var factoryRatesSnap = await Supabase.instance.client
          .from('factory_monthly_rates')
          .select()
          .eq('organization_id', orgId);
      Map<String, Map<String, double>> factoryRatesMap = {};
      Map<String, Map<String, double>> latestFactoryRates = {};
      for (var r in factoryRatesSnap) {
        String fId = r['factoryId'].toString();
        String m = r['month'].toString();
        double nRate = (r['normalRate'] ?? 0.0).toDouble();
        double sRate = (r['superRate'] ?? 0.0).toDouble();
        factoryRatesMap["${fId}_$m"] = {'normal': nRate, 'super': sRate};
        latestFactoryRates[fId] = {'normal': nRate, 'super': sRate};
      }

      var factoryFinalizedBills = await Supabase.instance.client
          .from('factory_finalized_bills')
          .select()
          .eq('organization_id', orgId);
      Map<String, double> factoryBillsGrossMap = {};
      for (var fb in factoryFinalizedBills) {
        String fId = fb['factoryId'].toString();
        String m = fb['month'].toString();
        factoryBillsGrossMap["${fId}_$m"] = _toDouble(fb['grossIncome']);
      }

      double totalFactoryIncome = 0.0;
      double factoryDeliveredWeight = 0.0;
      for (var fe in factoryEntries) {
        double fnw = _toDouble(fe['netWeight']);
        double fsw = _toDouble(fe['netWeight2']);
        factoryDeliveredWeight += (fnw + fsw);
      }
      Map<String, List<dynamic>> entriesByFactoryMonth = {};
      for (var fe in factoryEntries) {
        String fId = (fe['factoryId'] ?? '').toString();
        String dStr = (fe['date'] ?? '').toString();
        if (fId.isEmpty || dStr.length < 7) continue;
        String mKey = dStr.substring(0, 7);
        String groupKey = "${fId}_$mKey";
        entriesByFactoryMonth.putIfAbsent(groupKey, () => []).add(fe);
      }

      for (var entry in entriesByFactoryMonth.entries) {
        String groupKey = entry.key;
        if (_selectedFilter == 'This Month' && factoryBillsGrossMap.containsKey(groupKey)) {
          totalFactoryIncome += factoryBillsGrossMap[groupKey]!;
        } else {
          List<String> parts = groupKey.split('_');
          String fId = parts[0];
          var rates = factoryRatesMap[groupKey] ?? latestFactoryRates[fId];
          double nRate = rates?['normal'] ?? 0.0;
          double sRate = rates?['super'] ?? 0.0;
          double fGross = 0.0;
          for (var fe in entry.value) {
            double fnw = _toDouble(fe['netWeight']);
            double fsw = _toDouble(fe['netWeight2']);
            fGross += (fnw * nRate) + (fsw * sRate);
          }
          totalFactoryIncome += fGross;
        }
      }

      // Check if current month summary provides supplier leaf gross or items
      double finalSupplierCost = calcSupplierPayout;
      if (_selectedFilter == 'This Month' && _latestSummaryData != null) {
        DateTime selDate = DateTime(_selectedYear, _selectedMonth, 1);
        String curMonthName = DateFormat('MMMM').format(selDate);
        String expectedSummaryId = "$_selectedYear-$curMonthName";
        if (_latestSummaryId == expectedSummaryId) {
          double sGross = (_latestSummaryData!['totalGross'] ?? 0).toDouble();
          if (sGross > 0) finalSupplierCost = sGross;

          double sF1Q = (_latestSummaryData!['totalF1Qty'] ?? 0).toDouble();
          double sF2Q = (_latestSummaryData!['totalF2Qty'] ?? 0).toDouble();
          double sT1Q = (_latestSummaryData!['totalT1Qty'] ?? 0).toDouble();
          double sT2Q = (_latestSummaryData!['totalT2Qty'] ?? 0).toDouble();
          double sF1A = (_latestSummaryData!['totalF1Amt'] ?? 0).toDouble();
          double sF2A = (_latestSummaryData!['totalF2Amt'] ?? 0).toDouble();
          double sT1A = (_latestSummaryData!['totalT1Amt'] ?? 0).toDouble();
          double sT2A = (_latestSummaryData!['totalT2Amt'] ?? 0).toDouble();

          double curSlotTotalQ = slotQuantities.values.fold(0.0, (sum, val) => sum + val);
          if (curSlotTotalQ == 0 && (sF1Q + sF2Q + sT1Q + sT2Q > 0)) {
            totFertQty = sF1Q + sF2Q;
            totTeaQty = sT1Q + sT2Q;
            totItemsCost = sF1A + sF2A + sT1A + sT2A;
            slotQuantities[1] = sF1Q;
            slotQuantities[2] = sF2Q;
            slotQuantities[3] = sT1Q;
            slotQuantities[4] = sT2Q;
            slotAmounts[1] = sF1A;
            slotAmounts[2] = sF2A;
            slotAmounts[3] = sT1A;
            slotAmounts[4] = sT2A;
            if (sF1Q > 0) itemBreakdownQ[slotNames[1] ?? AppStrings.fertilizer1] = sF1Q;
            if (sF2Q > 0) itemBreakdownQ[slotNames[2] ?? AppStrings.fertilizer2] = sF2Q;
            if (sT1Q > 0) itemBreakdownQ[slotNames[3] ?? AppStrings.teaPacket1] = sT1Q;
            if (sT2Q > 0) itemBreakdownQ[slotNames[4] ?? AppStrings.teaPacket2] = sT2Q;
          }
        }
      }

      List<DashboardItemSummary> activeItems = [];
      double aggregatedTotalQ = 0.0;
      double aggregatedTotalAmt = 0.0;
      for (int s = 1; s <= 8; s++) {
        double q = slotQuantities[s] ?? 0.0;
        double a = slotAmounts[s] ?? 0.0;
        aggregatedTotalQ += q;
        aggregatedTotalAmt += a;
        if (q > 0 || a > 0) {
          activeItems.add(
            DashboardItemSummary(
              slotIndex: s,
              name: slotNames[s] ?? 'ද්‍රව්‍ය $s',
              code: slotCodes[s] ?? 'I$s',
              qty: q,
              amount: a,
              color: _itemSlotColors[s - 1],
            ),
          );
        }
      }
      if (totItemsCost == 0 && aggregatedTotalAmt > 0) {
        totItemsCost = aggregatedTotalAmt;
      }
      if (totFertQty + totTeaQty + totOtherQty == 0 && aggregatedTotalQ > 0) {
        totFertQty = (slotQuantities[1] ?? 0) + (slotQuantities[2] ?? 0);
        totTeaQty = (slotQuantities[3] ?? 0) + (slotQuantities[4] ?? 0);
        totOtherQty = aggregatedTotalQ - (totFertQty + totTeaQty);
      }

      // Net dealer income & margin per Kg
      double netIncome = totalFactoryIncome - finalSupplierCost;
      double marginPerKg = tw > 0 ? (netIncome / tw) : 0.0;
      double superRatio = tw > 0 ? (sw / tw * 100.0) : 0.0;

      setState(() {
        _totalCustomers = customersSnapshot.length;
        _totalWeight = tw;
        _normalLeafWeight = nw;
        _superLeafWeight = sw;
        _superLeafPercentage = superRatio;
        _activeSuppliersCount = activeSupplierIds.length;
        _overallOutstandingAdvances = totalOverallOutstanding;
        _allArrears = finalArrears;

        _todayTotalWeight = todayTot;
        _todayNormalWeight = todayNorm;
        _todaySuperWeight = todaySup;
        _todaySuppliersCount = todayCustCount;

        _totalFactoryRevenue = totalFactoryIncome;
        _totalSupplierPayout = finalSupplierCost;
        _netDealerIncome = netIncome;
        if (_chartIncomeValues.length == 12 && _selectedMonth >= 1 && _selectedMonth <= 12) {
          if (totalFactoryIncome > 0 && _chartIncomeValues[_selectedMonth - 1] <= 0) {
            _chartIncomeValues[_selectedMonth - 1] = totalFactoryIncome;
          }
          if (finalSupplierCost > 0 && _chartExpenseValues[_selectedMonth - 1] <= 0) {
            _chartExpenseValues[_selectedMonth - 1] = finalSupplierCost;
          }
        }
        _dealerMarginPerKg = marginPerKg;
        _totalFactoryDeliveredWeight = factoryDeliveredWeight;

        _totalFertilizerQty = totFertQty;
        _totalTeaPacketQty = totTeaQty;
        _totalOtherItemsQty = totOtherQty;
        _totalItemsCost = totItemsCost;
        _totalItemsQty = aggregatedTotalQ;
        _activeItemsSummary = activeItems;
        _itemBreakdownQuantities = itemBreakdownQ;
        _itemBreakdownAmounts = itemBreakdownA;

        _isLoading = false;
        _isInitialLoad = false;
        _isSummaryLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      setState(() {
        _isLoading = false;
        _isSummaryLoading = false;
      });
    }
  }

  bool _isInitialChartLoad = true;

  Future<void> _fetchChartData() async {
    if (_isInitialChartLoad) setState(() => _isChartLoading = true);
    final orgId = AppState.currentOrganizationId.value ?? '';

    try {
      // 1. Finalized summaries & factory bills
      var summarySnapshot = await Supabase.instance.client
          .from('monthly_summaries')
          .select()
          .eq('organization_id', orgId);
      _allMonthlySummaries = List<Map<String, dynamic>>.from(summarySnapshot);

      var factoryBillsSnapshot = await Supabase.instance.client
          .from('factory_finalized_bills')
          .select()
          .eq('organization_id', orgId);

      // 2. Fetch monthly rates (supplier leaf pricing)
      var ratesSnap = await Supabase.instance.client
          .from('monthly_rates')
          .select()
          .eq('organization_id', orgId);
      Map<int, double> normalRatesByMonth = {};
      Map<int, double> superRatesByMonth = {};
      double fallbackNormalRate = 0.0;
      double fallbackSuperRate = 0.0;

      for (var doc in ratesSnap) {
        double r1 = _toDouble(doc['teaRate']);
        double r2 = _toDouble(doc['teaRate2'] ?? doc['teaRate']);
        if (r1 > 0) fallbackNormalRate = r1;
        if (r2 > 0) fallbackSuperRate = r2;

        final parsedDt = BillingLockService.parseMonthYear(doc['id']?.toString());
        if (parsedDt != null && parsedDt.year == _selectedYear) {
          normalRatesByMonth[parsedDt.month] = r1;
          superRatesByMonth[parsedDt.month] = r2;
        } else {
          String idStr = doc['id']?.toString().toLowerCase() ?? '';
          for (int m = 1; m <= 12; m++) {
            DateTime mDate = DateTime(_selectedYear, m, 1);
            String fullM = DateFormat('MMMM', 'en_US').format(mDate).toLowerCase();
            String padM = m.toString().padLeft(2, '0');
            if (idStr.contains('$_selectedYear-$padM') ||
                idStr.contains('$_selectedYear-$fullM') ||
                idStr.contains(fullM)) {
              normalRatesByMonth[m] = r1;
              superRatesByMonth[m] = r2;
            }
          }
        }
      }

      // 3. Fetch factory monthly rates
      var factoryRatesSnap = await Supabase.instance.client
          .from('factory_monthly_rates')
          .select()
          .eq('organization_id', orgId);
      Map<String, double> factoryNormalRates = {};
      Map<String, double> factorySuperRates = {};
      double fallbackFactoryNormal = 0.0;
      double fallbackFactorySuper = 0.0;

      for (var r in factoryRatesSnap) {
        String fId = (r['factoryId'] ?? '').toString();
        String mStr = (r['month'] ?? '').toString();
        double nr = _toDouble(r['normalRate']);
        double sr = _toDouble(r['superRate']);
        if (nr > 0) fallbackFactoryNormal = nr;
        if (sr > 0) fallbackFactorySuper = sr;
        if (fId.isNotEmpty && mStr.isNotEmpty) {
          factoryNormalRates['${fId}_$mStr'] = nr;
          factorySuperRates['${fId}_$mStr'] = sr;
        }
      }

      // 4. Query daily_entries for the entire selected year
      final String yrStart = '$_selectedYear-01-01';
      final String yrEnd = '$_selectedYear-12-31';
      final DateTime yrStartDt = DateTime(_selectedYear, 1, 1);
      final DateTime yrEndDt = DateTime(_selectedYear, 12, 31, 23, 59, 59);

      List<dynamic> yearDailyEntries = [];
      int offset = 0;
      const int limit = 1000;
      while (true) {
        var chunk = await Supabase.instance.client
            .from('daily_entries')
            .select('date, timestamp, netWeight, netWeight2')
            .eq('organization_id', orgId)
            .gte('date', yrStart)
            .lte('date', yrEnd)
            .range(offset, offset + limit - 1);
        yearDailyEntries.addAll(chunk);
        if (chunk.length < limit) break;
        offset += limit;
      }

      if (yearDailyEntries.isEmpty) {
        offset = 0;
        while (true) {
          var chunk = await Supabase.instance.client
              .from('daily_entries')
              .select('date, timestamp, netWeight, netWeight2')
              .eq('organization_id', orgId)
              .gte('timestamp', yrStartDt.toIso8601String())
              .lte('timestamp', yrEndDt.toIso8601String())
              .range(offset, offset + limit - 1);
          yearDailyEntries.addAll(chunk);
          if (chunk.length < limit) break;
          offset += limit;
        }
      }

      // 5. Query factory_entries for the entire selected year
      List<dynamic> yearFactoryEntries = [];
      offset = 0;
      while (true) {
        var chunk = await Supabase.instance.client
            .from('factory_entries')
            .select('factoryId, date, timestamp, netWeight, netWeight2')
            .eq('organization_id', orgId)
            .gte('date', yrStart)
            .lte('date', yrEnd)
            .range(offset, offset + limit - 1);
        yearFactoryEntries.addAll(chunk);
        if (chunk.length < limit) break;
        offset += limit;
      }

      if (yearFactoryEntries.isEmpty) {
        offset = 0;
        while (true) {
          var chunk = await Supabase.instance.client
              .from('factory_entries')
              .select('factoryId, date, timestamp, netWeight, netWeight2')
              .eq('organization_id', orgId)
              .gte('timestamp', yrStartDt.toIso8601String())
              .lte('timestamp', yrEndDt.toIso8601String())
              .range(offset, offset + limit - 1);
          yearFactoryEntries.addAll(chunk);
          if (chunk.length < limit) break;
          offset += limit;
        }
      }

      int extractDocMonth(dynamic doc) {
        if (doc == null) return 0;
        final dVal = doc['date']?.toString().trim();
        if (dVal != null && dVal.length >= 7) {
          final parts = dVal.split('-');
          if (parts.length >= 2) {
            final parsedM = int.tryParse(parts[1]);
            if (parsedM != null && parsedM >= 1 && parsedM <= 12) return parsedM;
          }
        }
        final tsVal = doc['timestamp']?.toString().trim();
        if (tsVal != null && tsVal.isNotEmpty) {
          final dt = DateTime.tryParse(tsVal);
          if (dt != null) return dt.month;
        }
        return 0;
      }

      // Aggregate unfinalized supplier leaf costs by month
      Map<int, double> unfinalizedSupplierCost = {for (int i = 1; i <= 12; i++) i: 0.0};
      for (var entry in yearDailyEntries) {
        int m = extractDocMonth(entry);
        if (m >= 1 && m <= 12) {
          double w1 = _toDouble(entry['netWeight']);
          double w2 = _toDouble(entry['netWeight2']);
          double r1 = normalRatesByMonth[m] ?? fallbackNormalRate;
          double r2 = superRatesByMonth[m] ?? (fallbackSuperRate > 0 ? fallbackSuperRate : r1);
          unfinalizedSupplierCost[m] = (unfinalizedSupplierCost[m] ?? 0.0) + (w1 * r1) + (w2 * r2);
        }
      }

      // Aggregate unfinalized factory revenue by month
      Map<int, double> unfinalizedFactoryRev = {for (int i = 1; i <= 12; i++) i: 0.0};
      for (var fe in yearFactoryEntries) {
        int m = extractDocMonth(fe);
        if (m >= 1 && m <= 12) {
          String fId = (fe['factoryId'] ?? '').toString();
          String mKey = '$_selectedYear-${m.toString().padLeft(2, '0')}';
          double fnw = _toDouble(fe['netWeight']);
          double fsw = _toDouble(fe['netWeight2']);
          double fnr = factoryNormalRates['${fId}_$mKey'] ?? fallbackFactoryNormal;
          double fsr = factorySuperRates['${fId}_$mKey'] ?? fallbackFactorySuper;
          unfinalizedFactoryRev[m] = (unfinalizedFactoryRev[m] ?? 0.0) + (fnw * fnr) + (fsw * fsr);
        }
      }

      List<double> incVals = List.filled(12, 0.0);
      List<double> expVals = List.filled(12, 0.0);
      List<String> tl = [];

      for (int m = 1; m <= 12; m++) {
        DateTime mDate = DateTime(_selectedYear, m, 1);
        String lbl = AppStrings.getMonthShortName(m);
        tl.add(lbl);

        String fullMonth = DateFormat('MMMM', 'en_US').format(mDate);
        String expectedId = "$_selectedYear-$fullMonth";
        String monthKey = "$_selectedYear-${m.toString().padLeft(2, '0')}";

        // 1. Supplier leaf cost: prefer finalized monthly summary
        var matchSummary = summarySnapshot.where((s) {
          final parsedDt = BillingLockService.parseMonthYear(s['id']?.toString());
          if (parsedDt != null) {
            return parsedDt.year == _selectedYear && parsedDt.month == m;
          }
          return s['id']?.toString().toLowerCase() == expectedId.toLowerCase();
        }).firstOrNull;

        double supplierCost = matchSummary != null
            ? _toDouble(matchSummary['totalGross'])
            : 0.0;

        // If no finalized summary, fallback to live unfinalized calculation
        if (supplierCost <= 0.0) {
          supplierCost = unfinalizedSupplierCost[m] ?? 0.0;
        }

        // 2. Factory revenue: prefer finalized factory bill
        double factoryRev = 0.0;
        for (var fb in factoryBillsSnapshot) {
          if (fb['month'] == monthKey) {
            factoryRev += _toDouble(fb['grossIncome']);
          }
        }

        // If no finalized bill, fallback to live unfinalized calculation
        if (factoryRev <= 0.0) {
          factoryRev = unfinalizedFactoryRev[m] ?? 0.0;
        }

        // 3. For currently viewed month, synchronize with live telemetry if available
        if (m == _selectedMonth) {
          if (factoryRev <= 0.0 && _totalFactoryRevenue > 0) {
            factoryRev = _totalFactoryRevenue;
          }
          if (supplierCost <= 0.0 && _totalSupplierPayout > 0) {
            supplierCost = _totalSupplierPayout;
          }
        }

        incVals[m - 1] = factoryRev;
        expVals[m - 1] = supplierCost;
      }

      int lastDataMonth = 0;
      for (int m = 12; m >= 1; m--) {
        if (incVals[m - 1] > 0 || expVals[m - 1] > 0) {
          lastDataMonth = m;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _chartIncomeValues = incVals;
          _chartExpenseValues = expVals;
          _chartLabels = tl;
          _lastAvailableDataMonth = lastDataMonth;
          if (_graphFocusedMonth == 0 || _graphFocusedMonth > 12) {
            _graphFocusedMonth =
                lastDataMonth > 0 ? lastDataMonth : _selectedMonth;
          }
          _isChartLoading = false;
          _isInitialChartLoad = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching chart data: $e");
      if (mounted) setState(() => _isChartLoading = false);
    }
  }

  int _getMonthIndex(String monthName) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    int idx = months.indexOf(monthName);
    return idx != -1 ? idx + 1 : -1;
  }

  Widget _buildHeatMapContainer({Key? key, bool isMobile = false}) {
    if (_isHeatmapLoading) {
      return Container(
        key: key,
        child: const SkeletonBox(
          height: 360,
          width: double.infinity,
          borderRadius: 24,
        ),
      );
    }
    final DateTime firstDay = DateTime(_heatmapYear, _heatmapMonth, 1);
    final int daysInMonth = DateTime(_heatmapYear, _heatmapMonth + 1, 0).day;
    final int startOffset = (firstDay.weekday - 1) % 7; // Mon = 0, Sun = 6
    final String monthName = DateFormat('MMMM yyyy').format(firstDay);
    final weightF = NumberFormat('#,##0.##', 'en_US');

    // Aggregate telemetry for the month
    final double monthTotal = _heatmapData.values.fold(0.0, (sum, w) => sum + w);
    final int activeDays = _heatmapData.values.where((w) => w > 0).length;
    int peakDay = 0;
    double peakWeight = 0.0;
    _heatmapData.forEach((d, w) {
      if (w > peakWeight) {
        peakWeight = w;
        peakDay = d;
      }
    });
    final double consistencyPct =
        daysInMonth > 0 ? (activeDays / daysInMonth * 100.0) : 0.0;
    final double avgOnActiveDays =
        activeDays > 0 ? (monthTotal / activeDays) : 0.0;

    // Weekday short labels
    final weekdayLabels = AppStrings.weekdayShortNames;

    // Build true 7-column squared calendar
    final int totalSlots = startOffset + daysInMonth;
    final int rows = (totalSlots / 7).ceil();

    Widget calendarMatrix = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Weekday Headers
        Row(
          children: weekdayLabels
              .map(
                (lbl) => Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Text(
                        lbl,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        // Grid Rows
        ...List.generate(rows, (r) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 5.0),
            child: Row(
              children: List.generate(7, (c) {
                final int slotIndex = r * 7 + c;
                final int dayNumber = slotIndex - startOffset + 1;
                if (slotIndex < startOffset || dayNumber > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 36));
                }

                if (_isHeatmapLoading) {
                  return const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.0),
                      child: SkeletonBox(
                        width: double.infinity,
                        height: 36,
                        borderRadius: 8,
                      ),
                    ),
                  );
                }

                final double dayVal = _heatmapData[dayNumber] ?? 0.0;
                final double intensity = _heatmapMaxWeight > 0
                    ? (dayVal / _heatmapMaxWeight).clamp(0.0, 1.0)
                    : 0.0;
                final bool hasHarvest = dayVal > 0;

                final Color bgColor = !hasHarvest
                    ? const Color(0xFFF8FAFC)
                    : Color.lerp(
                        const Color(0xFFC8E6C9),
                        const Color(0xFF1B5E20),
                        intensity,
                      )!;

                final Color textColor = !hasHarvest
                    ? Colors.blueGrey.shade700
                    : (intensity > 0.45 ? Colors.white : const Color(0xFF065F46));

                final Border border = !hasHarvest
                    ? Border.all(color: const Color(0xFFE2E8F0), width: 1.0)
                    : Border.all(
                        color: Color.lerp(
                          const Color(0xFFA5D6A7),
                          const Color(0xFF0D5314),
                          intensity,
                        )!,
                        width: 1.0,
                      );

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Tooltip(
                      message:
                          '$monthName $dayNumber\n${hasHarvest ? "${dayVal.toStringAsFixed(1)} Kg" : (AppStrings.isSinhala ? "දළු නොමැත" : "No harvest")}',
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: border,
                          boxShadow: hasHarvest
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF1B5E20)
                                        .withValues(alpha: 0.18 * intensity),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1.5),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          dayNumber.toString(),
                          style: TextStyle(
                            color: textColor,
                            fontWeight: hasHarvest
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );

    // Month badge with previous / next month navigation
    Widget monthBadge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          tooltip: 'Previous Month',
          onPressed: () {
            int newM = _selectedMonth - 1;
            int newY = _selectedYear;
            if (newM < 1) {
              newM = 12;
              newY--;
            }
            _changeMonth(newY, newM);
          },
        ),
        InkWell(
          onTap: () => _showMonthPickerMenu(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF16A34A).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_selectedYear ${AppStrings.getMonthName(_selectedMonth)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF15803D),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 16,
                  color: Color(0xFF15803D),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          tooltip: 'Next Month',
          onPressed: () {
            int newM = _selectedMonth + 1;
            int newY = _selectedYear;
            if (newM > 12) {
              newM = 1;
              newY++;
            }
            _changeMonth(newY, newM);
          },
        ),
      ],
    );

    // Right-hand Side: Consolidated Month Performance & Leaf Quality Telemetry Panel
    Widget telemetryPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Total Month Leaf Intake & Super Leaf Quality Breakdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          color: Color(0xFF16A34A),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.monthHarvestTotal,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${weightF.format(monthTotal)} Kg',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF14532D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_superLeafPercentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                        Text(
                          AppStrings.superLeafRatio,
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 6,
                  child: LinearProgressIndicator(
                    value: monthTotal > 0
                        ? (_superLeafWeight / monthTotal).clamp(0.0, 1.0)
                        : 0.0,
                    backgroundColor: const Color(0xFF93C5FD).withValues(alpha: 0.5),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${AppStrings.normalLeaf}: ${weightF.format(_normalLeafWeight)} Kg',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey.shade700,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${AppStrings.superLeaf}: ${weightF.format(_superLeafWeight)} Kg',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 2. 2x2 Operational Telemetry Grid
        Row(
          children: [
            // Peak Day
            Expanded(
              child: _buildHeatmapMetricTile(
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFD97706),
                title: AppStrings.peakHarvestDay,
                value: peakDay > 0
                    ? '$peakDay (${weightF.format(peakWeight)} Kg)'
                    : '-',
                subtitle: peakDay > 0 ? 'Max single day' : 'No harvest',
              ),
            ),
            const SizedBox(width: 8),
            // Active Days
            Expanded(
              child: _buildHeatmapMetricTile(
                icon: Icons.event_available_rounded,
                iconColor: const Color(0xFF2563EB),
                title: AppStrings.harvestDays,
                value: '$activeDays / $daysInMonth',
                subtitle: '${consistencyPct.toStringAsFixed(0)}% frequency',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // Active Suppliers
            Expanded(
              child: _buildHeatmapMetricTile(
                icon: Icons.people_alt_rounded,
                iconColor: primaryAppColor,
                title: AppStrings.activeSuppliers,
                value: '$_activeSuppliersCount / $_totalCustomers',
                subtitle:
                    '${_totalCustomers > 0 ? ((_activeSuppliersCount / _totalCustomers) * 100).toStringAsFixed(0) : '0'}% active rate',
              ),
            ),
            const SizedBox(width: 8),
            // Daily Average
            Expanded(
              child: _buildHeatmapMetricTile(
                icon: Icons.speed_rounded,
                iconColor: const Color(0xFF059669),
                title: AppStrings.dailyAverageIntake,
                value: '${weightF.format(avgOnActiveDays)} Kg',
                subtitle: '$activeDays active days',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 3. Density Legend Bar
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${AppStrings.low} (0 Kg)',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blueGrey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: index == 0
                          ? const Color(0xFFF1F5F9)
                          : Color.lerp(
                              const Color(0xFFC8E6C9),
                              const Color(0xFF1B5E20),
                              index / 4,
                            ),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 8),
              Text(
                '${AppStrings.high} (${weightF.format(_heatmapMaxWeight)} Kg)',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blueGrey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      key: key,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.65),
                  Colors.white.withValues(alpha: 0.25),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isSplitView = constraints.maxWidth >= 540;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Header: Title & Month Navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.calendar_month_rounded,
                                  color: Color(0xFF16A34A),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  AppStrings.dailyLeafTotal,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        monthBadge,
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Main Area: Squared Calendar Grid + Telemetry Side Panel
                    if (isSplitView)
                      Row(
                        key: ValueKey(isMobile ? 'hm_split_mobile' : 'hm_split_desktop'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: True Squared Calendar Grid (7 columns)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: 310,
                              child: calendarMatrix,
                            ),
                          ),
                          // Divider
                          Container(
                            width: 1,
                            height: 280,
                            color: Colors.black.withValues(alpha: 0.06),
                            margin:
                                const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          // Right: Unused Space Reclaimed for Harvest Telemetry
                          Expanded(child: telemetryPanel),
                        ],
                      )
                    else
                      Column(
                        key: const ValueKey('hm_stacked_mobile'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: 310,
                                child: calendarMatrix,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          telemetryPanel,
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeatmapMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 8.5,
              color: Colors.blueGrey.shade500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

    Widget _buildCriticalAlertBanner(
    BuildContext context,
    NumberFormat currencyF, {
    bool removeBottomMargin = false,
  }) {
    if (_overallOutstandingAdvances <= 0) return const SizedBox();
    return Container(
      margin: EdgeInsets.only(bottom: removeBottomMargin ? 0 : 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    OutstandingListScreen(arrearsList: _allArrears),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFEF2F2).withValues(alpha: 0.8),
                      const Color(0xFFFEF2F2).withValues(alpha: 0.4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFDC2626),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.attention,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF991B1B),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppStrings.outstandingAlertPrompt(currencyF.format(_overallOutstandingAdvances)),
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppStrings.view,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonExecutiveKpiStrip(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final bool isDesktop = w >= 960;
        final bool isTablet = w >= 600 && w < 960;

        if (isDesktop) {
          return Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 3 ? 14.0 : 0.0),
                  child: const SkeletonBox(
                    height: 120,
                    width: double.infinity,
                    borderRadius: 20,
                  ),
                ),
              ),
            ),
          );
        } else if (isTablet) {
          return Column(
            children: [
              Row(
                children: const [
                  Expanded(
                    child: SkeletonBox(
                      height: 120,
                      width: double.infinity,
                      borderRadius: 20,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: SkeletonBox(
                      height: 120,
                      width: double.infinity,
                      borderRadius: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: const [
                  Expanded(
                    child: SkeletonBox(
                      height: 120,
                      width: double.infinity,
                      borderRadius: 20,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: SkeletonBox(
                      height: 120,
                      width: double.infinity,
                      borderRadius: 20,
                    ),
                  ),
                ],
              ),
            ],
          );
        } else {
          return Column(
            children: List.generate(
              4,
              (i) => const Padding(
                padding: EdgeInsets.only(bottom: 12.0),
                child: SkeletonBox(
                  height: 110,
                  width: double.infinity,
                  borderRadius: 20,
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildSkeletonHarvestAndQualitySection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 1020;
        if (isMobile) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SkeletonBox(
                height: 360,
                width: double.infinity,
                borderRadius: 24,
              ),
              SizedBox(height: 16),
              SkeletonBox(
                height: 360,
                width: double.infinity,
                borderRadius: 24,
              ),
            ],
          );
        }
        return const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: SkeletonBox(
                height: 360,
                width: double.infinity,
                borderRadius: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: SkeletonBox(
                height: 360,
                width: double.infinity,
                borderRadius: 24,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeletonDbBusinessSummary(BuildContext context) {
    return const SkeletonBox(
      height: 70,
      width: double.infinity,
      borderRadius: 24,
    );
  }

  Widget _buildFullSkeletonDashboard([NumberFormat? currencyF]) {
    final curF = currencyF ?? NumberFormat('#,##0.00', 'en_US');
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 20.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBannerAndMonthHeader(context, curF),
          _buildSkeletonExecutiveKpiStrip(context),
          const SizedBox(height: 24),
          _buildSkeletonHarvestAndQualitySection(context),
          const SizedBox(height: 32),
          const SkeletonBox(
            height: 220,
            width: double.infinity,
            borderRadius: 20,
          ),
          const SizedBox(height: 28),
          _buildSkeletonDbBusinessSummary(context),
          const SizedBox(height: 32),
          const SkeletonBox(
            height: 340,
            width: double.infinity,
            borderRadius: 24,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyF = NumberFormat('#,##0.00', 'en_US');
    final weightF = NumberFormat('#,##0.##', 'en_US');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchDashboardData();
          await _fetchChartData();
        },
        child: _isLoading
            ? _buildFullSkeletonDashboard(currencyF)
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 20.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBannerAndMonthHeader(context, currencyF),
                    _buildRealTimeOperationalKpiStrip(context, currencyF, weightF),
                    const SizedBox(height: 24),
                    _buildHarvestAndQualitySection(context, currencyF, weightF),
                    const SizedBox(height: 32),

                    // Bottom Section: Monthly Financial Settlement & Transit Variance
                    _isSummaryLoading
                        ? const SkeletonBox(
                            height: 220,
                            width: double.infinity,
                            borderRadius: 20,
                          )
                        : _buildMonthlyFinancialSettlementSection(context, currencyF, weightF),
                    const SizedBox(height: 28),

                    _isSummaryLoading
                        ? _buildSkeletonDbBusinessSummary(context)
                        : _buildDbBusinessSummary(currencyF, weightF),
                    const SizedBox(height: 36),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            AppStrings.topSuppliers,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        if (_allSuppliers.length > 5)
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TopSuppliersScreen(
                                    allSuppliers: _allSuppliers,
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppStrings.viewAll,
                                  style: TextStyle(
                                    color: primaryAppColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 12,
                                  color: primaryAppColor,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTopSuppliersList(weightF),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTopBannerAndMonthHeader(
    BuildContext context,
    NumberFormat currencyF,
  ) {
    final bool hasAlert = _overallOutstandingAdvances > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 650;

        if (!hasAlert) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildTopMonthNavigatorHeader(context),
              ],
            ),
          );
        }

        if (isMobile) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCriticalAlertBanner(
                  context,
                  currencyF,
                  removeBottomMargin: true,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildTopMonthNavigatorHeader(context),
                  ],
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _buildCriticalAlertBanner(
                  context,
                  currencyF,
                  removeBottomMargin: true,
                ),
              ),
              const SizedBox(width: 14),
              _buildTopMonthNavigatorHeader(context),
            ],
          ),
        );
      },
    );
  }

  void _changeMonth(int year, int month) {
    final bool yearChanged = year != _selectedYear;
    setState(() {
      _selectedFilter = 'This Month';
      _selectedYear = year;
      _selectedMonth = month;
      _graphFocusedMonth = month;
      if (yearChanged) {
        _isChartLoading = true;
      }
      _isSummaryLoading = true;
      _isHeatmapLoading = true;
      _heatmapData = {};
      _heatmapNormalData = {};
      _heatmapSuperData = {};
      _heatmapMaxWeight = 0;
    });
    _fetchDashboardData(isFullRefresh: false);
    _fetchHeatmapData();
    if (yearChanged) {
      _fetchChartData();
    }
  }

  Widget _buildTopMonthNavigatorHeader(BuildContext context) {
    final String currentMonthName = AppStrings.getMonthName(_selectedMonth);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showMonthPickerMenu(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 15,
                color: primaryAppColor,
              ),
              const SizedBox(width: 6),
              Text(
                '$_selectedYear $currentMonthName',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade900,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 18,
                color: Colors.blueGrey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMonthPickerMenu(BuildContext context) {
    int dialogYear = _selectedYear;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$dialogYear',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () {
                          setDialogState(() {
                            dialogYear--;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () {
                          setDialogState(() {
                            dialogYear++;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 340,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(12, (index) {
                    final int m = index + 1;
                    final bool isSel =
                        m == _selectedMonth && dialogYear == _selectedYear;
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _changeMonth(dialogYear, m);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 76,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSel ? primaryAppColor : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: isSel
                              ? null
                              : Border.all(
                                  color: Colors.grey.shade300,
                                  width: 0.8,
                                ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          AppStrings.getMonthShortName(m),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color:
                                isSel ? Colors.white : Colors.blueGrey.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRealTimeOperationalKpiStrip(
    BuildContext context,
    NumberFormat currencyF,
    NumberFormat weightF,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final bool isDesktop = w >= 1020;
        final bool isTablet = w >= 600 && w < 1020;
        final bool isMobilePlatform = !kIsWeb && Platform.isAndroid;
        final bool showItemsOnDesktop = isDesktop && !isMobilePlatform;

        Widget buildCard1([Key? k]) => _buildKpiCard(
          key: k,
          title: AppStrings.totalWeightToday,
          value: '${weightF.format(_todayTotalWeight)} Kg',
          badgeText: _todayTotalWeight > 0
              ? '$_todaySuppliersCount ${AppStrings.customers}'
              : AppStrings.today,
          badgeColor: const Color(0xFF059669),
          subtitle: _todayTotalWeight > 0
              ? '${AppStrings.normalLeaf}: ${weightF.format(_todayNormalWeight)} Kg | ${AppStrings.superLeaf}: ${weightF.format(_todaySuperWeight)} Kg'
              : AppStrings.noEntriesToday,
          icon: Icons.today_rounded,
          gradientColors: [
            const Color(0xFFECFDF5),
            const Color(0xFFD1FAE5).withValues(alpha: 0.6),
          ],
          accentColor: const Color(0xFF059669),
          borderColor: const Color(0xFF10B981).withValues(alpha: 0.25),
        );

        Widget buildCard2([Key? k, bool showItems = true]) {
          if (_isSummaryLoading) {
            return const SkeletonBox(
              key: ValueKey('items_card_skeleton'),
              height: 120,
              width: double.infinity,
              borderRadius: 20,
            );
          }
          return _buildItemsKpiCard(
            key: k,
            context: context,
            currencyF: currencyF,
            weightF: weightF,
            showItemBreakdown: showItems,
          );
        }

        Widget buildCard4([Key? k]) => _buildKpiCard(
          key: k,
          title: AppStrings.capitalExposure,
          value: 'Rs. ${currencyF.format(_overallOutstandingAdvances)}',
          badgeText: _allArrears.isNotEmpty ? '${_allArrears.length} ${AppStrings.customers}' : null,
          badgeColor: const Color(0xFFDC2626),
          subtitle: AppStrings.debtOutstanding,
          icon: Icons.account_balance_wallet_rounded,
          gradientColors: [
            const Color(0xFFFEF2F2),
            const Color(0xFFFEE2E2).withValues(alpha: 0.6),
          ],
          accentColor: const Color(0xFFDC2626),
          borderColor: const Color(0xFFEF4444).withValues(alpha: 0.25),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TotalOutstandingBalancesScreen(arrearsList: _allArrears),
            ),
          ),
        );

        if (isDesktop) {
          return IntrinsicHeight(
            child: Row(
              key: const ValueKey('op_desktop_row'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: buildCard2(const ValueKey('c2_d'), showItemsOnDesktop),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: buildCard1(const ValueKey('c1_d'))),
                        const SizedBox(width: 14),
                        Expanded(child: buildCard4(const ValueKey('c4_d'))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        } else if (isTablet) {
          return Column(
            key: const ValueKey('op_tablet_col'),
            children: [
              buildCard2(const ValueKey('c2_t2'), false),
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  key: const ValueKey('op_tablet_r1'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: buildCard1(const ValueKey('c1_t1'))),
                    const SizedBox(width: 14),
                    Expanded(child: buildCard4(const ValueKey('c4_t1'))),
                  ],
                ),
              ),
            ],
          );
        } else {
          return Column(
            key: const ValueKey('op_mobile_col'),
            children: [
              buildCard2(const ValueKey('c2_m'), false),
              const SizedBox(height: 12),
              buildCard1(const ValueKey('c1_m')),
              const SizedBox(height: 12),
              buildCard4(const ValueKey('c4_m')),
            ],
          );
        }
      },
    );
  }

  Widget _buildMonthlyFinancialSettlementSection(
    BuildContext context,
    NumberFormat currencyF,
    NumberFormat weightF,
  ) {
    final bool hasNoFactoryData = _totalFactoryRevenue == 0 && _totalSupplierPayout > 0;
    final double variance = _totalFactoryDeliveredWeight - _totalWeight;
    final double variancePercent = _totalWeight > 0 ? (variance / _totalWeight * 100.0) : 0.0;
    final bool hasDeliveredData = _totalFactoryDeliveredWeight > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final bool isDesktop = w >= 960;
        final bool isTablet = w >= 600 && w < 960;

        Widget buildFinCard1([Key? k]) => _buildKpiCard(
          key: k,
          title: AppStrings.factoryRevenue,
          value: 'Rs. ${currencyF.format(_totalFactoryRevenue)}',
          badgeText: hasDeliveredData ? '${weightF.format(_totalFactoryDeliveredWeight)} Kg' : null,
          badgeColor: const Color(0xFF2563EB),
          subtitle: AppStrings.deliveredToFactories,
          icon: Icons.factory_rounded,
          gradientColors: [
            const Color(0xFFEFF6FF),
            const Color(0xFFDBEAFE).withValues(alpha: 0.6),
          ],
          accentColor: const Color(0xFF2563EB),
          borderColor: const Color(0xFF3B82F6).withValues(alpha: 0.25),
        );

        Widget buildFinCard2([Key? k]) => _buildKpiCard(
          key: k,
          title: AppStrings.supplierPayout,
          value: 'Rs. ${currencyF.format(_totalSupplierPayout)}',
          badgeText: _totalWeight > 0 ? '${weightF.format(_totalWeight)} Kg' : null,
          badgeColor: const Color(0xFF7C3AED),
          subtitle: '${weightF.format(_totalWeight)} Kg ${AppStrings.totalLeafIntake}',
          icon: Icons.energy_savings_leaf_rounded,
          gradientColors: [
            const Color(0xFFF5F3FF),
            const Color(0xFFEDE9FE).withValues(alpha: 0.6),
          ],
          accentColor: const Color(0xFF7C3AED),
          borderColor: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
        );

        Widget buildFinCard3([Key? k]) => _buildKpiCard(
          key: k,
          title: AppStrings.netDealerIncome,
          value: hasNoFactoryData
              ? 'Rs. 0.00'
              : 'Rs. ${currencyF.format(_netDealerIncome)}',
          badgeText: hasNoFactoryData
              ? AppStrings.pendingMonthlyRates
              : (_totalWeight > 0 ? 'Rs. ${_dealerMarginPerKg.toStringAsFixed(2)} / Kg' : null),
          badgeColor: hasNoFactoryData
              ? const Color(0xFFD97706)
              : (_netDealerIncome >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626)),
          subtitle: hasNoFactoryData
              ? AppStrings.pendingFactoryEntry
              : (_netDealerIncome >= 0 ? 'ශුද්ධ ලාභය' : 'ව්‍යාපාරික පාඩුව'),
          icon: Icons.payments_rounded,
          gradientColors: hasNoFactoryData
              ? [
                  const Color(0xFFFFFBEB),
                  const Color(0xFFFEF3C7).withValues(alpha: 0.6),
                ]
              : (_netDealerIncome >= 0
                  ? [
                      const Color(0xFFECFDF5),
                      const Color(0xFFD1FAE5).withValues(alpha: 0.6),
                    ]
                  : [
                      const Color(0xFFFEF2F2),
                      const Color(0xFFFEE2E2).withValues(alpha: 0.6),
                    ]),
          accentColor: hasNoFactoryData
              ? const Color(0xFFD97706)
              : (_netDealerIncome >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626)),
          borderColor: hasNoFactoryData
              ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
              : (_netDealerIncome >= 0
                  ? const Color(0xFF10B981).withValues(alpha: 0.25)
                  : const Color(0xFFEF4444).withValues(alpha: 0.25)),
        );

        Widget cardsRow;
        if (isDesktop) {
          cardsRow = Row(
            key: const ValueKey('fin_desktop_row'),
            children: [
              Expanded(child: buildFinCard1(const ValueKey('fc1_d'))),
              const SizedBox(width: 14),
              Expanded(child: buildFinCard2(const ValueKey('fc2_d'))),
              const SizedBox(width: 14),
              Expanded(child: buildFinCard3(const ValueKey('fc3_d'))),
            ],
          );
        } else if (isTablet) {
          cardsRow = Column(
            key: const ValueKey('fin_tablet_col'),
            children: [
              Row(
                children: [
                  Expanded(child: buildFinCard1(const ValueKey('fc1_t'))),
                  const SizedBox(width: 14),
                  Expanded(child: buildFinCard2(const ValueKey('fc2_t'))),
                ],
              ),
              const SizedBox(height: 14),
              buildFinCard3(const ValueKey('fc3_t')),
            ],
          );
        } else {
          cardsRow = Column(
            key: const ValueKey('fin_mobile_col'),
            children: [
              buildFinCard1(const ValueKey('fc1_m')),
              const SizedBox(height: 12),
              buildFinCard2(const ValueKey('fc2_m')),
              const SizedBox(height: 12),
              buildFinCard3(const ValueKey('fc3_m')),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.financialOverview,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'කර්මාන්තශාලා ආදායම, සැපයුම් පිරිවැය සහ ප්‍රවාහන වෙනස',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            cardsRow,
            const SizedBox(height: 16),
            _buildTransitVarianceCard(context, weightF, hasDeliveredData, variance, variancePercent),
          ],
        );
      },
    );
  }

  Widget _buildTransitVarianceCard(
    BuildContext context,
    NumberFormat weightF,
    bool hasDeliveredData,
    double variance,
    double variancePercent,
  ) {
    final bool isLoss = variance < 0;
    final Color statusColor = hasDeliveredData
        ? (variancePercent.abs() <= 2.5 ? const Color(0xFF059669) : const Color(0xFFDC2626))
        : Colors.blueGrey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.compare_arrows_rounded, color: statusColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.transitLossOrGain,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              if (hasDeliveredData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    variancePercent.abs() <= 2.5 ? 'සාමාන්‍ය ප්‍රවාහන හානිය' : 'අධික ප්‍රවාහන හානිය',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isSmall = constraints.maxWidth < 500;
              final col1 = _buildVarianceItem(
                label: 'ගොවීන්ගේ එකතුව',
                value: '${weightF.format(_totalWeight)} Kg',
                icon: Icons.eco_outlined,
                color: const Color(0xFF059669),
              );
              final col2 = _buildVarianceItem(
                label: AppStrings.factoryDeliveredWeight,
                value: hasDeliveredData ? '${weightF.format(_totalFactoryDeliveredWeight)} Kg' : 'සටහන් කර නැත',
                icon: Icons.factory_outlined,
                color: const Color(0xFF2563EB),
              );
              final col3 = _buildVarianceItem(
                label: 'බර වෙනස (Variance)',
                value: hasDeliveredData
                    ? '${isLoss ? "" : "+"}${weightF.format(variance)} Kg (${variancePercent.toStringAsFixed(2)}%)'
                    : 'දත්ත පොරොත්තුවෙන්',
                icon: Icons.scale_rounded,
                color: statusColor,
              );

              if (isSmall) {
                return Column(
                  children: [
                    col1,
                    const SizedBox(height: 10),
                    col2,
                    const SizedBox(height: 10),
                    col3,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: col1),
                  Container(height: 36, width: 1, color: Colors.grey.shade200),
                  Expanded(child: col2),
                  Container(height: 36, width: 1, color: Colors.grey.shade200),
                  Expanded(child: col3),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVarianceItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsKpiCard({
    Key? key,
    required BuildContext context,
    required NumberFormat currencyF,
    required NumberFormat weightF,
    bool showItemBreakdown = true,
  }) {
    final double totalQty = _totalItemsQty > 0
        ? _totalItemsQty
        : (_totalFertilizerQty + _totalTeaPacketQty + _totalOtherItemsQty);
    final String valueText = _totalItemsCost > 0
        ? 'Rs. ${currencyF.format(_totalItemsCost)}'
        : (totalQty > 0 ? '${weightF.format(totalQty)} ඒකක' : 'Rs. 0.00');

    final Color accentColor = const Color(0xFF0284C7);
    final Color borderColor = const Color(0xFF38BDF8).withValues(alpha: 0.25);
    final List<Color> gradientColors = [
      const Color(0xFFF0F9FF),
      const Color(0xFFE0F2FE).withValues(alpha: 0.6),
    ];

    return Container(
      key: key,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Icon, Title, and Value
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.category_rounded, color: accentColor, size: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.itemsIssued,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            valueText,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    // Right area: Badge at top-right + 4x2 Item Grid (Desktop only)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (totalQty > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${weightF.format(totalQty)} ඒකක',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          if (showItemBreakdown) ...[
                            const SizedBox(height: 6),
                            _build4x2ItemGrid(weightF),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Horizontal Segmented Bar at the bottom
                _buildHorizontalItemBar(totalQty),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalItemBar(double totalQty) {
    if (_activeItemsSummary.isEmpty || totalQty <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Container(
          height: 8,
          width: double.infinity,
          color: Colors.blueGrey.shade100,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 8,
        width: double.infinity,
        color: Colors.blueGrey.shade100,
        child: Row(
          children: _activeItemsSummary.map((item) {
            final double q = item.qty > 0 ? item.qty : (item.amount > 0 ? item.amount : 1.0);
            final double denom = totalQty > 0 ? totalQty : (_totalItemsCost > 0 ? _totalItemsCost : 1.0);
            final int flex = math.max(1, ((q / denom) * 1000).round());
            return Expanded(
              flex: flex,
              child: Container(
                color: item.color,
                margin: _activeItemsSummary.length > 1
                    ? const EdgeInsets.symmetric(horizontal: 0.5)
                    : EdgeInsets.zero,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildItemRow(DashboardItemSummary item, NumberFormat weightF) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              '${item.name}:',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey.shade800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            weightF.format(item.qty),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build4x2ItemGrid(NumberFormat weightF) {
    if (_activeItemsSummary.isEmpty) {
      return Text(
        'ද්‍රව්‍ය නිකුත් කර නැත',
        style: TextStyle(
          fontSize: 11,
          color: Colors.blueGrey.shade600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final col1Items = _activeItemsSummary.take(4).toList();
    final col2Items = _activeItemsSummary.skip(4).take(4).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column 1 (Items 1 to 4)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: col1Items.map((item) => _buildItemRow(item, weightF)).toList(),
          ),
        ),
        const SizedBox(width: 12),
        // Column 2 (Items 5 to 8)
        Expanded(
          child: col2Items.isEmpty
              ? const SizedBox()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: col2Items.map((item) => _buildItemRow(item, weightF)).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    Key? key,
    required String title,
    required String value,
    String? badgeText,
    Color? badgeColor,
    String? subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required Color accentColor,
    required Color borderColor,
    VoidCallback? onTap,
  }) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: accentColor, size: 20),
                        ),
                        const SizedBox(width: 8),
                        if (badgeText != null)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: (badgeColor ?? accentColor).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                badgeText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: badgeColor ?? accentColor,
                                ),
                              ),
                            ),
                          )
                        else if (onTap != null)
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: accentColor.withValues(alpha: 0.6),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: (subtitle != null && subtitle.isNotEmpty)
                                ? Colors.blueGrey.shade600
                                : Colors.transparent,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHarvestAndQualitySection(
    BuildContext context,
    NumberFormat currencyF,
    NumberFormat weightF,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 1020;

        if (isMobile) {
          return Column(
            key: const ValueKey('harvest_col_mobile'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeatMapContainer(key: const ValueKey('hm_mobile'), isMobile: true),
              const SizedBox(height: 16),
              _buildAnnualIncomeExpenseBarChartCard(
                context,
                currencyF,
                key: const ValueKey('inc_mobile'),
                isMobile: true,
              ),
            ],
          );
        }

        return Row(
          key: const ValueKey('harvest_row_desktop'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: _buildHeatMapContainer(key: const ValueKey('hm_desktop'), isMobile: false),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: _buildAnnualIncomeExpenseBarChartCard(
                context,
                currencyF,
                key: const ValueKey('inc_desktop'),
                isMobile: false,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnnualIncomeExpenseBarChartCard(
    BuildContext context,
    NumberFormat currencyF, {
    Key? key,
    bool isMobile = false,
  }) {
    if (_isChartLoading) {
      return Container(
        key: key,
        height: 360,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    // Totals across the 12 months
    final double annualIncome =
        _chartIncomeValues.fold(0.0, (sum, val) => sum + val);
    final double annualExpense =
        _chartExpenseValues.fold(0.0, (sum, val) => sum + val);
    final double annualNet = annualIncome - annualExpense;

    // Max value for scaling
    double maxVal = 0.0;
    for (int i = 0; i < 12; i++) {
      final double inc =
          i < _chartIncomeValues.length ? _chartIncomeValues[i] : 0.0;
      final double exp =
          i < _chartExpenseValues.length ? _chartExpenseValues[i] : 0.0;
      if (inc > maxVal) maxVal = inc;
      if (exp > maxVal) maxVal = exp;
    }
    if (maxVal <= 0) maxVal = 100000.0;
    final double maxY = maxVal * 1.38;
    final double yInterval = (maxY / 4) > 0 ? (maxY / 4) : 25000.0;

    final int activeGraphMonth = _graphFocusedMonth > 0
        ? _graphFocusedMonth
        : (_lastAvailableDataMonth > 0 ? _lastAvailableDataMonth : _selectedMonth);

    // Build 12 month grouped bar data
    final List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < 12; i++) {
      final double inc =
          i < _chartIncomeValues.length ? _chartIncomeValues[i] : 0.0;
      final double exp =
          i < _chartExpenseValues.length ? _chartExpenseValues[i] : 0.0;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barsSpace: 2,
          showingTooltipIndicators: const [],
          barRods: [
            // Income Rod (Green)
            BarChartRodData(
              toY: inc,
              color: const Color(0xFF10B981),
              width: isMobile ? 5.5 : 7,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY,
                color: Colors.grey.withValues(alpha: 0.04),
              ),
            ),
            // Outcome / Expense Rod (Red)
            BarChartRodData(
              toY: exp,
              color: const Color(0xFFEF4444),
              width: isMobile ? 5.5 : 7,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY,
                color: Colors.grey.withValues(alpha: 0.04),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: key,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.7),
                  Colors.white.withValues(alpha: 0.35),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.bar_chart_rounded,
                              color: Color(0xFF059669),
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.factoryRevenueVsCost,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _lastAvailableDataMonth > 0
                                      ? '$_selectedYear ${AppStrings.annualIncomeOutcomeTrend} • ${AppStrings.lastAvailableData}: ${AppStrings.getMonthName(_lastAvailableDataMonth)}'
                                      : '$_selectedYear ${AppStrings.annualIncomeOutcomeTrend}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blueGrey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Annual Net Margin Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: (annualNet >= 0
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (annualNet >= 0
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444))
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            annualNet >= 0
                                ? Icons.trending_up_rounded
                                : Icons.trending_down_rounded,
                            size: 14,
                            color: annualNet >= 0
                                ? const Color(0xFF047857)
                                : const Color(0xFFB91C1C),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            annualNet >= 0
                                ? '+Rs. ${currencyF.format(annualNet)}'
                                : '-Rs. ${currencyF.format(annualNet.abs())}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: annualNet >= 0
                                  ? const Color(0xFF047857)
                                  : const Color(0xFFB91C1C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Main 12-Month Grouped Bar Chart
                SizedBox(
                  height: 205,
                  child: BarChart(
                    BarChartData(
                      maxY: maxY,
                      alignment: BarChartAlignment.spaceAround,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchCallback: (FlTouchEvent event,
                            BarTouchResponse? touchResponse) {
                          if (event is FlTapUpEvent &&
                              touchResponse != null &&
                              touchResponse.spot != null) {
                            final int tappedIndex =
                                touchResponse.spot!.touchedBarGroupIndex;
                            if (tappedIndex >= 0 && tappedIndex < 12) {
                              final int tappedMonth = tappedIndex + 1;
                              _selectGraphMonth(tappedMonth);
                            }
                          }
                        },
                        touchTooltipData: BarTouchTooltipData(
                          tooltipRoundedRadius: 10,
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          tooltipMargin: 6,
                          maxContentWidth: 260,
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipColor: (_) => const Color(0xFF0F172A)
                              .withValues(alpha: 0.95),
                          tooltipBorder: BorderSide(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 1,
                          ),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            if (groupIndex < 0 || groupIndex >= 12) return null;
                            final int m = groupIndex + 1;
                            final double inc =
                                groupIndex < _chartIncomeValues.length
                                    ? _chartIncomeValues[groupIndex]
                                    : 0.0;
                            final double exp =
                                groupIndex < _chartExpenseValues.length
                                    ? _chartExpenseValues[groupIndex]
                                    : 0.0;
                            final double net = inc - exp;
                            final String monthName = AppStrings.getMonthName(m);

                            return BarTooltipItem(
                              '$monthName $_selectedYear\n',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10.5,
                              ),
                              children: [
                                TextSpan(
                                  text:
                                      '● ${AppStrings.factoryRevenue}: Rs. ${currencyF.format(inc)}\n',
                                  style: const TextStyle(
                                    color: Color(0xFF34D399),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 9.5,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      '● ${AppStrings.supplierPayout}: Rs. ${currencyF.format(exp)}\n',
                                  style: const TextStyle(
                                    color: Color(0xFFF87171),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 9.5,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      '${AppStrings.netProfitOrMargin}: Rs. ${currencyF.format(net)}',
                                  style: TextStyle(
                                    color: net >= 0
                                        ? const Color(0xFF67E8F9)
                                        : const Color(0xFFFCA5A5),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            interval: yInterval,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const SizedBox();
                              String text;
                              if (value >= 1000000) {
                                text =
                                    '${(value / 1000000).toStringAsFixed(1)}M';
                              } else if (value >= 1000) {
                                text = '${(value / 1000).toStringAsFixed(0)}k';
                              } else {
                                text = value.toInt().toString();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.blueGrey.shade500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= 12) return const SizedBox();
                              final int m = idx + 1;
                              final bool isCurrentSel =
                                  m == activeGraphMonth;
                              final bool isLastDataMonth =
                                  m == _lastAvailableDataMonth;

                              return GestureDetector(
                                onTap: () => _selectGraphMonth(m),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isCurrentSel ? 6 : 2,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCurrentSel
                                              ? primaryAppColor
                                                  .withValues(alpha: 0.14)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          AppStrings.getMonthShortName(m),
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: isCurrentSel
                                                ? FontWeight.w900
                                                : FontWeight.w600,
                                            color: isCurrentSel
                                                ? primaryAppColor
                                                : Colors.blueGrey.shade700,
                                          ),
                                        ),
                                      ),
                                      if (isLastDataMonth && !isCurrentSel)
                                        Container(
                                          width: 3.5,
                                          height: 3.5,
                                          margin: const EdgeInsets.only(top: 2),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: yInterval,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.black.withValues(alpha: 0.05),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: barGroups,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Operational Summary Strip Below Bar Chart
                Row(
                  children: [
                    // Total Annual Income
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 13,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    AppStrings.totalIncome,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blueGrey.shade700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Rs. ${currencyF.format(annualIncome)}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Total Annual Outcome
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.arrow_downward_rounded,
                                  size: 13,
                                  color: Color(0xFFEF4444),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    AppStrings.totalOutcome,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blueGrey.shade700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Rs. ${currencyF.format(annualExpense)}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFB91C1C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Net Annual Margin
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_rounded,
                                  size: 13,
                                  color: Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    AppStrings.netProfitOrMargin,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blueGrey.shade700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Rs. ${currencyF.format(annualNet)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: annualNet >= 0
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFB91C1C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppStrings.factoryRevenue,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppStrings.supplierPayout,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildDbBusinessSummary(NumberFormat currencyF, NumberFormat weightF) {
    if (_latestSummaryData == null || _latestSummaryId == null)
      return const SizedBox();
    String displayDate = _latestSummaryId!;
    String monthName = "";
    try {
      List<String> parts = _latestSummaryId!.split('-');
      if (parts.length >= 2) {
        displayDate = "${parts[1]} ${parts[0]}";
        monthName = parts[1];
      }
    } catch (e) {}

    String summaryTitle = monthName.isNotEmpty
        ? AppStrings.monthlySummaryTitle(monthName)
        : AppStrings.summary;

    var s = _latestSummaryData!;
    double cWeight = (s['totalWeight'] ?? 0).toDouble();
    double cGross = (s['totalGross'] ?? 0).toDouble();
    double cAdv = (s['totalAdvance'] ?? 0).toDouble();
    double cTrans = (s['totalTransport'] ?? 0).toDouble();
    double cF1Amt = (s['totalF1Amt'] ?? 0).toDouble();
    double cF2Amt = (s['totalF2Amt'] ?? 0).toDouble();
    double cFertAmt = cF1Amt + cF2Amt;
    if (cFertAmt == 0) cFertAmt = (s['totalFertilizer'] ?? 0).toDouble();
    double cT1Amt = (s['totalT1Amt'] ?? 0).toDouble();
    double cT2Amt = (s['totalT2Amt'] ?? 0).toDouble();
    double cTeaAmt = cT1Amt + cT2Amt;
    if (cTeaAmt == 0) cTeaAmt = (s['totalTeaPacket'] ?? 0).toDouble();
    double cNegNet = (s['totalNegativeNet'] ?? 0).toDouble().abs();
    double cPosNet = (s['totalPositiveNet'] ?? 0).toDouble();
    double cNet = (s['totalNet'] ?? 0).toDouble();

    double? pWeight = _previousSummaryData != null
        ? (_previousSummaryData!['totalWeight'] ?? 0).toDouble()
        : null;
    double? pGross = _previousSummaryData != null
        ? (_previousSummaryData!['totalGross'] ?? 0).toDouble()
        : null;
    double? pAdv = _previousSummaryData != null
        ? (_previousSummaryData!['totalAdvance'] ?? 0).toDouble()
        : null;
    double? pTrans = _previousSummaryData != null
        ? (_previousSummaryData!['totalTransport'] ?? 0).toDouble()
        : null;
    double? pFertAmt;
    if (_previousSummaryData != null) {
      pFertAmt =
          (_previousSummaryData!['totalF1Amt'] ?? 0).toDouble() +
          (_previousSummaryData!['totalF2Amt'] ?? 0).toDouble();
      if (pFertAmt == 0)
        pFertAmt = (_previousSummaryData!['totalFertilizer'] ?? 0).toDouble();
    }
    double? pTeaAmt;
    if (_previousSummaryData != null) {
      pTeaAmt =
          (_previousSummaryData!['totalT1Amt'] ?? 0).toDouble() +
          (_previousSummaryData!['totalT2Amt'] ?? 0).toDouble();
      if (pTeaAmt == 0)
        pTeaAmt = (_previousSummaryData!['totalTeaPacket'] ?? 0).toDouble();
    }
    double? pNegNet = _previousSummaryData != null
        ? (_previousSummaryData!['totalNegativeNet'] ?? 0).toDouble().abs()
        : null;
    double? pPosNet = _previousSummaryData != null
        ? (_previousSummaryData!['totalPositiveNet'] ?? 0).toDouble()
        : null;
    double? pNet = _previousSummaryData != null
        ? (_previousSummaryData!['totalNet'] ?? 0).toDouble()
        : null;

    double f1Qty = (s['totalF1Qty'] ?? 0).toDouble();
    double f2Qty = (s['totalF2Qty'] ?? 0).toDouble();
    double t1Qty = (s['totalT1Qty'] ?? 0).toDouble();
    double t2Qty = (s['totalT2Qty'] ?? 0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double w = constraints.maxWidth;
          bool isMobile = w < 550;
          bool isTablet = w < 900;
          double w2 = isMobile ? w : (w - 16) / 2;
          double w3 = isMobile ? w : (isTablet ? (w - 16) / 2 : (w - 32) / 3);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _isMonthlySummaryExpanded = !_isMonthlySummaryExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                summaryTitle,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1F2937),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _isMonthlySummaryExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: primaryAppColor,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          displayDate,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primaryAppColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _isMonthlySummaryExpanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          Container(height: 1, color: Colors.grey.shade100),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: w2,
                                child: _miniTile(
                                  label: AppStrings.leafWeightTotal,
                                  value: "${weightF.format(cWeight)} Kg",
                                  icon: Icons.scale_rounded,
                                  color: const Color(0xFFF59E0B),
                                  currentVal: cWeight,
                                  prevVal: pWeight,
                                ),
                              ),
                              SizedBox(
                                width: w2,
                                child: _miniTile(
                                  label: AppStrings.grossIncome,
                                  value: "Rs. ${currencyF.format(cGross)}",
                                  icon: Icons.trending_up_rounded,
                                  color: primaryAppColor,
                                  currentVal: cGross,
                                  prevVal: pGross,
                                ),
                              ),

                              SizedBox(
                                width: w2,
                                child: _miniTile(
                                  label: AppStrings.advanceCash,
                                  value: "Rs. ${currencyF.format(cAdv)}",
                                  icon: Icons.payments_rounded,
                                  color: const Color(0xFF3B82F6),
                                  currentVal: cAdv,
                                  prevVal: pAdv,
                                  invertTrend: true,
                                ),
                              ),
                              SizedBox(
                                width: w2,
                                child: _miniTile(
                                  label: AppStrings.transportCost,
                                  value: "Rs. ${currencyF.format(cTrans)}",
                                  icon: Icons.local_shipping_rounded,
                                  color: const Color(0xFFEF4444),
                                  currentVal: cTrans,
                                  prevVal: pTrans,
                                  invertTrend: true,
                                ),
                              ),

                              SizedBox(
                                width: w2,
                                child: _miniTile(
                                  label: AppStrings.itemCost,
                                  value: "Rs. ${currencyF.format(cFertAmt)}",
                                  icon: Icons.compost_rounded,
                                  color: const Color(0xFF047857),
                                  currentVal: cFertAmt,
                                  prevVal: pFertAmt,
                                  invertTrend: true,
                                  extraDetails: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${AppStrings.fertilizer1}: ${weightF.format(f1Qty)} | Rs. ${currencyF.format(cF1Amt)}",
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.blueGrey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${AppStrings.fertilizer2}: ${weightF.format(f2Qty)} | Rs. ${currencyF.format(cF2Amt)}",
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.blueGrey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: w2,
                                child: _miniTile(
                                  label: AppStrings.teaPacketCost,
                                  value: "Rs. ${currencyF.format(cTeaAmt)}",
                                  icon: Icons.local_cafe_rounded,
                                  color: const Color(0xFF8B5CF6),
                                  currentVal: cTeaAmt,
                                  prevVal: pTeaAmt,
                                  invertTrend: true,
                                  extraDetails: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${AppStrings.teaPacket1}: ${weightF.format(t1Qty)} | Rs. ${currencyF.format(cT1Amt)}",
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.blueGrey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${AppStrings.teaPacket2}: ${weightF.format(t2Qty)} | Rs. ${currencyF.format(cT2Amt)}",
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.blueGrey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              SizedBox(
                                width: w2,
                                child: _miniTile(
                                  label: AppStrings.receivableAmount,
                                  value: "Rs. ${currencyF.format(cNegNet)}",
                                  icon: Icons.arrow_circle_down_rounded,
                                  color: const Color(0xFFFF6B6B),
                                  currentVal: cNegNet,
                                  prevVal: pNegNet,
                                  invertTrend: true,
                                ),
                              ),
                              SizedBox(
                                width: w2,
                                child: _miniTile(
                                  label: AppStrings.payableAmount,
                                  value: "Rs. ${currencyF.format(cPosNet)}",
                                  icon: Icons.arrow_circle_up_rounded,
                                  color: const Color(0xFF20C997),
                                  currentVal: cPosNet,
                                  prevVal: pPosNet,
                                ),
                              ),
                              SizedBox(
                                width: w2,
                                child: _miniTile(
                                  label: AppStrings.profitOrLoss,
                                  value: "Rs. ${currencyF.format(cNet)}",
                                  icon: Icons.account_balance_rounded,
                                  color: primaryAppColor,
                                  currentVal: cNet,
                                  prevVal: pNet,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _miniTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    Widget? extraDetails,
    double? currentVal,
    double? prevVal,
    bool invertTrend = false,
  }) {
    Widget trendWidget = const SizedBox();

    if (currentVal != null && prevVal != null) {
      double change = 0;
      if (prevVal != 0)
        change = ((currentVal - prevVal) / prevVal.abs()) * 100;
      else if (currentVal != 0)
        change = currentVal > 0 ? 100.0 : -100.0;

      if (prevVal != 0 || currentVal != 0) {
        bool isUp = change > 0;
        bool isSame = change == 0;

        Color tColor = isSame
            ? Colors.blueGrey
            : (isUp
                  ? (invertTrend
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A))
                  : (invertTrend
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626)));
        IconData tIcon = isSame
            ? Icons.horizontal_rule_rounded
            : (isUp
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded);
        String tText = isSame ? "0%" : "${change.abs().toStringAsFixed(1)}%";

        trendWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: tColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tIcon, color: tColor, size: 12),
              const SizedBox(width: 2),
              Text(
                tText,
                style: TextStyle(
                  color: tColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.4),
                  Colors.white.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (trendWidget is! SizedBox) ...[
                      const SizedBox(width: 8),
                      trendWidget,
                    ],
                  ],
                ),
                if (extraDetails != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: extraDetails,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSuppliersList(NumberFormat weightF) {
    if (_topSuppliers.isEmpty)
      return Center(
        child: Text(AppStrings.noDataFound, style: const TextStyle(color: Colors.grey)),
      );
    return Column(
      children: _topSuppliers
          .map(
            (s) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.4),
                          Colors.white.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE3F2FD),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            (_topSuppliers.indexOf(s) + 1).toString(),
                            style: TextStyle(
                              color: primaryAppColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        s['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF374151),
                        ),
                      ),
                      trailing: Text(
                        '${weightF.format(s['weight'])} Kg',
                        style: TextStyle(
                          color: primaryAppColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildIconToggleHeader(
    String title,
    String value,
    List<String> options,
    Map<String, IconData> iconMap,
    Function(String) onChanged,
  ) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30), // Pill shape
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: options.map((option) {
              bool isSelected = value == option;
              return Tooltip(
                message: _getFilterLabel(option),
                child: InkWell(
                  onTap: () => onChanged(option),
                  borderRadius: BorderRadius.circular(30), // Pill shape
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, // slightly wider for a perfect pill look
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryAppColor.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(30), // Pill shape
                    ),
                    child: Icon(
                      iconMap[option] ?? Icons.filter_alt_rounded,
                      size: 20,
                      color: isSelected
                          ? primaryAppColor
                          : Colors.blueGrey.shade400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _getFilterLabel(String option) {
    switch (option) {
      case 'Today':
        return AppStrings.today;
      case 'This Week':
        return AppStrings.thisWeek;
      case 'This Month':
        return AppStrings.thisMonth;
      case 'Last 6 Months':
        return AppStrings.last6Months;
      case 'Last Year':
        return AppStrings.lastYear;
      case 'Monthly':
        return AppStrings.monthly;
      case 'Yearly':
        return AppStrings.yearly;
      default:
        return option;
    }
  }
}
