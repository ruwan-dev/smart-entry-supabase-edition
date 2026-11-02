import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../widgets/skeleton_box.dart';
import 'package:smart_entry/features/reports/widgets/whatsapp_batch_dialog.dart';

import 'bill_pdf_service.dart';
import 'package:smart_entry/core/app_state.dart';
import 'package:smart_entry/core/items/item_service.dart';
import 'package:smart_entry/core/localization/app_strings.dart';
import 'package:smart_entry/core/localization/app_language.dart';
import '../../services/billing_lock_service.dart';

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
  bool? _latestBillHasChanges;

  String _customerPhone = '';
  String _orgName = '';
  String _companyLine1 = 'Authorized Green Dealer';
  String _companyLine2 = 'Gangoda';
  String _companyLine3 = 'Rakwana';
  String _companyLine4 = '';
  String _contactNumbers = 'Tel: 0713444934 / 0758258544';
  double _pageWidth = 21.07;
  double _pageHeight = 13.08;

  String get _addressText => [
        _companyLine1,
        _companyLine2,
        _companyLine3,
        _companyLine4,
      ].where((l) => l.trim().isNotEmpty).join(', ');

  final Map<String, String> _activeVersionTab = {};
  int _lastHandledRefresh = 0;

  @override
  void initState() {
    super.initState();
    AppLanguageService.currentLanguage.addListener(_onLanguageChanged);
    AppState.refreshTrigger.addListener(_onRefreshTriggered);
    _loadAllData();
  }

  @override
  void dispose() {
    AppLanguageService.currentLanguage.removeListener(_onLanguageChanged);
    AppState.refreshTrigger.removeListener(_onRefreshTriggered);
    super.dispose();
  }

  void _onRefreshTriggered() {
    if (!mounted) return;
    if (AppState.refreshTrigger.value != _lastHandledRefresh) {
      _lastHandledRefresh = AppState.refreshTrigger.value;
      _loadAllData();
    }
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _loadAllData() async {
    await BillingLockService().fetchLatestFinalizedMonth();
    setState(() => _isLoading = true);
    try {
      var customerSnap = await Supabase.instance.client
          .from('customers')
          .select('phone').eq('organization_id', AppState.currentOrganizationId.value ?? '')
          .eq('id', widget.customerId)
          .maybeSingle();
      if (customerSnap != null) {
        _customerPhone = customerSnap['phone']?.toString() ?? '';
      }

      final orgRes = await Supabase.instance.client
          .from('organizations')
          .select('name, company_line_1, company_line_2, company_line_3, company_line_4, company_line_5')
          .eq('id', AppState.currentOrganizationId.value ?? '')
          .maybeSingle();
      if (orgRes != null) {
        _orgName = (orgRes['name'] ?? '').toString().trim();
        _companyLine1 = (orgRes['company_line_1'] ?? '').toString().trim();
        _companyLine2 = (orgRes['company_line_2'] ?? '').toString().trim();
        _companyLine3 = (orgRes['company_line_3'] ?? '').toString().trim();
        _companyLine4 = (orgRes['company_line_4'] ?? '').toString().trim();

        String rawLine5 = (orgRes['company_line_5'] ?? '').toString().trim();
        if (rawLine5.startsWith('{')) {
          try {
            final map = jsonDecode(rawLine5) as Map<String, dynamic>;
            _contactNumbers = (map['contact'] ?? '').toString().trim();
            _pageWidth = (map['width'] as num?)?.toDouble() ?? 21.07;
            _pageHeight = (map['height'] as num?)?.toDouble() ?? 13.08;
          } catch (_) {}
        } else {
          if (rawLine5.toLowerCase().contains('tel') || rawLine5.toLowerCase().contains('07')) {
            _contactNumbers = rawLine5;
          }
          final match = RegExp(r'(\d+\.?\d*)\s*[xX*×]\s*(\d+\.?\d*)').firstMatch(rawLine5);
          if (match != null) {
            _pageWidth = double.tryParse(match.group(1)!) ?? 21.07;
            _pageHeight = double.tryParse(match.group(2)!) ?? 13.08;
          }
        }
      } else {
        _orgName = '';
        _companyLine1 = '';
        _companyLine2 = '';
        _companyLine3 = '';
        _companyLine4 = '';
        _contactNumbers = '';
      }

      // 1. Get all finalized bills for this customer directly from Supabase
      var billsSnap = await Supabase.instance.client
          .from('finalized_bills')
          .select('id, billData, finalizedAt').eq('organization_id', AppState.currentOrganizationId.value ?? '')
          .eq('customerId', widget.customerId)
          .order('finalizedAt', ascending: false);

      List<Map<String, dynamic>> finalizedBillsList = [];

      for (var doc in billsSnap) {
        var b = doc['billData'];
        if (b != null) {
          List<Map<String, dynamic>> history = [];
          if (b['revisionHistory'] is List) {
            history = (b['revisionHistory'] as List)
                .map((e) {
              final map = Map<String, dynamic>.from(e as Map);
              if (map['snapshot'] != null) {
                map['snapshot'] = _cleanBillSnapshot(map['snapshot']);
              }
              return map;
            })
                .toList();
          } else if (b['originalBillData'] != null) {
            history.add({
              'revNumber': 1,
              'tag': 'Original Finalized Bill',
              'timestamp': doc['finalizedAt']?.toString() ?? '',
              'reason': 'Initial Month-end Closing',
              'netPayable': _parseDouble(b['originalBillData']['netPayable']),
              'snapshot': b['originalBillData'],
            });
          }

          int curRev = 1;
          if (b['currentRevision'] is num) {
            curRev = (b['currentRevision'] as num).toInt();
          } else if (history.isNotEmpty) {
            curRev = history.length + 1;
          }

          finalizedBillsList.add({
            'id': doc['id'],
            'displayMonth': b['displayMonth'] ?? '',
            'teaRate': _parseDouble(b['teaRate']),
            'teaRate2': _parseDouble(b['teaRate2']),
            'grossIncome': _parseDouble(b['grossIncome']),
            'totalDeductions': _parseDouble(b['totalDeductions']),
            'previousArrears': _parseDouble(b['arrears'] ?? b['previousArrears']),
            'netPayable': _parseDouble(b['netPayable']),
            'tableRows': b['tableRows'] ?? [],
            'transportCost': _parseDouble(b['transportCost']),
            'otherCosts': _parseDouble(b['otherCosts']),
            'isRevised': b['isRevised'] == true,
            'currentRevision': curRev,
            'revisedAt': b['revisedAt'] ?? '',
            'revisionReason': b['revisionReason'] ?? '',
            'revisedBy': b['revisedBy'] ?? '',
            'originalBillData': b['originalBillData'],
            'revisionHistory': history,
            'finalizedAt': doc['finalizedAt'],
            'billData': b,
          });
        }
      }

      // Sort bills chronologically descending so index 0 is always the latest bill
      finalizedBillsList.sort((a, b) {
        int keyA = _billSortKey(a);
        int keyB = _billSortKey(b);
        return keyB.compareTo(keyA);
      });

      bool hasChanges = false;
      if (finalizedBillsList.isNotEmpty) {
        try {
          final diff = await _computeBillDifferences(finalizedBillsList.first);
          hasChanges = diff?.hasChanges ?? false;
        } catch (e) {
          debugPrint('Error checking latest bill for changes: $e');
        }
      }

      if (mounted) {
        setState(() {
          _monthlyBills = finalizedBillsList;
          _latestBillHasChanges = hasChanges;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _cleanBillSnapshot(dynamic raw) {
    if (raw is! Map) return {};
    final clean = Map<String, dynamic>.from(raw);
    clean.remove('revisionHistory');
    clean.remove('originalBillData');
    return clean;
  }

  int _billSortKey(Map<String, dynamic> billWrapper) {
    String dm = billWrapper['displayMonth'] ?? billWrapper['billData']?['displayMonth'] ?? '';
    final parts = dm.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      int y = int.tryParse(parts[0]) ?? 0;
      const monthNames = [
        'january', 'february', 'march', 'april', 'may', 'june',
        'july', 'august', 'september', 'october', 'november', 'december'
      ];
      int m = monthNames.indexOf(parts[1].toLowerCase()) + 1;
      return y * 100 + m;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(title: Text(AppStrings.monthlyBillReport)),
      body: _isLoading
          ? _buildSkeleton()
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _monthlyBills.length,
              itemBuilder: (context, index) =>
                  _buildInvoiceCard(_monthlyBills[index], isLatest: index == 0),
            ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> billWrapper, {bool isLatest = false}) {
    final bool isActuallyLatest = isLatest && BillingLockService().isLatestFinalizedMonth(billWrapper['displayMonth']?.toString());
    String billId = billWrapper['id']?.toString() ?? '';
    List<Map<String, dynamic>> history = (billWrapper['revisionHistory'] as List? ?? []).cast<Map<String, dynamic>>();
    bool hasRevision = billWrapper['isRevised'] == true || history.isNotEmpty || billWrapper['originalBillData'] != null;

    int activeRevNum = (billWrapper['currentRevision'] is num)
        ? (billWrapper['currentRevision'] as num).toInt()
        : (history.length + 1);

    String currentVersionKey = _activeVersionTab[billId] ?? 'active';

    // Locate the selected history entry if not 'active'
    Map<String, dynamic>? selectedHistoryItem;
    if (currentVersionKey.startsWith('rev_')) {
      int revIdx = int.tryParse(currentVersionKey.replaceFirst('rev_', '')) ?? -1;
      for (var h in history) {
        if (h['revNumber'] == revIdx) {
          selectedHistoryItem = h;
          break;
        }
      }
    } else if (currentVersionKey == 'previous' && history.isNotEmpty) {
      selectedHistoryItem = history.last;
    }

    bool isViewingHistory = selectedHistoryItem != null && currentVersionKey != 'active';

    // Select which bill payload to display (active revised vs historical revision snapshot)
    Map<String, dynamic> bill = isViewingHistory
        ? Map<String, dynamic>.from(selectedHistoryItem['snapshot'] ?? selectedHistoryItem)
        : (billWrapper['billData'] is Map
            ? Map<String, dynamic>.from(billWrapper['billData'])
            : billWrapper);

    // Calculate totals and extract days
    Map<int, double> weightByDay = {};
    Map<int, double> weight2ByDay = {};
    Map<int, double> advanceByDay = {};
    Map<int, double> f1ByDay = {};
    Map<int, double> f2ByDay = {};
    Map<int, double> t1ByDay = {};
    Map<int, double> t2ByDay = {};
    double totalAdvance = 0;
    double totalWeight = 0;
    double totalWeight2 = 0;

    for (var row in (bill['tableRows'] as List? ?? [])) {
      String dateStr = row['date'] ?? '';
      if (dateStr.isEmpty) continue;

      int day = int.tryParse(dateStr.split('-').last) ?? 0;
      if (day == 0) continue;

      double weight = _parseDouble(row['weight']);
      double weight2 = _parseDouble(row['weight2']);
      
      weightByDay[day] = weight;
      weight2ByDay[day] = weight2;
      
      if (weight > 0) totalWeight += weight;
      if (weight2 > 0) totalWeight2 += weight2;

      // Extract advance & items by day
      List<dynamic> deductions = row['deductions'] ?? row['items'] ?? [];
      for (var item in deductions) {
        String desc = (item['desc'] ?? '').toString().toLowerCase();
        double amt = _parseDouble(item['amt']);
        double qty = _parseDouble(item['qty']);
        if (desc.contains('advance') || desc.contains('අත්තිකාරම්')) {
          if (amt > 0) {
            totalAdvance += amt;
            advanceByDay[day] = (advanceByDay[day] ?? 0) + amt;
          }
        } else if (desc.contains('fert 01') || desc.contains('fertilizer 1') || desc.contains('fmdfydr 01') || desc.contains('පොහොර 1')) {
          if (qty > 0) f1ByDay[day] = (f1ByDay[day] ?? 0) + qty;
        } else if (desc.contains('fert 02') || desc.contains('fertilizer 2') || desc.contains('fmdfydr 02') || desc.contains('පොහොර 2')) {
          if (qty > 0) f2ByDay[day] = (f2ByDay[day] ?? 0) + qty;
        } else if (desc.contains('tea pkt 01') || desc.contains('tea packet 1') || desc.contains('f;a fld< 01') || desc.contains('තේ පැකට් 1') || desc.contains('තේ කොළ 1')) {
          if (qty > 0) t1ByDay[day] = (t1ByDay[day] ?? 0) + qty;
        } else if (desc.contains('tea pkt 02') || desc.contains('tea packet 2') || desc.contains('f;a fld< 02') || desc.contains('තේ පැකට් 2') || desc.contains('තේ කොළ 2')) {
          if (qty > 0) t2ByDay[day] = (t2ByDay[day] ?? 0) + qty;
        }
      }
    }

    final billItems = _extractBillItems(bill);
    double f1Total = billItems['f1Total']!;
    double f2Total = billItems['f2Total']!;
    double t1Total = billItems['t1Total']!;
    double t2Total = billItems['t2Total']!;
    double otherCosts = _parseDouble(bill['otherCosts']);
    double arrears = _parseDouble(bill['arrears'] ?? bill['previousArrears']);

    bool isMobile = MediaQuery.of(context).size.width < 600;
    int colsCount = isMobile ? 4 : 8;
    int rowsCount = isMobile ? 8 : 4;

    // Grid Rows
    List<TableRow> gridRows = [];
    gridRows.add(
      TableRow(
        decoration: BoxDecoration(color: Colors.grey.shade200),
        children: List.generate(
          colsCount,
          (index) => [
            _gridCell(AppStrings.isSinhala ? 'දිනය' : 'Day', isHeader: true),
            _gridCell(AppStrings.isSinhala ? 'කි.ග්‍රෑ' : 'Kg', isHeader: true),
          ],
        ).expand((x) => x).toList(),
      ),
    );

    for (int r = 0; r < rowsCount; r++) {
      List<Widget> rowChildren = [];
      for (int c = 0; c < colsCount; c++) {
        int day = r * colsCount + c + 1;
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

    Widget summaryBox = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Column(
        children: [
          if (totalWeight > 0 || totalWeight2 == 0)
            _summaryGridRow(
              AppStrings.normalLeaf,
              '${totalWeight % 1 == 0 ? totalWeight.toInt() : totalWeight.toStringAsFixed(1)} Kg',
              'Rs. ${_parseDouble(bill['teaRate']).toStringAsFixed(2)}',
              isBold: true,
            ),
          if (totalWeight2 > 0)
            _summaryGridRow(
              AppStrings.superLeaf,
              '${totalWeight2 % 1 == 0 ? totalWeight2.toInt() : totalWeight2.toStringAsFixed(1)} Kg',
              'Rs. ${(_parseDouble(bill['teaRate2']) == 0 && _parseDouble(bill['grossIncome']) > 0 ? ((_parseDouble(bill['grossIncome']) - (totalWeight * _parseDouble(bill['teaRate']))) / totalWeight2) : _parseDouble(bill['teaRate2'])).toStringAsFixed(2)}',
              isBold: true,
            ),
          const Divider(color: Colors.black, thickness: 1, height: 15),
          _summaryRow(AppStrings.grossIncome, 'Rs. ${_parseDouble(bill['grossIncome']).toStringAsFixed(2)}'),
          const SizedBox(height: 5),
          _summaryRow(AppStrings.totalAdvance, '-${totalAdvance.toStringAsFixed(2)}'),
          _summaryRow(AppStrings.isSinhala ? 'භාණ්ඩ සහ තේ කොළ' : 'Goods & Tea', '-${_parseDouble(bill['otherCosts']).toStringAsFixed(2)}'),
          _summaryRow(AppStrings.transportCost, '-${_parseDouble(bill['transportCost']).toStringAsFixed(2)}'),
          if (_parseDouble(bill['arrears'] ?? bill['previousArrears']) > 0)
            _summaryRow(AppStrings.previousArrears, '-${_parseDouble(bill['arrears'] ?? bill['previousArrears']).toStringAsFixed(2)}'),
          const Divider(color: Colors.black, thickness: 1, height: 15),
          _summaryRow(AppStrings.totalDeductions, '-${_parseDouble(bill['totalDeductions']).toStringAsFixed(2)}'),
          const Divider(color: Colors.black, thickness: 1, height: 15),
          _summaryRow(AppStrings.netPayable, 'Rs. ${_parseDouble(bill['netPayable']).toStringAsFixed(2)}', isBold: true),
          const Divider(color: Colors.black, thickness: 2, height: 5),
        ],
      ),
    );

    String formatQty(double q) => q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(1);
    List<String> itemRecords = [];
    Set<int> allItemDays = {...f1ByDay.keys, ...f2ByDay.keys, ...t1ByDay.keys, ...t2ByDay.keys};
    List<int> sortedItemDays = allItemDays.toList()..sort();
    for (int d in sortedItemDays) {
      if ((f1ByDay[d] ?? 0) > 0) itemRecords.add('D$d:F1x${formatQty(f1ByDay[d]!)}');
      if ((f2ByDay[d] ?? 0) > 0) itemRecords.add('D$d:F2x${formatQty(f2ByDay[d]!)}');
      if ((t1ByDay[d] ?? 0) > 0) itemRecords.add('D$d:T1x${formatQty(t1ByDay[d]!)}');
      if ((t2ByDay[d] ?? 0) > 0) itemRecords.add('D$d:T2x${formatQty(t2ByDay[d]!)}');
    }

    double totalItemsCost = f1Total + f2Total + t1Total + t2Total;
    if (totalItemsCost == 0 && otherCosts > 0) {
      totalItemsCost = otherCosts;
    }

    Widget deductionsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.isSinhala ? 'අඩු කිරීම් විස්තරය' : 'Deductions Breakdown',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
        ),
        const SizedBox(height: 8),
        if (totalAdvance > 0) ...[
          Text(
            '${AppStrings.advance} (${AppStrings.isSinhala ? "එකතුව" : "Total"}: Rs.${totalAdvance.toStringAsFixed(2)})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 5,
            runSpacing: 4,
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
          const SizedBox(height: 6),
        ],
        if (totalItemsCost > 0 || otherCosts > 0) ...[
          Text(
            '${AppStrings.isSinhala ? "පොහොර සහ තේ කොළ" : "Fertilizer & Tea"} (${AppStrings.isSinhala ? "එකතුව" : "Total"}: Rs.${totalItemsCost.toStringAsFixed(2)})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (itemRecords.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: itemRecords.map((e) => Text(
                e,
                style: const TextStyle(fontSize: 11),
              )).toList(),
            )
          else
            Text(
              'Rs.${totalItemsCost.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 11),
            ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 6),
        Text(
          '${AppStrings.transportCost} (${((totalWeight + totalWeight2) % 1 == 0) ? (totalWeight + totalWeight2).toInt() : (totalWeight + totalWeight2).toStringAsFixed(1)}kg) : Rs.${_parseDouble(bill['transportCost']).toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 12),
        ),
        if (arrears > 0) ...[
          const SizedBox(height: 4),
          Text(
            '${AppStrings.previousArrears} : Rs.${arrears.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12, color: Colors.red.shade800, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );

    // Dropdown items for versions
    List<DropdownMenuItem<String>> versionDropdownItems = [
      DropdownMenuItem<String>(
        value: 'active',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 6),
            Text(
              'Rev $activeRevNum (${AppStrings.isSinhala ? "වත්මන්" : "Active"}) • Rs. ${_parseDouble(billWrapper['netPayable']).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
      ...history.reversed.map((h) {
        int rNo = h['revNumber'] ?? 1;
        String rTag = h['tag'] ?? 'Revision $rNo';
        if (rNo == 1 && AppStrings.isSinhala) {
          rTag = 'මුල් පිටපත';
        } else if (AppStrings.isSinhala && rTag.startsWith('Revision ')) {
          rTag = 'සංශෝධනය $rNo';
        }
        double rNet = _parseDouble(h['netPayable'] ?? h['snapshot']?['netPayable']);
        return DropdownMenuItem<String>(
          value: 'rev_$rNo',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(rNo == 1 ? Icons.history : Icons.history_toggle_off, color: Colors.red.shade700, size: 16),
              const SizedBox(width: 6),
              Text(
                'Rev $rNo ($rTag) • Rs. ${rNet.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.red.shade900, fontSize: 12),
              ),
            ],
          ),
        );
      }),
    ];

    String dropdownSelectedValue = isViewingHistory ? 'rev_${selectedHistoryItem['revNumber']}' : 'active';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        initiallyExpanded: isLatest,
        title: Row(
          children: [
            Text(
              AppStrings.formatDisplayMonth(billWrapper['displayMonth']),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (isActuallyLatest && _latestBillHasChanges == true) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber.shade800),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber.shade900),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.billChangesDetected,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (hasRevision) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber.shade800),
                ),
                child: Text(
                  AppStrings.isSinhala ? 'සංශෝධිත (Rev $activeRevNum)' : 'REVISED (Rev $activeRevNum)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${AppStrings.isSinhala ? "ශුද්ධ ගෙවීම" : "Net Payment"}: Rs. ${_parseDouble(bill['netPayable']).toStringAsFixed(2)}',
          style: TextStyle(
            color: _parseDouble(bill['netPayable']) < 0 ? Colors.red : Colors.green.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: isViewingHistory ? Colors.red.shade50.withValues(alpha: 0.15) : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isActuallyLatest && !isViewingHistory && _latestBillHasChanges == true)
                  Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      border: Border.all(color: Colors.amber.shade700, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.youHaveBillChanges,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                AppStrings.billChangesPrompt,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.brown.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _handleRecalculateBill(billWrapper),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: Text(AppStrings.recalculateBill),
                        ),
                      ],
                    ),
                  ),
                // Multi-Version Selector Bar
                if (hasRevision)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.history_edu, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Text(AppStrings.viewingPrefix, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blue.shade400),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: dropdownSelectedValue,
                                  isDense: true,
                                  items: versionDropdownItems,
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _activeVersionTab[billId] = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.compare_arrows, size: 15),
                          label: Text(AppStrings.compareWithOriginal),
                          onPressed: () => _showComparisonDialog(billWrapper),
                        ),
                      ],
                    ),
                  ),

                // Version Seal Banner
                if (isViewingHistory)
                  _buildSupersededSeal(billWrapper, historyItem: selectedHistoryItem)
                else if (hasRevision)
                  _buildRevisedSeal(billWrapper),

                const SizedBox(height: 10),

                // Header
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_orgName.isNotEmpty ? _orgName.toUpperCase() : 'SMART ENTRY', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (_addressText.isNotEmpty) Text(_addressText, style: const TextStyle(fontSize: 12)),
                      if (_contactNumbers.isNotEmpty) Text(_contactNumbers, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      Text('${AppStrings.name}: ${widget.customerName} | ${AppStrings.refPrefix}${widget.refNumber}', style: const TextStyle(fontSize: 12)),
                      Text('${AppStrings.month}: ${AppStrings.formatDisplayMonth(bill['displayMonth'])}', style: const TextStyle(fontSize: 12)),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_orgName.isNotEmpty ? _orgName.toUpperCase() : 'SMART ENTRY', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (_addressText.isNotEmpty) Text(_addressText, style: const TextStyle(fontSize: 12)),
                          if (_contactNumbers.isNotEmpty) Text(_contactNumbers, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${AppStrings.name}: ${widget.customerName} | ${AppStrings.refPrefix}${widget.refNumber}', style: const TextStyle(fontSize: 12)),
                          Text('${AppStrings.month}: ${AppStrings.formatDisplayMonth(bill['displayMonth'])}', style: const TextStyle(fontSize: 12)),
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
                if (isMobile) ...[
                  summaryBox,
                  const SizedBox(height: 15),
                  deductionsColumn,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: deductionsColumn),
                      const SizedBox(width: 15),
                      Expanded(flex: 4, child: summaryBox),
                    ],
                  ),

                const SizedBox(height: 25),
                Center(
                  child: Text(
                    'Thank You! | Powered by OrbitView Innovations',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (!isViewingHistory && isActuallyLatest && _latestBillHasChanges == true)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _handleRecalculateBill(billWrapper),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(
                          '${AppStrings.recalculateBill} (${AppStrings.billChangesDetected})',
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _printBill(
                        bill,
                        isSuperseded: isViewingHistory,
                        versionTag: isViewingHistory
                            ? (selectedHistoryItem?['tag'] ?? 'Rev ${selectedHistoryItem?['revNumber']}')
                            : 'Rev $activeRevNum',
                      ),
                      icon: const Icon(Icons.print, size: 18),
                      label: Text(isViewingHistory ? AppStrings.printSelectedVersion : AppStrings.printSlip),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _sendIndividualWhatsApp(bill),
                      icon: const Icon(Icons.message, size: 18),
                      label: Text(AppStrings.sendBillWhatsApp),
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

  Widget _buildSupersededSeal(Map<String, dynamic> billWrapper, {Map<String, dynamic>? historyItem}) {
    int revNo = historyItem?['revNumber'] ?? 1;
    String tag = historyItem?['tag'] ?? 'Revision $revNo';
    if (revNo == 1 && AppStrings.isSinhala) {
      tag = 'මුල් පිටපත';
    } else if (AppStrings.isSinhala && tag.startsWith('Revision ')) {
      tag = 'සංශෝධනය $revNo';
    }
    String timestamp = (historyItem?['timestamp'] ?? billWrapper['revisedAt'])?.toString() ?? '';
    String reason = (historyItem?['reason'] ?? billWrapper['revisionReason'])?.toString() ?? '';
    String revisedBy = (historyItem?['revisedBy'] ?? billWrapper['revisedBy'])?.toString() ?? '';

    List<String> details = [];
    if (timestamp.isNotEmpty) details.add('${AppStrings.archivedOn}: $timestamp');
    if (revisedBy.isNotEmpty) details.add('${AppStrings.updatedBy}: $revisedBy');
    if (reason.isNotEmpty) details.add('${AppStrings.reason}: $reason');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade700, width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.history_toggle_off, color: Colors.red.shade800, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        AppStrings.isSinhala ? 'අවලංගු කළ පිටපත (REV $revNo)' : 'SUPERSEDED / REPLACED (REV $revNo)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$tag - ${AppStrings.isSinhala ? "පැරණි පිටපත" : "Old Copy"}',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    details.join(' • '),
                    style: TextStyle(fontSize: 11, color: Colors.red.shade900),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevisedSeal(Map<String, dynamic> billWrapper) {
    int activeRevNum = (billWrapper['currentRevision'] is num)
        ? (billWrapper['currentRevision'] as num).toInt()
        : ((billWrapper['revisionHistory'] as List? ?? []).length + 1);
    String revisedAt = billWrapper['revisedAt']?.toString() ?? '';
    String reason = billWrapper['revisionReason']?.toString() ?? '';
    String revisedBy = (billWrapper['revisedBy'] ?? billWrapper['billData']?['revisedBy'])?.toString() ?? '';

    List<String> details = [];
    if (revisedAt.isNotEmpty) details.add('${AppStrings.latestUpdate}: $revisedAt');
    if (revisedBy.isNotEmpty) details.add('${AppStrings.updatedBy}: $revisedBy');
    if (reason.isNotEmpty) details.add('${AppStrings.note}: $reason');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade700, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.verified, color: Colors.green.shade800, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.isSinhala ? 'සංශෝධිත බිල්පත (Rev $activeRevNum - වත්මන්)' : 'REVISED BILL (Rev $activeRevNum - Active)',
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                if (details.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      details.join(' • '),
                      style: TextStyle(fontSize: 11, color: Colors.green.shade900),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _printBill(Map<String, dynamic> bill, {bool isSuperseded = false, String versionTag = ''}) {
    BillPdfService.printFastDotMatrix(
      bill: bill,
      customerName: widget.customerName,
      refNumber: widget.refNumber,
      isSuperseded: isSuperseded,
      versionTag: versionTag,
      orgName: _orgName,
      addressText: _addressText,
      contactNumbers: _contactNumbers,
      widthCm: _pageWidth,
      heightCm: _pageHeight,
    );
  }

  Map<String, double> _extractBillItems(Map<String, dynamic> bill) {
    double f1Qty = _parseDouble(bill['f1Qty']);
    double f1Total = _parseDouble(bill['f1Total']);
    double f2Qty = _parseDouble(bill['f2Qty']);
    double f2Total = _parseDouble(bill['f2Total']);
    double t1Qty = _parseDouble(bill['t1Qty']);
    double t1Total = _parseDouble(bill['t1Total']);
    double t2Qty = _parseDouble(bill['t2Qty']);
    double t2Total = _parseDouble(bill['t2Total']);

    if (f1Qty == 0 && f1Total == 0 && f2Qty == 0 && f2Total == 0 && t1Qty == 0 && t1Total == 0 && t2Qty == 0 && t2Total == 0) {
      for (var row in (bill['tableRows'] as List? ?? [])) {
        List items = row['items'] ?? row['deductions'] ?? [];
        for (var it in items) {
          String desc = (it['desc'] ?? '').toString().toLowerCase();
          double qty = _parseDouble(it['qty']);
          double amt = _parseDouble(it['amt']);
          if (desc.contains('fert 01') || desc.contains('fertilizer 1') || desc.contains('fmdfydr 01') || desc.contains('පොහොර 1') || desc.contains('පොහොර 01')) {
            f1Qty += qty;
            f1Total += amt;
          } else if (desc.contains('fert 02') || desc.contains('fertilizer 2') || desc.contains('fmdfydr 02') || desc.contains('පොහොර 2') || desc.contains('පොහොර 02')) {
            f2Qty += qty;
            f2Total += amt;
          } else if (desc.contains('tea pkt 01') || desc.contains('tea packet 1') || desc.contains('f;a fld< 01') || desc.contains('තේ පැකට් 1') || desc.contains('තේ කොළ 1') || desc.contains('තේ කොළ 01')) {
            t1Qty += qty;
            t1Total += amt;
          } else if (desc.contains('tea pkt 02') || desc.contains('tea packet 2') || desc.contains('f;a fld< 02') || desc.contains('තේ පැකට් 2') || desc.contains('තේ කොළ 2') || desc.contains('තේ කොළ 02')) {
            t2Qty += qty;
            t2Total += amt;
          }
        }
      }
    }

    return {
      'f1Qty': f1Qty,
      'f1Total': f1Total,
      'f2Qty': f2Qty,
      'f2Total': f2Total,
      't1Qty': t1Qty,
      't1Total': t1Total,
      't2Qty': t2Qty,
      't2Total': t2Total,
    };
  }

  String _formatItemLabel(String baseName, double oldQty, double newQty) {
    String fmt(double q) => q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(1);
    if (oldQty > 0 || newQty > 0) {
      if ((oldQty - newQty).abs() > 0.001) {
        return '$baseName (${fmt(oldQty)} -> ${fmt(newQty)})';
      } else {
        return '$baseName (${fmt(newQty)})';
      }
    }
    return baseName;
  }

  TableRow _buildDiffRow(String label, double oldVal, double newVal, {bool isCurrency = true, bool isBold = false}) {
    final fmt = NumberFormat('#,##0.00');
    double diff = newVal - oldVal;
    String formatVal(double v) => fmt.format(v);
    
    Color diffColor = Colors.grey.shade800;
    if (diff > 0.001) diffColor = Colors.green.shade800;
    if (diff < -0.001) diffColor = Colors.red.shade800;
    
    String diffText = diff > 0.001 ? '+${fmt.format(diff)}' : fmt.format(diff);

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(formatVal(oldVal), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(formatVal(newVal), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(diffText, textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: diffColor)),
        ),
      ],
    );
  }


  void _showComparisonDialog(Map<String, dynamic> billWrapper) {
    var oldBill = billWrapper['originalBillData'] ?? {};
    var currentBill = billWrapper['billData'] ?? billWrapper;
    String displayMonth = billWrapper['displayMonth'] ?? '';
    String localizedDisplayMonth = AppStrings.formatDisplayMonth(displayMonth);
    int activeRev = (billWrapper['currentRevision'] is num)
        ? (billWrapper['currentRevision'] as num).toInt()
        : 1;

    final oldItems = _extractBillItems(oldBill is Map<String, dynamic> ? oldBill : Map<String, dynamic>.from(oldBill));
    final curItems = _extractBillItems(currentBill is Map<String, dynamic> ? currentBill : Map<String, dynamic>.from(currentBill));
    final oldF1Q = oldItems['f1Qty']!;
    final oldF1Amt = oldItems['f1Total']!;
    final curF1Q = curItems['f1Qty']!;
    final curF1Amt = curItems['f1Total']!;
    final oldF2Q = oldItems['f2Qty']!;
    final oldF2Amt = oldItems['f2Total']!;
    final curF2Q = curItems['f2Qty']!;
    final curF2Amt = curItems['f2Total']!;
    final oldT1Q = oldItems['t1Qty']!;
    final oldT1Amt = oldItems['t1Total']!;
    final curT1Q = curItems['t1Qty']!;
    final curT1Amt = curItems['t1Total']!;
    final oldT2Q = oldItems['t2Qty']!;
    final oldT2Amt = oldItems['t2Total']!;
    final curT2Q = curItems['t2Qty']!;
    final curT2Amt = curItems['t2Total']!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.compare_arrows, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(AppStrings.comparisonTitle(activeRev, localizedDisplayMonth)),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppStrings.customerName}: ${widget.customerName} (${AppStrings.refPrefix}${widget.refNumber})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (billWrapper['revisedAt'] != null && billWrapper['revisedAt'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${AppStrings.latestRevisionLabel}${billWrapper['revisedAt']}${billWrapper['revisedBy'] != null && billWrapper['revisedBy'].toString().isNotEmpty ? ' • ${AppStrings.updatedBy}: ${billWrapper['revisedBy']}' : ''}${billWrapper['revisionReason'] != null && billWrapper['revisionReason'].toString().isNotEmpty ? ' • ${billWrapper['revisionReason']}' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Table(
                    border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.shade300)),
                    columnWidths: const {
                      0: FlexColumnWidth(4),
                      1: FlexColumnWidth(3),
                      2: FlexColumnWidth(3),
                      3: FlexColumnWidth(3),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey.shade200),
                        children: [
                          Padding(padding: const EdgeInsets.all(6), child: Text(AppStrings.metric, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: const EdgeInsets.all(6), child: Text(AppStrings.isSinhala ? 'මුල් පිටපත (Rev 1)' : 'Original (Rev 1)', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: const EdgeInsets.all(6), child: Text(AppStrings.isSinhala ? 'වත්මන් (Rev $activeRev)' : 'Active (Rev $activeRev)', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: const EdgeInsets.all(6), child: Text(AppStrings.difference, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        ],
                      ),
                      _buildDiffRow('${AppStrings.normalLeaf} (kg)', _parseDouble(oldBill['totalWeight']), _parseDouble(currentBill['totalWeight']), isCurrency: false),
                      _buildDiffRow('${AppStrings.superLeaf} (kg)', _parseDouble(oldBill['totalWeight2']), _parseDouble(currentBill['totalWeight2']), isCurrency: false),
                      _buildDiffRow(AppStrings.grossIncome, _parseDouble(oldBill['grossIncome']), _parseDouble(currentBill['grossIncome'])),
                      _buildDiffRow(AppStrings.totalAdvance, _parseDouble(oldBill['advTotal']), _parseDouble(currentBill['advTotal'])),
                      _buildDiffRow(_formatItemLabel(AppStrings.fertilizer1, oldF1Q, curF1Q), oldF1Amt, curF1Amt),
                      if (oldF2Amt > 0 || curF2Amt > 0 || oldF2Q > 0 || curF2Q > 0)
                        _buildDiffRow(_formatItemLabel(AppStrings.fertilizer2, oldF2Q, curF2Q), oldF2Amt, curF2Amt),
                      _buildDiffRow(_formatItemLabel(AppStrings.teaPacket1, oldT1Q, curT1Q), oldT1Amt, curT1Amt),
                      if (oldT2Amt > 0 || curT2Amt > 0 || oldT2Q > 0 || curT2Q > 0)
                        _buildDiffRow(_formatItemLabel(AppStrings.teaPacket2, oldT2Q, curT2Q), oldT2Amt, curT2Amt),
                      _buildDiffRow(AppStrings.transportCost, _parseDouble(oldBill['transportCost']), _parseDouble(currentBill['transportCost'])),
                      _buildDiffRow(AppStrings.otherDeductions, _parseDouble(oldBill['otherCosts']), _parseDouble(currentBill['otherCosts'])),
                      _buildDiffRow(AppStrings.previousArrears, _parseDouble(oldBill['arrears'] ?? oldBill['previousArrears']), _parseDouble(currentBill['arrears'] ?? currentBill['previousArrears'])),
                      _buildDiffRow(AppStrings.totalDeductions, _parseDouble(oldBill['totalDeductions']), _parseDouble(currentBill['totalDeductions'])),
                      _buildDiffRow(AppStrings.netPayable, _parseDouble(oldBill['netPayable']), _parseDouble(currentBill['netPayable']), isBold: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.close),
          ),
        ],
      ),
    );
  }

  Future<_BillDiffResult?> _computeBillDifferences(Map<String, dynamic> billWrapper) async {
    final orgId = AppState.currentOrganizationId.value ?? '';
    if (orgId.isEmpty) return null;

    Map<String, dynamic> currentBill = billWrapper['billData'] ?? billWrapper;
    String displayMonth = currentBill['displayMonth'] ?? billWrapper['displayMonth'] ?? '';
    List<String> monthParts = displayMonth.trim().split(' ');
    if (monthParts.length < 2) return null;

    int year = int.tryParse(monthParts[0]) ?? DateTime.now().year;
    String monthName = monthParts[1];
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    int monthNum = monthNames.indexWhere((m) => m.toLowerCase() == monthName.toLowerCase()) + 1;
    if (monthNum == 0) return null;

    String localizedDisplayMonth = AppStrings.formatDisplayMonth(displayMonth);
    String ratesDocId = "$year-$monthName";

    // 1. Fetch monthly rates
    var ratesDoc = await Supabase.instance.client
        .from('monthly_rates')
        .select()
        .eq('organization_id', orgId)
        .eq('id', ratesDocId)
        .maybeSingle();

    double teaRate = _parseDouble(ratesDoc?['teaRate'] ?? currentBill['teaRate']);
    double teaRate2 = _parseDouble(ratesDoc?['teaRate2'] ?? currentBill['teaRate2']);
    double transportRate = _parseDouble(ratesDoc?['transportRate']);

    double oldTotalW = _parseDouble(currentBill['totalWeight']);
    double oldTotalW2 = _parseDouble(currentBill['totalWeight2']);
    double oldTransCost = _parseDouble(currentBill['transportCost']);
    if (transportRate == 0.0 && (oldTotalW + oldTotalW2) > 0) {
      transportRate = oldTransCost / (oldTotalW + oldTotalW2);
    }

    // 2. Fetch item prices
    final orgItems = await ItemService.getItems(organizationId: orgId);
    double f1Price = orgItems.where((it) => it.slotIndex == 1).firstOrNull?.unitPrice ?? 15500.0;
    double f2Price = orgItems.where((it) => it.slotIndex == 2).firstOrNull?.unitPrice ?? 18000.0;
    double t1Price = orgItems.where((it) => it.slotIndex == 3).firstOrNull?.unitPrice ?? 650.0;
    double t2Price = orgItems.where((it) => it.slotIndex == 4).firstOrNull?.unitPrice ?? 0.0;

    // 3. Fetch previous month arrears
    int prevMonth = monthNum == 1 ? 12 : monthNum - 1;
    int prevYear = monthNum == 1 ? year - 1 : year;
    String prevMonthName = monthNames[prevMonth - 1];
    String prevBillId = "${widget.customerId}_$prevYear-$prevMonthName";

    var prevBillDoc = await Supabase.instance.client
        .from('finalized_bills')
        .select()
        .eq('organization_id', orgId)
        .eq('id', prevBillId)
        .maybeSingle();

    double lastMonthArrears = 0.0;
    if (prevBillDoc != null) {
      var prevBillData = prevBillDoc['billData'];
      if (prevBillData is Map) {
        double prevNet = _parseDouble(prevBillData['netPayable']);
        if (prevNet < 0) {
          lastMonthArrears = prevNet.abs();
        }
      }
    } else {
      lastMonthArrears = _parseDouble(currentBill['arrears'] ?? currentBill['previousArrears']);
    }

    // 4. Fetch daily entries for this customer in this month
    int lastDay = DateTime(year, monthNum + 1, 0).day;
    String monthPadded = monthNum.toString().padLeft(2, '0');
    String startDate = "$year-$monthPadded-01";
    String endDate = "$year-$monthPadded-${lastDay.toString().padLeft(2, '0')}";

    var entriesSnap = await Supabase.instance.client
        .from('daily_entries')
        .select()
        .eq('organization_id', orgId)
        .eq('customerId', widget.customerId)
        .gte('date', startDate)
        .lte('date', endDate)
        .order('date', ascending: true);

    // 5. Calculate new entries
    double newTotalW = 0, newTotalW2 = 0, newAdvTotal = 0;
    double newF1Q = 0, newF2Q = 0, newT1Q = 0, newT2Q = 0, newDynamicAmt = 0;
    List<Map<String, dynamic>> newTableRows = [];

    for (var d in entriesSnap) {
      double w = _parseDouble(d['netWeight']);
      double w2 = _parseDouble(d['netWeight2']);
      double adv = _parseDouble(d['advanceAmount']);

      newTotalW += w;
      newTotalW2 += w2;
      newAdvTotal += adv;

      List<Map<String, dynamic>> items = [];
      if (adv > 0) {
        items.add({'desc': 'Advance', 'qty': 0, 'uPrice': 0, 'amt': adv});
      }

      final parsed = ItemService.parseDailyEntryItems(
        d,
        f1Price: f1Price,
        f2Price: f2Price,
        t1Price: t1Price,
        t2Price: t2Price,
      );

      newF1Q += parsed.f1Qty;
      newF2Q += parsed.f2Qty;
      newT1Q += parsed.t1Qty;
      newT2Q += parsed.t2Qty;
      newDynamicAmt += parsed.otherDynamicAmt;

      items.addAll(parsed.itemsList);

      newTableRows.add({'date': d['date'], 'weight': w, 'weight2': w2, 'items': items});
    }

    double newGross = (newTotalW * teaRate) + (newTotalW2 * teaRate2);
    double newTrans = (newTotalW + newTotalW2) * transportRate;
    double newF1Amt = newF1Q * f1Price;
    double newF2Amt = newF2Q * f2Price;
    double newT1Amt = newT1Q * t1Price;
    double newT2Amt = newT2Q * t2Price;
    double newOther = newAdvTotal + newF1Amt + newF2Amt + newT1Amt + newT2Amt + newDynamicAmt;
    double newTotalDeductions = newTrans + newOther + lastMonthArrears;
    double newNetPayable = newGross - newTotalDeductions;

    // Check if next month exists
    int nextMonth = monthNum == 12 ? 1 : monthNum + 1;
    int nextYear = monthNum == 12 ? year + 1 : year;
    String nextMonthName = monthNames[nextMonth - 1];
    String nextBillId = "${widget.customerId}_$nextYear-$nextMonthName";

    var nextBillDoc = await Supabase.instance.client
        .from('finalized_bills')
        .select('id')
        .eq('organization_id', orgId)
        .eq('id', nextBillId)
        .maybeSingle();

    bool isLatestAllowed = (nextBillDoc == null) && BillingLockService().isLatestFinalizedMonth(displayMonth);

    final curItems = _extractBillItems(currentBill);
    double curF1Q = curItems['f1Qty']!;
    double curF1Amt = curItems['f1Total']!;
    double curF2Q = curItems['f2Qty']!;
    double curF2Amt = curItems['f2Total']!;
    double curT1Q = curItems['t1Qty']!;
    double curT1Amt = curItems['t1Total']!;
    double curT2Q = curItems['t2Qty']!;
    double curT2Amt = curItems['t2Total']!;

    bool hasChanges =
        (_parseDouble(currentBill['totalWeight']) - newTotalW).abs() > 0.01 ||
        (_parseDouble(currentBill['totalWeight2']) - newTotalW2).abs() > 0.01 ||
        (_parseDouble(currentBill['grossIncome']) - newGross).abs() > 0.01 ||
        (_parseDouble(currentBill['advTotal']) - newAdvTotal).abs() > 0.01 ||
        (_parseDouble(currentBill['transportCost']) - newTrans).abs() > 0.01 ||
        (_parseDouble(currentBill['otherCosts']) - newOther).abs() > 0.01 ||
        (_parseDouble(currentBill['totalDeductions']) - newTotalDeductions).abs() > 0.01 ||
        (_parseDouble(currentBill['netPayable']) - newNetPayable).abs() > 0.01 ||
        (curF1Amt - newF1Amt).abs() > 0.01 ||
        (curF2Amt - newF2Amt).abs() > 0.01 ||
        (curT1Amt - newT1Amt).abs() > 0.01 ||
        (curT2Amt - newT2Amt).abs() > 0.01 ||
        (curF1Q - newF1Q).abs() > 0.01 ||
        (curF2Q - newF2Q).abs() > 0.01 ||
        (curT1Q - newT1Q).abs() > 0.01 ||
        (curT2Q - newT2Q).abs() > 0.01;

    return _BillDiffResult(
      hasChanges: hasChanges,
      isLatestAllowed: isLatestAllowed,
      currentBill: currentBill,
      displayMonth: displayMonth,
      localizedDisplayMonth: localizedDisplayMonth,
      ratesDocId: ratesDocId,
      teaRate: teaRate,
      teaRate2: teaRate2,
      transportRate: transportRate,
      lastMonthArrears: lastMonthArrears,
      newTotalW: newTotalW,
      newTotalW2: newTotalW2,
      newGross: newGross,
      newAdvTotal: newAdvTotal,
      newTrans: newTrans,
      newOther: newOther,
      newTotalDeductions: newTotalDeductions,
      newNetPayable: newNetPayable,
      newF1Q: newF1Q,
      newF1Amt: newF1Amt,
      newF2Q: newF2Q,
      newF2Amt: newF2Amt,
      newT1Q: newT1Q,
      newT1Amt: newT1Amt,
      newT2Q: newT2Q,
      newT2Amt: newT2Amt,
      newTableRows: newTableRows,
    );
  }

  Future<void> _handleRecalculateBill(Map<String, dynamic> billWrapper) async {
    final orgId = AppState.currentOrganizationId.value ?? '';
    if (orgId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.isSinhala ? 'දෝෂයකි: ආයතනික අංකයක් හමු නොවීය.' : 'Error: No active organization ID.')),
      );
      return;
    }

    // Show loading progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(AppStrings.recalculatingBillProgress),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final diff = await _computeBillDifferences(billWrapper);

      // Dismiss loading dialog
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (diff == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.isSinhala ? 'දෝෂයකි: ගණනය කිරීමට නොහැකි විය.' : 'Error: Unable to calculate bill differences.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!diff.isLatestAllowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.onlyLatestBillCanBeRecalculated),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        }
        return;
      }

      // Show Preview & Confirmation Dialog
      if (!mounted) return;
      final reasonController = TextEditingController();
      final updatedByController = TextEditingController();
      String? nameError;

      final curItems = _extractBillItems(diff.currentBill);
      final curF1Q = curItems['f1Qty']!;
      final curF1Amt = curItems['f1Total']!;
      final curF2Q = curItems['f2Qty']!;
      final curF2Amt = curItems['f2Total']!;
      final curT1Q = curItems['t1Qty']!;
      final curT1Amt = curItems['t1Total']!;
      final curT2Q = curItems['t2Qty']!;
      final curT2Amt = curItems['t2Total']!;

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.refresh, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(AppStrings.recalculateBillTitle(diff.localizedDisplayMonth)),
                  ),
                ],
              ),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppStrings.customerName}: ${widget.customerName} (${AppStrings.refPrefix}${widget.refNumber})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppStrings.reviewRecalculationChanges,
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                      const SizedBox(height: 10),
                      // Comparison Table
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Table(
                          border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.shade300)),
                          columnWidths: const {
                            0: FlexColumnWidth(4),
                            1: FlexColumnWidth(3),
                            2: FlexColumnWidth(3),
                            3: FlexColumnWidth(3),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: Colors.grey.shade200),
                              children: [
                                Padding(padding: const EdgeInsets.all(6), child: Text(AppStrings.metric, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Padding(padding: const EdgeInsets.all(6), child: Text(AppStrings.current, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Padding(padding: const EdgeInsets.all(6), child: Text(AppStrings.recalculated, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Padding(padding: const EdgeInsets.all(6), child: Text(AppStrings.difference, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              ],
                            ),
                            _buildDiffRow('${AppStrings.normalLeaf} (kg)', _parseDouble(diff.currentBill['totalWeight']), diff.newTotalW, isCurrency: false),
                            _buildDiffRow('${AppStrings.superLeaf} (kg)', _parseDouble(diff.currentBill['totalWeight2']), diff.newTotalW2, isCurrency: false),
                            _buildDiffRow(AppStrings.grossIncome, _parseDouble(diff.currentBill['grossIncome']), diff.newGross),
                            _buildDiffRow(AppStrings.totalAdvance, _parseDouble(diff.currentBill['advTotal']), diff.newAdvTotal),
                            _buildDiffRow(_formatItemLabel(AppStrings.fertilizer1, curF1Q, diff.newF1Q), curF1Amt, diff.newF1Amt),
                            if (curF2Amt > 0 || diff.newF2Amt > 0 || curF2Q > 0 || diff.newF2Q > 0)
                              _buildDiffRow(_formatItemLabel(AppStrings.fertilizer2, curF2Q, diff.newF2Q), curF2Amt, diff.newF2Amt),
                            _buildDiffRow(_formatItemLabel(AppStrings.teaPacket1, curT1Q, diff.newT1Q), curT1Amt, diff.newT1Amt),
                            if (curT2Amt > 0 || diff.newT2Amt > 0 || curT2Q > 0 || diff.newT2Q > 0)
                              _buildDiffRow(_formatItemLabel(AppStrings.teaPacket2, curT2Q, diff.newT2Q), curT2Amt, diff.newT2Amt),
                            _buildDiffRow(AppStrings.transportCost, _parseDouble(diff.currentBill['transportCost']), diff.newTrans),
                            _buildDiffRow(AppStrings.otherDeductions, _parseDouble(diff.currentBill['otherCosts']), diff.newOther),
                            if (diff.lastMonthArrears > 0 || _parseDouble(diff.currentBill['arrears'] ?? diff.currentBill['previousArrears']) > 0)
                              _buildDiffRow(AppStrings.previousArrears, _parseDouble(diff.currentBill['arrears'] ?? diff.currentBill['previousArrears']), diff.lastMonthArrears),
                            _buildDiffRow(AppStrings.totalDeductions, _parseDouble(diff.currentBill['totalDeductions']), diff.newTotalDeductions),
                            _buildDiffRow(AppStrings.netPayable, _parseDouble(diff.currentBill['netPayable']), diff.newNetPayable, isBold: true),
                          ],
                        ),
                      ),
                      if (!diff.hasChanges) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  AppStrings.noBillChangesDetected,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(AppStrings.updatedByLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: updatedByController,
                        style: const TextStyle(fontSize: 13),
                        onChanged: (val) {
                          if (nameError != null && val.trim().isNotEmpty) {
                            setDialogState(() {
                              nameError = null;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                          hintText: AppStrings.updatedByHint,
                          errorText: nameError,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(AppStrings.recalculationReasonLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: reasonController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: AppStrings.recalculationReasonHint,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: Text(AppStrings.cancel),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: diff.hasChanges ? Colors.blue.shade700 : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: diff.hasChanges
                      ? () {
                          final name = updatedByController.text.trim();
                          if (name.isEmpty) {
                            setDialogState(() {
                              nameError = AppStrings.updatedByNameRequired;
                            });
                            return;
                          }
                          Navigator.pop(dialogCtx, true);
                        }
                      : null,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(AppStrings.confirmAndUpdateBill),
                ),
              ],
            );
          },
        ),
      );

      if (confirmed != true || !mounted) return;
      final updatedPerson = updatedByController.text.trim();

      // Execute database updates
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(AppStrings.savingUpdatedBillProgress),
                ],
              ),
            ),
          ),
        ),
      );


      // Build updated revisionHistory list
      List<Map<String, dynamic>> updatedHistory = [];
      if (billWrapper['revisionHistory'] is List && (billWrapper['revisionHistory'] as List).isNotEmpty) {
        updatedHistory = (billWrapper['revisionHistory'] as List)
            .map((e) {
              final map = Map<String, dynamic>.from(e as Map);
              if (map['snapshot'] != null) {
                map['snapshot'] = _cleanBillSnapshot(map['snapshot']);
              }
              return map;
            })
            .toList();
      } else {
        // First recalculation: archive original finalized bill as Rev 1
        Map<String, dynamic> originalSnapshot = _cleanBillSnapshot(billWrapper['originalBillData'] ?? diff.currentBill);
        updatedHistory.add({
          'revNumber': 1,
          'tag': 'Original Finalized Bill',
          'timestamp': billWrapper['finalizedAt']?.toString() ?? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
          'reason': 'Initial Month-end Closing',
          'revisedBy': '',
          'netPayable': _parseDouble(originalSnapshot['netPayable']),
          'snapshot': originalSnapshot,
        });
      }

      // If this bill was already revised previously, archive the active version being replaced
      if (billWrapper['isRevised'] == true) {
        int archivedRevNum = updatedHistory.length + 1;
        updatedHistory.add({
          'revNumber': archivedRevNum,
          'tag': 'Revision ${archivedRevNum - 1}',
          'timestamp': diff.currentBill['revisedAt']?.toString() ?? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
          'reason': diff.currentBill['revisionReason']?.toString() ?? 'Recalculation adjustment',
          'revisedBy': diff.currentBill['revisedBy'] ?? billWrapper['revisedBy'] ?? '',
          'netPayable': _parseDouble(diff.currentBill['netPayable']),
          'snapshot': _cleanBillSnapshot(diff.currentBill),
        });
      }

      int newActiveRevNum = updatedHistory.length + 1;

      Map<String, dynamic> newBillData = {
        'displayMonth': diff.displayMonth,
        'teaRate': diff.teaRate,
        'teaRate2': diff.teaRate2,
        'totalWeight': diff.newTotalW,
        'totalWeight2': diff.newTotalW2,
        'grossIncome': diff.newGross,
        'transportCost': diff.newTrans,
        'otherCosts': diff.newOther,
        'arrears': diff.lastMonthArrears,
        'totalDeductions': diff.newTotalDeductions,
        'netPayable': diff.newNetPayable,
        'tableRows': diff.newTableRows,
        'advTotal': diff.newAdvTotal,
        'f1Qty': diff.newF1Q,
        'f1Total': diff.newF1Amt,
        'f2Qty': diff.newF2Q,
        'f2Total': diff.newF2Amt,
        't1Qty': diff.newT1Q,
        't1Total': diff.newT1Amt,
        't2Qty': diff.newT2Q,
        't2Total': diff.newT2Amt,
        // Revision Metadata
        'isRevised': true,
        'currentRevision': newActiveRevNum,
        'revisedAt': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
        'revisionReason': reasonController.text.trim(),
        'revisedBy': updatedPerson,
        'originalBillData': updatedHistory.first['snapshot'],
        'revisionHistory': updatedHistory,
      };

      // Update finalized_bills for this month
      await Supabase.instance.client
          .from('finalized_bills')
          .update({'billData': newBillData})
          .eq('organization_id', orgId)
          .eq('id', billWrapper['id']);

      // Update monthly_summaries delta for this month
      var summaryDoc = await Supabase.instance.client
          .from('monthly_summaries')
          .select()
          .eq('organization_id', orgId)
          .eq('id', diff.ratesDocId)
          .maybeSingle();

      if (summaryDoc != null) {
        double deltaGross = diff.newGross - _parseDouble(diff.currentBill['grossIncome']);
        double deltaTrans = diff.newTrans - _parseDouble(diff.currentBill['transportCost']);
        double deltaAdv = diff.newAdvTotal - _parseDouble(diff.currentBill['advTotal']);
        double deltaNet = diff.newNetPayable - _parseDouble(diff.currentBill['netPayable']);
        double deltaWeight = (diff.newTotalW + diff.newTotalW2) - (_parseDouble(diff.currentBill['totalWeight']) + _parseDouble(diff.currentBill['totalWeight2']));

        await Supabase.instance.client
            .from('monthly_summaries')
            .update({
              'totalGross': _parseDouble(summaryDoc['totalGross']) + deltaGross,
              'totalTransport': _parseDouble(summaryDoc['totalTransport']) + deltaTrans,
              'totalAdvance': _parseDouble(summaryDoc['totalAdvance']) + deltaAdv,
              'totalNet': _parseDouble(summaryDoc['totalNet']) + deltaNet,
              'totalWeight': _parseDouble(summaryDoc['totalWeight']) + deltaWeight,
            })
            .eq('organization_id', orgId)
            .eq('id', diff.ratesDocId);
      }

      // Dismiss saving dialog
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      // Reload all data
      await _loadAllData();

      // Trigger app-wide refresh so customer badges & dashboard update immediately
      _lastHandledRefresh = AppState.refreshTrigger.value + 1;
      AppState.triggerRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.billRecalculatedSuccess),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      debugPrint('Error in recalculate: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.recalculationErrorPrefix}$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

    if (totalWeight == 0 && totalWeight2 == 0 && bill['tableRows'] != null) {
      for (var row in bill['tableRows']) {
        totalWeight += _parseDouble(row['weight']);
        totalWeight2 += _parseDouble(row['weight2']);
      }
    }

    if (totalWeight == 0 && totalWeight2 == 0 && teaRate > 0) {
      totalWeight = grossIncome / teaRate;
    }

    if (teaRate2 == 0 && totalWeight2 > 0 && grossIncome > 0) {
      teaRate2 = (grossIncome - (totalWeight * teaRate)) / totalWeight2;
    }

    double advTotal = _parseDouble(bill['advTotal']);
    double f1Total = _parseDouble(bill['f1Total']);
    double f2Total = _parseDouble(bill['f2Total']);
    double t1Total = _parseDouble(bill['t1Total']);
    double t2Total = _parseDouble(bill['t2Total']);
    double transportCost = _parseDouble(bill['transportCost']);
    double arrears = _parseDouble(bill['arrears']);
    double otherCosts = _parseDouble(bill['otherCosts']);

    String displayMonth = bill['displayMonth'] ?? '';

    String msg = '';
    if (AppStrings.isSinhala) {
      if (bill['isRevised'] == true) {
        msg += "⚠️ *සංශෝධිත බිල්පත*\n";
        if (bill['revisedBy'] != null && bill['revisedBy'].toString().isNotEmpty) {
          msg += "_යාවත්කාලීන කළේ: ${bill['revisedBy']}_\n";
        }
        if (bill['revisionReason'] != null && bill['revisionReason'].toString().isNotEmpty) {
          msg += "_සටහන: ${bill['revisionReason']}_\n";
        }
        msg += "\n";
      }

      msg +=
          "ආයුබෝවන් *${widget.customerName}*,\n\n"
          "ඔබගේ $displayMonth මාසයේ බිල්පත:\n\n";

      if (totalWeight > 0 || totalWeight2 == 0) {
        double normalAmount = totalWeight * teaRate;
        msg += "සාමාන්‍ය දළු: *${totalWeight % 1 == 0 ? totalWeight.toInt() : totalWeight.toStringAsFixed(1)} kg*\n"
               "සාමාන්‍ය දළු මිල: *Rs ${currencyF.format(teaRate)}*\n"
               "සාමාන්‍ය දළු වටිනාකම: *Rs ${currencyF.format(normalAmount)}*\n";
      }
      if (totalWeight2 > 0) {
        double superAmount = totalWeight2 * teaRate2;
        msg += "සුපිරි දළු: *${totalWeight2 % 1 == 0 ? totalWeight2.toInt() : totalWeight2.toStringAsFixed(1)} kg*\n"
               "සුපිරි දළු මිල: *Rs ${currencyF.format(teaRate2)}*\n"
               "සුපිරි දළු වටිනාකම: *Rs ${currencyF.format(superAmount)}*\n";
      }

      msg += "\nමුළු දළු ආදායම: *Rs ${currencyF.format(grossIncome)}*\n\n";

      if (totalDeductions > 0) {
        msg += "අඩුකිරීම්:\n";
        if (advTotal > 0) {
          msg += "• අත්තිකාරම්: *Rs ${currencyF.format(advTotal)}*\n";
        }
        if (f1Total > 0) {
          msg += "• භාණ්ඩ 01: *Rs ${currencyF.format(f1Total)}*\n";
        }
        if (f2Total > 0) {
          msg += "• භාණ්ඩ 02: *Rs ${currencyF.format(f2Total)}*\n";
        }
        if (t1Total > 0) {
          msg += "• තේ කොළ 01: *Rs ${currencyF.format(t1Total)}*\n";
        }
        if (t2Total > 0) {
          msg += "• තේ කොළ 02: *Rs ${currencyF.format(t2Total)}*\n";
        }
        if (transportCost > 0) {
          msg += "• ප්‍රවාහනය: *Rs ${currencyF.format(transportCost)}*\n";
        }
        if (otherCosts > 0) {
          msg += "• වෙනත් අඩු කිරීම්: *Rs ${currencyF.format(otherCosts)}*\n";
        }
        if (arrears > 0) {
          msg += "• හිඟ මුදල්: *Rs ${currencyF.format(arrears)}*\n";
        }
        msg += "\nමුළු අඩුකිරීම්: *Rs ${currencyF.format(totalDeductions)}*\n\n";
      }

      List<String> companyLines = [
        _orgName,
        _companyLine1,
        _companyLine2,
        _companyLine3,
        _companyLine4,
        _contactNumbers,
      ];
      String companySignature = companyLines
          .where((l) => l.trim().isNotEmpty)
          .join('\n');

      msg +=
          "ලබා දිය යුතු මුදල: *Rs ${currencyF.format(netPayable)}*\n\n"
          "Thank you!\n$companySignature\n"
          "_powered by OrbitView Innovations_";
    } else {
      if (bill['isRevised'] == true) {
        msg += "⚠️ *Revised Bill*\n";
        if (bill['revisedBy'] != null && bill['revisedBy'].toString().isNotEmpty) {
          msg += "_Updated by: ${bill['revisedBy']}_\n";
        }
        if (bill['revisionReason'] != null && bill['revisionReason'].toString().isNotEmpty) {
          msg += "_Note: ${bill['revisionReason']}_\n";
        }
        msg += "\n";
      }

      msg +=
          "Hello *${widget.customerName}*,\n\n"
          "Your bill for $displayMonth:\n\n";

      if (totalWeight > 0 || totalWeight2 == 0) {
        double normalAmount = totalWeight * teaRate;
        msg += "Normal Leaf: *${totalWeight % 1 == 0 ? totalWeight.toInt() : totalWeight.toStringAsFixed(1)} kg*\n"
               "Normal Leaf Rate: *Rs ${currencyF.format(teaRate)}*\n"
               "Normal Leaf Value: *Rs ${currencyF.format(normalAmount)}*\n";
      }
      if (totalWeight2 > 0) {
        double superAmount = totalWeight2 * teaRate2;
        msg += "Super Leaf: *${totalWeight2 % 1 == 0 ? totalWeight2.toInt() : totalWeight2.toStringAsFixed(1)} kg*\n"
               "Super Leaf Rate: *Rs ${currencyF.format(teaRate2)}*\n"
               "Super Leaf Value: *Rs ${currencyF.format(superAmount)}*\n";
      }

      msg += "\nTotal Leaf Income: *Rs ${currencyF.format(grossIncome)}*\n\n";

      if (totalDeductions > 0) {
        msg += "Deductions:\n";
        if (advTotal > 0) {
          msg += "• Advance: *Rs ${currencyF.format(advTotal)}*\n";
        }
        if (f1Total > 0) {
          msg += "• Item 01: *Rs ${currencyF.format(f1Total)}*\n";
        }
        if (f2Total > 0) {
          msg += "• Item 02: *Rs ${currencyF.format(f2Total)}*\n";
        }
        if (t1Total > 0) {
          msg += "• Tea Packet 01: *Rs ${currencyF.format(t1Total)}*\n";
        }
        if (t2Total > 0) {
          msg += "• Tea Packet 02: *Rs ${currencyF.format(t2Total)}*\n";
        }
        if (transportCost > 0) {
          msg += "• Transport: *Rs ${currencyF.format(transportCost)}*\n";
        }
        if (otherCosts > 0) {
          msg += "• Other Deductions: *Rs ${currencyF.format(otherCosts)}*\n";
        }
        if (arrears > 0) {
          msg += "• Arrears: *Rs ${currencyF.format(arrears)}*\n";
        }
        msg += "\nTotal Deductions: *Rs ${currencyF.format(totalDeductions)}*\n\n";
      }

      List<String> companyLines = [
        _orgName,
        _companyLine1,
        _companyLine2,
        _companyLine3,
        _companyLine4,
        _contactNumbers,
      ];
      String companySignature = companyLines
          .where((l) => l.trim().isNotEmpty)
          .join('\n');

      msg +=
          "Net Payable: *Rs ${currencyF.format(netPayable)}*\n\n"
          "Thank you!\n$companySignature\n"
          "_powered by OrbitView Innovations_";
    }

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

class _BillDiffResult {
  final bool hasChanges;
  final bool isLatestAllowed;
  final Map<String, dynamic> currentBill;
  final String displayMonth;
  final String localizedDisplayMonth;
  final String ratesDocId;
  final double teaRate;
  final double teaRate2;
  final double transportRate;
  final double lastMonthArrears;
  final double newTotalW;
  final double newTotalW2;
  final double newGross;
  final double newAdvTotal;
  final double newTrans;
  final double newOther;
  final double newTotalDeductions;
  final double newNetPayable;
  final double newF1Q;
  final double newF1Amt;
  final double newF2Q;
  final double newF2Amt;
  final double newT1Q;
  final double newT1Amt;
  final double newT2Q;
  final double newT2Amt;
  final List<Map<String, dynamic>> newTableRows;

  _BillDiffResult({
    required this.hasChanges,
    required this.isLatestAllowed,
    required this.currentBill,
    required this.displayMonth,
    required this.localizedDisplayMonth,
    required this.ratesDocId,
    required this.teaRate,
    required this.teaRate2,
    required this.transportRate,
    required this.lastMonthArrears,
    required this.newTotalW,
    required this.newTotalW2,
    required this.newGross,
    required this.newAdvTotal,
    required this.newTrans,
    required this.newOther,
    required this.newTotalDeductions,
    required this.newNetPayable,
    required this.newF1Q,
    required this.newF1Amt,
    required this.newF2Q,
    required this.newF2Amt,
    required this.newT1Q,
    required this.newT1Amt,
    required this.newT2Q,
    required this.newT2Amt,
    required this.newTableRows,
  });
}
