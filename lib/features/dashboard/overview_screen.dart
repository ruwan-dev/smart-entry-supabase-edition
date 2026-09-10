import 'package:flutter/gestures.dart'; 
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'outstanding_list_screen.dart'; 

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
  String _selectedFilter = 'මෙම මාසය';
  bool _isLoading = true;
  bool _isSummaryLoading = true; // අලුතින් එක් කරන ලද විචල්‍යය

  bool _isMonthlySummaryExpanded = false; 

  double _totalWeight = 0.0;
  double _totalAdvance = 0.0;
  double _totalFertilizer1 = 0.0;
  double _totalFertilizer2 = 0.0;
  double _totalTeaPacket1 = 0.0;
  double _totalTeaPacket2 = 0.0;
  int _totalCustomers = 0;
  
  double _overallOutstandingAdvances = 0.0;
  
  Map<String, dynamic>? _latestSummaryData;
  String? _latestSummaryId;
  Map<String, dynamic>? _previousSummaryData; 

  double fert1Price = 0, fert2Price = 0, teaPkt1Price = 0, teaPkt2Price = 0;

  List<Map<String, dynamic>> _topSuppliers = [];
  List<Map<String, dynamic>> _allArrears = []; 
  
  final List<String> _filterOptions = ['අද', 'මෙම සතිය', 'මෙම මාසය', 'පසුගිය මාස 6', 'පසුගිය වසර'];

  String _chartFilter = 'මාසිකව';
  bool _isChartLoading = true;
  List<double> _chartValues = [];
  List<String> _chartLabels = [];
  
  final List<String> _chartFilterOptions = ['දිනපතා', 'මාසිකව', 'වාර්ෂිකව'];

  final Color primaryAppColor = const Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _fetchChartData();
  }

  bool _isInitialLoad = true;

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isSummaryLoading = true;
      if (_isInitialLoad) _isLoading = true;
    });
    
    DateTime now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_selectedFilter == 'අද') {
      start = DateTime(now.year, now.month, now.day);
    } else if (_selectedFilter == 'මෙම සතිය') {
      start = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(start.year, start.month, start.day);
    } else if (_selectedFilter == 'මෙම මාසය') {
      start = DateTime(now.year, now.month, 1);
    } else if (_selectedFilter == 'පසුගිය මාස 6') {
      start = DateTime(now.year, now.month - 5, 1);
    } else {
      start = DateTime(now.year - 1, now.month, now.day); 
    }

    try {
      var latestSummaries = await Supabase.instance.client
          .from('monthly_summaries')
          .select()
          .order('finalizedAt', ascending: false)
          .limit(2);

      if (latestSummaries.isNotEmpty) {
        _latestSummaryData = latestSummaries.first;
        _latestSummaryId = latestSummaries.first['id']; 
        
        if (latestSummaries.length > 1) {
          _previousSummaryData = latestSummaries[1];
        } else {
          _previousSummaryData = null;
        }
      } else {
        _latestSummaryData = null;
        _latestSummaryId = null;
        _previousSummaryData = null;
      }

      var priceDoc = await Supabase.instance.client.from('global_settings').select().eq('id', 'prices').maybeSingle();
      if (priceDoc != null) {
        fert1Price = (priceDoc['fertilizer1Price'] ?? 0.0).toDouble();
        fert2Price = (priceDoc['fertilizer2Price'] ?? 0.0).toDouble();
        teaPkt1Price = (priceDoc['teaPacket1Price'] ?? 0.0).toDouble();
        teaPkt2Price = (priceDoc['teaPacket2Price'] ?? 0.0).toDouble();
      }

      var ratesSnap = await Supabase.instance.client.from('monthly_rates').select();
      Map<String, double> ratesMap = {};
      for (var doc in ratesSnap) {
        ratesMap[doc['id']] = (doc['teaRate'] ?? 0.0).toDouble();
      }

      var customersSnapshot = await Supabase.instance.client.from('customers').select();
      Map<String, String> customerNames = {};
      for (var doc in customersSnapshot) {
        customerNames[doc['id']] = doc['name'] ?? 'Unknown';
      }

      var filteredEntries = await Supabase.instance.client
          .from('daily_entries')
          .select()
          .gte('timestamp', start.toIso8601String())
          .lte('timestamp', end.toIso8601String());

      double tw = 0.0, ta = 0.0, f1 = 0, f2 = 0, t1 = 0, t2 = 0;
      Map<String, double> supplierWeightMap = {};

      for (var d in filteredEntries) {
        double w = (d['netWeight'] ?? 0.0).toDouble();
        tw += w;
        ta += (d['advanceAmount'] ?? 0.0).toDouble();
        f1 += (d['fertilizer1Qty'] ?? 0.0).toDouble();
        f2 += (d['fertilizer2Qty'] ?? 0.0).toDouble();
        t1 += (d['teaPacket1Qty'] ?? 0.0).toDouble();
        t2 += (d['teaPacket2Qty'] ?? 0.0).toDouble();
        String cId = d['customerId'] ?? '';
        if (cId.isNotEmpty) supplierWeightMap[cId] = (supplierWeightMap[cId] ?? 0.0) + w;
      }

      var sortedSuppliers = supplierWeightMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      _topSuppliers = sortedSuppliers.take(5).map((e) => {'name': customerNames[e.key] ?? 'Unknown', 'weight': e.value}).toList();

      // ✅ CORRECT: Read from finalized_bills — these are official locked bills
      // that already include: transport cost, item prices, previous month arrears rollover
      // For each customer, get their LATEST finalized bill.
      // If netPayable < 0, that is the true outstanding amount.
      var allFinalizedBills = await Supabase.instance.client
          .from('finalized_bills')
          .select('customerId, customerName, refNumber, billData, finalizedAt')
          .order('finalizedAt', ascending: false);

      // Group by customerId — keep only the LATEST bill per customer
      Map<String, Map<String, dynamic>> latestBillPerCustomer = {};
      for (var bill in allFinalizedBills) {
        String cId = bill['customerId'] ?? '';
        if (cId.isEmpty) continue;
        // Since sorted by finalizedAt desc, first occurrence = latest
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

        // If latest bill netPayable is negative → customer owes that amount
        if (netPayable < 0) {
          double outstanding = netPayable.abs();
          arrearsMap[cId] = outstanding;
          totalOverallOutstanding += outstanding;
        }
      }

      _allArrears = arrearsMap.entries.toList().map((e) => {
        'id': e.key,
        'name': customerNames[e.key] ?? latestBillPerCustomer[e.key]?['customerName'] ?? 'Unknown',
        'customerNumber': customersSnapshot.firstWhere(
          (c) => c['id'] == e.key, 
          orElse: () => {'refNumber': ''},
        )['refNumber'] ?? '',
        'amount': e.value,
      }).toList()..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

      setState(() {
        _totalCustomers = customersSnapshot.length;
        _totalWeight = tw;
        _totalAdvance = ta;
        _totalFertilizer1 = f1; _totalFertilizer2 = f2;
        _totalTeaPacket1 = t1; _totalTeaPacket2 = t2;
        _overallOutstandingAdvances = totalOverallOutstanding;
        _isLoading = false;
        _isInitialLoad = false;
        _isSummaryLoading = false;
      });
    } catch (e) { 
      print(e);
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
    DateTime start;
    
    if (_chartFilter == 'දිනපතා') {
      start = DateTime(now.year, now.month, now.day - 29);
    } else if (_chartFilter == 'මාසිකව') {
      start = DateTime(now.year, now.month - 11, 1);
    } else { 
      start = DateTime(now.year - 4, 1, 1); 
    }

    try {
      var snapshot = await Supabase.instance.client.from('daily_entries').select().gte('timestamp', start.toIso8601String());
      List<double> tv = []; List<String> tl = [];
      
      if (_chartFilter == 'දිනපතා') {
        tv = List.filled(30, 0.0);
        for (int i = 29; i >= 0; i--) tl.add(DateFormat('MMM dd').format(now.subtract(Duration(days: i))));
        for (var doc in snapshot) {
          DateTime ts = DateTime.parse(doc['timestamp'].toString());
          int diff = DateTime(now.year, now.month, now.day).difference(DateTime(ts.year, ts.month, ts.day)).inDays;
          if (diff >= 0 && diff < 30) tv[29 - diff] += (doc['netWeight'] ?? 0.0).toDouble();
        }
      } else if (_chartFilter == 'මාසිකව') {
        tv = List.filled(12, 0.0);
        for (int i = 11; i >= 0; i--) {
          tl.add(DateFormat('MMM').format(DateTime(now.year, now.month - i, 1)));
        }
        for (var doc in snapshot) {
          DateTime ts = DateTime.parse(doc['timestamp'].toString());
          int monthDiff = (now.year - ts.year) * 12 + now.month - ts.month;
          if (monthDiff >= 0 && monthDiff < 12) {
            tv[11 - monthDiff] += (doc['netWeight'] ?? 0.0).toDouble();
          }
        }
      } else if (_chartFilter == 'වාර්ෂිකව') {
        tv = List.filled(5, 0.0);
        for (int i = 4; i >= 0; i--) {
          tl.add((now.year - i).toString());
        }
        for (var doc in snapshot) {
          DateTime ts = DateTime.parse(doc['timestamp'].toString());
          int yearDiff = now.year - ts.year;
          if (yearDiff >= 0 && yearDiff < 5) {
            tv[4 - yearDiff] += (doc['netWeight'] ?? 0.0).toDouble();
          }
        }
      }
      
      if (mounted) setState(() { 
        _chartValues = tv; 
        _chartLabels = tl; 
        _isChartLoading = false; 
        _isInitialChartLoad = false;
      });
    } catch (e) { if (mounted) setState(() => _isChartLoading = false); }
  }

  LineChartData _getYAxisData() {
    double mv = _chartValues.isNotEmpty ? _chartValues.reduce((a, b) => a > b ? a : b) : 100.0;
    if (mv == 0) mv = 100.0;
    
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
          )
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true, 
            reservedSize: 45, 
            interval: yInterval,
            getTitlesWidget: (v, m) {
              if (v == 0) return const SizedBox();
              String t = v >= 1000 ? '${(v/1000).toStringAsFixed(1)}k' : '${v.toInt()}';
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Text(t, style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w500), textAlign: TextAlign.right)
              );
            }
          )
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false), 
      lineBarsData: [
        LineChartBarData(
          spots: const [FlSpot(0, 0), FlSpot(1, 0)], 
          color: Colors.transparent, 
          dotData: const FlDotData(show: false),
        )
      ],
    );
  }

  LineChartData _getRealChartData() {
    double mv = _chartValues.isNotEmpty ? _chartValues.reduce((a, b) => a > b ? a : b) : 100.0;
    if (mv == 0) mv = 100.0;
    
    double yInterval = (mv / 5).ceilToDouble();
    if (yInterval == 0) yInterval = 10;

    double maxXV = (_chartValues.length > 1) ? (_chartValues.length - 1).toDouble() : 1.0;
    List<FlSpot> chartSpots = _chartValues.isEmpty
        ? const [FlSpot(0, 0), FlSpot(1, 0)]
        : (_chartValues.length == 1 
            ? [FlSpot(0, _chartValues[0]), FlSpot(1, _chartValues[0])] 
            : List.generate(_chartValues.length, (i) => FlSpot(i.toDouble(), _chartValues[i])));

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
                return Padding(padding: const EdgeInsets.only(top: 15.0), 
                  child: Transform.rotate(angle: -0.8, child: Text(_chartLabels[idx], style: const TextStyle(fontSize: 9, color: Colors.blueGrey, fontWeight: FontWeight.bold)))
                );
              }
              return const SizedBox();
            }
          )
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), 
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: true), 
      lineBarsData: [
        LineChartBarData(
          spots: chartSpots,
          isCurved: true, 
          color: primaryAppColor, 
          barWidth: 3.5, 
          dotData: FlDotData(
            show: true, 
            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: primaryAppColor)
          ),
          belowBarData: BarAreaData(
            show: true, 
            gradient: LinearGradient(
              colors: [primaryAppColor.withOpacity(0.3), primaryAppColor.withOpacity(0.0)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            )
          )
        )
      ],
    );
  }

  Widget _buildChartContainer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double availableWidthForChart = constraints.maxWidth - 50 - 15;
        if (availableWidthForChart < 0) availableWidthForChart = 0;

        double chartWidth = _chartFilter == 'දිනපතා' || _chartFilter == 'මාසිකව'
            ? (availableWidthForChart > 1200 ? availableWidthForChart : 1200.0) 
            : availableWidthForChart; 

        return Container(
          height: 340,
          padding: const EdgeInsets.only(top: 30, bottom: 10, right: 15),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(24), 
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 4))]
          ),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: LineChart(_getYAxisData()),
              ),
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
        );
      },
    );
  }

  Widget _buildCriticalAlertBanner(BuildContext context, NumberFormat currencyF) {
    if (_overallOutstandingAdvances <= 0) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => OutstandingListScreen(arrearsList: _allArrears)));
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.5))
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Color(0xFFFEE2E2), shape: BoxShape.circle),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("අවධානයට!", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B), fontSize: 14)),
                      const SizedBox(height: 4),
                      Text("ව්‍යාපාරයට රු. ${currencyF.format(_overallOutstandingAdvances)} ක හිඟ මුදලක් අයවීමට ඇත.", style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text("බලන්න", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullSkeletonDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SkeletonBox(height: 130, width: double.infinity, borderRadius: 24)),
              const SizedBox(width: 12),
              const Expanded(child: SkeletonBox(height: 130, width: double.infinity, borderRadius: 24)),
            ],
          ),
          const SizedBox(height: 24),
          const SkeletonBox(height: 280, width: double.infinity, borderRadius: 24),
          const SizedBox(height: 24),
          const SkeletonBox(height: 30, width: 150, borderRadius: 8), 
          const SizedBox(height: 16),
          const SkeletonBox(height: 340, width: double.infinity, borderRadius: 24),
          const SizedBox(height: 32),
          const SkeletonBox(height: 30, width: 120, borderRadius: 8), 
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: SkeletonBox(height: 140, width: double.infinity, borderRadius: 20)),
              const SizedBox(width: 12),
              const Expanded(child: SkeletonBox(height: 140, width: double.infinity, borderRadius: 20)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: SkeletonBox(height: 140, width: double.infinity, borderRadius: 20)),
              const SizedBox(width: 12),
              const Expanded(child: SkeletonBox(height: 140, width: double.infinity, borderRadius: 20)),
            ],
          ),
        ],
      ),
    );
  }

  // සාරාංශය (Summary) කොටස සඳහා පමණක් දිස්වන Skeleton Grid එක
  Widget _buildSkeletonSummaryGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double w = constraints.maxWidth;
        bool isMobile = w < 550; 
        bool isTablet = w < 900;
        double cardW = isMobile ? w : (isTablet ? (w - 16) / 2 : (w - 48) / 4);

        return Wrap(
          spacing: 16, runSpacing: 16,
          children: List.generate(4, (index) => SizedBox(
            width: cardW,
            child: const SkeletonBox(height: 140, width: double.infinity, borderRadius: 20),
          )),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyF = NumberFormat('#,##0.00', 'en_US');
    final weightF = NumberFormat('#,##0.##', 'en_US');

    final Map<String, IconData> summaryIconMap = {
      'අද': Icons.today_rounded,
      'මෙම සතිය': Icons.view_week_rounded,
      'මෙම මාසය': Icons.calendar_month_rounded,
      'පසුගිය මාස 6': Icons.date_range_rounded,
      'පසුගිය වසර': Icons.event_repeat_rounded,
    };

    final Map<String, IconData> chartIconMap = {
      'දිනපතා': Icons.view_day_rounded,
      'මාසිකව': Icons.calendar_view_month_rounded,
      'වාර්ෂිකව': Icons.calendar_today_rounded,
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), 
      body: RefreshIndicator(
        onRefresh: () async { await _fetchDashboardData(); await _fetchChartData(); },
        child: _isLoading 
            ? _buildFullSkeletonDashboard() 
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildCriticalAlertBanner(context, currencyF), 
                  _buildCombinedHeader(context, currencyF),
                  const SizedBox(height: 24),
                  
                  _buildIconToggleHeader('සාරාංශය', _selectedFilter, _filterOptions, summaryIconMap, (val) { 
                    if (_selectedFilter != val) {
                      setState(() => _selectedFilter = val); 
                      _fetchDashboardData(); 
                    }
                  }),
                  const SizedBox(height: 16),
                  
                  // Summary loading වන විට Skeleton පෙන්වීම
                  _isSummaryLoading 
                      ? _buildSkeletonSummaryGrid(context) 
                      : _buildSummaryGrid(context, weightF, currencyF),
                  
                  const SizedBox(height: 32),

                  _buildDbBusinessSummary(currencyF, weightF),
                  const SizedBox(height: 32),

                  _buildIconToggleHeader('දළු එකතුව (Kg)', _chartFilter, _chartFilterOptions, chartIconMap, (val) { 
                    setState(() => _chartFilter = val); 
                    _fetchChartData(); 
                  }),
                  const SizedBox(height: 16),
                  _isChartLoading ? const SkeletonBox(height: 340, width: double.infinity, borderRadius: 24) : _buildChartContainer(),
                  const SizedBox(height: 40),

                  const Text('වැඩිම දළු සැපයුම්කරුවන්', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
                  const SizedBox(height: 16),
                  _buildTopSuppliersList(weightF),
                  const SizedBox(height: 20),
                ]),
              ),
      ),
    );
  }

  Widget _buildCombinedHeader(BuildContext context, NumberFormat currencyF) { 
    return LayoutBuilder(
      builder: (context, constraints) {
        double w = constraints.maxWidth;
        bool isMobile = w < 550; 
        double cardWidth = isMobile ? w : (w - 16) / 2; 

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: cardWidth, 
              child: _statHeaderCard(
                title: 'පාරිභෝගිකයින්', 
                value: '$_totalCustomers', 
                icon: Icons.people_alt_rounded, 
                color: primaryAppColor, 
                bgColor: Colors.white,
                onTap: () {}
              )
            ), 
            SizedBox(
              width: cardWidth, 
              child: _statHeaderCard(
                title: 'මුළු හිඟ මුදල', 
                value: 'Rs. ${currencyF.format(_overallOutstandingAdvances)}', 
                icon: Icons.account_balance_wallet_rounded, 
                color: const Color(0xFFD32F2F), 
                bgColor: Colors.white,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OutstandingListScreen(arrearsList: _allArrears)))
              )
            )
          ]
        );
      }
    ); 
  }

  Widget _statHeaderCard({required String title, required String value, required IconData icon, required Color color, required Color bgColor, required VoidCallback onTap}) { 
    return InkWell(
      onTap: onTap, 
      borderRadius: BorderRadius.circular(24), 
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), 
        decoration: BoxDecoration(
          color: bgColor, 
          borderRadius: BorderRadius.circular(24), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, spreadRadius: 0, offset: const Offset(0, 4))]
        ), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, 
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ), 
                const SizedBox(width: 12), 
                Text(title, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13, fontWeight: FontWeight.w600))
              ]
            ), 
            const SizedBox(height: 16), 
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(color: const Color(0xFF1F2937), fontSize: color == const Color(0xFFD32F2F) ? 18 : 26, fontWeight: FontWeight.w800))
            )
          ]
        )
      )
    ); 
  }
  
  Widget _buildDbBusinessSummary(NumberFormat currencyF, NumberFormat weightF) { 
    if (_latestSummaryData == null || _latestSummaryId == null) return const SizedBox(); 
    String displayDate = _latestSummaryId!; 
    String monthName = "";
    try { 
      List<String> parts = _latestSummaryId!.split('-'); 
      if (parts.length >= 2) {
        displayDate = "${parts[1]} ${parts[0]}"; 
        monthName = parts[1]; 
      }
    } catch (e) {} 
    
    String summaryTitle = monthName.isNotEmpty ? "$monthName මාසික සාරාංශය" : "මාසික සාරාංශය";

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

    double? pWeight = _previousSummaryData != null ? (_previousSummaryData!['totalWeight'] ?? 0).toDouble() : null;
    double? pGross = _previousSummaryData != null ? (_previousSummaryData!['totalGross'] ?? 0).toDouble() : null;
    double? pAdv = _previousSummaryData != null ? (_previousSummaryData!['totalAdvance'] ?? 0).toDouble() : null;
    double? pTrans = _previousSummaryData != null ? (_previousSummaryData!['totalTransport'] ?? 0).toDouble() : null;
    double? pFertAmt;
    if (_previousSummaryData != null) {
      pFertAmt = (_previousSummaryData!['totalF1Amt'] ?? 0).toDouble() + (_previousSummaryData!['totalF2Amt'] ?? 0).toDouble();
      if (pFertAmt == 0) pFertAmt = (_previousSummaryData!['totalFertilizer'] ?? 0).toDouble();
    }
    double? pTeaAmt;
    if (_previousSummaryData != null) {
      pTeaAmt = (_previousSummaryData!['totalT1Amt'] ?? 0).toDouble() + (_previousSummaryData!['totalT2Amt'] ?? 0).toDouble();
      if (pTeaAmt == 0) pTeaAmt = (_previousSummaryData!['totalTeaPacket'] ?? 0).toDouble();
    }
    double? pNegNet = _previousSummaryData != null ? (_previousSummaryData!['totalNegativeNet'] ?? 0).toDouble().abs() : null;
    double? pPosNet = _previousSummaryData != null ? (_previousSummaryData!['totalPositiveNet'] ?? 0).toDouble() : null;
    double? pNet = _previousSummaryData != null ? (_previousSummaryData!['totalNet'] ?? 0).toDouble() : null;

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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, spreadRadius: 2, offset: const Offset(0, 8))]
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
                      Row(
                        children: [
                          Text(summaryTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))), 
                          const SizedBox(width: 8),
                          Icon(
                            _isMonthlySummaryExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: primaryAppColor,
                            size: 24,
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(20)), 
                        child: Text(displayDate, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryAppColor))
                      )
                    ]
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
                              SizedBox(width: w2, child: _miniTile(label: "මුළු දළු බර", value: "${weightF.format(cWeight)} Kg", icon: Icons.scale_rounded, color: const Color(0xFFF59E0B), currentVal: cWeight, prevVal: pWeight)), 
                              SizedBox(width: w2, child: _miniTile(label: "මුළු ආදායම", value: "Rs. ${currencyF.format(cGross)}", icon: Icons.trending_up_rounded, color: primaryAppColor, currentVal: cGross, prevVal: pGross)), 
                              
                              SizedBox(width: w2, child: _miniTile(label: "අත්තිකාරම් මුදල්", value: "Rs. ${currencyF.format(cAdv)}", icon: Icons.payments_rounded, color: const Color(0xFF3B82F6), currentVal: cAdv, prevVal: pAdv, invertTrend: true)), 
                              SizedBox(width: w2, child: _miniTile(label: "ප්‍රවාහන වියදම", value: "Rs. ${currencyF.format(cTrans)}", icon: Icons.local_shipping_rounded, color: const Color(0xFFEF4444), currentVal: cTrans, prevVal: pTrans, invertTrend: true)), 
                              
                              SizedBox(width: w2, child: _miniTile(
                                label: "පොහොර වියදම", value: "Rs. ${currencyF.format(cFertAmt)}", icon: Icons.compost_rounded, color: const Color(0xFF047857), currentVal: cFertAmt, prevVal: pFertAmt, invertTrend: true,
                                extraDetails: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("වර්ගය 1: ${weightF.format(f1Qty)} | Rs. ${currencyF.format(cF1Amt)}", style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 2),
                                    Text("වර්ගය 2: ${weightF.format(f2Qty)} | Rs. ${currencyF.format(cF2Amt)}", style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                                  ],
                                )
                              )), 
                              SizedBox(width: w2, child: _miniTile(
                                label: "තේ පැකට් වියදම", value: "Rs. ${currencyF.format(cTeaAmt)}", icon: Icons.local_cafe_rounded, color: const Color(0xFF8B5CF6), currentVal: cTeaAmt, prevVal: pTeaAmt, invertTrend: true,
                                extraDetails: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("වර්ගය 1: ${weightF.format(t1Qty)} | Rs. ${currencyF.format(cT1Amt)}", style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 2),
                                    Text("වර්ගය 2: ${weightF.format(t2Qty)} | Rs. ${currencyF.format(cT2Amt)}", style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                                  ],
                                )
                              )), 
                              
                              SizedBox(width: w3, child: _miniTile(label: "අයවියයුතු මුදල", value: "Rs. ${currencyF.format(cNegNet)}", icon: Icons.arrow_circle_down_rounded, color: const Color(0xFFE11D48), currentVal: cNegNet, prevVal: pNegNet, invertTrend: true)), 
                              SizedBox(width: w3, child: _miniTile(label: "ලබා දිය යුතු මුදල", value: "Rs. ${currencyF.format(cPosNet)}", icon: Icons.arrow_circle_up_rounded, color: const Color(0xFF059669), currentVal: cPosNet, prevVal: pPosNet)), 
                              SizedBox(width: w3, child: _miniTile(label: "ලාභ/අලාභය", value: "Rs. ${currencyF.format(cNet)}", icon: Icons.account_balance_rounded, color: primaryAppColor, currentVal: cNet, prevVal: pNet)), 
                            ]
                          )
                        ],
                      )
                    : const SizedBox.shrink(), 
              ),
            ]
          );
        }
      )
    ); 
  }
  
  Widget _miniTile({
    required String label, required String value, required IconData icon, required Color color, 
    Widget? extraDetails, double? currentVal, double? prevVal, bool invertTrend = false,
  }) {
    Widget trendWidget = const SizedBox();
    
    if (currentVal != null && prevVal != null) {
      double change = 0;
      if (prevVal != 0) change = ((currentVal - prevVal) / prevVal.abs()) * 100;
      else if (currentVal != 0) change = currentVal > 0 ? 100.0 : -100.0;

      if (prevVal != 0 || currentVal != 0) {
        bool isUp = change > 0;
        bool isSame = change == 0;
        
        Color tColor = isSame ? Colors.blueGrey : (isUp ? (invertTrend ? const Color(0xFFDC2626) : const Color(0xFF16A34A)) : (invertTrend ? const Color(0xFF16A34A) : const Color(0xFFDC2626)));
        IconData tIcon = isSame ? Icons.horizontal_rule_rounded : (isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);
        String tText = isSame ? "0%" : "${change.abs().toStringAsFixed(1)}%";
        
        trendWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: tColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tIcon, color: tColor, size: 12),
              const SizedBox(width: 2),
              Text(tText, style: TextStyle(color: tColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ]
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(16), 
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 16)), 
              const SizedBox(width: 10), 
              Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            ]
          ),
          const SizedBox(height: 12), 
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(color: Color(0xFF111827), fontSize: 14, fontWeight: FontWeight.w800)))),
              if (trendWidget is! SizedBox) ...[const SizedBox(width: 8), trendWidget]
            ]
          ),
          if (extraDetails != null) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.only(top: 12), decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))), child: extraDetails)
          ]
        ]
      )
    );
  }

  Widget _buildSummaryGrid(BuildContext context, NumberFormat weightF, NumberFormat currencyF) { 
    return LayoutBuilder(
      builder: (context, constraints) {
        double w = constraints.maxWidth;
        bool isMobile = w < 550; 
        bool isTablet = w < 900;
        double cardW = isMobile ? w : (isTablet ? (w - 16) / 2 : (w - 48) / 4);

        return Wrap(
          spacing: 16, runSpacing: 16,
          children: [
            SizedBox(width: cardW, child: _summaryCard(title: 'මුළු දළු', value: '${weightF.format(_totalWeight)} Kg', icon: Icons.eco_rounded, color: primaryAppColor)),
            SizedBox(width: cardW, child: _summaryCard(title: 'අත්තිකාරම්', value: 'Rs. ${currencyF.format(_totalAdvance)}', icon: Icons.payments_rounded, color: const Color(0xFF3B82F6))),
            SizedBox(width: cardW, child: _summaryCard(title: 'පොහොර', value: weightF.format(_totalFertilizer1 + _totalFertilizer2), icon: Icons.compost_rounded, color: const Color(0xFF047857), subItems: [_buildSubItemIcon(Icons.compost_rounded, weightF.format(_totalFertilizer1), const Color(0xFFEF4444)), _buildSubItemIcon(Icons.compost_rounded, weightF.format(_totalFertilizer2), const Color(0xFF3B82F6))])),
            SizedBox(width: cardW, child: _summaryCard(title: 'තේ පැකට්', value: weightF.format(_totalTeaPacket1 + _totalTeaPacket2), icon: Icons.local_cafe_rounded, color: const Color(0xFF8B5CF6), subItems: [_buildSubItemIcon(Icons.local_cafe_rounded, weightF.format(_totalTeaPacket1), const Color(0xFFEF4444)), _buildSubItemIcon(Icons.local_cafe_rounded, weightF.format(_totalTeaPacket2), const Color(0xFF3B82F6))])),
          ]
        );
      }
    );
  }
  
  Widget _summaryCard({required String title, required String value, required IconData icon, required Color color, List<Widget>? subItems}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18), 
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, spreadRadius: 0, offset: const Offset(0, 4))]), 
    child: Column(
      mainAxisSize: MainAxisSize.min, 
      mainAxisAlignment: MainAxisAlignment.center, 
      children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)), 
        const SizedBox(height: 12), 
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)))), 
        const SizedBox(height: 6),
        SizedBox(height: 16, child: subItems != null ? Row(mainAxisAlignment: MainAxisAlignment.center, children: subItems) : null), 
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, child: Text(title, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w600))) 
      ]
    )
  );

  Widget _buildSubItemIcon(IconData icon, String val, Color c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Row(children: [Icon(icon, size: 10, color: c), const SizedBox(width: 4), Text(val, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.blueGrey))]));
  
  Widget _buildTopSuppliersList(NumberFormat weightF) { 
    if (_topSuppliers.isEmpty) return const Center(child: Text('දත්ත නොමැත', style: TextStyle(color: Colors.grey))); 
    return Column(children: _topSuppliers.map((s) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(width: 40, height: 40, decoration: const BoxDecoration(color: Color(0xFFE3F2FD), shape: BoxShape.circle), child: Center(child: Text((_topSuppliers.indexOf(s) + 1).toString(), style: TextStyle(color: primaryAppColor, fontWeight: FontWeight.w800)))), 
        title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF374151))), 
        trailing: Text('${weightF.format(s['weight'])} Kg', style: TextStyle(color: primaryAppColor, fontWeight: FontWeight.w800, fontSize: 14)) 
      )
    )).toList()); 
  }
  
  Widget _buildIconToggleHeader(String title, String value, List<String> options, Map<String, IconData> iconMap, Function(String) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))), 
        Container(
          padding: const EdgeInsets.all(4), 
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(14), 
            border: Border.all(color: Colors.grey.shade300)
          ), 
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: options.map((option) {
              bool isSelected = value == option;
              return Tooltip(
                message: option, 
                child: InkWell(
                  onTap: () => onChanged(option),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryAppColor.withOpacity(0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      iconMap[option] ?? Icons.filter_alt_rounded,
                      size: 20,
                      color: isSelected ? primaryAppColor : Colors.blueGrey.shade400,
                    ),
                  ),
                ),
              );
            }).toList(),
          )
        )
      ]
    );
  }
}

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  const SkeletonBox({super.key, required this.width, required this.height, this.borderRadius = 12});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _colorAnimation = ColorTween(begin: const Color(0xFFE5E7EB), end: const Color(0xFFF3F4F6)).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: _colorAnimation.value, 
          borderRadius: BorderRadius.circular(widget.borderRadius)
        ),
      ),
    );
  }
}