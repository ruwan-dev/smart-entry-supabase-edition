import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_entry/core/entries/daily_entries_screen.dart';
import 'package:smart_entry/core/app_state.dart';
import '../billing/monthly_bill_screen.dart';
import 'add_customer_screen.dart';
import 'package:smart_entry/core/widgets/skeleton_box.dart';
import '../localization/app_strings.dart';
import '../localization/app_language.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  String _searchQuery = '';

  int _currentPage = 0;
  final int _itemsPerPage = 5;

  // ----------------------------------------------------------------------
  // ----------------------------------------------------------------------
  final Color _primaryColor = const Color(0xFF4A4ECA);
  final Color _backgroundColor = const Color(0xFFF9FAFC);
  final Color _cardColor = Colors.white;
  final Color _textColorPrimary = const Color(0xFF1E293B);
  final Color _textColorSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);

  final Color _statusGreenBg = const Color(0xFFF0FDF4); // Green 50
  final Color _statusGreenText = const Color(0xFF4ADE80); // Green 400 (Soft)
  final Color _tagPurpleBg = const Color(0xFFFAF5FF); // Purple 50
  final Color _tagPurpleText = const Color(0xFFC084FC); // Purple 400 (Soft)

  Future<void> _deleteCustomer(
    BuildContext context,
    String docId,
    String name,
  ) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(AppStrings.deleteCustomerConfirm),
            content: Text(
              AppStrings.deleteCustomerPrompt(name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  AppStrings.no,
                  style: TextStyle(color: _textColorSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  elevation: 0,
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(AppStrings.yesDelete),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await Supabase.instance.client
            .from('daily_entries')
            .delete()
            .eq('organization_id', AppState.currentOrganizationId.value ?? '')
            .eq('customerId', docId);

        await Supabase.instance.client
            .from('customers')
            .delete()
            .eq('organization_id', AppState.currentOrganizationId.value ?? '')
            .eq('id', docId);

        if (context.mounted) {
          Navigator.pop(context);
          AppState.triggerRefresh();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.customerDeleted,
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppStrings.errorPrefix}$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>>? _cachedCustomers;
  String? _errorMessage;
  bool _isFetching = false;
  bool _pendingFetch = false;

  Map<String, DateTime> _latestDates = {};
  Map<String, double> _latestMonthWeights = {};
  Set<String> _debtors = {};
  Set<String> _customersWithBillChanges = {};
  double _highVolumeThreshold = 150.0;

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    AppLanguageService.currentLanguage.addListener(_onLanguageChanged);
    AppState.refreshTrigger.addListener(_fetchCustomers);
    _fetchCustomers();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchCustomers() async {
    if (_isFetching) {
      _pendingFetch = true;
      return;
    }
    _isFetching = true;
    try {
      try {
        final orgId = AppState.currentOrganizationId.value ?? '';
        var settingDoc = await Supabase.instance.client
            .from('global_settings')
            .select()
            .eq('organization_id', orgId)
            .or('id.eq.rating_config,id.eq.${orgId}_rating_config')
            .maybeSingle();
        if (settingDoc != null && settingDoc['highVolumeThreshold'] != null) {
          _highVolumeThreshold = (settingDoc['highVolumeThreshold'] as num)
              .toDouble();
        }
      } catch (_) {}

      var allFinalizedBills = await Supabase.instance.client
          .from('finalized_bills')
          .select('customerId, billData')
          .eq('organization_id', AppState.currentOrganizationId.value ?? '')
          .order('finalizedAt', ascending: false);

      Set<String> debtors = {};
      Set<String> processedCids = {};
      for (var bill in allFinalizedBills) {
        String cId = bill['customerId'] ?? '';
        if (cId.isEmpty || processedCids.contains(cId)) continue;
        processedCids.add(cId);

        var billData = bill['billData'];
        if (billData is Map) {
          double netPayable = (billData['netPayable'] ?? 0.0) is num
              ? (billData['netPayable'] ?? 0.0).toDouble()
              : double.tryParse(billData['netPayable'].toString()) ?? 0.0;
          if (netPayable < 0) debtors.add(cId);
        }
      }

      final response = await Supabase.instance.client
          .from('customers')
          .select()
          .eq('organization_id', AppState.currentOrganizationId.value ?? '')
          .order('name');
      List<Map<String, dynamic>> customers = List<Map<String, dynamic>>.from(
        response,
      );

      List<String> customerIds = customers
          .map((c) => c['id'].toString())
          .toList();
      Map<String, DateTime> latestDates = {};
      Map<String, Map<String, double>> monthlyWeights = {};
      Map<String, Map<String, double>> monthlyWeights1 = {};
      Map<String, Map<String, double>> monthlyWeights2 = {};
      Map<String, Map<String, double>> monthlyAdvances = {};

      for (int i = 0; i < customerIds.length; i += 100) {
        int end = (i + 100 < customerIds.length) ? i + 100 : customerIds.length;
        var chunk = customerIds.sublist(i, end);
        List<dynamic> allEntries = [];
        int offset = 0;
        int limit = 1000;
        while (true) {
          var res = await Supabase.instance.client
              .from('daily_entries')
              .select('customerId, timestamp, netWeight, netWeight2, advanceAmount')
              .eq('organization_id', AppState.currentOrganizationId.value ?? '')
              .filter('customerId', 'in', chunk)
              .range(offset, offset + limit - 1);
          allEntries.addAll(res);
          if (res.length < limit) break;
          offset += limit;
        }

        for (var e in allEntries) {
          String cId = e['customerId'].toString();
          DateTime ts = DateTime.parse(e['timestamp'].toString());
          double w1 = _parseDouble(e['netWeight']);
          double w2 = _parseDouble(e['netWeight2']);
          double adv = _parseDouble(e['advanceAmount']);
          double weight = w1 + w2;

          if (weight > 0) {
            if (!latestDates.containsKey(cId) ||
                ts.isAfter(latestDates[cId]!)) {
              latestDates[cId] = ts;
            }
          }

          String monthKey = "${ts.year}-${ts.month.toString().padLeft(2, '0')}";
          monthlyWeights.putIfAbsent(cId, () => {});
          monthlyWeights[cId]![monthKey] =
              (monthlyWeights[cId]![monthKey] ?? 0.0) + weight;

          monthlyWeights1.putIfAbsent(cId, () => {});
          monthlyWeights1[cId]![monthKey] =
              (monthlyWeights1[cId]![monthKey] ?? 0.0) + w1;

          monthlyWeights2.putIfAbsent(cId, () => {});
          monthlyWeights2[cId]![monthKey] =
              (monthlyWeights2[cId]![monthKey] ?? 0.0) + w2;

          monthlyAdvances.putIfAbsent(cId, () => {});
          monthlyAdvances[cId]![monthKey] =
              (monthlyAdvances[cId]![monthKey] ?? 0.0) + adv;
        }
      }

      Map<String, double> latestMonthWeights = {};
      for (String cId in customerIds) {
        if (latestDates.containsKey(cId)) {
          DateTime lastDate = latestDates[cId]!;
          String monthKey =
              "${lastDate.year}-${lastDate.month.toString().padLeft(2, '0')}";
          latestMonthWeights[cId] = monthlyWeights[cId]?[monthKey] ?? 0.0;
        }
      }

      Set<String> customersWithBillChanges = {};
      Set<String> checkedBillCids = {};
      for (var bill in allFinalizedBills) {
        String cId = bill['customerId'] ?? '';
        if (cId.isEmpty || checkedBillCids.contains(cId)) continue;
        checkedBillCids.add(cId);

        var billData = bill['billData'];
        if (billData is Map) {
          String dm = billData['displayMonth'] ?? '';
          final parts = dm.trim().split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            int y = int.tryParse(parts[0]) ?? 0;
            const monthNames = [
              'january', 'february', 'march', 'april', 'may', 'june',
              'july', 'august', 'september', 'october', 'november', 'december'
            ];
            int m = monthNames.indexOf(parts[1].toLowerCase()) + 1;
            if (y > 0 && m > 0) {
              String monthKey = "$y-${m.toString().padLeft(2, '0')}";
              double recordedW1 = _parseDouble(billData['totalWeight']);
              double recordedW2 = _parseDouble(billData['totalWeight2']);
              double recordedAdv = _parseDouble(billData['advTotal']);

              double actualW1 = monthlyWeights1[cId]?[monthKey] ?? 0.0;
              double actualW2 = monthlyWeights2[cId]?[monthKey] ?? 0.0;
              double actualAdv = monthlyAdvances[cId]?[monthKey] ?? 0.0;

              bool hasChanges = (recordedW1 - actualW1).abs() > 0.01 ||
                                (recordedW2 - actualW2).abs() > 0.01 ||
                                (recordedAdv - actualAdv).abs() > 0.01;

              if (hasChanges) {
                customersWithBillChanges.add(cId);
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _latestDates = latestDates;
          _latestMonthWeights = latestMonthWeights;
          _debtors = debtors;
          _customersWithBillChanges = customersWithBillChanges;
          _cachedCustomers = customers;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      _isFetching = false;
      if (_pendingFetch && mounted) {
        _pendingFetch = false;
        _fetchCustomers();
      }
    }
  }

  @override
  void dispose() {
    AppLanguageService.currentLanguage.removeListener(_onLanguageChanged);
    AppState.refreshTrigger.removeListener(_fetchCustomers);
    super.dispose();
  }

  Widget _buildSkeletonItem() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SkeletonBox(width: 80, height: 24, borderRadius: 4),
              const SkeletonBox(width: 100, height: 24, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonBox(width: 150, height: 16),
          const SizedBox(height: 6),
          const SkeletonBox(width: double.infinity, height: 12),
          const SizedBox(height: 16),
          Row(
            children: const [
              SkeletonBox(width: 70, height: 30, borderRadius: 6),
              SizedBox(width: 8),
              SkeletonBox(width: 70, height: 30, borderRadius: 6),
              SizedBox(width: 8),
              SkeletonBox(width: 36, height: 30, borderRadius: 6),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildSkeletonItem(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          AppStrings.isSinhala ? 'පාරිභෝගික ලැයිස්තුව' : 'Customer List',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _textColorPrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: _borderColor, height: 1.0),
        ),
      ),
      floatingActionButton: MediaQuery.of(context).size.width >= 600
          ? FloatingActionButton.extended(
              heroTag: 'customer_form_add_fab',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddCustomerScreen()),
                );
                _fetchCustomers(); // Refresh the list after adding a new customer
              },
              backgroundColor: _primaryColor,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: Text(
                AppStrings.addCustomer,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 100.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 48,
              child: TextField(
                decoration: InputDecoration(
                  labelText: AppStrings.isSinhala ? 'නම හෝ අංකය මගින් සොයන්න' : 'Search by name or number',
                  labelStyle: TextStyle(
                    color: _textColorSecondary,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: _textColorSecondary,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _primaryColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                    _currentPage = 0;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    "Error: $_errorMessage",
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            else if (_cachedCustomers == null)
              _buildSkeletonList()
            else ...[
              Builder(
                builder: (context) {
                  var filteredDocs = _cachedCustomers!.where((data) {
                    String name = (data['name'] ?? '').toString().toLowerCase();
                    String ref = (data['refNumber'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(_searchQuery) ||
                        ref.contains(_searchQuery);
                  }).toList();

                  filteredDocs.sort((a, b) {
                    String refA = (a['refNumber'] ?? '').toString();
                    String refB = (b['refNumber'] ?? '').toString();

                    double? numA = double.tryParse(refA);
                    double? numB = double.tryParse(refB);

                    if (numA != null && numB != null) {
                      return numA.compareTo(numB);
                    }
                    return refA.compareTo(refB);
                  });

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(AppStrings.noCustomersFound),
                      ),
                    );
                  }

                  // 2. Pagination Logic
                  int totalPages = (filteredDocs.length / _itemsPerPage).ceil();

                  if (_currentPage >= totalPages && totalPages > 0) {
                    _currentPage = totalPages - 1;
                  }

                  var paginatedDocs = filteredDocs
                      .skip(_currentPage * _itemsPerPage)
                      .take(_itemsPerPage)
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: paginatedDocs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          var data = paginatedDocs[index];

                          return _buildResponsiveCustomerItem(data['id'], data);
                        },
                      ),

                      const SizedBox(height: 24),

                      if (totalPages > 1)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios, size: 16),
                              color: _currentPage > 0
                                  ? _primaryColor
                                  : Colors.grey,
                              onPressed: _currentPage > 0
                                  ? () => setState(() => _currentPage--)
                                  : null,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _borderColor),
                              ),
                              child: Text(
                                '${AppStrings.page} ${_currentPage + 1} / $totalPages',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              color: _currentPage < totalPages - 1
                                  ? _primaryColor
                                  : Colors.grey,
                              onPressed: _currentPage < totalPages - 1
                                  ? () => setState(() => _currentPage++)
                                  : null,
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildResponsiveCustomerItem(String docId, Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusGreenBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _statusGreenText.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _statusGreenText,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${AppStrings.refPrefix}${data['refNumber'] ?? ''}',
                      style: TextStyle(
                        color: _statusGreenText,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _tagPurpleBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone, size: 12, color: _tagPurpleText),
                        const SizedBox(width: 4),
                        Text(
                          data['phone'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: _tagPurpleText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // PIN tag
                  if ((data['pin'] ?? '').toString().isNotEmpty && MediaQuery.of(context).size.width >= 600)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 12, color: Colors.orange.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'PIN: ${data['pin']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Text(
                  data['name'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _textColorPrimary,
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  double volume = _latestMonthWeights[docId] ?? 0.0;
                  DateTime? lastDate = _latestDates[docId];
                  bool hasDebt = _debtors.contains(docId);
                  bool isActive =
                      lastDate != null &&
                      DateTime.now().difference(lastDate).inDays <= 45;

                  String imagePath;

                  if (hasDebt && !isActive) {
                    imagePath = "assets/badges/badge_ruby.png";
                  } else if (volume >= _highVolumeThreshold &&
                      !hasDebt &&
                      isActive) {
                    imagePath = "assets/badges/badge_diamond.png";
                  } else if (volume >= 50.0 && !hasDebt) {
                    imagePath = "assets/badges/badge_gold.png";
                  } else if (hasDebt) {
                    imagePath = "assets/badges/badge_ruby.png";
                  } else {
                    imagePath = "assets/badges/badge_platinum.png";
                  }

                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Image.asset(imagePath, width: 60, height: 60),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            data['address'] ?? '',
            style: TextStyle(fontSize: 12, color: _textColorSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),

          Builder(
            builder: (context) {
              DateTime? lastDate = _latestDates[docId];
              double lastMonthWeight = _latestMonthWeights[docId] ?? 0.0;

              String lastDateStr = lastDate != null
                  ? "${lastDate.year}-${lastDate.month.toString().padLeft(2, '0')}-${lastDate.day.toString().padLeft(2, '0')}"
                  : (AppStrings.isSinhala ? "දත්ත නොමැත" : "No Data");
              String weightStr = lastDate != null
                  ? "${lastMonthWeight.toStringAsFixed(1)} Kg"
                  : "-";

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.isSinhala ? "අවසන් දළු දුන් දිනය" : "Last Supply Date",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lastDateStr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.isSinhala ? "එම මාසයේ මුළු දළු" : "Monthly Total Leaf",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          weightStr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildActionButton(
                label: AppStrings.isSinhala ? 'සටහන්' : 'Entries',
                icon: Icons.add_chart,
                color: Colors.teal.shade400,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DailyEntriesScreen(
                        initialCustomerId: docId,
                        initialRefNumber: data['refNumber'] ?? '',
                      ),
                    ),
                  ).then((_) => _fetchCustomers());
                },
              ),
              _buildActionButton(
                label: AppStrings.isSinhala ? 'බිල්පත' : 'Bill',
                icon: Icons.receipt_long,
                color: Colors.lightBlue.shade400,
                badgeText: _customersWithBillChanges.contains(docId)
                    ? AppStrings.billChangesDetected
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MonthlyBillScreen(
                        customerId: docId,
                        customerName: data['name'] ?? '',
                        refNumber: data['refNumber'] ?? '',
                      ),
                    ),
                  ).then((_) => _fetchCustomers());
                },
              ),
              if (MediaQuery.of(context).size.width >= 600) ...[
                _buildActionButton(
                  label: 'PIN',
                  icon: Icons.lock_reset,
                  color: Colors.orange.shade400,
                  onTap: () => _showEditPinDialog(context, docId, data['name'] ?? ''),
                ),
                InkWell(
                  onTap: () =>
                      _deleteCustomer(context, docId, data['name'] ?? ''),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red.shade300.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.red.shade50,
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // --- Edit PIN Dialog ---
  void _showEditPinDialog(BuildContext context, String docId, String customerName) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$customerName - ${AppStrings.isSinhala ? 'PIN වෙනස් කරන්න' : 'Change PIN'}'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppStrings.isSinhala ? 'අලුත් 6-digit PIN' : 'New 6-digit PIN',
            prefixIcon: const Icon(Icons.lock),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              String newPin = pinController.text.trim();
              if (newPin.length != 6) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(AppStrings.isSinhala ? 'PIN 6 ඉලක්කම් විය යුතුය.' : 'PIN must be 6 digits.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              await Supabase.instance.client
                  .from('customers')
                  .update({'pin': newPin})
                  .eq('organization_id', AppState.currentOrganizationId.value ?? '')
                  .eq('id', docId);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(AppStrings.isSinhala ? 'PIN සාර්ථකව වෙනස් විය!' : 'PIN changed successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text(AppStrings.save, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- Action Button Component ---
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    final effectiveColor = badgeText != null ? Colors.amber.shade800 : color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: badgeText != null ? Colors.amber.shade700 : color.withValues(alpha: 0.3),
            width: badgeText != null ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(6),
          color: badgeText != null ? Colors.amber.shade50 : color.withValues(alpha: 0.05),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: effectiveColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// --- Submit Button Component ---
class SLongButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color primaryColor;
  const SLongButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        child: child,
      ),
    );
  }
}
