import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:smart_entry/core/widgets/blinking_logo_loader.dart';
import 'widgets/monthly_closing_widget.dart';
import 'widgets/whatsapp_management_widget.dart';
import 'package:smart_entry/core/app_state.dart';
import '../../core/items/item_service.dart';
import '../../core/items/item_model.dart';
import 'package:smart_entry/core/localization/app_strings.dart';
import 'package:smart_entry/core/localization/app_language.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  String _activePreset = 'This Month';

  String _selectedReportType = 'Daily All Data';
  String? _selectedCustomerId;
  String? _selectedCustomItemId;
  CustomItem? _selectedCustomItem;

  List<Map<String, dynamic>> _customers = [];
  List<CustomItem> _orgCustomItems = [];
  bool _isLoading = false;

  final List<String> _reportTypes = [
    'Daily All Data',
    'Customer Wise',
    'Tea Leaves Only',
    'Advances & Items',
    'Item Wise Breakdown',
  ];

  final Color primaryAppColor = const Color(0xFF1976D2);

  // Analysis State
  bool _hasAnalyzed = false;
  List<Map<String, dynamic>> _analyzedEntries = [];
  Map<String, String> _customerNamesMap = {};
  double _fert1Price = 0, _fert2Price = 0, _teaPkt1Price = 0, _teaPkt2Price = 0;
  double _totalWeight = 0, _totalAdvance = 0, _totalDed = 0;
  double _totalF1 = 0, _totalF2 = 0, _totalT1 = 0, _totalT2 = 0;
  int _uniqueDatesCount = 0;
  int _uniqueCustomersCount = 0;
  double _avgDailyWeight = 0;

  // Search filter
  String _searchQuery = '';

  // Pagination State
  int _currentPage = 0;
  final int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    AppLanguageService.currentLanguage.addListener(_onLanguageChanged);
    _fetchCustomers();
    _fetchCustomItems();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppLanguageService.currentLanguage.removeListener(_onLanguageChanged);
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    var snap = await Supabase.instance.client
        .from('customers')
        .select()
        .eq('organization_id', AppState.currentOrganizationId.value ?? '')
        .order('name');
    setState(() {
      _customers = List.from(snap);
      for (var c in _customers) {
        _customerNamesMap[c['id']] = c['name'] ?? 'Unknown';
      }
    });
  }

  Future<void> _fetchCustomItems() async {
    final items = await ItemService.getItems(
      organizationId: AppState.currentOrganizationId.value ?? '',
      activeOnly: false,
    );
    if (mounted) {
      setState(() {
        _orgCustomItems = items;
      });
    }
  }

  void _applyDatePreset(String preset) {
    final now = DateTime.now();
    DateTime start = _startDate;
    DateTime end = _endDate;

    switch (preset) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'This Week':
        final weekday = now.weekday; // 1 = Monday
        start = DateTime(now.year, now.month, now.day - (weekday - 1));
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'This Month':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'Last Month':
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        final lastDay = DateTime(now.year, now.month, 0).day;
        start = DateTime(prevYear, prevMonth, 1);
        end = DateTime(prevYear, prevMonth, lastDay, 23, 59, 59);
        break;
      case 'Custom':
        break;
    }

    setState(() {
      _activePreset = preset;
      _startDate = start;
      _endDate = end;
    });

    if (preset != 'Custom') {
      _analyzeData();
    }
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
        _activePreset = 'Custom';
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
        SnackBar(content: Text(AppStrings.pleaseSelectCustomer)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final orgItems = await ItemService.getItems(
        organizationId: AppState.currentOrganizationId.value ?? '',
      );
      _fert1Price = orgItems.where((it) => it.slotIndex == 1).firstOrNull?.unitPrice ?? 15500.0;
      _fert2Price = orgItems.where((it) => it.slotIndex == 2).firstOrNull?.unitPrice ?? 18000.0;
      _teaPkt1Price = orgItems.where((it) => it.slotIndex == 3).firstOrNull?.unitPrice ?? 650.0;
      _teaPkt2Price = orgItems.where((it) => it.slotIndex == 4).firstOrNull?.unitPrice ?? 0.0;

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
      } else if (_selectedReportType == 'Advances & Items') {
        entries = entries
            .where((doc) {
              if ((doc['advanceAmount'] ?? 0) > 0) return true;
              final parsed = ItemService.parseDailyEntryItems(doc);
              return parsed.hasAnyItems;
            })
            .toList();
      } else if (_selectedReportType == 'Item Wise Breakdown') {
        entries = entries.where((doc) {
          final parsed = ItemService.parseDailyEntryItems(doc);
          if (_selectedCustomItem == null) return parsed.hasAnyItems;
          final targetSlot = _selectedCustomItem!.slotIndex;
          final targetCode = _selectedCustomItem!.code;
          return parsed.itemsList.any(
            (it) => it['slot'] == targetSlot || it['code'] == targetCode,
          );
        }).toList();
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
        
        final parsed = ItemService.parseDailyEntryItems(
          data,
          f1Price: _fert1Price,
          f2Price: _fert2Price,
          t1Price: _teaPkt1Price,
          t2Price: _teaPkt2Price,
        );

        double rowTotal = adv + parsed.totalItemsAmt;

        tWeight += w;
        tAdvance += adv;
        tF1 += parsed.f1Qty;
        tF2 += parsed.f2Qty;
        tT1 += parsed.t1Qty;
        tT2 += parsed.t2Qty;
        tDed += rowTotal;
      }

      final uniqueDates = entries
          .map((e) => (e['timestamp'] ?? '').toString().substring(0, 10))
          .toSet();
      final uniqueCustomers = entries.map((e) => e['customerId']).toSet();
      final uDatesCount = uniqueDates.length;
      final uCustomersCount = uniqueCustomers.length;
      final avgWeight = uDatesCount > 0 ? (tWeight / uDatesCount) : 0.0;

      setState(() {
        _analyzedEntries = entries;
        _totalWeight = tWeight;
        _totalAdvance = tAdvance;
        _totalF1 = tF1;
        _totalF2 = tF2;
        _totalT1 = tT1;
        _totalT2 = tT2;
        _totalDed = tDed;
        _uniqueDatesCount = uDatesCount;
        _uniqueCustomersCount = uCustomersCount;
        _avgDailyWeight = avgWeight;
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

  Future<void> _exportCsv() async {
    if (_analyzedEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.noDataFound)),
      );
      return;
    }

    try {
      final StringBuffer sb = StringBuffer();
      // Add UTF-8 BOM so Microsoft Excel correctly renders Sinhala Unicode characters
      sb.write('\uFEFF');

      // CSV Header
      sb.writeln(
        'Date,Customer ID,Customer Name,Net Weight (Kg),Advance (Rs),Fertilizer 1 (Qty),Fertilizer 2 (Qty),Tea Packets (Qty),Total Deductions (Rs)',
      );

      for (var data in _analyzedEntries) {
        final date = (data['timestamp'] ?? '').toString().substring(0, 10);
        final cId = data['customerId'] ?? '';
        final cName = (_customerNamesMap[cId] ?? 'Unknown').replaceAll(',', ' ');
        final w = (data['netWeight'] ?? 0).toDouble();
        final adv = (data['advanceAmount'] ?? 0).toDouble();

        final parsed = ItemService.parseDailyEntryItems(
          data,
          f1Price: _fert1Price,
          f2Price: _fert2Price,
          t1Price: _teaPkt1Price,
          t2Price: _teaPkt2Price,
        );

        final totalDed = adv + parsed.totalItemsAmt;

        sb.writeln(
          '$date,$cId,"$cName",${w.toStringAsFixed(1)},${adv.toStringAsFixed(2)},${parsed.f1Qty.toStringAsFixed(1)},${parsed.f2Qty.toStringAsFixed(1)},${(parsed.t1Qty + parsed.t2Qty).toStringAsFixed(0)},${totalDed.toStringAsFixed(2)}',
        );
      }

      // Summary row
      sb.writeln(
        'TOTALS,,,"${_totalWeight.toStringAsFixed(1)}","${_totalAdvance.toStringAsFixed(2)}","${_totalF1.toStringAsFixed(1)}","${_totalF2.toStringAsFixed(1)}","${(_totalT1 + _totalT2).toStringAsFixed(0)}","${_totalDed.toStringAsFixed(2)}"',
      );

      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'SmartEntry_Report_$dateStr.csv';

      Directory? dir;
      if (!kIsWeb && Platform.isWindows) {
        dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final file = File('${dir.path}/$fileName');
      await file.writeAsString(sb.toString(), encoding: utf8);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            content: Text(
              AppStrings.isSinhala
                  ? 'CSV වාර්තාව සාර්ථකව සුරැකිණි: $fileName'
                  : 'Report exported to: $fileName',
            ),
            action: (!kIsWeb && Platform.isWindows)
                ? SnackBarAction(
                    label: AppStrings.isSinhala ? 'ෆෝල්ඩරය' : 'Open Folder',
                    textColor: Colors.white,
                    onPressed: () {
                      Process.run('explorer.exe', ['/select,', file.path]);
                    },
                  )
                : null,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_analyzedEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.noDataFound)),
      );
      return;
    }

    final currencyF = NumberFormat('#,##0.00');
    final weightF = NumberFormat('#,##0.0');

    final doc = pw.Document();

    final dateRangeStr =
        '${DateFormat('yyyy-MM-dd').format(_startDate)} to ${DateFormat('yyyy-MM-dd').format(_endDate)}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context ctx) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Smart Entry — Data & Operational Report',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Report Type: $_selectedReportType • Date Range: $dateRangeStr',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.Text(
                'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 8),

          // KPI summary
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfKpiBox('Total Leaf', '${weightF.format(_totalWeight)} Kg'),
              _buildPdfKpiBox('Total Advance', 'Rs. ${currencyF.format(_totalAdvance)}'),
              _buildPdfKpiBox('Total Items', 'Rs. ${currencyF.format(_totalDed - _totalAdvance)}'),
              _buildPdfKpiBox('Active Days', '$_uniqueDatesCount Days'),
              _buildPdfKpiBox('Daily Avg', '${weightF.format(_avgDailyWeight)} Kg'),
            ],
          ),
          pw.SizedBox(height: 12),

          // Table
          pw.TableHelper.fromTextArray(
            headers: [
              'Date',
              'Customer',
              'Leaf (Kg)',
              'Advance (Rs)',
              'F1 (Bags)',
              'F2 (Bags)',
              'Tea Pkts',
              'Total Ded (Rs)',
            ],
            data: _analyzedEntries.map((data) {
              final date = (data['timestamp'] ?? '').toString().substring(0, 10);
              final cId = data['customerId'] ?? '';
              final cName = _customerNamesMap[cId] ?? 'Unknown';
              final w = (data['netWeight'] ?? 0).toDouble();
              final adv = (data['advanceAmount'] ?? 0).toDouble();
              final parsed = ItemService.parseDailyEntryItems(
                data,
                f1Price: _fert1Price,
                f2Price: _fert2Price,
                t1Price: _teaPkt1Price,
                t2Price: _teaPkt2Price,
              );
              final totalDed = adv + parsed.totalItemsAmt;

              return [
                date,
                cName,
                w > 0 ? weightF.format(w) : '-',
                adv > 0 ? currencyF.format(adv) : '-',
                parsed.f1Qty > 0 ? parsed.f1Qty.toStringAsFixed(0) : '-',
                parsed.f2Qty > 0 ? parsed.f2Qty.toStringAsFixed(0) : '-',
                (parsed.t1Qty + parsed.t2Qty) > 0 ? (parsed.t1Qty + parsed.t2Qty).toInt().toString() : '-',
                totalDed > 0 ? currencyF.format(totalDed) : '-',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
            },
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
          ),
          pw.SizedBox(height: 16),
          // Signatures footer
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Prepared By: ___________________', style: const pw.TextStyle(fontSize: 8.5)),
              pw.Text('Verified By: ___________________', style: const pw.TextStyle(fontSize: 8.5)),
              pw.Text('Authorized Signature: ___________________', style: const pw.TextStyle(fontSize: 8.5)),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'SmartEntry_Report_${DateFormat('yyyyMMdd').format(_startDate)}.pdf',
    );
  }

  static pw.Widget _buildPdfKpiBox(String title, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
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
            tabs: [
              Tab(text: AppStrings.accountClosing),
              Tab(text: AppStrings.dataAnalysis),
              Tab(text: AppStrings.whatsapp),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildClosingTab(),

            _buildAnalysisTab(),

            const WhatsappManagementWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildClosingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.monthlyClosingTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.monthlyClosingSubtitle,
            style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
          ),
          const SizedBox(height: 24),

          const MonthlyClosingWidget(),
        ],
      ),
    );
  }

  Widget _buildAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.dataAnalysis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.dataAnalysisSubtitle,
            style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
          ),
          const SizedBox(height: 16),

          _buildQuickDatePresets(),
          const SizedBox(height: 20),

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
                        height: 380,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.6),
                              Colors.white.withValues(alpha: 0.2),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
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
                                Text(
                                  AppStrings.dateRange,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildDatePickerSection(),
                                const SizedBox(height: 16),
                                Text(
                                  AppStrings.reportType,
                                  style: const TextStyle(
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
                                    if (val != 'Item Wise Breakdown') {
                                      _selectedCustomItemId = null;
                                      _selectedCustomItem = null;
                                    }
                                    _hasAnalyzed = false;
                                  }),
                                ),
                                if (_selectedReportType == 'Customer Wise') ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    AppStrings.selectCustomer,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildCustomerDropdown(),
                                ],
                                if (_selectedReportType == 'Item Wise Breakdown') ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    AppStrings.isSinhala ? 'භාණ්ඩය තෝරන්න' : 'Select Item',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildItemDropdown(),
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
                      height: 380,
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.insights_rounded, size: 20, color: primaryAppColor),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '${DateFormat('yyyy-MM-dd').format(_startDate)} ${AppStrings.isSinhala ? 'සිට' : 'to'} ${DateFormat('yyyy-MM-dd').format(_endDate)} ${AppStrings.isSinhala ? 'දක්වා' : ''} • $_selectedReportType',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                              fontSize: 13.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _exportCsv,
                        icon: const Icon(Icons.table_chart_rounded, size: 15),
                        label: Text(AppStrings.isSinhala ? 'Excel (CSV)' : 'CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _exportPdf,
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                        label: Text(AppStrings.isSinhala ? 'PDF / Print' : 'PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryAppColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _hasAnalyzed = false),
                        icon: const Icon(Icons.tune_rounded, size: 15),
                        label: Text(AppStrings.change),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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

  Widget _buildQuickDatePresets() {
    final presets = [
      {
        'id': 'Today',
        'label': AppStrings.isSinhala ? 'අද' : 'Today',
        'icon': Icons.today_rounded,
      },
      {
        'id': 'This Week',
        'label': AppStrings.isSinhala ? 'මෙම සතිය' : 'This Week',
        'icon': Icons.date_range_rounded,
      },
      {
        'id': 'This Month',
        'label': AppStrings.isSinhala ? 'මෙම මාසය' : 'This Month',
        'icon': Icons.calendar_month_rounded,
      },
      {
        'id': 'Last Month',
        'label': AppStrings.isSinhala ? 'පසුගිය මාසය' : 'Last Month',
        'icon': Icons.history_rounded,
      },
      {
        'id': 'Custom',
        'label': AppStrings.isSinhala ? 'තෝරාගත් දින' : 'Custom',
        'icon': Icons.edit_calendar_rounded,
      },
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets.map((p) {
        final bool isSel = _activePreset == p['id'];
        return InkWell(
          onTap: () => _applyDatePreset(p['id'] as String),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
            decoration: BoxDecoration(
              color: isSel ? primaryAppColor : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSel ? primaryAppColor : Colors.grey.shade300,
                width: 1.2,
              ),
              boxShadow: isSel
                  ? [
                      BoxShadow(
                        color: primaryAppColor.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  p['icon'] as IconData,
                  size: 15,
                  color: isSel ? Colors.white : Colors.blueGrey.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  p['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                    color: isSel ? Colors.white : Colors.blueGrey.shade800,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDatePickerSection() {
    return Row(
      children: [
        Expanded(child: _dateTile(AppStrings.startDay, _startDate, true)),
        const SizedBox(width: 16),
        Expanded(child: _dateTile(AppStrings.endDay, _endDate, false)),
      ],
    );
  }

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
                color: Colors.white.withValues(alpha: 0.5),
                border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
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
            color: Colors.white.withValues(alpha: 0.5),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
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
            color: Colors.white.withValues(alpha: 0.5),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCustomerId,
              hint: Text(
                AppStrings.selectCustomer,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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

  Widget _buildItemDropdown() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCustomItemId,
              hint: Text(
                AppStrings.isSinhala ? 'සියලුම භාණ්ඩ (All Items)' : 'All Dynamic Items',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(AppStrings.isSinhala ? 'සියලුම භාණ්ඩ (All Items)' : 'All Dynamic Items'),
                ),
                ..._orgCustomItems.map(
                  (item) => DropdownMenuItem<String>(
                    value: item.id.isNotEmpty ? item.id : 'slot_${item.slotIndex}',
                    child: Text(
                      '${item.name} (${item.code}) • Rs. ${item.unitPrice.toStringAsFixed(0)}',
                    ),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedCustomItemId = val;
                  _selectedCustomItem = val == null
                      ? null
                      : _orgCustomItems
                          .where((it) => (it.id.isNotEmpty ? it.id : 'slot_${it.slotIndex}') == val)
                          .firstOrNull;
                  _hasAnalyzed = false;
                });
              },
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
            color: actionColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: actionColor.withValues(alpha: 0.5), width: 1.5),
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
                            AppStrings.search,
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
      'Item Wise Breakdown',
    ].contains(_selectedReportType);
    bool showTeaPkt = [
      'Daily All Data',
      'Customer Wise',
      'Advances & Items',
      'Item Wise Breakdown',
    ].contains(_selectedReportType);
    bool showTotalDed = [
      'Daily All Data',
      'Customer Wise',
      'Advances & Items',
      'Item Wise Breakdown',
    ].contains(_selectedReportType);

    final filteredEntries = _searchQuery.isEmpty
        ? _analyzedEntries
        : _analyzedEntries.where((data) {
            final date = (data['timestamp'] ?? '').toString();
            final cId = (data['customerId'] ?? '').toString();
            final cName = (_customerNamesMap[cId] ?? '').toLowerCase();
            return date.contains(_searchQuery) ||
                cName.contains(_searchQuery) ||
                cId.toLowerCase().contains(_searchQuery);
          }).toList();

    int totalRecords = filteredEntries.length;
    int totalPages = (totalRecords / _rowsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    int startIndex = _currentPage * _rowsPerPage;
    int endIndex = startIndex + _rowsPerPage;
    if (endIndex > totalRecords) endIndex = totalRecords;

    List<Map<String, dynamic>> currentEntries = totalRecords > 0
        ? filteredEntries.sublist(startIndex, endIndex)
        : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.analysisResults,
          style: const TextStyle(
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
                  AppStrings.isSinhala ? 'මුළු දළු' : 'Total Leaf',
                  '${weightF.format(_totalWeight)} Kg',
                  Icons.eco_rounded,
                  Colors.green,
                ),
              if (showAdvance) const SizedBox(width: 12),
              if (showAdvance)
                _buildSummaryCard(
                  AppStrings.totalAdvance,
                  'Rs. ${currencyF.format(_totalAdvance)}',
                  Icons.payments_rounded,
                  Colors.blue,
                ),
              if (showTotalDed) const SizedBox(width: 12),
              if (showTotalDed)
                _buildSummaryCard(
                  AppStrings.totalDeductions,
                  'Rs. ${currencyF.format(_totalDed)}',
                  Icons.remove_circle_outline_rounded,
                  Colors.redAccent,
                ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                AppStrings.isSinhala ? 'දළු එකතු කළ දින' : 'Supply Days',
                '$_uniqueDatesCount ${AppStrings.isSinhala ? 'දින' : 'Days'}',
                Icons.calendar_today_rounded,
                Colors.amber.shade800,
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                AppStrings.isSinhala ? 'දිනක සාමාන්‍යය' : 'Daily Average',
                '${weightF.format(_avgDailyWeight)} Kg',
                Icons.trending_up_rounded,
                Colors.indigo,
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                AppStrings.isSinhala ? 'සැපයුම්කරුවන්' : 'Suppliers',
                '$_uniqueCustomersCount ${AppStrings.isSinhala ? 'දෙනෙක්' : 'Suppliers'}',
                Icons.people_alt_rounded,
                Colors.teal,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Search Bar & Filter Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 270,
              height: 38,
              child: TextField(
                onChanged: (val) => setState(() {
                  _searchQuery = val.trim().toLowerCase();
                  _currentPage = 0;
                }),
                decoration: InputDecoration(
                  hintText: AppStrings.isSinhala
                      ? 'සොයන්න (නම හෝ දිනය)...'
                      : 'Search customer or date...',
                  hintStyle: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.blueGrey),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
            Text(
              '${AppStrings.isSinhala ? 'ප්‍රතිඵල ගණන' : 'Records'}: $totalRecords',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Data Table Container
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
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
                            DataColumn(label: Text(AppStrings.date)),
                            DataColumn(
                              label: Text(AppStrings.customers),
                            ),
                            if (showWeight)
                              DataColumn(
                                label: Text(AppStrings.isSinhala ? 'දළු' : 'Weight'),
                                numeric: true,
                              ),
                            if (showAdvance)
                              DataColumn(
                                label: Text(AppStrings.advance),
                                numeric: true,
                              ),
                            if (showFertilizer)
                              DataColumn(
                                label: Text(AppStrings.fertilizer1),
                                numeric: true,
                              ),
                            if (showFertilizer)
                              DataColumn(
                                label: Text(AppStrings.fertilizer2),
                                numeric: true,
                              ),
                            if (showTeaPkt)
                              DataColumn(
                                label: Text(AppStrings.teaPackets),
                                numeric: true,
                              ),
                            if (showTotalDed)
                              DataColumn(
                                label: Text(AppStrings.totalDeductions),
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
                            final parsed = ItemService.parseDailyEntryItems(
                              data,
                              f1Price: _fert1Price,
                              f2Price: _fert2Price,
                              t1Price: _teaPkt1Price,
                              t2Price: _teaPkt2Price,
                            );
                            double f1 = parsed.f1Qty;
                            double f2 = parsed.f2Qty;
                            double t1 = parsed.t1Qty;
                            double t2 = parsed.t2Qty;
                            double rowTotal = adv + parsed.totalItemsAmt;

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
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
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
