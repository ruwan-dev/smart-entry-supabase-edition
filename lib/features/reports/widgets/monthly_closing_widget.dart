import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

class MonthlyClosingWidget extends StatefulWidget {
  const MonthlyClosingWidget({super.key});

  @override
  State<MonthlyClosingWidget> createState() => _MonthlyClosingWidgetState();
}

class _MonthlyClosingWidgetState extends State<MonthlyClosingWidget> {
  final int _currentYear = DateTime.now().year;
  late int _selectedMonth;

  bool _isCalculating = false;
  bool _isAlreadyFinalized = false;
  bool _ratesMissing = false;
  List<Map<String, dynamic>> _billingList = [];
  Map<String, dynamic>? _monthlySummaryData;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now().month;
    _checkStatusAndCalculate();
  }

  // ===========================================================================
  // 🚀 FAST LOADING LOGIC (සමාන්තරව දත්ත ලබාගැනීම) 
  // ===========================================================================
  Future<void> _checkStatusAndCalculate() async {
    setState(() {
      _isCalculating = true;
      _billingList = [];
      _isAlreadyFinalized = false;
      _ratesMissing = false;
      _monthlySummaryData = null;
    });

    try {
      String monthName = DateFormat('MMMM').format(DateTime(_currentYear, _selectedMonth));
      String displayMonth = "$_currentYear $monthName";
      String ratesDocId = "$_currentYear-$monthName";

      int prevMonth = _selectedMonth - 1;
      int prevYear = _currentYear;
      if (prevMonth == 0) {
        prevMonth = 12;
        prevYear = _currentYear - 1;
      }
      String prevMonthName = DateFormat('MMMM').format(DateTime(prevYear, prevMonth));
      String prevMonthKey = "$prevYear-$prevMonthName"; 

      var ratesDoc = await Supabase.instance.client.from('monthly_rates').select().eq('id', ratesDocId).maybeSingle();
      if (ratesDoc == null) {
        setState(() { _ratesMissing = true; _isCalculating = false; });
        return;
      }

      var summaryDoc = await Supabase.instance.client.from('monthly_summaries').select().eq('id', ratesDocId).maybeSingle();
      if (summaryDoc != null) {
        _isAlreadyFinalized = true;
        _monthlySummaryData = summaryDoc;
      }

      var priceDoc = await Supabase.instance.client.from('global_settings').select().eq('id', 'prices').maybeSingle();
      var pData = priceDoc ?? {};
      
      double teaRate = (ratesDoc['teaRate'] ?? 0).toDouble();
      double transRate = (ratesDoc['transportRate'] ?? 0).toDouble();

      var customers = await Supabase.instance.client.from('customers').select();
      
      String searchKey = "$_currentYear-${_selectedMonth.toString().padLeft(2, '0')}";
      var allEntriesSnapshot = await Supabase.instance.client.from('daily_entries')
          .select()
          .gte('date', "$searchKey-01")
          .lte('date', "$searchKey-31");

      Map<String, List<Map<String, dynamic>>> groupedEntries = {};
      for (var doc in allEntriesSnapshot) {
        String cId = doc['customerId'];
        if (!groupedEntries.containsKey(cId)) groupedEntries[cId] = [];
        groupedEntries[cId]!.add(doc);
      }

      var prevBillFutures = customers.map((customer) => 
        Supabase.instance.client.from('finalized_bills').select().eq('id', "${customer['id']}_$prevMonthKey").maybeSingle()
      ).toList();
      var prevBillDocs = await Future.wait(prevBillFutures);
      
      Map<String, Map<String, dynamic>?> prevBillsMap = {};
      for (int i = 0; i < customers.length; i++) {
        prevBillsMap[customers[i]['id']] = prevBillDocs[i];
      }

      List<Map<String, dynamic>> results = [];

      for (var customer in customers) {
        var monthlyEntries = groupedEntries[customer['id']] ?? [];
        if (monthlyEntries.isEmpty) continue;

        monthlyEntries.sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));

        double totalW = 0, totalAdv = 0, f1Q = 0, f2Q = 0, t1Q = 0, t2Q = 0;
        List<Map<String, dynamic>> rows = [];
        
        for (var d in monthlyEntries) {
          double w = (d['netWeight'] ?? 0).toDouble();
          double adv = (d['advanceAmount'] ?? 0).toDouble();
          double f1q = (d['fertilizer1Qty'] ?? 0).toDouble();
          double f2q = (d['fertilizer2Qty'] ?? 0).toDouble();
          double t1q = (d['teaPacket1Qty'] ?? 0).toDouble();
          double t2q = (d['teaPacket2Qty'] ?? 0).toDouble();

          totalW += w; totalAdv += adv;
          f1Q += f1q; f2Q += f2q; t1Q += t1q; t2Q += t2q;

          List<Map<String, dynamic>> items = [];
          if (adv > 0) items.add({'desc': 'Advance', 'qty': 0, 'uPrice': 0, 'amt': adv});
          if (f1q > 0) items.add({'desc': 'Fert 01', 'qty': f1q, 'uPrice': (pData['fertilizer1Price'] ?? 0).toDouble(), 'amt': f1q * (pData['fertilizer1Price'] ?? 0)});
          if (f2q > 0) items.add({'desc': 'Fert 02', 'qty': f2q, 'uPrice': (pData['fertilizer2Price'] ?? 0).toDouble(), 'amt': f2q * (pData['fertilizer2Price'] ?? 0)});
          if (t1q > 0) items.add({'desc': 'Tea Pkt 01', 'qty': t1q, 'uPrice': (pData['teaPacket1Price'] ?? 0).toDouble(), 'amt': t1q * (pData['teaPacket1Price'] ?? 0)});
          if (t2q > 0) items.add({'desc': 'Tea Pkt 02', 'qty': t2q, 'uPrice': (pData['teaPacket2Price'] ?? 0).toDouble(), 'amt': t2q * (pData['teaPacket2Price'] ?? 0)});

          rows.add({'date': d['date'], 'weight': w, 'items': items});
        }

        double lastMonthArrears = 0.0;
        var prevBillDoc = prevBillsMap[customer['id']];
        if (prevBillDoc != null) {
          // Supabase returns JSONB as Map<String, dynamic> — cast safely
          var billData = prevBillDoc['billData'];
          if (billData is Map) {
            double prevNetPayable = (billData['netPayable'] ?? 0.0) is num
                ? (billData['netPayable'] ?? 0.0).toDouble()
                : double.tryParse(billData['netPayable'].toString()) ?? 0.0;
            if (prevNetPayable < 0) {
              lastMonthArrears = prevNetPayable.abs();
            }
          }
        }

        double gross = totalW * teaRate;
        double trans = totalW * transRate;
        double other = totalAdv + (f1Q * (pData['fertilizer1Price'] ?? 0)) + (f2Q * (pData['fertilizer2Price'] ?? 0)) + (t1Q * (pData['teaPacket1Price'] ?? 0)) + (t2Q * (pData['teaPacket2Price'] ?? 0));

        results.add({
          'customerId': customer['id'], 'name': customer['name'], 'ref': customer['refNumber'],
          'bill': {
            'displayMonth': displayMonth, 'teaRate': teaRate, 'grossIncome': gross,
            'transportCost': trans, 'otherCosts': other, 
            'arrears': lastMonthArrears, 
            'totalDeductions': trans + other + lastMonthArrears, 
            'netPayable': gross - (trans + other + lastMonthArrears), 
            'tableRows': rows,
            'advTotal': totalAdv, 'f1Qty': f1Q, 'f1Total': f1Q * (pData['fertilizer1Price'] ?? 0),
            'f2Qty': f2Q, 'f2Total': f2Q * (pData['fertilizer2Price'] ?? 0),
            't1Qty': t1Q, 't1Total': t1Q * (pData['teaPacket1Price'] ?? 0),
            't2Qty': t2Q, 't2Total': t2Q * (pData['teaPacket2Price'] ?? 0),
          },
          'isFinalized': _isAlreadyFinalized,
        });
      }

      results.sort((a, b) => (int.tryParse(a['ref'].toString()) ?? 0).compareTo(int.tryParse(b['ref'].toString()) ?? 0));
      setState(() { _billingList = results; _isCalculating = false; });
    } catch (e) { 
        print("Error: $e");
        setState(() => _isCalculating = false); 
    }
  }

  Future<void> _finalizeAndGeneratePDF() async {
    if (_billingList.isEmpty) return;
    setState(() => _isCalculating = true);
    final pdf = pw.Document();
    
    final fmFontData = await rootBundle.load("assets/fonts/FM-Abhaya.ttf");
    final fmFont = pw.Font.ttf(fmFontData);
    final engFont = pw.Font.helvetica();

    try {
      String monthName = DateFormat('MMMM').format(DateTime(_currentYear, _selectedMonth));
      String ratesDocId = "$_currentYear-$monthName";

      double totalWeight = 0, totalGross = 0, totalAdvance = 0;
      double totalF1Qty = 0, totalF1Amt = 0, totalF2Qty = 0, totalF2Amt = 0;
      double totalT1Qty = 0, totalT1Amt = 0, totalT2Qty = 0, totalT2Amt = 0;
      double totalTransport = 0, totalPositiveNet = 0, totalNegativeNet = 0, totalNet = 0;

      for (var item in _billingList) {
        var b = item['bill'];
        
        if (item['isFinalized'] == false) {
          String monthKey = b['displayMonth'].toString().replaceAll(' ', '-');
          await Supabase.instance.client.from('finalized_bills').upsert({
            'id': "${item['customerId']}_$monthKey",
            'customerId': item['customerId'], 'customerName': item['name'], 'refNumber': item['ref'],
            'billData': b, 'finalizedAt': DateTime.now().toIso8601String(),
          });
        }
        
        // Derive weight from grossIncome/teaRate (avoids re-summing tableRows, prevents type errors)
        double bTeaRate = (b['teaRate'] ?? 0).toDouble();
        double bGross = (b['grossIncome'] ?? 0).toDouble();
        double tw = bTeaRate > 0 ? bGross / bTeaRate : 0;
        totalWeight += tw;
        totalGross += bGross;
        totalAdvance += (b['advTotal'] ?? 0).toDouble();
        totalF1Qty += (b['f1Qty'] ?? 0).toDouble(); totalF1Amt += (b['f1Total'] ?? 0).toDouble();
        totalF2Qty += (b['f2Qty'] ?? 0).toDouble(); totalF2Amt += (b['f2Total'] ?? 0).toDouble();
        totalT1Qty += (b['t1Qty'] ?? 0).toDouble(); totalT1Amt += (b['t1Total'] ?? 0).toDouble();
        totalT2Qty += (b['t2Qty'] ?? 0).toDouble(); totalT2Amt += (b['t2Total'] ?? 0).toDouble();
        totalTransport += (b['transportCost'] ?? 0).toDouble();
        
        double net = (b['netPayable'] ?? 0).toDouble();
        totalNet += net;
        if (net > 0) totalPositiveNet += net;
        else totalNegativeNet += net.abs();

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(21.07 * PdfPageFormat.cm, 13.08 * PdfPageFormat.cm), 
            margin: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 10), 
            build: (pw.Context context) => _buildPdfBill(item, engFont, fmFont),
          ),
        );
      }

      if (!_isAlreadyFinalized) {
        await Supabase.instance.client.from('monthly_summaries').upsert({
          'id': ratesDocId,
          'totalWeight': totalWeight,
          'totalGross': totalGross,
          'totalAdvance': totalAdvance,
          'totalF1Qty': totalF1Qty, 'totalF1Amt': totalF1Amt,
          'totalF2Qty': totalF2Qty, 'totalF2Amt': totalF2Amt,
          'totalT1Qty': totalT1Qty, 'totalT1Amt': totalT1Amt,
          'totalT2Qty': totalT2Qty, 'totalT2Amt': totalT2Amt,
          'totalTransport': totalTransport,
          'totalPositiveNet': totalPositiveNet,
          'totalNegativeNet': totalNegativeNet,
          'totalNet': totalNet,
          'finalizedAt': DateTime.now().toIso8601String(),
        });
      }

      // 💡 නව PDF ගොනු නාමයේ ආකෘතිය: year_month_currenttime.pdf
      String currentTime = DateFormat('hh_mm_ss_a').format(DateTime.now()); 
      String customFileName = "${_currentYear}_${monthName}_$currentTime.pdf";
      
      // 🚀 🚀 🚀 ප්‍රධාන වෙනස මෙතැනයි 🚀 🚀 🚀
      // Windows වලදී නම හරියටම Save As වෙන්න layoutPdf වෙනුවට sharePdf භාවිතා කර ඇත.
      await Printing.sharePdf(bytes: await pdf.save(), filename: customFileName);
      
      _checkStatusAndCalculate();
    } catch (e) { 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); 
    } finally { 
      setState(() => _isCalculating = false); 
    }
  }

  // ===========================================================================
  // 🎨 UI COMPONENTS (Clean, Modern, Web-inspired Design + Skeleton)
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMonthSelector(),
          const SizedBox(height: 20),
          _buildActionCard(),
          if (_isAlreadyFinalized && _monthlySummaryData != null) ...[
             const SizedBox(height: 20),
             _buildSummaryCard(),
          ]
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    List<String> months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.black54),
            const SizedBox(width: 15),
            Text("$_currentYear", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
            const SizedBox(width: 15),
            Container(width: 1, height: 20, color: Colors.grey.shade300),
            const SizedBox(width: 15),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedMonth,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                  items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(months[i], style: const TextStyle(fontSize: 15, color: Colors.black87)))),
                  onChanged: (val) { setState(() => _selectedMonth = val!); _checkStatusAndCalculate(); },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard() {
    bool hasData = _billingList.isNotEmpty;
    Color actionColor = _isAlreadyFinalized ? Colors.green.shade600 : (_ratesMissing ? Colors.orange.shade600 : Colors.blue.shade600);
    
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: actionColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(
                    _isAlreadyFinalized ? Icons.check_circle_outline : (_ratesMissing ? Icons.warning_amber_rounded : Icons.account_balance_wallet_outlined), 
                    color: actionColor, size: 24
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isAlreadyFinalized ? "Finalized" : (_ratesMissing ? "Rates Missing" : "Ready to Close"),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: actionColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isAlreadyFinalized ? "මෙම මාසයේ ගිණුම් පියවා අවසන් කර ඇත. වාර්තා නැවත නැරඹිය හැක." : (_ratesMissing ? "කරුණාකර මෙම මාසය සඳහා අදාළ Rates ඇතුළත් කරන්න." : "දත්ත සූදානම්. මාසික ගිණුම් පියවා වාර්තා සකසන්න."),
                        style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // 💡 Skeleton Loader එක
            if (_isCalculating)
              _SkeletonPulse(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity, height: 48,
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 180, height: 12,
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: (!hasData && !_isAlreadyFinalized) ? null : _finalizeAndGeneratePDF,
                  icon: Icon(_isAlreadyFinalized ? Icons.picture_as_pdf_outlined : Icons.save_alt_rounded, size: 20),
                  label: Text(_isAlreadyFinalized ? "VIEW ALL BILLS PDF" : "FINALIZE & SAVE ALL", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: actionColor, 
                    foregroundColor: Colors.white, 
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    var s = _monthlySummaryData!;
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("මාසික ව්‍යාපාරික සාරාංශය", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
            const SizedBox(height: 20),
            _row("මුළු දළු බර (Total Weight)", "${(s['totalWeight'] ?? 0).toStringAsFixed(1)} Kg", isBold: true),
            _row("මුළු ආදායම (Gross Income)", "Rs. ${(s['totalGross'] ?? 0).toStringAsFixed(2)}", isBold: true),
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  const Row(children: [
                    Expanded(flex: 4, child: Text("Breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54))),
                    Expanded(flex: 2, child: Text("Qty", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54))),
                    Expanded(flex: 3, child: Text("Amount", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54))),
                  ]),
                  const Divider(color: Colors.black12, height: 24),
                  _itemRow("Advance", "-", s['totalAdvance']),
                  _itemRow("Fertilizer 01", s['totalF1Qty'], s['totalF1Amt']),
                  _itemRow("Fertilizer 02", s['totalF2Qty'], s['totalF2Amt']),
                  _itemRow("Tea Pkt 01", s['totalT1Qty'], s['totalT1Amt']),
                  _itemRow("Tea Pkt 02", s['totalT2Qty'], s['totalT2Amt']),
                  _itemRow("Transport", "-", s['totalTransport']),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            const Text("Payments Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 12),
            _row("ගෙවීමට ඇති (+) ", "Rs. ${(s['totalPositiveNet'] ?? 0).toStringAsFixed(2)}", color: Colors.blue.shade700),
            _row("අයවීමට ඇති (-) ", "Rs. ${(s['totalNegativeNet'] ?? 0).toStringAsFixed(2)}", color: Colors.red.shade700),
            const Divider(height: 24, color: Colors.black12),
            _row("ශුද්ධ ලාභ/අලාභය", "Rs. ${(s['totalNet'] ?? 0).toStringAsFixed(2)}", isBold: true, color: Colors.black87),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  Widget _itemRow(String label, dynamic qty, dynamic amt) {
    String qtyStr = (qty is String) ? qty : (qty > 0 ? qty.toStringAsFixed(0) : "-");
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(flex: 4, child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87))),
        Expanded(flex: 2, child: Text(qtyStr, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.black87))),
        Expanded(flex: 3, child: Text("Rs. ${(amt ?? 0).toStringAsFixed(2)}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87))),
      ]),
    );
  }

  // ===========================================================================
  // 🌟 PDF GENERATION LOGIC (NO CHANGES)
  // ===========================================================================
  pw.Widget _buildPdfBill(Map<String, dynamic> item, pw.Font engFont, pw.Font fmFont) {
    var b = item['bill'];

    Map<int, double> dailyWeights = {};
    List<String> advanceRecords = [];
    double totalW = 0;

    for (var row in b['tableRows']) {
      int day = int.parse(row['date'].toString().split('-').last);
      double w = (row['weight'] ?? 0.0).toDouble();
      if (w > 0) {
        dailyWeights[day] = (dailyWeights[day] ?? 0.0) + w;
        totalW += w;
      }

      List items = row['items'] ?? [];
      for (var it in items) {
        if (it['desc'] == 'Advance' && it['amt'] > 0) {
          advanceRecords.add('D${day.toString().padLeft(2, '0')}: Rs.${it['amt'].toStringAsFixed(0)}');
        }
      }
    }

    final gridRows = <pw.TableRow>[];
    
    gridRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          for (int i = 0; i < 8; i++) ...[
            _pdfCell('Day', engFont, bold: true),
            _pdfCell('Kg', engFont, bold: true),
          ]
        ]
      )
    );

    for (int r = 0; r < 4; r++) { 
      final rowChildren = <pw.Widget>[];
      for (int c = 0; c < 8; c++) { 
        int day = (r * 8) + c + 1; 
        if (day > 31) {
          rowChildren.addAll([_pdfCell('', engFont), _pdfCell('', engFont)]);
        } else {
          double w = dailyWeights[day] ?? 0.0;
          rowChildren.addAll([
            _pdfCell(day.toString(), engFont),
            _pdfCell(w > 0 ? w.toStringAsFixed(1) : '-', engFont),
          ]);
        }
      }
      gridRows.add(pw.TableRow(children: rowChildren));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('NALEEN SURANGA', style: pw.TextStyle(font: engFont, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('Authorized Green Dealer - Gangoda, Rakwana', style: pw.TextStyle(font: engFont, fontSize: 8)),
                pw.Text('Tel: 0713444934 / 0758258544', style: pw.TextStyle(font: engFont, fontSize: 8)),
              ]
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Name: ${item['name']} | Ref: ${item['ref'].toString().padLeft(3, '0')}', style: pw.TextStyle(font: engFont, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('Month: ${b['displayMonth']}', style: pw.TextStyle(font: engFont, fontSize: 9)),
              ]
            )
          ]
        ),
        pw.SizedBox(height: 5),

        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey700),
          defaultColumnWidth: const pw.FlexColumnWidth(), 
          children: gridRows,
        ),
        pw.SizedBox(height: 10),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 1, 
              child: pw.Container(
                padding: const pw.EdgeInsets.only(right: 15),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('wvq lsÍï úia;rh', style: pw.TextStyle(font: fmFont, fontSize: 12, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                    pw.SizedBox(height: 5),
                    
                    if (b['advTotal'] > 0) ...[
                      pw.Row(children: [
                        pw.Text('w;a;sldrï ', style: pw.TextStyle(font: fmFont, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('(Total: Rs.${b['advTotal'].toStringAsFixed(2)})', style: pw.TextStyle(font: engFont, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ]),
                      pw.SizedBox(height: 2),
                      pw.Wrap(
                        spacing: 8, runSpacing: 2,
                        children: advanceRecords.map((e) => pw.Text(e, style: pw.TextStyle(font: engFont, fontSize: 8, color: PdfColors.grey800))).toList(),
                      ),
                      pw.SizedBox(height: 4),
                    ],

                    if (b['f1Qty'] > 0) 
                      pw.Row(children: [
                        pw.Text('fmdfydr 01 : ', style: pw.TextStyle(font: fmFont, fontSize: 10)),
                        pw.Text('${b['f1Qty']} x Rs.${(b['f1Total']/b['f1Qty']).toStringAsFixed(2)} = Rs.${b['f1Total'].toStringAsFixed(2)}', style: pw.TextStyle(font: engFont, fontSize: 8)),
                      ]),

                    if (b['f2Qty'] > 0) 
                      pw.Row(children: [
                        pw.Text('fmdfydr 02 : ', style: pw.TextStyle(font: fmFont, fontSize: 10)),
                        pw.Text('${b['f2Qty']} x Rs.${(b['f2Total']/b['f2Qty']).toStringAsFixed(2)} = Rs.${b['f2Total'].toStringAsFixed(2)}', style: pw.TextStyle(font: engFont, fontSize: 8)),
                      ]),

                    if (b['t1Qty'] > 0) 
                      pw.Row(children: [
                        pw.Text('f;a fld< 01  ', style: pw.TextStyle(font: fmFont, fontSize: 10)),
                        pw.Text('${b['t1Qty']} x Rs.${(b['t1Total']/b['t1Qty']).toStringAsFixed(2)} = Rs.${b['t1Total'].toStringAsFixed(2)}', style: pw.TextStyle(font: engFont, fontSize: 8)),
                      ]),

                    if (b['t2Qty'] > 0) 
                      pw.Row(children: [
                        pw.Text('f;a fld< 02 : ', style: pw.TextStyle(font: fmFont, fontSize: 10)),
                        pw.Text('${b['t2Qty']} x Rs.${(b['t2Total']/b['t2Qty']).toStringAsFixed(2)} = Rs.${b['t2Total'].toStringAsFixed(2)}', style: pw.TextStyle(font: engFont, fontSize: 8)),
                      ]),
                    
                    pw.SizedBox(height: 4),
                    pw.Row(children: [
                      pw.Text('m%jdyk .dia;= ', style: pw.TextStyle(font: fmFont, fontSize: 10)),
                      pw.Text('(${totalW.toStringAsFixed(1)}kg) : Rs.${b['transportCost'].toStringAsFixed(2)}', style: pw.TextStyle(font: engFont, fontSize: 8)),
                    ]),
                    
                    if ((b['arrears'] ?? 0) > 0) ...[
                      pw.SizedBox(height: 2),
                      pw.Row(children: [
                        pw.Text('miq.sh udifha ysÕ uqo,a  ', style: pw.TextStyle(font: fmFont, fontSize: 10, color: PdfColors.red800)),
                        pw.Text('Rs.${b['arrears'].toStringAsFixed(2)}', style: pw.TextStyle(font: engFont, fontSize: 8, color: PdfColors.red800)),
                      ]),
                    ]
                  ]
                )
              )
            ),

            pw.Expanded(
              flex: 1, 
              child: pw.Container(
                padding: const pw.EdgeInsets.all(5),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5, color: PdfColors.grey700)),
                child: pw.Column(
                  children: [
                    _pdfSummaryRow('uq¿ o¿ nr', '${totalW.toStringAsFixed(1)} Kg', fmFont, engFont, bold: true),
                    _pdfSummaryRow('o¿ lsf,dajl ñ,', 'Rs. ${b['teaRate'].toStringAsFixed(2)}', fmFont, engFont), 
                    pw.Divider(thickness: 0.5),
                    _pdfSummaryRow('o< wdodhu', 'Rs. ${b['grossIncome'].toStringAsFixed(2)}', fmFont, engFont, bold: true),
                    pw.SizedBox(height: 5),
                    
                    _pdfSummaryRow('uq¿ w;a;sldrï', '-${b['advTotal'].toStringAsFixed(2)}', fmFont, engFont),
                    _pdfSummaryRow('fmdfydr iy f;a fld<', '-${(b['f1Total'] + b['f2Total'] + b['t1Total'] + b['t2Total']).toStringAsFixed(2)}', fmFont, engFont),
                    _pdfSummaryRow('m%jdyk .dia;=', '-${b['transportCost'].toStringAsFixed(2)}', fmFont, engFont),
                    if ((b['arrears'] ?? 0) > 0)
                      _pdfSummaryRow('ysÕ uqo,a', '-${b['arrears'].toStringAsFixed(2)}', fmFont, engFont),
                    
                    pw.Divider(thickness: 0.5),
                    _pdfSummaryRow('uq¿ wvq lsÍï', '-${b['totalDeductions'].toStringAsFixed(2)}', fmFont, engFont, bold: true),
                    pw.Divider(thickness: 1.5),
                    _pdfSummaryRow('f.úh hq;= Y=oaO uqo,', 'Rs. ${b['netPayable'].toStringAsFixed(2)}', fmFont, engFont, bold: true),
                    pw.Divider(thickness: 1.5),
                  ]
                )
              )
            )
          ]
        ),

        pw.SizedBox(height: 15), 
        pw.Divider(thickness: 0.5),
        pw.Center(
          child: pw.Text('Thank You! | Powered by OrbitView Innovations', style: pw.TextStyle(font: engFont, fontSize: 7, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700))
        )
      ]
    );
  }

  pw.Widget _pdfCell(String text, pw.Font font, {bool bold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  pw.Widget _pdfSummaryRow(String fmLabel, String value, pw.Font fmFont, pw.Font engFont, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(fmLabel, style: pw.TextStyle(font: fmFont, fontSize: 11, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(font: engFont, fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}

// ===========================================================================
// 🌟 CUSTOM SKELETON LOADER WIDGET (No External Packages Required)
// ===========================================================================
class _SkeletonPulse extends StatefulWidget {
  final Widget child;
  const _SkeletonPulse({required this.child});

  @override
  __SkeletonPulseState createState() => __SkeletonPulseState();
}

class __SkeletonPulseState extends State<_SkeletonPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_controller),
      child: widget.child,
    );
  }
}