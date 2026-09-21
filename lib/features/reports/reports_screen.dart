import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

import 'package:smart_entry/core/widgets/blinking_logo_loader.dart';
import 'widgets/monthly_closing_widget.dart';
import 'widgets/whatsapp_management_widget.dart';
import 'package:smart_entry/core/app_state.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  String _selectedReportType = 'Daily All Data';
  String? _selectedCustomerId;

  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = false;

  final List<String> _reportTypes = [
    'Daily All Data',
    'Customer Wise',
    'Tea Leaves Only',
    'Fertilizer Wise',
    'Tea Packet Wise',
    'Advances & Items',
  ];

  final Color primaryAppColor = const Color(0xFF1976D2);

  // Analysis State
  bool _hasAnalyzed = false;
  List<Map<String, dynamic>> _analyzedEntries = [];
  Map<String, String> _customerNamesMap = {};
  double _fert1Price = 0, _fert2Price = 0, _teaPkt1Price = 0, _teaPkt2Price = 0;
  double _totalWeight = 0, _totalAdvance = 0, _totalDed = 0;
  double _totalF1 = 0, _totalF2 = 0, _totalT1 = 0, _totalT2 = 0;

  // Pagination State
  int _currentPage = 0;
  final int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    var snap = await Supabase.instance.client
        .from('customers')
        .select().eq('organization_id', AppState.currentOrganizationId.value ?? '')
        .order('name');
    setState(() {
      _customers = List.from(snap);
      for (var c in _customers) {
        _customerNamesMap[c['id']] = c['name'] ?? 'Unknown';
      }
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryAppColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _analyzeData() async {
    if (_selectedReportType == 'Customer Wise' && _selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('කරුණාකර පාරිභෝගිකයෙකු තෝරන්න')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      var priceDoc = await Supabase.instance.client
          .from('global_settings')
          .select().eq('organization_id', AppState.currentOrganizationId.value ?? '')
          .eq('id', 'prices')
          .maybeSingle();
      if (priceDoc != null) {
        _fert1Price = (priceDoc['fertilizer1Price'] ?? 0.0).toDouble();
        _fert2Price = (priceDoc['fertilizer2Price'] ?? 0.0).toDouble();
        _teaPkt1Price = (priceDoc['teaPacket1Price'] ?? 0.0).toDouble();
        _teaPkt2Price = (priceDoc['teaPacket2Price'] ?? 0.0).toDouble();
      }

      DateTime endOfDay = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        23,
        59,
        59,
      );

      List<dynamic> snap = [];
      int offset = 0;
      int limit = 1000;
      while (true) {
        var chunk = await Supabase.instance.client
            .from('daily_entries')
            .select().eq('organization_id', AppState.currentOrganizationId.value ?? '')
            .gte('timestamp', _startDate.toIso8601String())
            .lte('timestamp', endOfDay.toIso8601String())
            .range(offset, offset + limit - 1);
        snap.addAll(chunk);
        if (chunk.length < limit) break;
        offset += limit;
      }

      List<Map<String, dynamic>> entries = List.from(snap);

      if (_selectedReportType == 'Customer Wise') {
        entries = entries
            .where((doc) => doc['customerId'] == _selectedCustomerId)
            .toList();
      } else if (_selectedReportType == 'Tea Leaves Only') {
        entries = entries.where((doc) => (doc['netWeight'] ?? 0) > 0).toList();
      } else if (_selectedReportType == 'Fertilizer Wise') {
        entries = entries
            .where(
              (doc) =>
                  (doc['fertilizer1Qty'] ?? 0) > 0 ||
                  (doc['fertilizer2Qty'] ?? 0) > 0,
            )
            .toList();
      } else if (_selectedReportType == 'Tea Packet Wise') {
        entries = entries
            .where(
              (doc) =>
                  (doc['teaPacket1Qty'] ?? 0) > 0 ||
                  (doc['teaPacket2Qty'] ?? 0) > 0,
            )
            .toList();
      } else if (_selectedReportType == 'Advances & Items') {
        entries = entries
            .where(
              (doc) =>
                  (doc['advanceAmount'] ?? 0) > 0 ||
                  (doc['fertilizer1Qty'] ?? 0) > 0 ||
                  (doc['fertilizer2Qty'] ?? 0) > 0 ||
                  (doc['teaPacket1Qty'] ?? 0) > 0 ||
                  (doc['teaPacket2Qty'] ?? 0) > 0,
            )
            .toList();
      }

      entries.sort(
        (a, b) => DateTime.parse(
          a['timestamp'],
        ).compareTo(DateTime.parse(b['timestamp'])),
      );

      double tWeight = 0, tAdvance = 0, tDed = 0;
      double tF1 = 0, tF2 = 0, tT1 = 0, tT2 = 0;

      for (var data in entries) {
        double w = (data['netWeight'] ?? 0).toDouble();
        double adv = (data['advanceAmount'] ?? 0).toDouble();
        double f1 = (data['fertilizer1Qty'] ?? 0).toDouble();
        double f2 = (data['fertilizer2Qty'] ?? 0).toDouble();
        double t1 = (data['teaPacket1Qty'] ?? 0).toDouble();
        double t2 = (data['teaPacket2Qty'] ?? 0).toDouble();
        double rowTotal =
            adv +
            (f1 * _fert1Price) +
            (f2 * _fert2Price) +
            (t1 * _teaPkt1Price) +
            (t2 * _teaPkt2Price);

        tWeight += w;
        tAdvance += adv;
        tF1 += f1;
        tF2 += f2;
        tT1 += t1;
        tT2 += t2;
        tDed += rowTotal;
      }

      setState(() {
        _analyzedEntries = entries;
        _totalWeight = tWeight;
        _totalAdvance = tAdvance;
        _totalF1 = tF1;
        _totalF2 = tF2;
        _totalT1 = tT1;
        _totalT2 = tT2;
        _totalDed = tDed;
        _hasAnalyzed = true;
        _isLoading = false;
        _currentPage = 0;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. DefaultTabController මගින් පිටුව කොටස් 3කට වෙන් කිරීම
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8), // ආකර්ෂණීය ලා අළු පසුබිම
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F2937),
          elevation: 0,
          toolbarHeight: 0,
          bottom: TabBar(
            labelColor: primaryAppColor,
            unselectedLabelColor: Colors.blueGrey.shade400,
            indicatorColor: primaryAppColor,
            indicatorWeight: 4,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'ගිණුම් පියවීම (Closing)'),
              Tab(text: 'දත්ත විශ්ලේෂණය (Analysis)'),
              Tab(text: 'WhatsApp (වට්ස්ඇප්)'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 1 වැනි Tab එක: මාසික ගිණුම් පියවීම
            _buildClosingTab(),

            // 2 වැනි Tab එක: දත්ත විශ්ලේෂණය
            _buildAnalysisTab(),

            // 3 වැනි Tab එක: WhatsApp
            const WhatsappManagementWidget(),
          ],
        ),
      ),
    );
  }

  // --- Tab 1: ගිණුම් පියවීම ---
  Widget _buildClosingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'මාසික ගිණුම් අවසන් කිරීම',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'මෙහිදී අදාළ මාසයේ සියලුම දත්ත පරීක්ෂා කර ස්ථිර කිරීම සිදු කෙරේ.',
            style: TextStyle(fontSize: 13, color: Colors.blueGrey),
          ),
          const SizedBox(height: 24),

          // Original widget එක අලංකාර Container එකකට ඇතුළත් කර ඇත
          // Original widget එක අලංකාර Container එකකට ඇතුළත් කර ඇත
          const MonthlyClosingWidget(),
        ],
      ),
    );
  }

  // --- Tab 2: දත්ත විශ්ලේෂණය ---
  Widget _buildAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'දත්ත විශ්ලේෂණය',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ඔබට අවශ්‍ය දින පරාසය සහ වර්ගය තෝරා දත්ත තිරය මත විශ්ලේෂණය කරන්න.',
            style: TextStyle(fontSize: 13, color: Colors.blueGrey),
          ),
          const SizedBox(height: 24),

          if (!_hasAnalyzed)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        height: 360,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.6),
                              Colors.white.withOpacity(0.2),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.8),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'දින පරාසය',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildDatePickerSection(),
                                const SizedBox(height: 16),
                                const Text(
                                  'වාර්තා වර්ගය',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildDropdown(
                                  _selectedReportType,
                                  _reportTypes,
                                  (val) => setState(() {
                                    _selectedReportType = val!;
                                    if (val != 'Customer Wise') {
                                      _selectedCustomerId = null;
                                    }
                                    _hasAnalyzed = false;
                                  }),
                                ),
                                if (_selectedReportType == 'Customer Wise') ...[
                                  const SizedBox(height: 16),
                                  const Text(
                                    'පාරිභෝගිකයා තෝරන්න',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildCustomerDropdown(),
                                ],
                                const SizedBox(height: 24),
                                _buildAnalyzeButton(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/analysis_bg.jpg',
                      fit: BoxFit.cover,
                      height: 360,
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${DateFormat('yyyy-MM-dd').format(_startDate)} සිට ${DateFormat('yyyy-MM-dd').format(_endDate)} දක්වා • $_selectedReportType',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _hasAnalyzed = false),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('වෙනස් කරන්න'),
                ),
              ],
            ),

          if (_hasAnalyzed) ...[
            const SizedBox(height: 32),
            _buildAnalysisResults(),
          ],
        ],
      ),
    );
  }

  // --- UI Helper Widgets ---

  Widget _buildDatePickerSection() {
    return Row(
      children: [
        Expanded(child: _dateTile('මුල දින', _startDate, true)),
        const SizedBox(width: 16),
        Expanded(child: _dateTile('අවසාන දින', _endDate, false)),
      ],
    );
  }

  // නවීන පෙනුමකින් යුත් Date Picker Tile
  Widget _dateTile(String label, DateTime date, bool isStart) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _selectDate(context, isStart),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                border: Border.all(color: Colors.white.withOpacity(0.7)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    color: primaryAppColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('yyyy-MM-dd').format(date),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFF1F2937),
                          ),
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
    );
  }

  // නවීන පෙනුමකින් යුත් Dropdown Component
  Widget _buildDropdown(
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            border: Border.all(color: Colors.white.withOpacity(0.7)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.blueGrey,
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerDropdown() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            border: Border.all(color: Colors.white.withOpacity(0.7)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCustomerId,
              hint: const Text(
                'පාරිභෝගිකයෙකු තෝරන්න',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.blueGrey,
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
              items: _customers
                  .map(
                    (doc) => DropdownMenuItem<String>(
                      value: doc['id'] as String,
                      child: Text((doc['name'] ?? '') as String),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedCustomerId = val),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    Color actionColor = const Color(0xFF0096C7);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 48,
          width: double.infinity,
          decoration: BoxDecoration(
            color: actionColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: actionColor.withOpacity(0.5), width: 1.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _analyzeData,
              child: Center(
                child: _isLoading
                    ? const BlinkingLogoLoader(size: 28)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 22,
                            color: actionColor,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'සොයන්න',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 0.5,
                              color: actionColor,
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

  Widget _buildAnalysisResults() {
    final currencyF = NumberFormat('#,##0.00');
    final weightF = NumberFormat('#,##0.0');

    bool showWeight = [
      'Daily All Data',
      'Customer Wise',
      'Tea Leaves Only',
    ].contains(_selectedReportType);
    bool showAdvance = [
      'Daily All Data',
      'Customer Wise',
      'Advances & Items',
    ].contains(_selectedReportType);
    bool showFertilizer = [
      'Daily All Data',
      'Customer Wise',
      'Advances & Items',
      'Fertilizer Wise',
    ].contains(_selectedReportType);
    bool showTeaPkt = [
      'Daily All Data',
      'Customer Wise',
      'Advances & Items',
      'Tea Packet Wise',
    ].contains(_selectedReportType);
    bool showTotalDed = [
      'Daily All Data',
      'Customer Wise',
      'Advances & Items',
    ].contains(_selectedReportType);

    int totalRecords = _analyzedEntries.length;
    int totalPages = (totalRecords / _rowsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    int startIndex = _currentPage * _rowsPerPage;
    int endIndex = startIndex + _rowsPerPage;
    if (endIndex > totalRecords) endIndex = totalRecords;

    List<Map<String, dynamic>> currentEntries = _analyzedEntries.sublist(
      startIndex,
      endIndex,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'විශ්ලේෂණ ප්‍රතිඵල',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),

        // Summary Cards Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (showWeight)
                _buildSummaryCard(
                  'මුළු දළු',
                  '${weightF.format(_totalWeight)} Kg',
                  Icons.eco_rounded,
                  Colors.green,
                ),
              if (showAdvance) const SizedBox(width: 12),
              if (showAdvance)
                _buildSummaryCard(
                  'මුළු අත්තිකාරම්',
                  'Rs. ${currencyF.format(_totalAdvance)}',
                  Icons.payments_rounded,
                  Colors.blue,
                ),
              if (showTotalDed) const SizedBox(width: 12),
              if (showTotalDed)
                _buildSummaryCard(
                  'මුළු අඩු කිරීම්',
                  'Rs. ${currencyF.format(_totalDed)}',
                  Icons.remove_circle_outline_rounded,
                  Colors.redAccent,
                ),
              if (showFertilizer) const SizedBox(width: 12),
              if (showFertilizer)
                _buildSummaryCard(
                  'පොහොර (මිටි)',
                  '${weightF.format(_totalF1 + _totalF2)}',
                  Icons.compost_rounded,
                  Colors.teal,
                ),
              if (showTeaPkt) const SizedBox(width: 12),
              if (showTeaPkt)
                _buildSummaryCard(
                  'තේ පැකට්',
                  '${weightF.format(_totalT1 + _totalT2)}',
                  Icons.local_cafe_rounded,
                  Colors.purple,
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Data Table Container
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF9FAFB),
                          ),
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF374151),
                            fontSize: 13,
                          ),
                          dataTextStyle: const TextStyle(
                            color: Color(0xFF4B5563),
                            fontSize: 13,
                          ),
                          columnSpacing: 24,
                          columns: [
                            const DataColumn(label: Text('දිනය (Date)')),
                            const DataColumn(
                              label: Text('පාරිභෝගිකයා (Customer)'),
                            ),
                            if (showWeight)
                              const DataColumn(
                                label: Text('දළු (Weight)'),
                                numeric: true,
                              ),
                            if (showAdvance)
                              const DataColumn(
                                label: Text('අත්තිකාරම් (Advance)'),
                                numeric: true,
                              ),
                            if (showFertilizer)
                              const DataColumn(
                                label: Text('පොහොර 1'),
                                numeric: true,
                              ),
                            if (showFertilizer)
                              const DataColumn(
                                label: Text('පොහොර 2'),
                                numeric: true,
                              ),
                            if (showTeaPkt)
                              const DataColumn(
                                label: Text('තේ පැකට්'),
                                numeric: true,
                              ),
                            if (showTotalDed)
                              const DataColumn(
                                label: Text('මුළු මුදල (Total Ded.)'),
                                numeric: true,
                              ),
                          ],
                          rows: currentEntries.map((data) {
                            String date = DateFormat(
                              'MM-dd',
                            ).format(DateTime.parse(data['timestamp']));
                            String cName =
                                _customerNamesMap[data['customerId']] ?? '-';

                            double w = (data['netWeight'] ?? 0).toDouble();
                            double adv = (data['advanceAmount'] ?? 0)
                                .toDouble();
                            double f1 = (data['fertilizer1Qty'] ?? 0)
                                .toDouble();
                            double f2 = (data['fertilizer2Qty'] ?? 0)
                                .toDouble();
                            double t1 = (data['teaPacket1Qty'] ?? 0).toDouble();
                            double t2 = (data['teaPacket2Qty'] ?? 0).toDouble();
                            double rowTotal =
                                adv +
                                (f1 * _fert1Price) +
                                (f2 * _fert2Price) +
                                (t1 * _teaPkt1Price) +
                                (t2 * _teaPkt2Price);

                            return DataRow(
                              cells: [
                                DataCell(Text(date)),
                                DataCell(Text(cName)),
                                if (showWeight)
                                  DataCell(
                                    Text(w > 0 ? w.toStringAsFixed(1) : '-'),
                                  ),
                                if (showAdvance)
                                  DataCell(
                                    Text(adv > 0 ? currencyF.format(adv) : '-'),
                                  ),
                                if (showFertilizer)
                                  DataCell(
                                    Text(f1 > 0 ? f1.toStringAsFixed(0) : '-'),
                                  ),
                                if (showFertilizer)
                                  DataCell(
                                    Text(f2 > 0 ? f2.toStringAsFixed(0) : '-'),
                                  ),
                                if (showTeaPkt)
                                  DataCell(
                                    Text(
                                      t1 > 0 || t2 > 0
                                          ? '${t1.toInt()}/${t2.toInt()}'
                                          : '-',
                                    ),
                                  ),
                                if (showTotalDed)
                                  DataCell(
                                    Text(
                                      rowTotal > 0
                                          ? currencyF.format(rowTotal)
                                          : '-',
                                    ),
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Pagination Footer
              if (totalRecords > 0) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${startIndex + 1}-${endIndex} of $totalRecords',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        splashRadius: 20,
                        onPressed: _currentPage > 0
                            ? () => setState(() => _currentPage--)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        splashRadius: 20,
                        onPressed: _currentPage < totalPages - 1
                            ? () => setState(() => _currentPage++)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 160,
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
