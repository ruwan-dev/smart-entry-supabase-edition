import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'widgets/monthly_closing_widget.dart'; 

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
    'Advances & Items'
  ];

  final Color primaryAppColor = const Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    var snap = await Supabase.instance.client.from('customers').select().order('name');
    setState(() {
      _customers = List.from(snap);
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

  Future<void> _generatePdfReport() async {
    if (_selectedReportType == 'Customer Wise' && _selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('කරුණාකර පාරිභෝගිකයෙකු තෝරන්න')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      double fert1Price = 0, fert2Price = 0, teaPkt1Price = 0, teaPkt2Price = 0;
      var priceDoc = await Supabase.instance.client.from('global_settings').select().eq('id', 'prices').maybeSingle();
      if (priceDoc != null) {
        fert1Price = (priceDoc['fertilizer1Price'] ?? 0.0).toDouble();
        fert2Price = (priceDoc['fertilizer2Price'] ?? 0.0).toDouble();
        teaPkt1Price = (priceDoc['teaPacket1Price'] ?? 0.0).toDouble();
        teaPkt2Price = (priceDoc['teaPacket2Price'] ?? 0.0).toDouble();
      }

      DateTime endOfDay = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

      var snap = await Supabase.instance.client
          .from('daily_entries')
          .select()
          .gte('timestamp', _startDate.toIso8601String())
          .lte('timestamp', endOfDay.toIso8601String());

      List<Map<String, dynamic>> entries = List.from(snap);

      if (_selectedReportType == 'Customer Wise') {
        entries = entries.where((doc) => doc['customerId'] == _selectedCustomerId).toList();
      } else if (_selectedReportType == 'Tea Leaves Only') {
        entries = entries.where((doc) => (doc['netWeight'] ?? 0) > 0).toList();
      } else if (_selectedReportType == 'Fertilizer Wise') {
        entries = entries.where((doc) => (doc['fertilizer1Qty'] ?? 0) > 0 || (doc['fertilizer2Qty'] ?? 0) > 0).toList();
      } else if (_selectedReportType == 'Tea Packet Wise') {
        entries = entries.where((doc) => (doc['teaPacket1Qty'] ?? 0) > 0 || (doc['teaPacket2Qty'] ?? 0) > 0).toList();
      } else if (_selectedReportType == 'Advances & Items') {
        entries = entries.where((doc) => 
          (doc['advanceAmount'] ?? 0) > 0 || 
          (doc['fertilizer1Qty'] ?? 0) > 0 || 
          (doc['fertilizer2Qty'] ?? 0) > 0 || 
          (doc['teaPacket1Qty'] ?? 0) > 0 || 
          (doc['teaPacket2Qty'] ?? 0) > 0
        ).toList();
      }

      entries.sort((a, b) => DateTime.parse(a['timestamp']).compareTo(DateTime.parse(b['timestamp'])));

      Map<String, String> customerNames = {};
      for (var c in _customers) {
        customerNames[c['id']] = c['name'] ?? 'Unknown';
      }

      final pdf = pw.Document();
      
      bool showWeight = ['Daily All Data', 'Customer Wise', 'Tea Leaves Only'].contains(_selectedReportType);
      bool showAdvance = ['Daily All Data', 'Customer Wise', 'Advances & Items'].contains(_selectedReportType);
      bool showFertilizer = ['Daily All Data', 'Customer Wise', 'Advances & Items', 'Fertilizer Wise'].contains(_selectedReportType);
      bool showTeaPkt = ['Daily All Data', 'Customer Wise', 'Advances & Items', 'Tea Packet Wise'].contains(_selectedReportType);
      bool showTotalDed = ['Daily All Data', 'Customer Wise', 'Advances & Items'].contains(_selectedReportType);

      List<String> headers = ['Date', 'Customer Name'];
      Map<int, pw.Alignment> alignments = {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft};
      int colIndex = 2;
      if (showWeight) { headers.add('Weight\n(Kg)'); alignments[colIndex++] = pw.Alignment.centerRight; }
      if (showAdvance) { headers.add('Advance\n(Rs)'); alignments[colIndex++] = pw.Alignment.centerRight; }
      if (showFertilizer) { headers.add('Fert. 1'); alignments[colIndex++] = pw.Alignment.center; headers.add('Fert. 2'); alignments[colIndex++] = pw.Alignment.center; }
      if (showTeaPkt) { headers.add('Tea Pkt'); alignments[colIndex++] = pw.Alignment.center; }
      if (showTotalDed) { headers.add('Total Ded.'); alignments[colIndex++] = pw.Alignment.centerRight; }

      List<List<String>> tableData = entries.map((data) {
        String date = DateFormat('MM-dd').format(DateTime.parse(data['timestamp']));
        String cName = customerNames[data['customerId']] ?? '-';
        
        double w = (data['netWeight'] ?? 0).toDouble();
        double adv = (data['advanceAmount'] ?? 0).toDouble();
        double f1 = (data['fertilizer1Qty'] ?? 0).toDouble();
        double f2 = (data['fertilizer2Qty'] ?? 0).toDouble();
        double t1 = (data['teaPacket1Qty'] ?? 0).toDouble();
        double t2 = (data['teaPacket2Qty'] ?? 0).toDouble();
        double rowTotal = adv + (f1 * fert1Price) + (f2 * fert2Price) + (t1 * teaPkt1Price) + (t2 * teaPkt2Price);

        List<String> row = [date, cName];
        if (showWeight) row.add(w > 0 ? w.toStringAsFixed(1) : '-');
        if (showAdvance) row.add(adv > 0 ? adv.toStringAsFixed(0) : '-');
        if (showFertilizer) { row.add(f1 > 0 ? f1.toStringAsFixed(0) : '-'); row.add(f2 > 0 ? f2.toStringAsFixed(0) : '-'); }
        if (showTeaPkt) row.add(t1 > 0 || t2 > 0 ? '${t1.toInt()}/${t2.toInt()}' : '-');
        if (showTotalDed) row.add(rowTotal > 0 ? rowTotal.toStringAsFixed(0) : '-');
        return row;
      }).toList();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Powered by OrbitView Innovations', style: const pw.TextStyle(fontSize: 8)),
        ),
        build: (pw.Context context) => [
          pw.Header(level: 0, child: pw.Text('SMART ENTRY - SYSTEM REPORT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 10),
          pw.Text('Report: $_selectedReportType | Period: ${DateFormat('yyyy-MM-dd').format(_startDate)} to ${DateFormat('yyyy-MM-dd').format(_endDate)}'),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(headers: headers, data: tableData, cellAlignments: alignments, headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), cellStyle: const pw.TextStyle(fontSize: 8)),
        ],
      ));

      await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Report.pdf');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. DefaultTabController මගින් පිටුව කොටස් 2කට වෙන් කිරීම
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8), // ආකර්ෂණීය ලා අළු පසුබිම
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F2937), // තද අළු පැහැ අකුරු
          elevation: 0,
          title: const Text('වාර්තා සහ ගිණුම් පියවීම', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          bottom: TabBar(
            labelColor: primaryAppColor,
            unselectedLabelColor: Colors.blueGrey.shade400,
            indicatorColor: primaryAppColor,
            indicatorWeight: 4,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [
              Tab(text: 'ගිණුම් පියවීම (Closing)'),
              Tab(text: 'PDF වාර්තා'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 1 වැනි Tab එක: මාසික ගිණුම් පියවීම
            _buildClosingTab(),
            
            // 2 වැනි Tab එක: PDF වාර්තා ලබාගැනීම
            _buildPdfTab(),
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
          const Text('මාසික ගිණුම් අවසන් කිරීම', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          const Text('මෙහිදී අදාළ මාසයේ සියලුම දත්ත පරීක්ෂා කර ස්ථිර කිරීම සිදු කෙරේ.', style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
          const SizedBox(height: 24),
          
          // Original widget එක අලංකාර Container එකකට ඇතුළත් කර ඇත
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: const MonthlyClosingWidget(),
          ),
        ],
      ),
    );
  }

  // --- Tab 2: PDF වාර්තා ---
  Widget _buildPdfTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PDF වාර්තා ලබාගැනීම', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          const Text('ඔබට අවශ්‍ය දින පරාසය සහ වාර්තා වර්ගය තෝරා වාර්තා බාගත කරගන්න.', style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
          const SizedBox(height: 24),
          
          // සැකසුම් කොටස (Form Section)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('දින පරාසය', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                const SizedBox(height: 12),
                _buildDatePickerSection(),
                
                const SizedBox(height: 24),
                const Text('වාර්තා වර්ගය', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                const SizedBox(height: 12),
                _buildDropdown(
                  _selectedReportType, 
                  _reportTypes, 
                  (val) => setState(() { 
                    _selectedReportType = val!; 
                    if(val != 'Customer Wise') _selectedCustomerId = null; 
                  })
                ),

                if (_selectedReportType == 'Customer Wise') ...[
                  const SizedBox(height: 24),
                  const Text('පාරිභෝගිකයා තෝරන්න', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                  const SizedBox(height: 12),
                  _buildCustomerDropdown(),
                ],

                const SizedBox(height: 40),
                _buildPdfButton(),
              ],
            ),
          ),
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
    return InkWell(
      onTap: () => _selectDate(context, isStart),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white, 
          border: Border.all(color: Colors.grey.shade300), 
          borderRadius: BorderRadius.circular(12)
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: primaryAppColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(DateFormat('yyyy-MM-dd').format(date), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1F2937))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // නවීන පෙනුමකින් යුත් Dropdown Component
  Widget _buildDropdown(String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white, 
        border: Border.all(color: Colors.grey.shade300), 
        borderRadius: BorderRadius.circular(12)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blueGrey),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCustomerDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white, 
        border: Border.all(color: Colors.grey.shade300), 
        borderRadius: BorderRadius.circular(12)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCustomerId,
          hint: const Text('පාරිභෝගිකයෙකු තෝරන්න', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blueGrey),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
          items: _customers.map((doc) => DropdownMenuItem<String>(value: doc['id'] as String, child: Text((doc['name'] ?? '') as String))).toList(),
          onChanged: (val) => setState(() => _selectedCustomerId = val),
        ),
      ),
    );
  }

  Widget _buildPdfButton() {
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _generatePdfReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAppColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_rounded, size: 22),
                  SizedBox(width: 10),
                  Text('PDF වාර්තාව ලබාගන්න', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
                ],
              ),
      ),
    );
  }
}