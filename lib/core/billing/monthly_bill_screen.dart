import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../widgets/skeleton_box.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_entry/features/reports/widgets/whatsapp_batch_dialog.dart';

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

  String _customerPhone = '';
  String _companyLine1 = 'SmartEntry';
  String _companyLine2 = '';
  String _companyLine3 = '';
  String _companyLine4 = '';
  String _companyLine5 = '';

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
      var customerSnap = await Supabase.instance.client
          .from('customers')
          .select('phone')
          .eq('id', widget.customerId)
          .maybeSingle();
      if (customerSnap != null) {
        _customerPhone = customerSnap['phone']?.toString() ?? '';
      }

      final prefs = await SharedPreferences.getInstance();
      _companyLine1 = prefs.getString('company_line_1') ?? 'SmartEntry';
      _companyLine2 = prefs.getString('company_line_2') ?? '';
      _companyLine3 = prefs.getString('company_line_3') ?? '';
      _companyLine4 = prefs.getString('company_line_4') ?? '';
      _companyLine5 = prefs.getString('company_line_5') ?? '';

      // 1. Get all finalized bills for this customer directly from Supabase
      var billsSnap = await Supabase.instance.client
          .from('finalized_bills')
          .select('id, billData, finalizedAt')
          .eq('customerId', widget.customerId)
          .order('finalizedAt', ascending: false);

      List<Map<String, dynamic>> finalizedBillsList = [];

      for (var doc in billsSnap) {
        var b = doc['billData'];
        if (b != null) {
          finalizedBillsList.add({
            'id': doc['id'],
            'displayMonth': b['displayMonth'] ?? '',
            'teaRate': _parseDouble(b['teaRate']),
            'grossIncome': _parseDouble(b['grossIncome']),
            'totalDeductions': _parseDouble(b['totalDeductions']),
            'previousArrears': _parseDouble(b['arrears']),
            'netPayable': _parseDouble(b['netPayable']),
            'tableRows': b['tableRows'] ?? [],
            'transportCost': _parseDouble(b['transportCost']),
            'otherCosts': _parseDouble(b['otherCosts']),
            'billData': b,
          });
        }
      }

      setState(() {
        _monthlyBills = finalizedBillsList;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(title: const Text('මාසික බිල්පත් වාර්තාව')),
      body: _isLoading
          ? _buildSkeleton()
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _monthlyBills.length,
              itemBuilder: (context, index) =>
                  _buildInvoiceCard(_monthlyBills[index]),
            ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> bill) {
    // Calculate totals and extract days
    Map<int, double> weightByDay = {};
    Map<int, double> weight2ByDay = {};
    Map<int, double> advanceByDay = {};
    double totalAdvance = 0;
    double totalWeight = 0;
    double totalWeight2 = 0;

    for (var row in bill['tableRows']) {
      String dateStr = row['date'] ?? '';
      if (dateStr.isEmpty) continue;

      int day = int.tryParse(dateStr.split('-').last) ?? 0;
      if (day == 0) continue;

      double weight = _parseDouble(row['weight']);
      double weight2 = _parseDouble(row['weight2']);
      
      weightByDay[day] = weight;
      weight2ByDay[day] = weight2;
      
      totalWeight += weight;
      totalWeight2 += weight2;

      for (var item in row['items']) {
        if (item['desc'] == 'Advance') {
          double amt = _parseDouble(item['amt']);
          if (amt > 0) {
            totalAdvance += amt;
            advanceByDay[day] = (advanceByDay[day] ?? 0) + amt;
          }
        }
      }
    }

    // Grid Rows
    List<TableRow> gridRows = [];
    gridRows.add(
      TableRow(
        decoration: BoxDecoration(color: Colors.grey.shade200),
        children: List.generate(
          8,
          (index) => [
            _gridCell('Day', isHeader: true),
            _gridCell('Kg', isHeader: true),
          ],
        ).expand((x) => x).toList(),
      ),
    );

    for (int r = 0; r < 4; r++) {
      List<Widget> rowChildren = [];
      for (int c = 0; c < 8; c++) {
        int day = r * 8 + c + 1;
        if (day <= 31) {
          rowChildren.add(_gridCell(day.toString()));
          double w = weightByDay[day] ?? 0;
          double w2 = weight2ByDay[day] ?? 0;
          
          String formatW(double val) => val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
          String wStr = '-';
          if (w > 0 && w2 > 0) {
            wStr = '${formatW(w)}/${formatW(w2)}';
          } else if (w > 0) {
            wStr = formatW(w);
          } else if (w2 > 0) {
            wStr = '-/${formatW(w2)}';
          }
          
          rowChildren.add(_gridCell(wStr));
        } else {
          rowChildren.add(_gridCell(''));
          rowChildren.add(_gridCell(''));
        }
      }
      gridRows.add(TableRow(children: rowChildren));
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        title: Text(
          bill['displayMonth'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(
          'ශුද්ධ ගෙවීම: Rs. ${bill['netPayable'].toStringAsFixed(2)}',
          style: TextStyle(
            color: bill['netPayable'] < 0 ? Colors.red : Colors.green.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'NALEEN SURANGA',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Authorized Green Dealer - Gangoda, Rakwana',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Tel: 0713444934 / 0758258544',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Name: ${widget.customerName} | Ref: ${widget.refNumber}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Month: ${bill['displayMonth']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Day / Kg Grid
                Table(
                  border: TableBorder.all(color: Colors.black, width: 0.5),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: gridRows,
                ),
                const SizedBox(height: 15),

                // Bottom Section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column - Deductions Info
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'අඩු කිරීම් විස්තරය',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'අත්තිකාරම් (Total: Rs.${totalAdvance.toStringAsFixed(2)})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: advanceByDay.entries.map((e) {
                              String dayStr = e.key.toString().padLeft(2, '0');
                              return SizedBox(
                                width: 90,
                                child: Text(
                                  'D$dayStr: Rs.${e.value.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'ප්‍රවාහන ගාස්තු (${((totalWeight + totalWeight2) % 1 == 0) ? (totalWeight + totalWeight2).toInt() : (totalWeight + totalWeight2).toStringAsFixed(1)}kg) : Rs.${bill['transportCost'].toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),

                    // Right Column - Summary Box
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: Column(
                          children: [
                            if (totalWeight > 0 || totalWeight2 == 0)
                              _summaryGridRow(
                                'සාමාන්‍ය දළු',
                                '${totalWeight % 1 == 0 ? totalWeight.toInt() : totalWeight.toStringAsFixed(1)} Kg',
                                'Rs. ${(bill['teaRate'] ?? 0).toStringAsFixed(2)}',
                                isBold: true,
                              ),
                            if (totalWeight2 > 0)
                              _summaryGridRow(
                                'සුපිරි දළු',
                                '${totalWeight2 % 1 == 0 ? totalWeight2.toInt() : totalWeight2.toStringAsFixed(1)} Kg',
                                'Rs. ${(bill['teaRate2'] ?? 0).toStringAsFixed(2)}',
                                isBold: true,
                              ),
                            const Divider(
                              color: Colors.black,
                              thickness: 1,
                              height: 15,
                            ),

                            _summaryRow(
                              'දළ ආදායම',
                              'Rs. ${bill['grossIncome'].toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 5),
                            _summaryRow(
                              'මුළු අත්තිකාරම්',
                              '-${totalAdvance.toStringAsFixed(2)}',
                            ),
                            _summaryRow(
                              'පොහොර සහ තේ කොළ',
                              '-${bill['otherCosts'].toStringAsFixed(2)}',
                            ),
                            _summaryRow(
                              'ප්‍රවාහන ගාස්තු',
                              '-${bill['transportCost'].toStringAsFixed(2)}',
                            ),
                            if (bill['previousArrears'] > 0)
                              _summaryRow(
                                'පසුගිය හිඟ මුදල',
                                '-${bill['previousArrears'].toStringAsFixed(2)}',
                              ),

                            const Divider(
                              color: Colors.black,
                              thickness: 1,
                              height: 15,
                            ),
                            _summaryRow(
                              'මුළු අඩු කිරීම්',
                              '-${bill['totalDeductions'].toStringAsFixed(2)}',
                            ),

                            const Divider(
                              color: Colors.black,
                              thickness: 1,
                              height: 15,
                            ),
                            _summaryRow(
                              'ගෙවිය යුතු ශුද්ධ මුදල',
                              'Rs. ${bill['netPayable'].toStringAsFixed(2)}',
                              isBold: true,
                            ),
                            const Divider(
                              color: Colors.black,
                              thickness: 2,
                              height: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),
                const Center(
                  child: Text(
                    'Thank You! | Powered by OrbitView Innovations',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _sendIndividualWhatsApp(bill),
                      icon: const Icon(Icons.message, size: 18),
                      label: const Text('Send Bill (WhatsApp)'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: 120, height: 20),
                    const SizedBox(height: 8),
                    const SkeletonBox(width: 180, height: 16),
                  ],
                ),
                const SkeletonBox(width: 24, height: 24, borderRadius: 12), // for dropdown arrow
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryGridRow(
    String label,
    String weightVal,
    String rateVal, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              weightVal,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              rateVal,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _buildWhatsAppMessage(Map<String, dynamic> wrapper) {
    final currencyF = NumberFormat('#,##0.00');
    var bill = wrapper['billData'] ?? wrapper;

    double grossIncome = _parseDouble(bill['grossIncome']);
    double totalDeductions = _parseDouble(bill['totalDeductions']);
    double netPayable = _parseDouble(bill['netPayable']);

    double teaRate = _parseDouble(bill['teaRate']);
    double teaRate2 = _parseDouble(bill['teaRate2']);
    double totalWeight = _parseDouble(bill['totalWeight']);
    double totalWeight2 = _parseDouble(bill['totalWeight2']);

    // Fallback if older bills don't have totalWeight stored
    if (totalWeight == 0 && totalWeight2 == 0 && teaRate > 0) {
      totalWeight = grossIncome / teaRate;
    }

    double advTotal = _parseDouble(bill['advTotal']);
    double f1Total = _parseDouble(bill['f1Total']);
    double f2Total = _parseDouble(bill['f2Total']);
    double t1Total = _parseDouble(bill['t1Total']);
    double t2Total = _parseDouble(bill['t2Total']);
    double transportCost = _parseDouble(bill['transportCost']);
    double arrears = _parseDouble(bill['arrears']);

    String displayMonth = bill['displayMonth'] ?? '';

    String msg =
        "ආයුබෝවන් *${widget.customerName}*,\n\n"
        "ඔබගේ $displayMonth මාසයේ බිල්පත:\n\n";

    if (totalWeight > 0 || totalWeight2 == 0) {
      msg += "සාමාන්‍ය දළු: *${totalWeight % 1 == 0 ? totalWeight.toInt() : totalWeight.toStringAsFixed(1)} kg*\n"
             "සාමාන්‍ය දළු මිල: *Rs ${currencyF.format(teaRate)}*\n";
    }
    if (totalWeight2 > 0) {
      msg += "සුපිරි දළු: *${totalWeight2 % 1 == 0 ? totalWeight2.toInt() : totalWeight2.toStringAsFixed(1)} kg*\n"
             "සුපිරි දළු මිල: *Rs ${currencyF.format(teaRate2)}*\n";
    }

    msg += "\nමුළු දළු ආදායම: *Rs ${currencyF.format(grossIncome)}*\n\n";

    if (totalDeductions > 0) {
      msg += "අඩුකිරීම්:\n";
      if (advTotal > 0)
        msg += "• අත්තිකාරම්: *Rs ${currencyF.format(advTotal)}*\n";
      if (f1Total > 0) msg += "• පොහොර 01: *Rs ${currencyF.format(f1Total)}*\n";
      if (f2Total > 0) msg += "• පොහොර 02: *Rs ${currencyF.format(f2Total)}*\n";
      if (t1Total > 0)
        msg += "• තේ කොළ 01: *Rs ${currencyF.format(t1Total)}*\n";
      if (t2Total > 0)
        msg += "• තේ කොළ 02: *Rs ${currencyF.format(t2Total)}*\n";
      if (transportCost > 0)
        msg += "• ප්‍රවාහනය: *Rs ${currencyF.format(transportCost)}*\n";
      if (arrears > 0)
        msg += "• හිඟ මුදල්: *Rs ${currencyF.format(arrears)}*\n";
      msg += "\nමුළු අඩුකිරීම්: *Rs ${currencyF.format(totalDeductions)}*\n\n";
    }

    List<String> companyLines = [
      _companyLine1,
      _companyLine2,
      _companyLine3,
      _companyLine4,
      _companyLine5,
    ];
    String companySignature = companyLines
        .where((l) => l.trim().isNotEmpty)
        .join('\n');

    msg +=
        "ලබා දිය යුතු මුදල: *Rs ${currencyF.format(netPayable)}*\n\n"
        "ස්තූතියි!\n$companySignature\n"
        "_powered by OrbitView Innovations_";

    return msg;
  }

  void _sendIndividualWhatsApp(Map<String, dynamic> billWrapper) {
    if (_customerPhone.isEmpty || _customerPhone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Customer phone number is invalid or missing.'),
        ),
      );
      return;
    }

    String msg = _buildWhatsAppMessage(billWrapper);

    List<Map<String, String>> billsToSend = [
      {'id': widget.customerId, 'phone': _customerPhone, 'message': msg},
    ];

    WhatsAppBatchDialog.show(context, billsToSend);
  }
}
