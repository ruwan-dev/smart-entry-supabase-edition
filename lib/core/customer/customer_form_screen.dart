import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_entry/core/entries/daily_entries_screen.dart';
import '../billing/monthly_bill_screen.dart';
import 'add_customer_screen.dart';
import 'package:smart_entry/core/widgets/skeleton_box.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _refNumberController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  bool _isLoading = false;
  String _searchQuery = '';

  // Pagination සඳහා අවශ්‍ය විචල්‍යයන් (Variables)
  int _currentPage = 0;
  final int _itemsPerPage = 5; // එක පිටුවකට පෙන්වන ප්‍රමාණය

  // ----------------------------------------------------------------------
  // UI වර්ණ රටාව
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

  Future<void> _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String refNumber = _refNumberController.text.trim();
        String name = _nameController.text.trim();

        var querySnapshot = await Supabase.instance.client
            .from('customers')
            .select()
            .eq('refNumber', refNumber);

        if (querySnapshot.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('මෙම යොමු අංකය දැනටමත් භාවිතයේ පවතී'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }

        var response = await Supabase.instance.client.from('customers').insert({
          'refNumber': refNumber,
          'name': name,
          'address': _addressController.text.trim(),
          'phone': _phoneController.text.trim(),
          'pin': _pinController.text.trim(),
        }).select();

        String docId = response.first['id'];

        _refNumberController.clear();
        _nameController.clear();
        _addressController.clear();
        _phoneController.clear();
        _pinController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('පාරිභෝගිකයා සාර්ථකව සුරකින ලදී')),
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DailyEntriesScreen(
                initialCustomerId: docId,
                initialRefNumber: refNumber,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('දෝෂයකි: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

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
            title: const Text('පාරිභෝගිකයා ඉවත් කරන්නද?'),
            content: Text(
              'ඔබ ස්ථිරවම $name සහ ඔහුට/ඇයට අදාළ සියලුම තේ දළු හා අත්තිකාරම් සටහන් පද්ධතියෙන් ඉවත් කිරීමට අවශ්‍යද?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'නැත',
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
                child: const Text('ඔව්, ඉවත් කරන්න'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await Supabase.instance.client
            .from('daily_entries')
            .delete()
            .eq('customerId', docId);

        await Supabase.instance.client
            .from('customers')
            .delete()
            .eq('id', docId);

        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'පාරිභෝගිකයා සහ අදාළ සියලුම සටහන් සාර්ථකව ඉවත් කරන ලදී',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('දෝෂයකි: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>>? _cachedCustomers;
  String? _errorMessage;

  Map<String, DateTime> _latestDates = {};
  Map<String, double> _latestMonthWeights = {};
  Set<String> _debtors = {};
  double _highVolumeThreshold = 150.0;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    try {
      try {
        var settingDoc = await Supabase.instance.client
            .from('global_settings')
            .select()
            .eq('id', 'rating_config')
            .maybeSingle();
        if (settingDoc != null && settingDoc['highVolumeThreshold'] != null) {
          _highVolumeThreshold = (settingDoc['highVolumeThreshold'] as num)
              .toDouble();
        }
      } catch (_) {}

      var allFinalizedBills = await Supabase.instance.client
          .from('finalized_bills')
          .select('customerId, billData')
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
          .order('name');
      List<Map<String, dynamic>> customers = List<Map<String, dynamic>>.from(
        response,
      );

      List<String> customerIds = customers
          .map((c) => c['id'].toString())
          .toList();
      Map<String, DateTime> latestDates = {};
      Map<String, Map<String, double>> monthlyWeights = {};

      for (int i = 0; i < customerIds.length; i += 100) {
        int end = (i + 100 < customerIds.length) ? i + 100 : customerIds.length;
        var chunk = customerIds.sublist(i, end);
        List<dynamic> allEntries = [];
        int offset = 0;
        int limit = 1000;
        while (true) {
          var res = await Supabase.instance.client
              .from('daily_entries')
              .select('customerId, timestamp, netWeight')
              .filter('customerId', 'in', chunk)
              .range(offset, offset + limit - 1);
          allEntries.addAll(res);
          if (res.length < limit) break;
          offset += limit;
        }

        for (var e in allEntries) {
          String cId = e['customerId'].toString();
          DateTime ts = DateTime.parse(e['timestamp'].toString());
          double weight = (e['netWeight'] ?? 0.0).toDouble();

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

      if (mounted) {
        setState(() {
          _latestDates = latestDates;
          _latestMonthWeights = latestMonthWeights;
          _debtors = debtors;
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
    }
  }

  @override
  void dispose() {
    _refNumberController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
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
        title: const Text(
          'පාරිභෝගික ලැයිස්තුව',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
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
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddCustomerScreen()),
                );
                _fetchCustomers(); // Refresh the list after adding a new customer
              },
              backgroundColor: _primaryColor,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text(
                'නව පාරිභෝගිකයෙකු',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 100.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- සෙවීම් තීරුව ---
            SizedBox(
              height: 48,
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'නම හෝ අංකය මගින් සොයන්න',
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
                    _currentPage = 0; // Search කරන විට මුල් පිටුවට යාමට
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // --- පාරිභෝගික ලැයිස්තුව සහ Pagination ---
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
                  // 1. Search කිරීම (Filter)
                  var filteredDocs = _cachedCustomers!.where((data) {
                    String name = (data['name'] ?? '').toString().toLowerCase();
                    String ref = (data['refNumber'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(_searchQuery) ||
                        ref.contains(_searchQuery);
                  }).toList();

                  // 2. Ref Number අනුව පිළිවෙළට සැකසීම (Sort)
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
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("පාරිභෝගිකයින් කිසිවෙකු හමුවුණේ නැත."),
                      ),
                    );
                  }

                  // 2. Pagination Logic
                  int totalPages = (filteredDocs.length / _itemsPerPage).ceil();

                  // (ආරක්ෂිත පියවරක්: currentPage එක totalPages වලට වඩා වැඩි නම්)
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
                      // List එක පෙන්වීම
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

                      // --- Pagination Controls පෙන්වීම ---
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
                                'පිටුව ${_currentPage + 1} / $totalPages',
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

  // --- Input Field Component ---
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _textColorSecondary, fontSize: 14),
        prefixIcon: Icon(icon, color: _textColorSecondary, size: 20),
        filled: true,
        fillColor: _backgroundColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primaryColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 12,
        ),
      ),
      style: TextStyle(color: _textColorPrimary, fontSize: 14),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
      validator: (value) => value == null || value.isEmpty ? 'අවශ්‍ය වේ' : null,
    );
  }

  // --- Responsive Customer Item (RenderFlex Overflow එක විසඳීම සඳහා) ---
  Widget _buildResponsiveCustomerItem(String docId, Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      padding: const EdgeInsets.all(16), // Padding එක
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. උඩ පේළිය: යොමු අංකය සහ දුරකථන අංකය
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              // යොමු අංකය
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusGreenBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _statusGreenText.withOpacity(0.2)),
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
                      'යොමුව: ${data['refNumber'] ?? ''}',
                      style: TextStyle(
                        color: _statusGreenText,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // දුරකථන අංකය සහ PIN
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

          // 2. මැද කොටස: නම සහ ලිපිනය
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

                  String label;
                  Color bgColor;
                  Color textColor;
                  String imagePath;

                  if (hasDebt && !isActive) {
                    label = "Risk";
                    bgColor = Colors.red.shade50;
                    textColor = Colors.red.shade700;
                    imagePath = "assets/badges/badge_ruby.png";
                  } else if (volume >= _highVolumeThreshold &&
                      !hasDebt &&
                      isActive) {
                    label = "Platinum";
                    bgColor = Colors.amber.shade100;
                    textColor = Colors.amber.shade900;
                    imagePath = "assets/badges/badge_diamond.png";
                  } else if (volume >= 50.0 && !hasDebt) {
                    label = "Gold";
                    bgColor = Colors.orange.shade50;
                    textColor = Colors.orange.shade800;
                    imagePath = "assets/badges/badge_gold.png";
                  } else if (hasDebt) {
                    label = "Risk";
                    bgColor = Colors.red.shade50;
                    textColor = Colors.red.shade700;
                    imagePath = "assets/badges/badge_ruby.png";
                  } else {
                    label = "Silver";
                    bgColor = Colors.grey.shade100;
                    textColor = Colors.grey.shade800;
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

          // 2.5 මෑත දත්ත
          Builder(
            builder: (context) {
              DateTime? lastDate = _latestDates[docId];
              double lastMonthWeight = _latestMonthWeights[docId] ?? 0.0;

              String lastDateStr = lastDate != null
                  ? "${lastDate.year}-${lastDate.month.toString().padLeft(2, '0')}-${lastDate.day.toString().padLeft(2, '0')}"
                  : "දත්ත නොමැත";
              String weightStr = lastDate != null
                  ? "${lastMonthWeight.toStringAsFixed(1)} Kg"
                  : "-";

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "අවසන් දළු දුන් දිනය",
                          style: TextStyle(
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
                        const Text(
                          "එම මාසයේ මුළු දළු",
                          style: TextStyle(
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

          // 3. යට පේළිය: ක්‍රියාකාරකම් බොත්තම් (Wrap භාවිතා කර ඇත, එබැවින් ඉඩ මදි නම් ඊළඟ පේළියට යයි)
          Wrap(
            spacing: 8, // බොත්තම් අතර තිරස් පරතරය
            runSpacing: 8, // පේළි අතර සිරස් පරතරය
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildActionButton(
                label: 'සටහන්',
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
                  );
                },
              ),
              _buildActionButton(
                label: 'බිල්පත',
                icon: Icons.receipt_long,
                color: Colors.lightBlue.shade400,
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
                  );
                },
              ),
              if (MediaQuery.of(context).size.width >= 600) ...[
                _buildActionButton(
                  label: 'PIN',
                  icon: Icons.lock_reset,
                  color: Colors.orange.shade400,
                  onTap: () => _showEditPinDialog(context, docId, data['name'] ?? ''),
                ),
              // Delete බොත්තම
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
                      border: Border.all(color: Colors.red.shade300.withOpacity(0.5)),
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
        title: Text('$customerName - PIN වෙනස් කරන්න'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'අලුත් 6-digit PIN',
            prefixIcon: Icon(Icons.lock),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('අවලංගු'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              String newPin = pinController.text.trim();
              if (newPin.length != 6) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('PIN 6 ඉලක්කම් විය යුතුය.'), backgroundColor: Colors.red),
                );
                return;
              }
              await Supabase.instance.client
                  .from('customers')
                  .update({'pin': newPin})
                  .eq('id', docId);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('PIN සාර්ථකව වෙනස් විය!'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('සුරකින්න', style: TextStyle(color: Colors.white)),
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
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
