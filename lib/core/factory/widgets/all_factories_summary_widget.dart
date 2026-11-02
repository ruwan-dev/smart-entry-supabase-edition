import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../app_state.dart';
import '../../widgets/skeleton_box.dart';
import '../factory_ledger_screen.dart';
import '../factory_report_screen.dart';
import '../../localization/app_strings.dart';

class FactorySummaryItem {
  final String factoryId;
  final String factoryName;
  final String refNumber;
  final double normalLeafKg;
  final double superLeafKg;
  final double totalLeafKg;
  final double? normalRate;
  final double? superRate;
  final double grossLeafIncome;
  final double advanceAmount;
  final Map<String, double> itemQuantities;
  final Map<String, double> itemPrices;
  final Map<String, double> itemTotals;
  final double totalItemsCost;
  final double totalDeductions;
  final double previousArrears;
  final double netReceivable;
  final bool isFinalized;

  FactorySummaryItem({
    required this.factoryId,
    required this.factoryName,
    required this.refNumber,
    required this.normalLeafKg,
    required this.superLeafKg,
    required this.totalLeafKg,
    this.normalRate,
    this.superRate,
    required this.grossLeafIncome,
    required this.advanceAmount,
    required this.itemQuantities,
    required this.itemPrices,
    required this.itemTotals,
    required this.totalItemsCost,
    required this.totalDeductions,
    required this.previousArrears,
    required this.netReceivable,
    required this.isFinalized,
  });
}

class AllFactoriesSummaryWidget extends StatefulWidget {
  const AllFactoriesSummaryWidget({super.key});

  @override
  State<AllFactoriesSummaryWidget> createState() => _AllFactoriesSummaryWidgetState();
}

class _AllFactoriesSummaryWidgetState extends State<AllFactoriesSummaryWidget> {
  final int _currentYear = DateTime.now().year;
  late int _selectedMonth;
  late int _selectedYear;

  bool _isLoading = true;
  String? _errorMessage;

  List<FactorySummaryItem> _factoryItems = [];

  // Aggregated totals across all factories
  double _totalDeliveredKg = 0.0;
  double _totalNormalKg = 0.0;
  double _totalSuperKg = 0.0;
  double _totalGrossIncome = 0.0;
  double _totalAdvance = 0.0;
  double _totalItemsCost = 0.0;
  double _totalDeductions = 0.0;
  double _totalNetReceivable = 0.0;

  // Supplier reconciliation data
  double _totalSupplierCollectedKg = 0.0;

  final currencyF = NumberFormat('#,##0.00');
  final weightF = NumberFormat('#,##0.0');

  final List<String> _englishMonthNames = [
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

  List<String> get _sinhalaMonthNames => AppStrings.monthNames;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now().month;
    _selectedYear = _currentYear;
    AppState.refreshTrigger.addListener(_fetchSummaryData);
    AppState.currentOrganizationId.addListener(_fetchSummaryData);
    _fetchSummaryData();
  }

  @override
  void dispose() {
    AppState.refreshTrigger.removeListener(_fetchSummaryData);
    AppState.currentOrganizationId.removeListener(_fetchSummaryData);
    super.dispose();
  }

  Future<void> _fetchSummaryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orgId = AppState.currentOrganizationId.value ?? '';
      if (orgId.isEmpty) {
        if (mounted) {
          setState(() {
            _factoryItems = [];
            _isLoading = false;
          });
        }
        return;
      }
      String monthKey = "$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}";
      int lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
      String lastDayStr = lastDay.toString().padLeft(2, '0');

      // 1. Fetch active factories for this organization
      final factoriesRes = await Supabase.instance.client
          .from('factories')
          .select()
          .eq('organization_id', orgId)
          .order('name');

      final List<Map<String, dynamic>> factoriesList =
          List<Map<String, dynamic>>.from(factoriesRes);

      // 2. Fetch all factory entries for the selected month range
      List<dynamic> allFactoryEntries = [];
      int offset = 0;
      const int limit = 1000;
      while (true) {
        final chunk = await Supabase.instance.client
            .from('factory_entries')
            .select()
            .eq('organization_id', orgId)
            .gte('date', "$monthKey-01")
            .lte('date', "$monthKey-$lastDayStr")
            .range(offset, offset + limit - 1);
        allFactoryEntries.addAll(chunk);
        if (chunk.length < limit) break;
        offset += limit;
      }

      // Group entries by factoryId
      Map<String, List<Map<String, dynamic>>> entriesByFactory = {};
      for (var entry in allFactoryEntries) {
        String fId = (entry['factoryId'] ?? '').toString();
        if (fId.isEmpty) continue;
        entriesByFactory.putIfAbsent(fId, () => []).add(entry);
      }

      // 3. Fetch monthly rates for this month
      final ratesRes = await Supabase.instance.client
          .from('factory_monthly_rates')
          .select()
          .eq('organization_id', orgId)
          .eq('month', monthKey);
      Map<String, Map<String, dynamic>> ratesByFactory = {};
      for (var r in ratesRes) {
        ratesByFactory[r['factoryId'].toString()] = r;
      }

      // 4. Fetch finalized bills for this month
      final finalizedRes = await Supabase.instance.client
          .from('factory_finalized_bills')
          .select()
          .eq('organization_id', orgId)
          .eq('month', monthKey);
      Map<String, Map<String, dynamic>> finalizedByFactory = {};
      for (var f in finalizedRes) {
        finalizedByFactory[f['factoryId'].toString()] = f;
      }

      // 5. Fetch supplier entries for reconciliation
      List<dynamic> supplierEntries = [];
      offset = 0;
      while (true) {
        final chunk = await Supabase.instance.client
            .from('daily_entries')
            .select('netWeight, netWeight2')
            .eq('organization_id', orgId)
            .gte('date', "$monthKey-01")
            .lte('date', "$monthKey-$lastDayStr")
            .range(offset, offset + limit - 1);
        supplierEntries.addAll(chunk);
        if (chunk.length < limit) break;
        offset += limit;
      }

      double supplierLeafTotal = 0.0;
      for (var se in supplierEntries) {
        supplierLeafTotal += ((se['netWeight'] ?? 0) as num).toDouble();
        supplierLeafTotal += ((se['netWeight2'] ?? 0) as num).toDouble();
      }

      // 6. Build factory-wise summary items
      List<FactorySummaryItem> items = [];
      double sumDelivered = 0.0;
      double sumNormal = 0.0;
      double sumSuper = 0.0;
      double sumGross = 0.0;
      double sumAdv = 0.0;
      double sumItemsCost = 0.0;
      double sumDed = 0.0;
      double sumNet = 0.0;

      for (var factory in factoriesList) {
        String fId = factory['id'].toString();
        String fName = factory['name'] ?? 'Unknown Factory';
        String fRef = (factory['refNumber'] ?? '').toString();

        // Extract unit prices for this factory's items
        Map<String, double> itemPrices = {};
        List<dynamic> itemsList = [];
        if (factory['items'] != null && (factory['items'] as List).isNotEmpty) {
          itemsList = factory['items'];
        } else {
          if (factory['fertilizers'] != null) {
            itemsList.addAll(factory['fertilizers'] as List);
          }
          if (factory['tea_packets'] != null) {
            itemsList.addAll(factory['tea_packets'] as List);
          }
        }
        for (var it in itemsList) {
          itemPrices[it['name'].toString()] =
              double.tryParse(it['price'].toString()) ?? 0.0;
        }

        // Aggregate entries
        final fEntries = entriesByFactory[fId] ?? [];
        double nLeaf = 0.0;
        double sLeaf = 0.0;
        double adv = 0.0;
        Map<String, double> itemQuantities = {};

        for (var entry in fEntries) {
          nLeaf += ((entry['netWeight'] ?? 0) as num).toDouble();
          sLeaf += ((entry['netWeight2'] ?? 0) as num).toDouble();
          adv += ((entry['advanceAmount'] ?? 0) as num).toDouble();

          if (entry['dynamic_items'] != null) {
            Map<String, dynamic>.from(entry['dynamic_items']).forEach((k, v) {
              itemQuantities[k] =
                  (itemQuantities[k] ?? 0.0) + ((v as num).toDouble());
            });
          }
          if (entry['dynamic_fertilizers'] != null) {
            Map<String, dynamic>.from(entry['dynamic_fertilizers']).forEach((k, v) {
              itemQuantities[k] =
                  (itemQuantities[k] ?? 0.0) + ((v as num).toDouble());
            });
          }
          if (entry['dynamic_tea_packets'] != null) {
            Map<String, dynamic>.from(entry['dynamic_tea_packets']).forEach((k, v) {
              itemQuantities[k] =
                  (itemQuantities[k] ?? 0.0) + ((v as num).toDouble());
            });
          }
        }

        // Compute itemized costs
        Map<String, double> itemTotals = {};
        double fItemsCost = 0.0;
        itemQuantities.forEach((name, qty) {
          double price = itemPrices[name] ?? 0.0;
          double total = qty * price;
          itemTotals[name] = total;
          fItemsCost += total;
        });

        // Rates
        double? nRate = (ratesByFactory[fId]?['normalRate'] as num?)?.toDouble();
        double? sRate = (ratesByFactory[fId]?['superRate'] as num?)?.toDouble();

        // Check finalized bill
        final finalizedBill = finalizedByFactory[fId];
        bool isFinalized = finalizedBill != null;

        double fGross;
        double fTotalDed;
        double fPrevArrears;
        double fNet;

        if (isFinalized) {
          fGross = ((finalizedBill['grossIncome'] ?? 0) as num).toDouble();
          fTotalDed = ((finalizedBill['totalDeductions'] ?? 0) as num).toDouble();
          fPrevArrears = ((finalizedBill['previousArrears'] ?? 0) as num).toDouble();
          fNet = ((finalizedBill['netPayable'] ?? 0) as num).toDouble();
        } else {
          fGross = (nLeaf * (nRate ?? 0)) + (sLeaf * (sRate ?? 0));
          fTotalDed = fItemsCost + adv;
          fPrevArrears = 0.0;
          fNet = fGross - fTotalDed + fPrevArrears;
        }

        double totalLeaf = nLeaf + sLeaf;

        items.add(FactorySummaryItem(
          factoryId: fId,
          factoryName: fName,
          refNumber: fRef,
          normalLeafKg: nLeaf,
          superLeafKg: sLeaf,
          totalLeafKg: totalLeaf,
          normalRate: nRate,
          superRate: sRate,
          grossLeafIncome: fGross,
          advanceAmount: adv,
          itemQuantities: itemQuantities,
          itemPrices: itemPrices,
          itemTotals: itemTotals,
          totalItemsCost: fItemsCost,
          totalDeductions: fTotalDed,
          previousArrears: fPrevArrears,
          netReceivable: fNet,
          isFinalized: isFinalized,
        ));

        sumDelivered += totalLeaf;
        sumNormal += nLeaf;
        sumSuper += sLeaf;
        sumGross += fGross;
        sumAdv += adv;
        sumItemsCost += fItemsCost;
        sumDed += fTotalDed;
        sumNet += fNet;
      }

      if (mounted) {
        setState(() {
          _factoryItems = items;
          _totalDeliveredKg = sumDelivered;
          _totalNormalKg = sumNormal;
          _totalSuperKg = sumSuper;
          _totalGrossIncome = sumGross;
          _totalAdvance = sumAdv;
          _totalItemsCost = sumItemsCost;
          _totalDeductions = sumDed;
          _totalNetReceivable = sumNet;
          _totalSupplierCollectedKg = supplierLeafTotal;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching all factories summary: $e");
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _generateConsolidatedPDF() async {
    if (_factoryItems.isEmpty) return;

    try {
      final pdf = pw.Document();
      final engFont = pw.Font.helvetica();
      final boldFont = pw.Font.helveticaBold();

      String monthName = _englishMonthNames[_selectedMonth - 1];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ALL FACTORIES MONTHLY STATEMENT',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 16,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Statement Month: $_selectedYear $monthName',
                        style: pw.TextStyle(
                          font: engFont,
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                        style: pw.TextStyle(font: engFont, fontSize: 9, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        'Smart Entry Management System',
                        style: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.blueGrey800),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 10),

              // KPI Summary Boxes
              pw.Row(
                children: [
                  _pdfKpiCard('Total Delivered Leaf', '${weightF.format(_totalDeliveredKg)} Kg', boldFont, engFont),
                  pw.SizedBox(width: 8),
                  _pdfKpiCard('Gross Value', 'Rs. ${currencyF.format(_totalGrossIncome)}', boldFont, engFont),
                  pw.SizedBox(width: 8),
                  _pdfKpiCard('Total Fertilizer & Items', 'Rs. ${currencyF.format(_totalItemsCost)}', boldFont, engFont),
                  pw.SizedBox(width: 8),
                  _pdfKpiCard('Total Advances', 'Rs. ${currencyF.format(_totalAdvance)}', boldFont, engFont),
                  pw.SizedBox(width: 8),
                  _pdfKpiCard('Net Receivable', 'Rs. ${currencyF.format(_totalNetReceivable)}', boldFont, engFont, isHighlight: true),
                ],
              ),
              pw.SizedBox(height: 16),

              // Comparative Table
              pw.Text(
                'FACTORY-WISE SUMMARY BREAKDOWN',
                style: pw.TextStyle(font: boldFont, fontSize: 11, color: PdfColors.blueGrey800),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _pdfHeaderCell('Ref', boldFont),
                      _pdfHeaderCell('Factory Name', boldFont),
                      _pdfHeaderCell('Normal (Kg)', boldFont, align: pw.TextAlign.right),
                      _pdfHeaderCell('Super (Kg)', boldFont, align: pw.TextAlign.right),
                      _pdfHeaderCell('Total (Kg)', boldFont, align: pw.TextAlign.right),
                      _pdfHeaderCell('Gross (Rs.)', boldFont, align: pw.TextAlign.right),
                      _pdfHeaderCell('Fertilizers (Rs.)', boldFont, align: pw.TextAlign.right),
                      _pdfHeaderCell('Advance (Rs.)', boldFont, align: pw.TextAlign.right),
                      _pdfHeaderCell('Net Balance (Rs.)', boldFont, align: pw.TextAlign.right),
                      _pdfHeaderCell('Status', boldFont, align: pw.TextAlign.center),
                    ],
                  ),
                  // Table Data Rows
                  ..._factoryItems.map((item) {
                    return pw.TableRow(
                      children: [
                        _pdfDataCell(item.refNumber.isEmpty ? '-' : item.refNumber, engFont),
                        _pdfDataCell(item.factoryName, boldFont),
                        _pdfDataCell(weightF.format(item.normalLeafKg), engFont, align: pw.TextAlign.right),
                        _pdfDataCell(weightF.format(item.superLeafKg), engFont, align: pw.TextAlign.right),
                        _pdfDataCell(weightF.format(item.totalLeafKg), boldFont, align: pw.TextAlign.right),
                        _pdfDataCell(currencyF.format(item.grossLeafIncome), engFont, align: pw.TextAlign.right),
                        _pdfDataCell(currencyF.format(item.totalItemsCost), engFont, align: pw.TextAlign.right),
                        _pdfDataCell(currencyF.format(item.advanceAmount), engFont, align: pw.TextAlign.right),
                        _pdfDataCell(
                          currencyF.format(item.netReceivable),
                          boldFont,
                          align: pw.TextAlign.right,
                          color: item.netReceivable >= 0 ? PdfColors.green800 : PdfColors.red800,
                        ),
                        _pdfDataCell(item.isFinalized ? 'Finalized' : 'In Progress', engFont, align: pw.TextAlign.center),
                      ],
                    );
                  }),
                  // Table Total Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _pdfDataCell('', boldFont),
                      _pdfDataCell('TOTALS', boldFont),
                      _pdfDataCell(weightF.format(_totalNormalKg), boldFont, align: pw.TextAlign.right),
                      _pdfDataCell(weightF.format(_totalSuperKg), boldFont, align: pw.TextAlign.right),
                      _pdfDataCell(weightF.format(_totalDeliveredKg), boldFont, align: pw.TextAlign.right),
                      _pdfDataCell(currencyF.format(_totalGrossIncome), boldFont, align: pw.TextAlign.right),
                      _pdfDataCell(currencyF.format(_totalItemsCost), boldFont, align: pw.TextAlign.right),
                      _pdfDataCell(currencyF.format(_totalAdvance), boldFont, align: pw.TextAlign.right),
                      _pdfDataCell(currencyF.format(_totalNetReceivable), boldFont, align: pw.TextAlign.right),
                      _pdfDataCell('', boldFont),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Itemized Fertilizer Detail Table
              pw.Text(
                'FERTILIZER & SUPPLY DEDUCTIONS ITEMIZATION',
                style: pw.TextStyle(font: boldFont, fontSize: 11, color: PdfColors.blueGrey800),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _pdfHeaderCell('Factory', boldFont),
                      _pdfHeaderCell('Item Name', boldFont),
                      _pdfHeaderCell('Quantity', boldFont, align: pw.TextAlign.right),
                      _pdfHeaderCell('Unit Price (Rs.)', boldFont, align: pw.TextAlign.right),
                      _pdfHeaderCell('Total Amount (Rs.)', boldFont, align: pw.TextAlign.right),
                    ],
                  ),
                  ..._factoryItems.expand((f) {
                    if (f.itemQuantities.isEmpty) {
                      return [
                        pw.TableRow(children: [
                          _pdfDataCell(f.factoryName, engFont),
                          _pdfDataCell('No fertilizers or materials taken', engFont),
                          _pdfDataCell('-', engFont, align: pw.TextAlign.right),
                          _pdfDataCell('-', engFont, align: pw.TextAlign.right),
                          _pdfDataCell('0.00', engFont, align: pw.TextAlign.right),
                        ]),
                      ];
                    }
                    return f.itemQuantities.entries.map((entry) {
                      double unitPrice = f.itemPrices[entry.key] ?? 0.0;
                      double total = f.itemTotals[entry.key] ?? 0.0;
                      return pw.TableRow(children: [
                        _pdfDataCell(f.factoryName, engFont),
                        _pdfDataCell(entry.key, engFont),
                        _pdfDataCell(entry.value.toStringAsFixed(1), engFont, align: pw.TextAlign.right),
                        _pdfDataCell(currencyF.format(unitPrice), engFont, align: pw.TextAlign.right),
                        _pdfDataCell(currencyF.format(total), engFont, align: pw.TextAlign.right),
                      ]);
                    });
                  }),
                ],
              ),
            ];
          },
        ),
      );

      String customFileName = "All_Factories_Summary_${_selectedYear}_$monthName.pdf";
      await Printing.sharePdf(bytes: await pdf.save(), filename: customFileName);
    } catch (e) {
      debugPrint("Error generating PDF: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF generation error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  pw.Widget _pdfKpiCard(String title, String value, pw.Font boldFont, pw.Font regFont, {bool isHighlight = false}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: isHighlight ? PdfColors.green50 : PdfColors.grey50,
          border: pw.Border.all(
            color: isHighlight ? PdfColors.green300 : PdfColors.grey300,
            width: 0.5,
          ),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(font: regFont, fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 10,
                color: isHighlight ? PdfColors.green900 : PdfColors.blueGrey900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfHeaderCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.blueGrey900),
      ),
    );
  }

  pw.Widget _pdfDataCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor color = PdfColors.black,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 8, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSkeletonSummary();
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('${AppStrings.errorPrefix}$_errorMessage', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchSummaryData,
                icon: const Icon(Icons.refresh),
                label: Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      );
    }

    bool hasAnyData = _factoryItems.any((item) =>
        item.totalLeafKg > 0 ||
        item.totalItemsCost > 0 ||
        item.advanceAmount > 0 ||
        item.isFinalized);

    if (!hasAnyData) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Control Bar: Month Picker & Actions
            _buildControlBar(),
            const SizedBox(height: 24),

            // Validation Message when no data exists (DO NOT show KPI or breakdown components)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_off_outlined, size: 56, color: Colors.amber.shade600),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.noDataFound,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.isSinhala
                        ? '$_selectedYear ${_sinhalaMonthNames[_selectedMonth - 1]} මාසය සඳහා කිසිදු කර්මාන්තශාලා දත්තයක් ඇතුළත් කර නොමැත. කරුණාකර වෙනත් මාසයක් තෝරන්න.'
                        : 'No factory data has been entered for ${_sinhalaMonthNames[_selectedMonth - 1]} $_selectedYear. Please select another month.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    double leafVariance = _totalDeliveredKg - _totalSupplierCollectedKg;
    double variancePercent = _totalSupplierCollectedKg > 0
        ? (leafVariance / _totalSupplierCollectedKg) * 100
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Control Bar: Month Picker & Actions
          _buildControlBar(),
          const SizedBox(height: 20),

          // KPI Overview Cards
          _buildKpiGrid(leafVariance, variancePercent),
          const SizedBox(height: 24),

          // Detailed Factory-wise Breakdown Cards
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.detailedFactorySummary,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              Text(
                AppStrings.activeFactoriesCount(_factoryItems.length),
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _factoryItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) => _buildFactoryDetailCard(_factoryItems[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonSummary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkeletonControlBar(),
          const SizedBox(height: 20),
          _buildSkeletonKpiGrid(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              SkeletonBox(width: 300, height: 20, borderRadius: 4),
              SkeletonBox(width: 120, height: 18, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 12),
          _buildSkeletonFactoryCard(),
          const SizedBox(height: 16),
          _buildSkeletonFactoryCard(),
        ],
      ),
    );
  }

  Widget _buildSkeletonControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: const [
              SkeletonBox(width: 24, height: 24, borderRadius: 6),
              SizedBox(width: 10),
              SkeletonBox(width: 75, height: 16, borderRadius: 4),
              SizedBox(width: 10),
              SkeletonBox(width: 90, height: 38, borderRadius: 8),
              Spacer(),
              SkeletonBox(width: 36, height: 36, borderRadius: 8),
              SizedBox(width: 8),
              SkeletonBox(width: 170, height: 38, borderRadius: 8),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: List.generate(
                12,
                (_) => const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: SkeletonBox(width: double.infinity, height: 32, borderRadius: 6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonKpiGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 900 ? 5 : (constraints.maxWidth > 600 ? 3 : 2);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          children: List.generate(
            5,
            (_) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Row(
                    children: [
                      SkeletonBox(width: 16, height: 16, borderRadius: 4),
                      SizedBox(width: 6),
                      SkeletonBox(width: 100, height: 12, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 8),
                  SkeletonBox(width: 120, height: 18, borderRadius: 4),
                  SizedBox(height: 6),
                  SkeletonBox(width: 90, height: 10, borderRadius: 3),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonFactoryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: const [
                SkeletonBox(width: 70, height: 22, borderRadius: 6),
                SizedBox(width: 10),
                SkeletonBox(width: 160, height: 18, borderRadius: 4),
                Spacer(),
                SkeletonBox(width: 100, height: 22, borderRadius: 12),
              ],
            ),
          ),

          // 3 Columns: Leaf, Fertilizer, Settlement
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leaf box
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0).withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(width: 130, height: 14, borderRadius: 4),
                        Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonBox(width: 75, height: 12, borderRadius: 3),
                            SkeletonBox(width: 60, height: 12, borderRadius: 3),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonBox(width: 70, height: 12, borderRadius: 3),
                            SkeletonBox(width: 55, height: 12, borderRadius: 3),
                          ],
                        ),
                        Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonBox(width: 85, height: 13, borderRadius: 3),
                            SkeletonBox(width: 70, height: 13, borderRadius: 3),
                          ],
                        ),
                        SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonBox(width: 80, height: 13, borderRadius: 3),
                            SkeletonBox(width: 75, height: 13, borderRadius: 3),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Fertilizer box
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(width: 140, height: 14, borderRadius: 4),
                        Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonBox(width: 120, height: 12, borderRadius: 3),
                            SkeletonBox(width: 60, height: 12, borderRadius: 3),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonBox(width: 100, height: 12, borderRadius: 3),
                            SkeletonBox(width: 55, height: 12, borderRadius: 3),
                          ],
                        ),
                        Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonBox(width: 100, height: 13, borderRadius: 3),
                            SkeletonBox(width: 70, height: 13, borderRadius: 3),
                          ],
                        ),
                        SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonBox(width: 90, height: 12, borderRadius: 3),
                            SkeletonBox(width: 65, height: 12, borderRadius: 3),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Settlement box
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(width: 130, height: 14, borderRadius: 4),
                        Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonBox(width: 85, height: 12, borderRadius: 3),
                            SkeletonBox(width: 70, height: 12, borderRadius: 3),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonBox(width: 90, height: 12, borderRadius: 3),
                            SkeletonBox(width: 65, height: 12, borderRadius: 3),
                          ],
                        ),
                        Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonBox(width: 95, height: 14, borderRadius: 3),
                            SkeletonBox(width: 80, height: 14, borderRadius: 3),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Footer buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                SkeletonBox(width: 110, height: 32, borderRadius: 6),
                SizedBox(width: 8),
                SkeletonBox(width: 140, height: 32, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Year Selector & Action Buttons
          Row(
            children: [
              const Icon(Icons.calendar_month, color: Color(0xFF06B6D4), size: 20),
              const SizedBox(width: 8),
              Text(
                AppStrings.applicableYear,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
              ),
              const SizedBox(width: 10),

              // Year Dropdown
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedYear,
                    items: [
                      _currentYear - 3,
                      _currentYear - 2,
                      _currentYear - 1,
                      _currentYear,
                      _currentYear + 1,
                    ].map((y) {
                      return DropdownMenuItem<int>(
                        value: y,
                        child: Text(
                          y.toString(),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      );
                    }).toList(),
                    onChanged: (newYear) {
                      if (newYear != null && newYear != _selectedYear) {
                        setState(() => _selectedYear = newYear);
                        _fetchSummaryData();
                      }
                    },
                  ),
                ),
              ),

              const Spacer(),

              // Refresh Button
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
                tooltip: AppStrings.refresh,
                onPressed: _fetchSummaryData,
              ),
              const SizedBox(width: 8),

              // PDF Print Button
              ElevatedButton.icon(
                onPressed: _generateConsolidatedPDF,
                icon: const Icon(Icons.print, size: 18),
                label: Text(AppStrings.printSummaryReport),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Bottom Row: Monthly Tabs
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.all(4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                bool canExpand = constraints.maxWidth >= 950;
                if (canExpand) {
                  return Row(
                    children: List.generate(12, (index) {
                      int monthNum = index + 1;
                      bool isSelected = _selectedMonth == monthNum;
                      return Expanded(
                        child: _buildMonthTabItem(monthNum, _sinhalaMonthNames[index], isSelected),
                      );
                    }),
                  );
                } else {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(12, (index) {
                        int monthNum = index + 1;
                        bool isSelected = _selectedMonth == monthNum;
                        return SizedBox(
                          width: 85,
                          child: _buildMonthTabItem(monthNum, _sinhalaMonthNames[index], isSelected),
                        );
                      }),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthTabItem(int monthNum, String monthName, bool isSelected) {
    return InkWell(
      onTap: () {
        if (_selectedMonth != monthNum) {
          setState(() => _selectedMonth = monthNum);
          _fetchSummaryData();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF06B6D4) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          monthName,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }

  Widget _buildKpiGrid(double leafVariance, double variancePercent) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 900 ? 5 : (constraints.maxWidth > 600 ? 3 : 2);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          children: [
            _buildKpiCard(
              title: AppStrings.totalLeafSupply,
              value: '${weightF.format(_totalDeliveredKg)} Kg',
              subtitle: '${AppStrings.normalLeaf}: ${weightF.format(_totalNormalKg)} | ${AppStrings.superLeaf}: ${weightF.format(_totalSuperKg)}',
              icon: Icons.eco,
              accentColor: const Color(0xFF10B981),
            ),
            _buildKpiCard(
              title: AppStrings.grossIncome,
              value: 'Rs. ${currencyF.format(_totalGrossIncome)}',
              subtitle: AppStrings.factoryLeafValue,
              icon: Icons.monetization_on,
              accentColor: const Color(0xFF0EA5E9),
            ),
            _buildKpiCard(
              title: AppStrings.fertilizerAndMaterials,
              value: 'Rs. ${currencyF.format(_totalItemsCost)}',
              subtitle: AppStrings.factoryDeductions,
              icon: Icons.agriculture,
              accentColor: const Color(0xFFF59E0B),
            ),
            _buildKpiCard(
              title: AppStrings.totalAdvance,
              value: 'Rs. ${currencyF.format(_totalAdvance)}',
              subtitle: AppStrings.totalAdvanceTaken,
              icon: Icons.payments,
              accentColor: const Color(0xFF8B5CF6),
            ),
            _buildKpiCard(
              title: AppStrings.netReceivable,
              value: 'Rs. ${currencyF.format(_totalNetReceivable)}',
              subtitle: '${AppStrings.totalDeductions}: Rs. ${currencyF.format(_totalDeductions)}',
              icon: Icons.account_balance_wallet,
              accentColor: const Color(0xFF059669),
              isHighlight: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlight ? accentColor.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlight ? accentColor.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
          width: isHighlight ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isHighlight ? accentColor : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isHighlight ? accentColor : const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFactoryDetailCard(FactorySummaryItem item) {
    bool hasMissingRate = !item.isFinalized &&
        (item.normalRate == null || item.normalRate == 0) &&
        (item.superRate == null || item.superRate == 0) &&
        (item.normalLeafKg > 0 || item.superLeafKg > 0);

    bool hasNoData = !item.isFinalized &&
        item.totalLeafKg == 0 &&
        item.totalItemsCost == 0 &&
        item.advanceAmount == 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isFinalized
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : (hasMissingRate
                  ? Colors.red.shade300
                  : const Color(0xFFE2E8F0)),
          width: item.isFinalized || hasMissingRate ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Factory Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: item.isFinalized
                  ? const Color(0xFF10B981).withValues(alpha: 0.06)
                  : (hasMissingRate
                      ? Colors.red.shade50.withValues(alpha: 0.5)
                      : const Color(0xFFF8FAFC)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.refNumber.isEmpty ? 'REF: -' : 'REF: ${item.refNumber}',
                    style: const TextStyle(
                      color: Color(0xFF0891B2),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.factoryName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.isFinalized
                        ? const Color(0xFFDCFCE7)
                        : (hasMissingRate
                            ? const Color(0xFFFEE2E2)
                            : (hasNoData
                                ? Colors.grey.shade100
                                : const Color(0xFFFEF3C7))),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.isFinalized
                            ? Icons.check_circle
                            : (hasMissingRate
                                ? Icons.error_outline
                                : (hasNoData ? Icons.info_outline : Icons.hourglass_top)),
                        size: 13,
                        color: item.isFinalized
                            ? const Color(0xFF16A34A)
                            : (hasMissingRate
                                ? Colors.red.shade700
                                : (hasNoData ? Colors.grey.shade600 : const Color(0xFFD97706))),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.isFinalized
                            ? AppStrings.finalized
                            : (hasMissingRate
                                ? AppStrings.rateNotSet
                                : (hasNoData ? AppStrings.noDataFound : AppStrings.calculated)),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: item.isFinalized
                              ? const Color(0xFF16A34A)
                              : (hasMissingRate
                                  ? Colors.red.shade700
                                  : (hasNoData ? Colors.grey.shade600 : const Color(0xFFD97706))),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (hasMissingRate)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.ratesNotSetPrompt,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppStrings.isSinhala
                                ? 'දළු සැපයුම: ${weightF.format(item.totalLeafKg)} Kg. ගණනය කිරීම් සහ වාර්තා බැලීමට කරුණාකර පළමුව අනුපාත ඇතුළත් කරන්න.'
                                : 'Leaf supply: ${weightF.format(item.totalLeafKg)} Kg. Please enter rates first to view calculations and reports.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FactoryLedgerScreen(
                              factoryId: item.factoryId,
                              factoryName: item.factoryName,
                              refNumber: item.refNumber,
                            ),
                          ),
                        ).then((_) => _fetchSummaryData());
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: Text(AppStrings.enterRates),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (hasNoData)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blueGrey.shade400, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppStrings.noFactoryDataForMonth,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Factory Details Grid: Leaf, Fertilizers, and Financials
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // 1. Tea Leaf Deliveries Box
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.eco, size: 15, color: Color(0xFF16A34A)),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.leafSupplyDetails,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        _rowItem(
                          '${AppStrings.normalLeaf}:',
                          '${weightF.format(item.normalLeafKg)} Kg',
                          trailing: item.normalRate != null && item.normalRate! > 0
                              ? '@ Rs. ${item.normalRate!.toStringAsFixed(2)}'
                              : AppStrings.rateNotSet,
                        ),
                        _rowItem(
                          '${AppStrings.superLeaf}:',
                          '${weightF.format(item.superLeafKg)} Kg',
                          trailing: item.superRate != null && item.superRate! > 0
                              ? '@ Rs. ${item.superRate!.toStringAsFixed(2)}'
                              : AppStrings.rateNotSet,
                        ),
                        const Divider(height: 12),
                        _rowItem(
                          '${AppStrings.leafWeightTotal}:',
                          '${weightF.format(item.totalLeafKg)} Kg',
                          isBold: true,
                        ),
                        _rowItem(
                          AppStrings.isSinhala ? 'දළු ආදායම:' : 'Leaf Income:',
                          'Rs. ${currencyF.format(item.grossLeafIncome)}',
                          isBold: true,
                          color: const Color(0xFF15803D),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Fertilizer & Items Box
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.agriculture, size: 15, color: Color(0xFFD97706)),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.fertilizerAndMaterials,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        if (item.itemQuantities.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              AppStrings.noMaterialsTaken,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF78716C)),
                            ),
                          )
                        else
                          ...item.itemQuantities.entries.map((entry) {
                            double unitPrice = item.itemPrices[entry.key] ?? 0.0;
                            double totalCost = item.itemTotals[entry.key] ?? 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      '• ${entry.key}: ${entry.value.toStringAsFixed(1)} pcs (@ Rs. ${unitPrice.toStringAsFixed(2)})',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${currencyF.format(totalCost)}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          }),
                        const Divider(height: 12),
                        _rowItem(
                          AppStrings.totalFertilizer,
                          'Rs. ${currencyF.format(item.totalItemsCost)}',
                          isBold: true,
                          color: const Color(0xFFB45309),
                        ),
                        _rowItem(
                          '${AppStrings.advance}:',
                          'Rs. ${currencyF.format(item.advanceAmount)}',
                          color: const Color(0xFF6B7280),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 3. Financial Settlement Box
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance, size: 15, color: Color(0xFF0284C7)),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.accountBalance,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        _rowItem(
                          '${AppStrings.grossIncome}:',
                          'Rs. ${currencyF.format(item.grossLeafIncome)}',
                        ),
                        _rowItem(
                          '${AppStrings.deductions}:',
                          '- Rs. ${currencyF.format(item.totalDeductions)}',
                          color: Colors.red.shade700,
                        ),
                        if (item.previousArrears != 0)
                          _rowItem(
                            '${AppStrings.previousArrears}:',
                            '+ Rs. ${currencyF.format(item.previousArrears)}',
                            color: Colors.blueGrey,
                          ),
                        const Divider(height: 12),
                        _rowItem(
                          '${AppStrings.netReceivable}:',
                          'Rs. ${currencyF.format(item.netReceivable)}',
                          isBold: true,
                          color: item.netReceivable >= 0
                              ? const Color(0xFF16A34A)
                              : Colors.red.shade700,
                        ),
                        const SizedBox(height: 8),

                        // Action button to open detailed individual screen
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 14),
                            label: Text(AppStrings.viewSingleReport, style: const TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF06B6D4),
                              side: const BorderSide(color: Color(0xFF06B6D4)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FactoryReportScreen(
                                    factoryId: item.factoryId,
                                    factoryName: item.factoryName,
                                  ),
                                ),
                              ).then((_) => _fetchSummaryData());
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _rowItem(String label, String value, {String? trailing, bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? const Color(0xFF475569),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
