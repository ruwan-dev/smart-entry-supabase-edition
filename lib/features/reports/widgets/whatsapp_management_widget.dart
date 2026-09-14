import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:smart_entry/features/reports/widgets/whatsapp_batch_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared_report_state.dart';

class WhatsappManagementWidget extends StatefulWidget {
  const WhatsappManagementWidget({super.key});

  @override
  State<WhatsappManagementWidget> createState() =>
      _WhatsappManagementWidgetState();
}

class _WhatsappManagementWidgetState extends State<WhatsappManagementWidget> {
  final int _currentYear = DateTime.now().year;
  late int _selectedMonth;

  bool _isLoading = false;
  bool _hasFinalizedBills = false;
  List<Map<String, dynamic>> _billingList = [];
  String _companyLine1 = 'SmartEntry';
  String _companyLine2 = '';
  String _companyLine3 = '';
  String _companyLine4 = '';
  String _companyLine5 = '';

  final List<String> _monthLabels = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  final List<String> _sinhalaMonths = [
    "ජනවාරි",
    "පෙබරවාරි",
    "මාර්තු",
    "අප්‍රේල්",
    "මැයි",
    "ජූනි",
    "ජූලි",
    "අගෝස්තු",
    "සැප්තැම්බර්",
    "ඔක්තෝබර්",
    "නොවැම්බර්",
    "දෙසැම්බර්",
  ];

  @override
  void initState() {
    super.initState();
    _selectedMonth = SharedReportState.selectedMonth.value;
    SharedReportState.selectedMonth.addListener(_onSharedMonthChanged);
    _loadCompanyName();
    _fetchFinalizedBills();
  }

  void _onSharedMonthChanged() {
    if (_selectedMonth != SharedReportState.selectedMonth.value) {
      if (mounted) {
        setState(() {
          _selectedMonth = SharedReportState.selectedMonth.value;
        });
        _fetchFinalizedBills();
      }
    }
  }

  @override
  void dispose() {
    SharedReportState.selectedMonth.removeListener(_onSharedMonthChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _companyLine1 = prefs.getString('company_line_1') ?? 'SmartEntry';
      _companyLine2 = prefs.getString('company_line_2') ?? '';
      _companyLine3 = prefs.getString('company_line_3') ?? '';
      _companyLine4 = prefs.getString('company_line_4') ?? '';
      _companyLine5 = prefs.getString('company_line_5') ?? '';
    });
  }

  String _searchQuery = "";
  int _currentPage = 0;
  final int _rowsPerPage = 5;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> get _filteredList {
    if (_searchQuery.isEmpty) return _billingList;
    return _billingList.where((item) {
      String name = (item['name'] ?? '').toString().toLowerCase();
      String ref = (item['ref'] ?? '').toString().toLowerCase();
      String q = _searchQuery.toLowerCase();
      return name.contains(q) || ref.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _paginatedList {
    var filtered = _filteredList;
    int start = _currentPage * _rowsPerPage;
    if (start >= filtered.length) return [];
    int end = start + _rowsPerPage;
    if (end > filtered.length) end = filtered.length;
    return filtered.sublist(start, end);
  }

  int get _totalPages {
    int len = _filteredList.length;
    if (len == 0) return 1;
    return (len / _rowsPerPage).ceil();
  }

  Future<void> _fetchFinalizedBills() async {
    setState(() {
      _isLoading = true;
      _billingList.clear();
      _hasFinalizedBills = false;
      _currentPage = 0;
    });

    try {
      String displayMonth = "$_currentYear ${_monthLabels[_selectedMonth - 1]}";
      String monthKey = displayMonth.replaceAll(' ', '-');

      // 1. Fetch finalized bills for this month
      var billsRes = await Supabase.instance.client
          .from('finalized_bills')
          .select()
          .like('id', '%_$monthKey');

      if (billsRes.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. Fetch customers to get their phone numbers
      var customersRes = await Supabase.instance.client
          .from('customers')
          .select('id, phone');
      Map<String, String> phoneMap = {};
      for (var c in customersRes) {
        String cId = c['id'].toString();
        phoneMap[cId] = (c['phone'] ?? '').toString().trim();
      }

      // 3. Combine them
      List<Map<String, dynamic>> combined = [];
      for (var b in billsRes) {
        var billData = b['billData'];
        String customerId = b['customerId'].toString();
        String phone = phoneMap[customerId] ?? '';
        bool isSent = billData != null && billData['whatsapp_sent'] == true;

        combined.add({
          'id': b['id'],
          'customerId': customerId,
          'name': b['customerName'],
          'ref': b['refNumber'],
          'phone': phone,
          'bill': billData,
          'isSent': isSent,
        });
      }

      // Sort by ref number
      combined.sort(
        (a, b) => (int.tryParse(a['ref'].toString()) ?? 0).compareTo(
          int.tryParse(b['ref'].toString()) ?? 0,
        ),
      );

      setState(() {
        _billingList = combined;
        _hasFinalizedBills = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching finalized bills: $e");
      setState(() => _isLoading = false);
    }
  }

  String _buildWhatsAppMessage(String name, dynamic bill) {
    final currencyF = NumberFormat('#,##0.00');
    double grossIncome = (bill['grossIncome'] ?? 0).toDouble();
    double totalDeductions = (bill['totalDeductions'] ?? 0).toDouble();
    double netPayable = (bill['netPayable'] ?? 0).toDouble();

    double teaRate = (bill['teaRate'] ?? 0).toDouble();
    double teaRate2 = (bill['teaRate2'] ?? 0).toDouble();
    double totalWeight = (bill['totalWeight'] ?? 0).toDouble();
    double totalWeight2 = (bill['totalWeight2'] ?? 0).toDouble();

    // Fallback if older bills don't have totalWeight stored
    if (totalWeight == 0 && totalWeight2 == 0 && teaRate > 0) {
      totalWeight = grossIncome / teaRate;
    }

    double advTotal = (bill['advTotal'] ?? 0).toDouble();
    double f1Total = (bill['f1Total'] ?? 0).toDouble();
    double f2Total = (bill['f2Total'] ?? 0).toDouble();
    double t1Total = (bill['t1Total'] ?? 0).toDouble();
    double t2Total = (bill['t2Total'] ?? 0).toDouble();
    double transportCost = (bill['transportCost'] ?? 0).toDouble();
    double arrears = (bill['arrears'] ?? 0).toDouble();

    String msg =
        "ආයුබෝවන් *$name*,\n\n"
        "ඔබගේ ${_sinhalaMonths[_selectedMonth - 1]} මාසයේ බිල්පත:\n\n";

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

  void _sendWhatsAppBatch({required bool onlyUnsent}) {
    List<Map<String, dynamic>> billsToSend = [];

    for (var item in _billingList) {
      String phone = (item['phone'] ?? '').toString().trim();
      bool isSent = item['isSent'] == true;

      if (phone.isEmpty) continue;
      if (onlyUnsent && isSent) continue; // Skip already sent if requested

      var bill = item['bill'];
      if (bill == null) continue;

      String name = item['name'] ?? 'Unknown';
      String message = _buildWhatsAppMessage(name, bill);

      billsToSend.add({"id": item['id'], "phone": phone, "message": message});
    }

    if (billsToSend.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'යැවීමට අලුත් බිල්පත් හෝ දුරකථන අංක නොමැත! (No matching bills/phones found)',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    WhatsAppBatchDialog.show(context, billsToSend).then((_) {
      // Re-fetch when dialog closes to show updated 'Sent' status
      _fetchFinalizedBills();
    });
  }

  void _sendSingleWhatsApp(Map<String, dynamic> item) {
    String phone = (item['phone'] ?? '').toString().trim();
    if (phone.isEmpty) return;

    String name = item['name'] ?? 'Unknown';
    var bill = item['bill'];
    if (bill == null) return;

    String message = _buildWhatsAppMessage(name, bill);

    WhatsAppBatchDialog.show(context, [
      {"id": item['id'], "phone": phone, "message": message},
    ]).then((_) {
      _fetchFinalizedBills();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 800;

              Widget leftPane = ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    constraints: BoxConstraints(minHeight: isWide ? 360 : 0),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8B9CB2).withOpacity(0.3),
                          const Color(0xFF8B9CB2).withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B9CB2).withOpacity(0.1),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Month Selector Box
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.6),
                                      Colors.white.withOpacity(0.2),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.6),
                                    width: 1.5,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_month,
                                        color: Color(0xFF1F2937),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$_currentYear',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _selectedMonth,
                                            isExpanded: true,
                                            icon: const Icon(
                                              Icons.keyboard_arrow_down,
                                              color: Color(0xFF1F2937),
                                            ),
                                            dropdownColor: Colors.white,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1F2937),
                                            ),
                                            items: List.generate(12, (index) {
                                              return DropdownMenuItem(
                                                value: index + 1,
                                                child: Text(
                                                  _monthLabels[index],
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              );
                                            }),
                                            onChanged: (val) {
                                              if (val != null) {
                                                SharedReportState
                                                        .selectedMonth
                                                        .value =
                                                    val;
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // State specific UI (Loader, Error or Button)
                          if (_isLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (!_hasFinalizedBills)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.5),
                                        Colors.white.withOpacity(0.1),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.6),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade600
                                                .withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.orange.shade600,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Not Finalized",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange.shade600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                "මෙම මාසයේ ගිණුම් පියවීම අවසන් කර නැත.",
                                                style: TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
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
                            )
                          else
                            Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.green.withOpacity(0.5),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _sendWhatsAppBatch(
                                            onlyUnsent: true,
                                          ),
                                          child: Center(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.send,
                                                  size: 16,
                                                  color: Colors.green.shade600,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "SEND TO UNSENT ONLY (යැවීමට ඉතිරි)",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color:
                                                        Colors.green.shade700,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.blue.withOpacity(0.5),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _sendWhatsAppBatch(
                                            onlyUnsent: false,
                                          ),
                                          child: Center(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.replay,
                                                  size: 16,
                                                  color: Colors.blue.shade600,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "RESEND TO ALL (සියල්ලන්ටම නැවත යවන්න)",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              Widget rightPane = ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/whatsapp_bg.jpg',
                  fit: BoxFit.cover,
                  height: isWide ? 360 : 240,
                  width: double.infinity,
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: leftPane),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: rightPane),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [leftPane, const SizedBox(height: 24), rightPane],
                );
              }
            },
          ),
          if (!_isLoading && _hasFinalizedBills) ...[
            const SizedBox(height: 32),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                const Text(
                  "තනි බිල්පත් (Individual Bills)",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                SizedBox(
                  width: 300,
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _currentPage = 0;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search Name or Ref...",
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: Colors.blueGrey,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Color(0xFF0096C7)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_filteredList.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    "No matching bills found.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else ...[
              // Individual List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _paginatedList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  var item = _paginatedList[index];
                  String name = item['name'] ?? 'Unknown';
                  String ref = item['ref'] ?? 'N/A';
                  String phone = (item['phone'] ?? '').toString().trim();
                  double net = (item['bill']?['netPayable'] ?? 0.0).toDouble();
                  final currencyF = NumberFormat('#,##0.00');

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (ref != 'N/A')
                                Text(
                                  "Ref: $ref",
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade400,
                                    fontSize: 11,
                                  ),
                                ),
                              if (phone.isNotEmpty)
                                Text(
                                  phone,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              if (phone.isEmpty)
                                Text(
                                  "දුරකථන අංකයක් නොමැත",
                                  style: TextStyle(
                                    color: Colors.red.shade400,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          "Rs ${currencyF.format(net)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0096C7),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item['isSent'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: Colors.blue.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Sent",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (item['isSent'] == true)
                              const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                item['isSent'] == true
                                    ? Icons.replay
                                    : Icons.message,
                                color: phone.isEmpty
                                    ? Colors.grey
                                    : (item['isSent'] == true
                                          ? Colors.blue
                                          : Colors.green),
                              ),
                              tooltip: item['isSent'] == true
                                  ? "Resend WhatsApp"
                                  : "Send WhatsApp",
                              onPressed: phone.isEmpty
                                  ? null
                                  : () => _sendSingleWhatsApp(item),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Pagination Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Material(
                    color: _currentPage > 0
                        ? Colors.white
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.chevron_left,
                          color: _currentPage > 0
                              ? Colors.black87
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Text(
                    "Page ${_currentPage + 1} of $_totalPages",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Material(
                    color: _currentPage < _totalPages - 1
                        ? Colors.white
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _currentPage < _totalPages - 1
                          ? () => setState(() => _currentPage++)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          color: _currentPage < _totalPages - 1
                              ? Colors.black87
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
