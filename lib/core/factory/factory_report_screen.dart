import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../app_state.dart';
import '../widgets/skeleton_box.dart';
import '../widgets/max_number_input_formatter.dart';
import 'factory_ledger_screen.dart';
import '../localization/app_strings.dart';

class MonthlyFactoryData {
  String displayMonthStr;
  String monthKey;
  double totalNormalLeaf = 0.0;
  double totalSuperLeaf = 0.0;
  double totalAdvance = 0.0;
  Map<String, double> itemQuantities = {};
  
  Map<int, double> dailyWeightsN = {};
  Map<int, double> dailyWeightsS = {};
  Map<int, double> dailyAdvances = {};
  double? normalRate;
  double? superRate;

  bool isFinalized = false;
  double previousArrears = 0.0;
  double receivedAmount = 0.0;
  double forwardArrears = 0.0;
  double finalizedGrossIncome = 0.0;
  double finalizedTotalDeductions = 0.0;
  double finalizedNetPayable = 0.0;

  MonthlyFactoryData({required this.displayMonthStr, required this.monthKey});

  Map<String, dynamic> toJson() {
    return {
      'totalNormalLeaf': totalNormalLeaf,
      'totalSuperLeaf': totalSuperLeaf,
      'totalAdvance': totalAdvance,
      'itemQuantities': itemQuantities,
      
      'dailyWeightsN': dailyWeightsN.map((k, v) => MapEntry(k.toString(), v)),
      'dailyWeightsS': dailyWeightsS.map((k, v) => MapEntry(k.toString(), v)),
      'dailyAdvances': dailyAdvances.map((k, v) => MapEntry(k.toString(), v)),
      'normalRate': normalRate,
      'superRate': superRate,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    totalNormalLeaf = (json['totalNormalLeaf'] as num?)?.toDouble() ?? 0.0;
    totalSuperLeaf = (json['totalSuperLeaf'] as num?)?.toDouble() ?? 0.0;
    totalAdvance = (json['totalAdvance'] as num?)?.toDouble() ?? 0.0;
    
    if (json['itemQuantities'] != null) {
      (json['itemQuantities'] as Map).forEach((k, v) => itemQuantities[k.toString()] = (v as num).toDouble());
    }
    
    if (json['dailyWeightsN'] != null) {
      (json['dailyWeightsN'] as Map).forEach((k, v) => dailyWeightsN[int.parse(k.toString())] = (v as num).toDouble());
    }
    if (json['dailyWeightsS'] != null) {
      (json['dailyWeightsS'] as Map).forEach((k, v) => dailyWeightsS[int.parse(k.toString())] = (v as num).toDouble());
    }
    if (json['dailyAdvances'] != null) {
      (json['dailyAdvances'] as Map).forEach((k, v) => dailyAdvances[int.parse(k.toString())] = (v as num).toDouble());
    }
    normalRate = (json['normalRate'] as num?)?.toDouble();
    superRate = (json['superRate'] as num?)?.toDouble();
  }
}

class FactoryReportScreen extends StatefulWidget {
  final String factoryId;
  final String factoryName;

  const FactoryReportScreen({
    super.key,
    required this.factoryId,
    required this.factoryName,
  });

  @override
  State<FactoryReportScreen> createState() => _FactoryReportScreenState();
}

class _FactoryReportScreenState extends State<FactoryReportScreen> {
  bool _isLoading = true;
  String _refNumber = '';
  List<MonthlyFactoryData> _reports = [];
  final Map<String, double> _itemPrices = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final orgId = AppState.currentOrganizationId.value ?? '';

      // 1. Fetch factory settings for prices
      final factoryRes = await Supabase.instance.client
          .from('factories')
          .select()
          .eq('organization_id', orgId)
          .eq('id', widget.factoryId)
          .maybeSingle();

      if (factoryRes != null) {
        _refNumber = factoryRes['refNumber']?.toString() ?? '';
        _itemPrices.clear();
        List<dynamic> itemsList = [];
        if (factoryRes['items'] != null && (factoryRes['items'] as List).isNotEmpty) {
          itemsList = factoryRes['items'];
        } else {
          if (factoryRes['fertilizers'] != null) {
            itemsList.addAll(factoryRes['fertilizers'] as List);
          }
          if (factoryRes['tea_packets'] != null) {
            itemsList.addAll(factoryRes['tea_packets'] as List);
          }
        }
        for (var item in itemsList) {
          _itemPrices[item['name'].toString()] = double.tryParse(item['price'].toString()) ?? 0.0;
        }
      }

      // 2. Fetch monthly rates
      final rateRes = await Supabase.instance.client
          .from('factory_monthly_rates')
          .select('month, normalRate, superRate')
          .eq('organization_id', orgId)
          .eq('factoryId', widget.factoryId);
          
      Map<String, Map<String, dynamic>> ratesByMonth = {};
      for (var r in rateRes) {
        ratesByMonth[r['month'].toString()] = r;
      }

      // 3. Fetch finalized bills
      final finalizedRes = await Supabase.instance.client
          .from('factory_finalized_bills')
          .select()
          .eq('organization_id', orgId)
          .eq('factoryId', widget.factoryId);
          
      Map<String, Map<String, dynamic>> finalizedByMonth = {};
      for (var row in finalizedRes) {
        finalizedByMonth[row['month'].toString()] = row;
      }

      // 4. Fetch entries for the factory
      final entriesRes = await Supabase.instance.client
          .from('factory_entries')
          .select()
          .eq('organization_id', orgId)
          .eq('factoryId', widget.factoryId)
          .order('date', ascending: false);

      Map<String, MonthlyFactoryData> groupedData = {};

      for (var entry in entriesRes) {
        if (entry['date'] == null) continue;
        String dateStr = entry['date'].toString();
        if (dateStr.length < 7) continue;
        
        String monthKey = dateStr.substring(0, 7);
        
        if (!groupedData.containsKey(monthKey)) {
          DateTime dt = DateTime.parse('$monthKey-01');
          String display = DateFormat('yyyy MMMM').format(dt);
          groupedData[monthKey] = MonthlyFactoryData(displayMonthStr: display, monthKey: monthKey);
          
          if (ratesByMonth.containsKey(monthKey)) {
            groupedData[monthKey]!.normalRate = (ratesByMonth[monthKey]!['normalRate'] as num?)?.toDouble() ?? 0.0;
            groupedData[monthKey]!.superRate = (ratesByMonth[monthKey]!['superRate'] as num?)?.toDouble() ?? 0.0;
          }
        }
        
        var data = groupedData[monthKey]!;
        
        double nWeight = (entry['netWeight'] as num?)?.toDouble() ?? 0.0;
        double sWeight = (entry['netWeight2'] as num?)?.toDouble() ?? 0.0;
        double adv = (entry['advanceAmount'] as num?)?.toDouble() ?? 0.0;
        
        data.totalNormalLeaf += nWeight;
        data.totalSuperLeaf += sWeight;
        data.totalAdvance += adv;

        try {
          DateTime dt = DateTime.parse(dateStr);
          int day = dt.day;
          if (nWeight > 0 || sWeight > 0) {
            data.dailyWeightsN[day] = (data.dailyWeightsN[day] ?? 0.0) + nWeight;
            data.dailyWeightsS[day] = (data.dailyWeightsS[day] ?? 0.0) + sWeight;
          }
          if (adv > 0) {
            data.dailyAdvances[day] = (data.dailyAdvances[day] ?? 0.0) + adv;
          }
        } catch(e) {
          // ignore parse errors
        }

        if (entry['dynamic_items'] != null) {
          Map<String, dynamic> dynItems = Map<String, dynamic>.from(entry['dynamic_items']);
          dynItems.forEach((k, v) {
            data.itemQuantities[k] = (data.itemQuantities[k] ?? 0.0) + ((v as num).toDouble());
          });
        }
        if (entry['dynamic_fertilizers'] != null) {
          Map<String, dynamic> dynFerts = Map<String, dynamic>.from(entry['dynamic_fertilizers']);
          dynFerts.forEach((k, v) {
            data.itemQuantities[k] = (data.itemQuantities[k] ?? 0.0) + ((v as num).toDouble());
          });
        }
        if (entry['dynamic_tea_packets'] != null) {
          Map<String, dynamic> dynTeas = Map<String, dynamic>.from(entry['dynamic_tea_packets']);
          dynTeas.forEach((k, v) {
            data.itemQuantities[k] = (data.itemQuantities[k] ?? 0.0) + ((v as num).toDouble());
          });
        }
      }

      // Apply finalized data
      finalizedByMonth.forEach((monthKey, row) {
        if (!groupedData.containsKey(monthKey)) {
          DateTime dt = DateTime.parse('$monthKey-01');
          String display = DateFormat('yyyy MMMM').format(dt);
          groupedData[monthKey] = MonthlyFactoryData(displayMonthStr: display, monthKey: monthKey);
        }
        var data = groupedData[monthKey]!;
        data.isFinalized = true;
        data.finalizedGrossIncome = (row['grossIncome'] as num).toDouble();
        data.finalizedTotalDeductions = (row['totalDeductions'] as num).toDouble();
        data.previousArrears = (row['previousArrears'] as num).toDouble();
        data.finalizedNetPayable = (row['netPayable'] as num).toDouble();
        data.receivedAmount = (row['receivedAmount'] as num).toDouble();
        data.forwardArrears = (row['forwardArrears'] as num).toDouble();
        if (row['billData'] != null) {
          data.fromJson(row['billData'] as Map<String, dynamic>);
        }
      });

      var sortedList = groupedData.values.toList();
      sortedList.sort((a, b) => a.monthKey.compareTo(b.monthKey));

      double carryForward = 0.0;
      for (var data in sortedList) {
        if (!data.isFinalized) {
          data.previousArrears = carryForward;
        } else {
          carryForward = data.forwardArrears;
        }
      }

      sortedList.sort((a, b) => b.monthKey.compareTo(a.monthKey));
      _reports = sortedList;
    } catch (e) {
      debugPrint('Error fetching report data: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generatePDF(MonthlyFactoryData data, double netIncome, double totalLeafIncome, double totalFertCost, double totalTeaCost, double totalDeduction) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('FACTORY BILL', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Factory Name: ${widget.factoryName}', style: pw.TextStyle(fontSize: 14)),
                      pw.Text('Month: ${data.displayMonthStr}', style: pw.TextStyle(fontSize: 14)),
                    ]
                  ),
                ]
              ),
              pw.SizedBox(height: 20),
              
              pw.Text('INCOME', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Normal Leaf (${data.totalNormalLeaf.toStringAsFixed(1)} Kg @ Rs.${data.normalRate ?? 0})'), pw.Text('Rs. ${(data.totalNormalLeaf * (data.normalRate ?? 0)).toStringAsFixed(2)}')]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Super Leaf (${data.totalSuperLeaf.toStringAsFixed(1)} Kg @ Rs.${data.superRate ?? 0})'), pw.Text('Rs. ${(data.totalSuperLeaf * (data.superRate ?? 0)).toStringAsFixed(2)}')]),
              pw.Divider(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('GROSS INCOME', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('Rs. ${totalLeafIncome.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
              
              pw.SizedBox(height: 20),
              pw.Text('DEDUCTIONS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Advances (Total)'), pw.Text('Rs. ${data.totalAdvance.toStringAsFixed(2)}')]),
              pw.Wrap(
                spacing: 10,
                runSpacing: 5,
                children: data.dailyAdvances.entries.map((e) {
                  return pw.Text('D${e.key.toString().padLeft(2, '0')}: Rs.${e.value.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 10));
                }).toList(),
              ),
              pw.SizedBox(height: 5),
              ...data.itemQuantities.entries.map((e) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('${e.key} (${e.value.toStringAsFixed(2)} @ Rs.${_itemPrices[e.key] ?? 0})'), pw.Text('Rs. ${(e.value * (_itemPrices[e.key] ?? 0)).toStringAsFixed(2)}')])),
              pw.Divider(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('TOTAL DEDUCTIONS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('Rs. ${totalDeduction.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
              if (data.previousArrears != 0) pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('PREVIOUS ARREARS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text((data.previousArrears > 0 ? '+' : '') + data.previousArrears.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
              pw.SizedBox(height: 30),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('NET RECEIVABLE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)), pw.Text('Rs. ${netIncome.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))]),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  void _showReceivedDialog(MonthlyFactoryData data, double grossIncome, double totalDeductions, double netPayable) {
    TextEditingController controller = TextEditingController(text: netPayable.toStringAsFixed(2));
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppStrings.finalize),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${AppStrings.netReceivable}: Rs. ${netPayable.toStringAsFixed(2)}'),
              Text('${AppStrings.previousArrears}: Rs. ${data.previousArrears.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              Text(AppStrings.enterReceivedAmount),
              TextField(
                controller: controller,
                inputFormatters: [MaxNumberInputFormatter.currency],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixText: 'Rs. ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(AppStrings.cancel)),
            ElevatedButton(
              onPressed: () async {
                double received = double.tryParse(controller.text) ?? 0.0;
                double forward = netPayable - received;
                
                Navigator.pop(dialogContext);
                setState(() => _isLoading = true);
                
                try {
                  await Supabase.instance.client.from('factory_finalized_bills').insert({
                    'organization_id': AppState.currentOrganizationId.value,
                    'factoryId': widget.factoryId,
                    'month': data.monthKey,
                    'grossIncome': grossIncome,
                    'totalDeductions': totalDeductions,
                    'previousArrears': data.previousArrears,
                    'netPayable': netPayable,
                    'receivedAmount': received,
                    'forwardArrears': forward,
                    'billData': data.toJson(),
                  });
                  await _fetchData();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.finalizedSuccess)));
                } catch(e) {
                  setState(() => _isLoading = false);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppStrings.errorPrefix}$e')));
                }
              },
              child: Text(AppStrings.saveAndFinalize),
            ),
          ],
        );
      }
    );
  }

  Widget _buildDailyGrid(MonthlyFactoryData data) {
    List<Widget> rows = [];
    
    List<Widget> headerRow = [];
    for (int i = 0; i < 8; i++) {
      headerRow.add(Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)), padding: const EdgeInsets.symmetric(vertical: 4), child: Center(child: Text(AppStrings.days, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))))));
      headerRow.add(Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)), padding: const EdgeInsets.symmetric(vertical: 4), child: const Center(child: Text('Kg', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))))));
    }
    rows.add(Row(children: headerRow));

    int currentDay = 1;
    for (int row = 0; row < 4; row++) {
      List<Widget> daysRow = [];
      for (int col = 0; col < 8; col++) {
        if (currentDay <= 31) {
          daysRow.add(Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)), padding: const EdgeInsets.symmetric(vertical: 4), child: Center(child: Text('$currentDay', style: const TextStyle(fontSize: 10))))));
          
          double n = data.dailyWeightsN[currentDay] ?? 0.0;
          double s = data.dailyWeightsS[currentDay] ?? 0.0;
          String valStr = '-';
          if (n > 0 && s > 0) {
            valStr = '${n.toStringAsFixed(0)}/${s.toStringAsFixed(0)}';
          } else if (n > 0) {
            valStr = n.toStringAsFixed(0);
          } else if (s > 0) {
            valStr = '0/${s.toStringAsFixed(0)}';
          }
          
          daysRow.add(Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)), padding: const EdgeInsets.symmetric(vertical: 4), child: Center(child: Text(valStr, style: const TextStyle(fontSize: 10))))));
          currentDay++;
        } else if (currentDay == 32) {
          daysRow.add(Expanded(child: Container(decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.grey.shade400)), padding: const EdgeInsets.symmetric(vertical: 4), child: Center(child: Text(AppStrings.total, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))))));
          daysRow.add(Expanded(child: Container(decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.grey.shade400)), padding: const EdgeInsets.symmetric(vertical: 4), child: Center(child: Text('${(data.totalNormalLeaf + data.totalSuperLeaf).toStringAsFixed(0)} Kg', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))))));
          currentDay++;
        } else {
          daysRow.add(Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)))));
          daysRow.add(Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)))));
        }
      }
      rows.add(Row(children: daysRow));
    }

    return Column(children: rows);
  }

  Widget _buildSummaryRow(String label, String middle, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(flex: 3, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
          if (middle.isNotEmpty) Expanded(flex: 2, child: Text(middle, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
          Expanded(flex: 3, child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
    );
  }

  Widget _buildReportCard(MonthlyFactoryData data) {
    bool hasMissingRates = (data.normalRate == null || data.normalRate == 0) && (data.superRate == null || data.superRate == 0);
    bool hasNoData = data.totalNormalLeaf == 0 && data.totalSuperLeaf == 0 && data.itemQuantities.isEmpty && data.totalAdvance == 0 && !data.isFinalized;
    bool rateNotSet = hasMissingRates && (data.totalNormalLeaf > 0 || data.totalSuperLeaf > 0) && !data.isFinalized;
    
    double totalLeafIncome = data.isFinalized ? data.finalizedGrossIncome : (data.totalNormalLeaf * (data.normalRate ?? 0)) + (data.totalSuperLeaf * (data.superRate ?? 0));

    double totalFertCost = 0.0;
    data.itemQuantities.forEach((name, qty) {
      double price = _itemPrices[name] ?? 0.0;
      totalFertCost += (qty * price);
    });
    double totalTeaCost = 0.0;

    double calculatedDeduction = totalFertCost + totalTeaCost + data.totalAdvance;
    double totalDeduction = data.isFinalized ? data.finalizedTotalDeductions : calculatedDeduction;
    double netIncome = data.isFinalized ? data.finalizedNetPayable : (totalLeafIncome - totalDeduction + data.previousArrears);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        title: Text(data.displayMonthStr, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: hasNoData
            ? Text(AppStrings.noDataFound, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
            : rateNotSet
                ? Text(AppStrings.ratesNotSetPrompt, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                : Text('${AppStrings.netReceivable}: Rs. ${netIncome.toStringAsFixed(2)}', style: TextStyle(color: netIncome >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasNoData)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey.shade600),
                        const SizedBox(width: 12),
                        Text(
                          AppStrings.noFactoryDataForMonth,
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else if (rateNotSet)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.ratesNotSetPrompt,
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppStrings.isSinhala
                                    ? 'දළු බර: ${(data.totalNormalLeaf + data.totalSuperLeaf).toStringAsFixed(1)} Kg ක් ඇත. ගණනය කිරීම් සහ වාර්තාව දැකීමට කරුණාකර පළමුව මිල ඇතුලත් කරන්න.'
                                    : 'Leaf weight: ${(data.totalNormalLeaf + data.totalSuperLeaf).toStringAsFixed(1)} Kg. Please enter rates first to view calculations and reports.',
                                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FactoryLedgerScreen(
                                  factoryId: widget.factoryId,
                                  factoryName: widget.factoryName,
                                  refNumber: _refNumber,
                                ),
                              ),
                            ).then((_) {
                              if (!mounted) return;
                              setState(() => _isLoading = true);
                              _fetchData();
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(AppStrings.enterRates),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.factoryName.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                      Row(
                        children: [
                          if (!data.isFinalized)
                            ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(AppStrings.finalize),
                            onPressed: (hasMissingRates && (data.totalNormalLeaf > 0 || data.totalSuperLeaf > 0)) 
                                ? null 
                                : () => _showReceivedDialog(data, totalLeafIncome, totalDeduction, netIncome),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green, 
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade400,
                              disabledForegroundColor: Colors.grey.shade200,
                            ),
                          )
                        else
                          Chip(
                            label: Text(AppStrings.finalized, style: const TextStyle(color: Colors.white)),
                            backgroundColor: Colors.green,
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.print, color: Colors.blue),
                          tooltip: 'Print Bill',
                          onPressed: () => _generatePDF(data, netIncome, totalLeafIncome, totalFertCost, totalTeaCost, totalDeduction),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                _buildDailyGrid(data),
                const SizedBox(height: 24),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppStrings.deductions, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                          const SizedBox(height: 8),
                          Text('${AppStrings.advance} (${AppStrings.total}: Rs.${data.totalAdvance.toStringAsFixed(2)})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: data.dailyAdvances.entries.map((e) {
                              String dayStr = e.key.toString().padLeft(2, '0');
                              return SizedBox(
                                width: 90,
                                child: Text('D$dayStr: Rs.${e.value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          ...data.itemQuantities.entries.map((e) => Text('${e.key} (${e.value.toStringAsFixed(2)}) : Rs.${(e.value * (_itemPrices[e.key] ?? 0)).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.black87))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: Container(
                        decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryRow(AppStrings.normalLeaf, '${data.totalNormalLeaf.toStringAsFixed(0)} Kg', 'Rs. ${data.normalRate?.toStringAsFixed(2) ?? '0.00'}'),
                            _buildSummaryRow(AppStrings.superLeaf, '${data.totalSuperLeaf.toStringAsFixed(0)} Kg', 'Rs. ${data.superRate?.toStringAsFixed(2) ?? '0.00'}'),
                            const Divider(color: Colors.black, thickness: 1),
                            _buildSummaryRow(AppStrings.grossIncome, '', 'Rs. ${totalLeafIncome.toStringAsFixed(2)}'),
                            _buildSummaryRow(AppStrings.totalAdvance, '', '-${data.totalAdvance.toStringAsFixed(2)}'),
                            _buildSummaryRow(AppStrings.otherDeductions, '', '-${(totalFertCost + totalTeaCost).toStringAsFixed(2)}'),
                            const Divider(color: Colors.black, thickness: 1),
                            _buildSummaryRow(AppStrings.totalDeductions, '', '-${totalDeduction.toStringAsFixed(2)}'),
                            if (data.previousArrears != 0) const Divider(color: Colors.black, thickness: 1),
                            if (data.previousArrears != 0) _buildSummaryRow(AppStrings.previousArrears, '', (data.previousArrears > 0 ? '+' : '') + data.previousArrears.toStringAsFixed(2)),
                            const Divider(color: Colors.black, thickness: 1),
                            _buildSummaryRow(AppStrings.netReceivable, '', 'Rs. ${netIncome.toStringAsFixed(2)}', isBold: true),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonReportList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 2,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.only(bottom: 24),
        elevation: 3,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  SkeletonBox(width: 140, height: 28, borderRadius: 6),
                  SkeletonBox(width: 110, height: 28, borderRadius: 6),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  SkeletonBox(width: 160, height: 20, borderRadius: 4),
                  SkeletonBox(width: 120, height: 36, borderRadius: 8),
                ],
              ),
              const SizedBox(height: 16),
              const SkeletonBox(width: double.infinity, height: 120, borderRadius: 8),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Expanded(
                    flex: 3,
                    child: SkeletonBox(width: double.infinity, height: 100, borderRadius: 8),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: SkeletonBox(width: double.infinity, height: 100, borderRadius: 8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(AppStrings.factoryReport),
        backgroundColor: const Color(0xFF06B6D4),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? _buildSkeletonReportList()
          : _reports.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_off_outlined, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.noDataFound,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reports.length,
                  itemBuilder: (context, index) => _buildReportCard(_reports[index]),
                ),
    );
  }
}
