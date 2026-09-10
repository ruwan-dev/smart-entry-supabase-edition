import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// ගොනු තුනම එකම Folder එකේ තියෙන නිසා මෙහෙම Import කරන්න
import 'bill_pdf_service.dart';
import 'raw_text_print_service.dart';

class MonthlyBillScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String refNumber;

  const MonthlyBillScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.refNumber,
  });

  @override
  State<MonthlyBillScreen> createState() => _MonthlyBillScreenState();
}

class _MonthlyBillScreenState extends State<MonthlyBillScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _monthlyBills = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Monthly Rates (Tea Rate & Transport Rate) ලබා ගැනීම
      var ratesSnap = await Supabase.instance.client.from('monthly_rates').select();
      Map<String, Map<String, double>> monthlyRatesMap = {};
      for (var doc in ratesSnap) {
        monthlyRatesMap[doc['id']] = {
          'teaRate': _parseDouble(doc['teaRate']),
          'transportRate': _parseDouble(doc['transportRate']),
        };
      }

      // 2. Global Settings (item unit prices) ලබා ගැනීම
      var priceDoc = await Supabase.instance.client
          .from('global_settings')
          .select()
          .eq('id', 'prices')
          .maybeSingle();
      double f1Price = _parseDouble(priceDoc?['fertilizer1Price']);
      double f2Price = _parseDouble(priceDoc?['fertilizer2Price']);
      double tp1Price = _parseDouble(priceDoc?['teaPacket1Price']);
      double tp2Price = _parseDouble(priceDoc?['teaPacket2Price']);

      // 3. Daily Entries ලබා ගැනීම
      var entriesSnap = await Supabase.instance.client
          .from('daily_entries')
          .select()
          .eq('customerId', widget.customerId)
          .order('date', ascending: true);

      Map<String, List<Map<String, dynamic>>> entriesByMonth = {};
      for (var doc in entriesSnap) {
        String dateStr = doc['date'] ?? ''; 
        if (dateStr.length >= 7) {
          String monthKey = dateStr.substring(0, 7); 
          if (!entriesByMonth.containsKey(monthKey)) entriesByMonth[monthKey] = [];
          entriesByMonth[monthKey]!.add(doc);
        }
      }

      List<Map<String, dynamic>> calculatedBills = [];
      double carriedForwardArrears = 0.0; 

      List<String> sortedMonthKeys = entriesByMonth.keys.toList()..sort();

      for (String monthKey in sortedMonthKeys) {
        List<Map<String, dynamic>> docs = entriesByMonth[monthKey]!;
        DateTime parsedDate = DateTime.parse('$monthKey-01');
        String monthName = DateFormat('MMMM').format(parsedDate); 
        String yearStr = parsedDate.year.toString();
        String rateDocId = '$yearStr-$monthName';

        double teaRate = monthlyRatesMap[rateDocId]?['teaRate'] ?? 0;
        double transportRate = monthlyRatesMap[rateDocId]?['transportRate'] ?? 0;

        double sumNetWeight = 0;
        double sumAdvance = 0;
        double sumItemsTotal = 0;
        
        Map<String, Map<String, dynamic>> dailyData = {};

        for (var data in docs) {
          String date = data['date'].toString();
          double netW = _parseDouble(data['netWeight']);
          
          double f1Qty = _parseDouble(data['fertilizer1Qty']);
          double f2Qty = _parseDouble(data['fertilizer2Qty']);
          double tp1Qty = _parseDouble(data['teaPacket1Qty']);
          double tp2Qty = _parseDouble(data['teaPacket2Qty']);
          double adv = _parseDouble(data['advanceAmount']);

          sumNetWeight += netW;
          sumAdvance += adv;
          
          // Use prices from global_settings (not from daily_entries — they don't have unit prices)
          double dayItemsTotal = (f1Qty * f1Price) + (f2Qty * f2Price) + (tp1Qty * tp1Price) + (tp2Qty * tp2Price);
          sumItemsTotal += dayItemsTotal;

          if (!dailyData.containsKey(date)) dailyData[date] = {'weight': 0.0, 'items': []};
          dailyData[date]!['weight'] += netW;

          if (f1Qty > 0) dailyData[date]!['items'].add({'desc': 'Fertilizer 01', 'qty': f1Qty, 'uPrice': f1Price, 'amt': f1Qty * f1Price});
          if (f2Qty > 0) dailyData[date]!['items'].add({'desc': 'Fertilizer 02', 'qty': f2Qty, 'uPrice': f2Price, 'amt': f2Qty * f2Price});
          if (tp1Qty > 0) dailyData[date]!['items'].add({'desc': 'Tea Packet 01', 'qty': tp1Qty, 'uPrice': tp1Price, 'amt': tp1Qty * tp1Price});
          if (tp2Qty > 0) dailyData[date]!['items'].add({'desc': 'Tea Packet 02', 'qty': tp2Qty, 'uPrice': tp2Price, 'amt': tp2Qty * tp2Price});
          if (adv > 0) dailyData[date]!['items'].add({'desc': 'Advance', 'qty': 0, 'uPrice': 0, 'amt': adv});
        }

        double grossIncome = sumNetWeight * teaRate;
        double transportCost = sumNetWeight * transportRate;
        double otherCosts = sumAdvance + sumItemsTotal;
        double totalDeductions = transportCost + otherCosts;
        double previousArrears = carriedForwardArrears;
        double netPayable = grossIncome - (totalDeductions + previousArrears);

        carriedForwardArrears = netPayable < 0 ? netPayable.abs() : 0;

        List<String> sortedDates = dailyData.keys.toList()..sort();
        List<Map<String, dynamic>> tableRows = sortedDates.map((d) => {
          'date': d, 'weight': dailyData[d]!['weight'], 'items': dailyData[d]!['items']
        }).toList();

        calculatedBills.add({
          'displayMonth': '$monthName $yearStr',
          'teaRate': teaRate, 
          'grossIncome': grossIncome,
          'totalDeductions': totalDeductions,
          'previousArrears': previousArrears,
          'netPayable': netPayable,
          'tableRows': tableRows,
          'transportCost': transportCost,
          'otherCosts': otherCosts,
        });
      }

      setState(() {
        _monthlyBills = calculatedBills.reversed.toList(); 
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(title: const Text('මාසික බිල්පත් වාර්තාව')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _monthlyBills.length,
            itemBuilder: (context, index) => _buildInvoiceCard(_monthlyBills[index]),
          ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> bill) {
    return Card(
      elevation: 4, margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        title: Text(bill['displayMonth'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text('ශුද්ධ ගෙවීම: Rs. ${bill['netPayable'].toStringAsFixed(2)}', 
            style: TextStyle(color: bill['netPayable'] < 0 ? Colors.red : Colors.green.shade800, fontWeight: FontWeight.bold)),
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            child: Column(children: [
              const Text('NALEEN SURANGA', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Text('Authorized Green Tea Dealer', style: TextStyle(fontSize: 10)),
              const Divider(height: 30),
              
              Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(2.5), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1.5), 4: FlexColumnWidth(1.5)},
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100), 
                    children: const [
                      _Cell('දිනය', b: true), _Cell('විස්තරය', b: true), _Cell('ප්‍රමාණය', b: true), _Cell('මිල', b: true), _Cell('එකතුව', b: true)
                    ]
                  ),
                  ...(bill['tableRows'] as List).map((row) {
                    List<dynamic> items = row['items'];
                    double weight = row['weight'];
                    
                    return TableRow(
                      children: [
                        _Cell(row['date']),
                        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          if (weight > 0) const _InternalCell('Tea Leaves', align: TextAlign.left),
                          ...items.map((i) => _InternalCell(i['desc'], align: TextAlign.left)),
                        ]),
                        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          if (weight > 0) _InternalCell('${weight.toStringAsFixed(1)} Kg', align: TextAlign.right),
                          ...items.map((i) => _InternalCell(i['qty'] > 0 ? i['qty'].toStringAsFixed(0) : '-', align: TextAlign.right)),
                        ]),
                        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          if (weight > 0) _InternalCell(bill['teaRate'].toStringAsFixed(2), align: TextAlign.right),
                          ...items.map((i) => _InternalCell(i['uPrice'] > 0 ? i['uPrice'].toStringAsFixed(2) : '-', align: TextAlign.right)),
                        ]),
                        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          if (weight > 0) _InternalCell((weight * bill['teaRate']).toStringAsFixed(2), align: TextAlign.right),
                          ...items.map((i) => _InternalCell(i['amt'].toStringAsFixed(2), align: TextAlign.right, color: Colors.red)),
                        ]),
                      ],
                    );
                  }).toList(),
                ],
              ),
              
              const SizedBox(height: 25),
              _row('මුළු දළු ආදායම', 'Rs. ${bill['grossIncome'].toStringAsFixed(2)}', b: true),
              _row('ප්‍රවාහන වියදම', '- Rs. ${bill['transportCost'].toStringAsFixed(2)}', c: Colors.red),
              _row('අනෙකුත් අඩු කිරීම්', '- Rs. ${bill['otherCosts'].toStringAsFixed(2)}', c: Colors.red),
              if (bill['previousArrears'] > 0) 
                _row('පසුගිය හිඟ මුදල', '- Rs. ${bill['previousArrears'].toStringAsFixed(2)}', c: Colors.red),
              const Divider(thickness: 2),
              _row('ශුද්ධ ගෙවීම', 'Rs. ${bill['netPayable'].toStringAsFixed(2)}', b: true, fontSize: 18, c: bill['netPayable'] < 0 ? Colors.red : Colors.green.shade900),
              
              const Divider(height: 30),
              const Center(child: Text('Powered by OrbitView Innovations', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
              const SizedBox(height: 15),

              // මෙහිදී PDF බොත්තම ඉවත් කර DOT MATRIX PRINT බොත්තම පමණක් තබා ඇත
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    bool ok = await RawTextPrintService.printToWindows(
                      bill: bill, customerName: widget.customerName, refNumber: widget.refNumber
                    );
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'මුද්‍රණය සඳහා යවන ලදී' : 'මුද්‍රණ දෝෂයකි'), backgroundColor: ok ? Colors.green : Colors.red));
                  }, 
                  icon: const Icon(Icons.bolt), 
                  label: const Text('DOT MATRIX PRINT'), 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black, 
                    foregroundColor: Colors.white, 
                    minimumSize: const Size(0, 50)
                  )
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _row(String l, String v, {bool b = false, Color? c, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Text(l, style: TextStyle(fontSize: fontSize, fontWeight: b ? FontWeight.bold : FontWeight.normal)), 
          Text(v, style: TextStyle(fontSize: fontSize, fontWeight: b ? FontWeight.bold : FontWeight.normal, color: c))
        ]
      )
    );
  }
}

class _InternalCell extends StatelessWidget {
  final String text; 
  final TextAlign align; 
  final Color? color;
  const _InternalCell(this.text, {this.align = TextAlign.center, this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5), 
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5))), 
    child: Text(text, textAlign: align, style: TextStyle(fontSize: 10, color: color))
  );
}

class _Cell extends StatelessWidget {
  final String text; 
  final bool b;
  const _Cell(this.text, {this.b = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8), 
    child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: b ? FontWeight.bold : FontWeight.normal))
  );
}