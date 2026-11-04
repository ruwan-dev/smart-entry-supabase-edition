import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
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
  double _totalAdvance = 0.0;
  double _totalFertilizer1 = 0.0;
  double _totalFertilizer2 = 0.0;
  double _totalTeaPacket1 = 0.0;
  double _totalTeaPacket2 = 0.0;
  int _totalCustomers = 0;

  double _overallOutstandingAdvances = 0.0;

  // Organization Financial & Yield Analytics
  double _totalFactoryRevenue = 0.0;
  double _totalSupplierPayout = 0.0;
  double _netDealerIncome = 0.0;
  double _dealerMarginPerKg = 0.0;
  double _normalLeafWeight = 0.0;
  double _superLeafWeight = 0.0;
  double _superLeafPercentage = 0.0;
  int _activeSuppliersCount = 0;

  Map<String, dynamic>? _latestSummaryData;
  String? _latestSummaryId;
  Map<String, dynamic>? _previousSummaryData;

  double fert1Price = 0, fert2Price = 0, teaPkt1Price = 0, teaPkt2Price = 0;

  List<Map<String, dynamic>> _topSuppliers = [];
  List<Map<String, dynamic>> _allSuppliers = [];
  List<Map<String, dynamic>> _allArrears = [];

  final List<String> _filterOptions = [
    'Today',
    'This Week',
    'This Month',
    'Last 6 Months',
    'Last Year',
  ];

  String _chartFilter = 'Monthly';
  bool _isChartLoading = true;
  List<double> _chartIncomeValues = [];
  List<double> _chartExpenseValues = [];
  List<String> _chartLabels = [];
  List<Map<String, dynamic>> _allMonthlySummaries = [];

  Map<int, double> _heatmapData = {}; // day -> weight
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
    _fetchDashboardData();
    _fetchChartData();
    _fetchHeatmapData();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  void _onRefresh() {
    _fetchDashboardData();
    _fetchChartData();
    _fetchHeatmapData();
  }

  @override
  void dispose() {
    AppState.refreshTrigger.removeListener(_onRefresh);
    AppLanguageService.currentLanguage.removeListener(_onLanguageChanged);
    super.dispose();
  }

  Future<void> _fetchHeatmapData() async {
    setState(() => _isHeatmapLoading = true);
    DateTime start = DateTime(_selectedYear, _selectedMonth, 1);
    DateTime end = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);

    try {
      List<dynamic> snapshot = [];
      int offset = 0;
      int limit = 1000;
      while (true) {
        var chunk = await Supabase.instance.client
            .from('daily_entries')
            .select('timestamp, netWeight, netWeight2').eq('organization_id', AppState.currentOrganizationId.value ?? '')
            .gte('timestamp', start.toIso8601String())
            .lte('timestamp', end.toIso8601String())
            .range(offset, offset + limit - 1);
        snapshot.addAll(chunk);
        if (chunk.length < limit) break;
        offset += limit;
      }

      Map<int, double> data = {};
      double maxW = 0;

      for (var doc in snapshot) {
        if (doc['timestamp'] != null) {
          DateTime ts = DateTime.parse(doc['timestamp'].toString());
          int d = ts.day;
          double w = (doc['netWeight'] ?? 0.0).toDouble() + (doc['netWeight2'] ?? 0.0).toDouble();

          data[d] = (data[d] ?? 0) + w;
          if (data[d]! > maxW) maxW = data[d]!;
        }
      }

      if (mounted) {
        setState(() {
          _heatmapData = data;
          _heatmapMaxWeight = maxW;
          _isHeatmapLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isHeatmapLoading = false);
    }
  }

  bool _isInitialLoad = true;

  Future<void> _fetchDashboardData() async {
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
      String selMonthName = DateFormat('MMMM').format(DateTime(_selectedYear, _selectedMonth, 1));
      String expectedSummaryId = "$_selectedYear-$selMonthName";

      var allSummaries = await Supabase.instance.client
          .from('monthly_summaries')
          .select()
          .eq('organization_id', orgId);

      var currentMonthSummary = allSummaries.where((s) => s['id'] == expectedSummaryId).firstOrNull;

      if (currentMonthSummary != null) {
        _latestSummaryData = currentMonthSummary;
        _latestSummaryId = currentMonthSummary['id'];
        DateTime prevMonthDate = DateTime(_selectedYear, _selectedMonth - 1, 1);
        String prevMonthName = DateFormat('MMMM').format(prevMonthDate);
        String prevExpectedId = "${prevMonthDate.year}-$prevMonthName";
        _previousSummaryData = allSummaries.where((s) => s['id'] == prevExpectedId).firstOrNull;
      } else {
        var sortedSummaries = List<Map<String, dynamic>>.from(allSummaries)
          ..sort((a, b) => (b['finalizedAt'] ?? '').toString().compareTo((a['finalizedAt'] ?? '').toString()));
        _latestSummaryData = sortedSummaries.isNotEmpty ? sortedSummaries.first : null;
        _latestSummaryId = _latestSummaryData?['id'];
        _previousSummaryData = sortedSummaries.length > 1 ? sortedSummaries[1] : null;
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

      double tw = 0.0, nw = 0.0, sw = 0.0, ta = 0.0, f1 = 0, f2 = 0, t1 = 0, t2 = 0;
      double calcSupplierPayout = 0.0;
      Set<String> activeSupplierIds = {};
      Map<String, double> supplierWeightMap = {};

      for (var d in filteredEntries) {
        double w1 = (d['netWeight'] ?? 0.0).toDouble();
        double w2 = (d['netWeight2'] ?? 0.0).toDouble();
        double entryWeight = w1 + w2;
        nw += w1;
        sw += w2;
        tw += entryWeight;
        ta += (d['advanceAmount'] ?? 0.0).toDouble();

        final parsed = ItemService.parseDailyEntryItems(d);
        f1 += parsed.f1Qty;
        f2 += parsed.f2Qty + parsed.otherDynamicQty;
        t1 += parsed.t1Qty;
        t2 += parsed.t2Qty;

        String cId = d['customerId'] ?? '';
        if (cId.isNotEmpty) {
          if (entryWeight > 0) activeSupplierIds.add(cId);
          supplierWeightMap[cId] = (supplierWeightMap[cId] ?? 0.0) + entryWeight;
        }

        // Calculate supplier payout
        String mKey = '';
        if (d['timestamp'] != null) {
          DateTime dt = DateTime.tryParse(d['timestamp'].toString()) ?? DateTime.now();
          mKey = "${dt.year}-${DateFormat('MMMM').format(dt)}";
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

      // Read from finalized_bills for true arrears
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

      double totalOverallOutstanding = 0.0;
      Map<String, double> arrearsMap = {};

      for (var entry in latestBillPerCustomer.entries) {
        String cId = entry.key;
        var bill = entry.value;
        var billData = bill['billData'];
        if (billData is! Map) continue;

        double netPayable = (billData['netPayable'] ?? 0.0) is num
            ? (billData['netPayable'] ?? 0.0).toDouble()
            : double.tryParse(billData['netPayable'].toString()) ?? 0.0;

        if (netPayable < 0) {
          double outstanding = netPayable.abs();
          arrearsMap[cId] = outstanding;
          totalOverallOutstanding += outstanding;
        }
      }

      _allArrears =
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
                  (b['amount'] as double).compareTo(a['amount'] as double),
            );

      // --- Factory Revenue Calculations ---
      String startDateStr = DateFormat('yyyy-MM-dd').format(start);
      String endDateStr = DateFormat('yyyy-MM-dd').format(end);

      List<dynamic> factoryEntries = [];
      offset = 0;
      while (true) {
        var chunk = await Supabase.instance.client
            .from('factory_entries')
            .select()
            .eq('organization_id', orgId)
            .gte('date', startDateStr)
            .lte('date', endDateStr)
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
        factoryBillsGrossMap["${fId}_$m"] = ((fb['grossIncome'] ?? 0) as num).toDouble();
      }

      double totalFactoryIncome = 0.0;
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
            double fnw = ((fe['netWeight'] ?? 0) as num).toDouble();
            double fsw = ((fe['netWeight2'] ?? 0) as num).toDouble();
            fGross += (fnw * nRate) + (fsw * sRate);
          }
          totalFactoryIncome += fGross;
        }
      }

      // Check if current month summary provides supplier leaf gross
      double finalSupplierCost = calcSupplierPayout;
      if (_selectedFilter == 'This Month' && _latestSummaryData != null) {
        DateTime selDate = DateTime(_selectedYear, _selectedMonth, 1);
        String curMonthName = DateFormat('MMMM').format(selDate);
        String expectedSummaryId = "$_selectedYear-$curMonthName";
        if (_latestSummaryId == expectedSummaryId) {
          double sGross = (_latestSummaryData!['totalGross'] ?? 0).toDouble();
          if (sGross > 0) finalSupplierCost = sGross;
        }
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
        _totalAdvance = ta;
        _totalFertilizer1 = f1;
        _totalFertilizer2 = f2;
        _totalTeaPacket1 = t1;
        _totalTeaPacket2 = t2;
        _overallOutstandingAdvances = totalOverallOutstanding;

        _totalFactoryRevenue = totalFactoryIncome;
        _totalSupplierPayout = finalSupplierCost;
        _netDealerIncome = netIncome;
        _dealerMarginPerKg = marginPerKg;

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
    DateTime now = DateTime.now();
    final orgId = AppState.currentOrganizationId.value ?? '';

    try {
      var summarySnapshot = await Supabase.instance.client
          .from('monthly_summaries')
          .select()
          .eq('organization_id', orgId);
      _allMonthlySummaries = List<Map<String, dynamic>>.from(summarySnapshot);

      var factoryBillsSnapshot = await Supabase.instance.client
          .from('factory_finalized_bills')
          .select()
          .eq('organization_id', orgId);

      List<double> incVals = [];
      List<double> expVals = [];
      List<String> tl = [];

      if (_chartFilter == 'Monthly') {
        incVals = List.filled(12, 0.0);
        expVals = List.filled(12, 0.0);
        for (int i = 11; i >= 0; i--) {
          DateTime mDate = DateTime(now.year, now.month - i, 1);
          String lbl = DateFormat('MMM').format(mDate);
          tl.add(lbl);

          String fullMonth = DateFormat('MMMM').format(mDate);
          String expectedId = "${mDate.year}-$fullMonth";
          String monthKey = "${mDate.year}-${mDate.month.toString().padLeft(2, '0')}";

          // Supplier leaf cost from monthly_summaries
          var matchSummary = summarySnapshot.where((s) => s['id'] == expectedId).firstOrNull;
          double supplierCost = matchSummary != null
              ? ((matchSummary['totalGross'] ?? 0) as num).toDouble()
              : 0.0;

          // Factory revenue from factory_finalized_bills
          double factoryRev = 0.0;
          for (var fb in factoryBillsSnapshot) {
            if (fb['month'] == monthKey) {
              factoryRev += ((fb['grossIncome'] ?? 0) as num).toDouble();
            }
          }

          incVals[11 - i] = factoryRev;
          expVals[11 - i] = supplierCost;
        }
      } else if (_chartFilter == 'Yearly') {
        incVals = List.filled(5, 0.0);
        expVals = List.filled(5, 0.0);
        for (int i = 4; i >= 0; i--) {
          String yearStr = (now.year - i).toString();
          tl.add(yearStr);

          double yInc = 0;
          double yExp = 0;
          for (var doc in summarySnapshot) {
            if (doc['id'].toString().startsWith("$yearStr-")) {
              yExp += ((doc['totalGross'] ?? 0) as num).toDouble();
            }
          }
          for (var fb in factoryBillsSnapshot) {
            if (fb['month'].toString().startsWith(yearStr)) {
              yInc += ((fb['grossIncome'] ?? 0) as num).toDouble();
            }
          }
          incVals[4 - i] = yInc;
          expVals[4 - i] = yExp;
        }
      }

      if (mounted) {
        setState(() {
          _chartIncomeValues = incVals;
          _chartExpenseValues = expVals;
          _chartLabels = tl;
          _isChartLoading = false;
          _isInitialChartLoad = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isChartLoading = false);
    }
  }

  double _getMaxChartValue() {
    double mv2 = _chartIncomeValues.isNotEmpty
        ? _chartIncomeValues.reduce((a, b) => a > b ? a : b)
        : 0.0;
    double mv3 = _chartExpenseValues.isNotEmpty
        ? _chartExpenseValues.reduce((a, b) => a > b ? a : b)
        : 0.0;
    double mv = mv2 > mv3 ? mv2 : mv3;
    return mv == 0 ? 100.0 : mv;
  }

  LineChartData _getYAxisData() {
    double mv = _getMaxChartValue();
    double yInterval = (mv / 5).ceilToDouble();
    if (yInterval == 0) yInterval = 10;

    return LineChartData(
      minX: 0,
      maxX: 1,
      minY: 0,
      maxY: mv * 1.2,
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 60,
            getTitlesWidget: (v, m) => const SizedBox(),
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 45,
            interval: yInterval,
            getTitlesWidget: (v, m) {
              if (v == 0) return const SizedBox();
              String t = v >= 1000000
                  ? '${(v / 1000000).toStringAsFixed(1)}M'
                  : (v >= 1000
                        ? '${(v / 1000).toStringAsFixed(1)}k'
                        : '${v.toInt()}');
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Text(
                  t,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: const [FlSpot(0, 0), FlSpot(1, 0)],
          color: Colors.transparent,
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }

  LineChartData _getRealChartData() {
    double mv = _getMaxChartValue();
    double yInterval = (mv / 5).ceilToDouble();
    if (yInterval == 0) yInterval = 10;

    double maxXV = (_chartIncomeValues.length > 1)
        ? (_chartIncomeValues.length - 1).toDouble()
        : 1.0;

    List<FlSpot> incSpots = [];
    List<FlSpot> expSpots = [];
    if (_chartIncomeValues.isNotEmpty) {
      incSpots = _chartIncomeValues.length == 1
          ? [FlSpot(0, _chartIncomeValues[0]), FlSpot(1, _chartIncomeValues[0])]
          : List.generate(
              _chartIncomeValues.length,
              (i) => FlSpot(i.toDouble(), _chartIncomeValues[i]),
            );
    }
    if (_chartExpenseValues.isNotEmpty) {
      expSpots = _chartExpenseValues.length == 1
          ? [
              FlSpot(0, _chartExpenseValues[0]),
              FlSpot(1, _chartExpenseValues[0]),
            ]
          : List.generate(
              _chartExpenseValues.length,
              (i) => FlSpot(i.toDouble(), _chartExpenseValues[i]),
            );
    }

    return LineChartData(
      minX: 0,
      maxX: maxXV,
      minY: 0,
      maxY: mv * 1.2,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        drawHorizontalLine: true,
        horizontalInterval: yInterval,
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 60,
            interval: 1,
            getTitlesWidget: (v, m) {
              int idx = v.toInt();
              if (idx >= 0 && idx < _chartLabels.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 15.0),
                  child: Transform.rotate(
                    angle: -0.8,
                    child: Text(
                      _chartLabels[idx],
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: true),
      lineBarsData: [
        if (incSpots.isNotEmpty)
          LineChartBarData(
            spots: incSpots,
            isCurved: true,
            color: const Color(0xFF20C997), // Green for Income
            barWidth: 3.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: const Color(0xFF20C997),
                  ),
            ),
            belowBarData: BarAreaData(show: false),
          ),
        if (expSpots.isNotEmpty)
          LineChartBarData(
            spots: expSpots,
            isCurved: true,
            color: const Color(0xFFFF6B6B), // Red for Expense
            barWidth: 3.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: const Color(0xFFFF6B6B),
                  ),
            ),
            belowBarData: BarAreaData(show: false),
          ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildChartContainer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double availableWidthForChart = constraints.maxWidth - 50 - 15;
        if (availableWidthForChart < 0) availableWidthForChart = 0;

        double chartWidth = _chartFilter == 'Daily' || _chartFilter == 'Monthly'
            ? (availableWidthForChart > 1200 ? availableWidthForChart : 1200.0)
            : availableWidthForChart;

        return Container(
          height: 340,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
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
                padding: const EdgeInsets.only(top: 30, bottom: 10, right: 15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.4),
                      Colors.white.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 50, child: LineChart(_getYAxisData())),
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: MyCustomScrollBehavior(),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: SizedBox(
                            width: chartWidth,
                            child: LineChart(_getRealChartData()),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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

  Widget _buildHeatMapContainer({bool isMobile = false}) {
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

    // Month badge
    Widget monthBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
      ),
      child: Text(
        '$_selectedYear ${AppStrings.getMonthName(_selectedMonth)}',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF15803D),
        ),
      ),
    );

    // Right-hand Side: Month Performance Telemetry Panel
    Widget telemetryPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 1. Total Month Leaf Intake
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.monthHarvestTotal,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${weightF.format(monthTotal)} Kg',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF14532D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 2. Dual Mini Metric Tiles: Peak Day & Active Rate
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(9),
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
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            AppStrings.peakHarvestDay,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      peakDay > 0
                          ? '$peakDay (${weightF.format(peakWeight)} Kg)'
                          : '-',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      peakDay > 0 ? 'Max single day' : 'No harvest',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.blueGrey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(9),
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
                        const Icon(
                          Icons.event_available_rounded,
                          size: 14,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            AppStrings.harvestDays,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$activeDays / $daysInMonth',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      '${consistencyPct.toStringAsFixed(0)}% frequency',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.blueGrey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 3. Average per active day
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.dailyAverageIntake,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blueGrey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${weightF.format(avgOnActiveDays)} Kg / day',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 4. Density Legend Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${AppStrings.low} (0 Kg)',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blueGrey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
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
      ],
    );

    return Container(
      height: isMobile ? null : 362,
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
                  mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
                  children: [
                    // Top Header: Title & Month Navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
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
                            Text(
                              AppStrings.dailyLeafTotal,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        monthBadge,
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Main Area: Squared Calendar Grid + Telemetry Side Panel
                    if (isSplitView)
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left: True Squared Calendar Grid (7 columns)
                            SizedBox(
                              width: 310,
                              child: calendarMatrix,
                            ),
                            // Divider
                            Container(
                              width: 1,
                              color: Colors.black.withValues(alpha: 0.06),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 14),
                            ),
                            // Right: Unused Space Reclaimed for Harvest Telemetry
                            Expanded(child: telemetryPanel),
                          ],
                        ),
                      )
                    else ...[
                      calendarMatrix,
                      const SizedBox(height: 14),
                      telemetryPanel,
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

    Widget _buildCriticalAlertBanner(
    BuildContext context,
    NumberFormat currencyF,
  ) {
    if (_overallOutstandingAdvances <= 0) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
                      const Color(0xFFFEF2F2).withOpacity(0.8),
                      const Color(0xFFFEF2F2).withOpacity(0.4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.6),
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
                            color: Colors.red.withOpacity(0.3),
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

  Widget _buildFullSkeletonDashboard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final bool isDesktop = w >= 960;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 4 Executive KPI Skeleton cards
              if (isDesktop)
                Row(
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
                )
              else
                Column(
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
                ),
              const SizedBox(height: 24),
              // Heatmap + Quality Section Skeleton
              if (isDesktop)
                const Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: SkeletonBox(
                        height: 362,
                        width: double.infinity,
                        borderRadius: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: SkeletonBox(
                        height: 362,
                        width: double.infinity,
                        borderRadius: 24,
                      ),
                    ),
                  ],
                )
              else
                const Column(
                  children: [
                    SkeletonBox(
                      height: 362,
                      width: double.infinity,
                      borderRadius: 24,
                    ),
                    SizedBox(height: 16),
                    SkeletonBox(
                      height: 362,
                      width: double.infinity,
                      borderRadius: 24,
                    ),
                  ],
                ),
              const SizedBox(height: 28),
              const SkeletonBox(height: 30, width: 150, borderRadius: 8),
              const SizedBox(height: 16),
              const SkeletonBox(
                height: 280,
                width: double.infinity,
                borderRadius: 24,
              ),
              const SizedBox(height: 32),
              const SkeletonBox(
                height: 340,
                width: double.infinity,
                borderRadius: 24,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeletonSummaryGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double w = constraints.maxWidth;
        bool isMobile = w < 550;
        bool isTablet = w < 900;
        double cardW = isMobile ? w : (isTablet ? (w - 16) / 2 : (w - 48) / 4);

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: List.generate(
            4,
            (index) => SizedBox(
              width: cardW,
              child: const SkeletonBox(
                height: 140,
                width: double.infinity,
                borderRadius: 20,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyF = NumberFormat('#,##0.00', 'en_US');
    final weightF = NumberFormat('#,##0.##', 'en_US');

    final Map<String, IconData> summaryIconMap = {
      'Today': Icons.today_rounded,
      'This Week': Icons.view_week_rounded,
      'This Month': Icons.calendar_month_rounded,
      'Last 6 Months': Icons.date_range_rounded,
      'Last Year': Icons.event_repeat_rounded,
    };

    final Map<String, IconData> chartIconMap = {
      'Daily': Icons.view_day_rounded,
      'Monthly': Icons.calendar_view_month_rounded,
      'Yearly': Icons.calendar_today_rounded,
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchDashboardData();
          await _fetchChartData();
        },
        child: _isLoading
            ? _buildFullSkeletonDashboard()
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 20.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCriticalAlertBanner(context, currencyF),
                    _buildTopMonthNavigatorHeader(context),
                    _buildExecutiveKpiStrip(context, currencyF, weightF),
                    const SizedBox(height: 24),
                    _buildHarvestAndQualitySection(context, weightF),
                    const SizedBox(height: 24),

                    _buildIconToggleHeader(
                      AppStrings.summary,
                      _selectedFilter,
                      _filterOptions,
                      summaryIconMap,
                      (val) {
                        if (_selectedFilter != val) {
                          setState(() => _selectedFilter = val);
                          _fetchDashboardData();
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    _isSummaryLoading
                        ? _buildSkeletonSummaryGrid(context)
                        : _buildSummaryGrid(context, weightF, currencyF),

                    const SizedBox(height: 32),

                    _buildDbBusinessSummary(currencyF, weightF),
                    const SizedBox(height: 32),

                    _buildIconToggleHeader(
                      AppStrings.factoryRevenueVsCost,
                      _chartFilter,
                      _chartFilterOptions,
                      chartIconMap,
                      (val) {
                        setState(() => _chartFilter = val);
                        _fetchChartData();
                      },
                    ),
                    const SizedBox(height: 16),
                    _isChartLoading
                        ? const SkeletonBox(
                            height: 340,
                            width: double.infinity,
                            borderRadius: 24,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildChartContainer(),
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 12.0,
                                  right: 8.0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _buildLegendItem(
                                      AppStrings.factoryRevenue,
                                      const Color(0xFF20C997),
                                    ),
                                    const SizedBox(width: 16),
                                    _buildLegendItem(
                                      AppStrings.supplierPayout,
                                      const Color(0xFFFF6B6B),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 40),

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

  Widget _buildTopMonthNavigatorHeader(BuildContext context) {
    final String currentMonthName = AppStrings.getMonthName(_selectedMonth);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: 34,
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
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  onPressed: () {
                    setState(() {
                      _selectedFilter = 'This Month';
                      _selectedMonth--;
                      if (_selectedMonth < 1) {
                        _selectedMonth = 12;
                        _selectedYear--;
                      }
                    });
                    _fetchDashboardData();
                    _fetchHeatmapData();
                  },
                ),
                InkWell(
                  onTap: () => _showMonthPickerMenu(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 14,
                          color: primaryAppColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$_selectedYear $currentMonthName',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade900,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 18,
                          color: Colors.blueGrey.shade600,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  onPressed: () {
                    setState(() {
                      _selectedFilter = 'This Month';
                      _selectedMonth++;
                      if (_selectedMonth > 12) {
                        _selectedMonth = 1;
                        _selectedYear++;
                      }
                    });
                    _fetchDashboardData();
                    _fetchHeatmapData();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMonthPickerMenu(BuildContext context) {
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
                    '$_selectedYear',
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
                          setState(() => _selectedYear--);
                          setDialogState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () {
                          setState(() => _selectedYear++);
                          setDialogState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(12, (index) {
                    final int m = index + 1;
                    final bool isSel = m == _selectedMonth;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedFilter = 'This Month';
                          _selectedMonth = m;
                        });
                        Navigator.pop(ctx);
                        _fetchDashboardData();
                        _fetchHeatmapData();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 70,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSel ? primaryAppColor : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          AppStrings.getMonthName(m),
                          style: TextStyle(
                            fontSize: 12,
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

  Widget _buildExecutiveKpiStrip(
    BuildContext context,
    NumberFormat currencyF,
    NumberFormat weightF,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final bool isDesktop = w >= 960;
        final bool isTablet = w >= 600 && w < 960;

        final bool hasNoFactoryData = _totalFactoryRevenue == 0 && _totalSupplierPayout > 0;
        final card1 = _buildKpiCard(
          title: AppStrings.netDealerIncome,
          value: hasNoFactoryData
              ? 'Rs. 0.00'
              : 'Rs. ${currencyF.format(_netDealerIncome)}',
          badgeText: hasNoFactoryData
              ? AppStrings.pendingFactoryEntry
              : (_totalWeight > 0 ? 'Rs. ${_dealerMarginPerKg.toStringAsFixed(2)} / Kg' : null),
          badgeColor: hasNoFactoryData ? const Color(0xFFD97706) : const Color(0xFF059669),
          subtitle: hasNoFactoryData
              ? '${AppStrings.supplierPayout}: Rs. ${currencyF.format(_totalSupplierPayout)}'
              : AppStrings.dealerGrossMargin,
          icon: Icons.payments_rounded,
          gradientColors: hasNoFactoryData
              ? [
                  const Color(0xFFFFFBEB),
                  const Color(0xFFFEF3C7).withValues(alpha: 0.6),
                ]
              : [
                  const Color(0xFFECFDF5),
                  const Color(0xFFD1FAE5).withValues(alpha: 0.6),
                ],
          accentColor: hasNoFactoryData ? const Color(0xFFD97706) : const Color(0xFF059669),
          borderColor: hasNoFactoryData
              ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
              : const Color(0xFF10B981).withValues(alpha: 0.25),
        );

        final card2 = _buildKpiCard(
          title: AppStrings.factoryRevenue,
          value: 'Rs. ${currencyF.format(_totalFactoryRevenue)}',
          badgeText: null,
          subtitle: AppStrings.deliveredToFactories,
          icon: Icons.factory_rounded,
          gradientColors: [
            const Color(0xFFEFF6FF),
            const Color(0xFFDBEAFE).withValues(alpha: 0.6),
          ],
          accentColor: const Color(0xFF2563EB),
          borderColor: const Color(0xFF3B82F6).withValues(alpha: 0.25),
        );

        final card3 = _buildKpiCard(
          title: AppStrings.supplierPayout,
          value: 'Rs. ${currencyF.format(_totalSupplierPayout)}',
          badgeText: null,
          subtitle: '${weightF.format(_totalWeight)} Kg ' + AppStrings.totalLeafIntake,
          icon: Icons.energy_savings_leaf_rounded,
          gradientColors: [
            const Color(0xFFF5F3FF),
            const Color(0xFFEDE9FE).withValues(alpha: 0.6),
          ],
          accentColor: const Color(0xFF7C3AED),
          borderColor: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
        );

        final card4 = _buildKpiCard(
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
          return Row(
            children: [
              Expanded(child: card1),
              const SizedBox(width: 14),
              Expanded(child: card2),
              const SizedBox(width: 14),
              Expanded(child: card3),
              const SizedBox(width: 14),
              Expanded(child: card4),
            ],
          );
        } else if (isTablet) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 14),
                  Expanded(child: card2),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: card3),
                  const SizedBox(width: 14),
                  Expanded(child: card4),
                ],
              ),
            ],
          );
        } else {
          return Column(
            children: [
              card1,
              const SizedBox(height: 12),
              card2,
              const SizedBox(height: 12),
              card3,
              const SizedBox(height: 12),
              card4,
            ],
          );
        }
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    String? badgeText,
    Color? badgeColor,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required Color accentColor,
    required Color borderColor,
    VoidCallback? onTap,
  }) {
    return Container(
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
                  mainAxisSize: MainAxisSize.min,
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
                        if (badgeText != null)
                          Container(
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
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: badgeColor ?? accentColor,
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
                    const SizedBox(height: 12),
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
                      subtitle,
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHarvestAndQualitySection(BuildContext context, NumberFormat weightF) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 880;
        final heatmapWidget = _buildHeatMapContainer(isMobile: isMobile);
        final qualityWidget = _buildQualityAndIntakeMatrixCard(context, weightF, isMobile: isMobile);

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heatmapWidget,
              const SizedBox(height: 16),
              qualityWidget,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: heatmapWidget),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: qualityWidget),
          ],
        );
      },
    );
  }

  Widget _buildQualityAndIntakeMatrixCard(
    BuildContext context,
    NumberFormat weightF, {
    bool isMobile = false,
  }) {
    final int activeDays = _heatmapData.values.where((w) => w > 0).length;
    final double dailyAvg = activeDays > 0 ? (_totalWeight / activeDays) : 0.0;

    return Container(
      height: isMobile ? null : 362,
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
            padding: const EdgeInsets.all(20),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryAppColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.insights_rounded, color: primaryAppColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.leafHarvestAnalytics,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              AppStrings.qualityBreakdown,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CustomerAnalysisScreen(),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryAppColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primaryAppColor.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppStrings.customerAnalysis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: primaryAppColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: primaryAppColor),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Super Leaf Progress & Yield Ratio
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.eco_rounded, size: 16, color: Color(0xFF059669)),
                              const SizedBox(width: 6),
                              Text(
                                AppStrings.superLeafRatio,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_superLeafPercentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 10,
                          child: LinearProgressIndicator(
                            value: _totalWeight > 0 ? (_superLeafWeight / _totalWeight).clamp(0.0, 1.0) : 0.0,
                            backgroundColor: const Color(0xFF93C5FD).withValues(alpha: 0.5),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF3B82F6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${AppStrings.normalLeaf}: ${weightF.format(_normalLeafWeight)} Kg',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blueGrey.shade700,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${AppStrings.superLeaf}: ${weightF.format(_superLeafWeight)} Kg',
                                style: const TextStyle(
                                  fontSize: 11,
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
                const SizedBox(height: 12),

                // Dual Operational Matrix Blocks (Active Suppliers + Daily Intake)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.people_alt_rounded, size: 16, color: primaryAppColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    AppStrings.activeSuppliers,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blueGrey.shade700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$_activeSuppliersCount / $_totalCustomers',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              '${_totalCustomers > 0 ? ((_activeSuppliersCount / _totalCustomers) * 100).toStringAsFixed(0) : '0'}% active rate',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blueGrey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.speed_rounded, size: 16, color: Color(0xFFD97706)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    AppStrings.dailyAverageIntake,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blueGrey.shade700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${weightF.format(dailyAvg)} Kg',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              '$activeDays active days',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blueGrey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
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
            color: Colors.black.withOpacity(0.04),
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
            color: tColor.withOpacity(0.1),
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
            color: Colors.black.withOpacity(0.02),
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
                  Colors.white.withOpacity(0.4),
                  Colors.white.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
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
                        color: color.withOpacity(0.15),
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

  Widget _buildSummaryGrid(
    BuildContext context,
    NumberFormat weightF,
    NumberFormat currencyF,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double w = constraints.maxWidth;
        bool isMobile = w < 550;
        bool isTablet = w < 900;
        double cardW = isMobile ? w : (isTablet ? (w - 16) / 2 : (w - 48) / 4);

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: cardW,
              child: _summaryCard(
                title: AppStrings.leafWeightTotal,
                value: '${weightF.format(_totalWeight)} Kg',
                icon: Icons.eco_rounded,
                color: primaryAppColor,
                imagePath: 'assets/tealeaves_badge.png',
              ),
            ),
            SizedBox(
              width: cardW,
              child: _summaryCard(
                title: AppStrings.advance,
                value: 'Rs. ${currencyF.format(_totalAdvance)}',
                icon: Icons.payments_rounded,
                color: const Color(0xFF3B82F6),
                imagePath: 'assets/advance_badge.png',
              ),
            ),
            SizedBox(
              width: cardW,
              child: _summaryCard(
                title: AppStrings.fertilizer,
                value: weightF.format(_totalFertilizer1 + _totalFertilizer2),
                icon: Icons.compost_rounded,
                color: const Color(0xFF047857),
                imagePath: 'assets/fertilizer_badge.png',
                subItems: [
                  _buildSubItemIcon(
                    Icons.compost_rounded,
                    weightF.format(_totalFertilizer1),
                    const Color(0xFFEF4444),
                  ),
                  _buildSubItemIcon(
                    Icons.compost_rounded,
                    weightF.format(_totalFertilizer2),
                    const Color(0xFF3B82F6),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: cardW,
              child: _summaryCard(
                title: AppStrings.teaPackets,
                value: weightF.format(_totalTeaPacket1 + _totalTeaPacket2),
                icon: Icons.local_cafe_rounded,
                color: const Color(0xFF8B5CF6),
                imagePath: 'assets/teapackets_badge.png',
                subItems: [
                  _buildSubItemIcon(
                    Icons.local_cafe_rounded,
                    weightF.format(_totalTeaPacket1),
                    const Color(0xFFEF4444),
                  ),
                  _buildSubItemIcon(
                    Icons.local_cafe_rounded,
                    weightF.format(_totalTeaPacket2),
                    const Color(0xFF3B82F6),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    List<Widget>? subItems,
    String? imagePath,
  }) {
    if (imagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Full image — the entire tile
            Image.asset(
              imagePath,
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
            // Text centered in the white space area (top ~40% of image)
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.85),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          if (subItems != null) ...[
                            const SizedBox(width: 6),
                            const Text(
                              "(",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.blueGrey,
                              ),
                            ),
                            ...subItems,
                            const Text(
                              ")",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.4),
                  Colors.white.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      if (subItems != null) ...[
                        const SizedBox(width: 4),
                        const Text(
                          "(",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.blueGrey,
                          ),
                        ),
                        ...subItems,
                        const Text(
                          ")",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubItemIcon(IconData icon, String val, Color c) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Row(
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 2),
        Text(
          val,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.blueGrey,
          ),
        ),
      ],
    ),
  );

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
                    color: Colors.black.withOpacity(0.02),
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
                          Colors.white.withOpacity(0.4),
                          Colors.white.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
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
                          ? primaryAppColor.withOpacity(0.12)
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
