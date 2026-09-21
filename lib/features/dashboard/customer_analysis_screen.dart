import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/widgets/skeleton_box.dart';
import 'package:smart_entry/core/app_state.dart';

class CustomerAnalysisScreen extends StatefulWidget {
  const CustomerAnalysisScreen({super.key});

  @override
  State<CustomerAnalysisScreen> createState() => _CustomerAnalysisScreenState();
}

class _CustomerAnalysisScreenState extends State<CustomerAnalysisScreen> {
  bool _isLoading = true;
  int _totalCustomers = 0;
  int _activeCustomers = 0;
  int _debtorCustomers = 0;
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _inactiveCustomersList = [];
  Map<String, double> _customerDebts = {};
  Map<String, DateTime> _latestDates = {};
  Map<String, double> _latestMonthWeights = {};

  int _platinumCount = 0;
  int _goldCount = 0;
  int _silverCount = 0;
  int _riskCount = 0;
  double _highVolumeThreshold = 150.0;
  Map<String, String> _customerTiers = {};

  final Color primaryAppColor = const Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    _fetchAnalysisData();
  }

  Future<void> _fetchAnalysisData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      try {
        var settingDoc = await Supabase.instance.client
            .from('global_settings')
            .select().eq('organization_id', AppState.currentOrganizationId.value ?? '')
            .eq('id', 'rating_config')
            .maybeSingle();
        if (settingDoc != null && settingDoc['highVolumeThreshold'] != null) {
          _highVolumeThreshold = (settingDoc['highVolumeThreshold'] as num)
              .toDouble();
        }
      } catch (_) {}

      // 1. Get all customers
      var customersSnap = await Supabase.instance.client
          .from('customers')
          .select('id, name, phone, refNumber').eq('organization_id', AppState.currentOrganizationId.value ?? '');
      _totalCustomers = customersSnap.length;

      // 2. Get active customers (active within last 45 days to match rating logic)
      DateTime now = DateTime.now();
      DateTime startDate = now.subtract(const Duration(days: 45));

      var entriesSnap = await Supabase.instance.client
          .from('daily_entries')
          .select('customerId').eq('organization_id', AppState.currentOrganizationId.value ?? '')
          .gte('timestamp', startDate.toIso8601String());

      Set<String> activeIds = {};
      for (var entry in entriesSnap) {
        if (entry['customerId'] != null) {
          activeIds.add(entry['customerId'].toString());
        }
      }
      _activeCustomers = activeIds.length;

      // Identify inactive customers
      _inactiveCustomersList = customersSnap
          .where((c) => !activeIds.contains(c['id'].toString()))
          .toList();
      _inactiveCustomersList.sort(
        (a, b) => (a['refNumber'] ?? '').compareTo(b['refNumber'] ?? ''),
      );

      // 3. Get debtors from latest finalized bills
      var allFinalizedBills = await Supabase.instance.client
          .from('finalized_bills')
          .select('customerId, billData').eq('organization_id', AppState.currentOrganizationId.value ?? '')
          .order('finalizedAt', ascending: false);

      Map<String, double> latestArrears = {};
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
          if (netPayable < 0) {
            latestArrears[cId] = netPayable.abs();
          }
        }
      }
      _debtorCustomers = latestArrears.length;

      // 4. Fetch weights for ALL customers to calculate ratings
      _latestDates.clear();
      _latestMonthWeights.clear();
      _customerDebts = latestArrears;

      List<String> allCustomerIds = customersSnap
          .map((c) => c['id'].toString())
          .toList();
      Map<String, Map<String, double>> monthlyWeights = {};

      for (int i = 0; i < allCustomerIds.length; i += 100) {
        int end = (i + 100 < allCustomerIds.length)
            ? i + 100
            : allCustomerIds.length;
        var chunk = allCustomerIds.sublist(i, end);
        List<dynamic> allEntries = [];
        int offset = 0;
        int limit = 1000;
        while (true) {
          var res = await Supabase.instance.client
              .from('daily_entries')
              .select('customerId, timestamp, netWeight').eq('organization_id', AppState.currentOrganizationId.value ?? '')
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
            if (!_latestDates.containsKey(cId) ||
                ts.isAfter(_latestDates[cId]!)) {
              _latestDates[cId] = ts;
            }
          }

          String monthKey = "${ts.year}-${ts.month.toString().padLeft(2, '0')}";
          monthlyWeights.putIfAbsent(cId, () => {});
          monthlyWeights[cId]![monthKey] =
              (monthlyWeights[cId]![monthKey] ?? 0.0) + weight;
        }
      }

      int platinum = 0, gold = 0, silver = 0, risk = 0;
      Map<String, String> customerTiers = {};

      for (String cId in allCustomerIds) {
        double vol = 0.0;
        DateTime? lastDate = _latestDates[cId];
        if (lastDate != null) {
          String monthKey =
              "${lastDate.year}-${lastDate.month.toString().padLeft(2, '0')}";
          vol = monthlyWeights[cId]?[monthKey] ?? 0.0;
          _latestMonthWeights[cId] = vol;
        }

        bool hasDebt = latestArrears.containsKey(cId);
        bool isActive =
            lastDate != null &&
            DateTime.now().difference(lastDate).inDays <= 45;

        String tier;
        if (hasDebt && !isActive) {
          tier = "Risk";
          risk++;
        } else if (vol >= _highVolumeThreshold && !hasDebt && isActive) {
          tier = "Platinum";
          platinum++;
        } else if (vol >= 50.0 && !hasDebt) {
          tier = "Gold";
          gold++;
        } else if (hasDebt) {
          tier = "Risk";
          risk++;
        } else {
          tier = "Silver";
          silver++;
        }

        customerTiers[cId] = tier;
      }

      if (mounted) {
        setState(() {
          _platinumCount = platinum;
          _goldCount = gold;
          _silverCount = silver;
          _riskCount = risk;
          _customerTiers = customerTiers;
          _allCustomers = List<Map<String, dynamic>>.from(customersSnap);
          _isLoading = false;
        });
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching customer analysis: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.blueGrey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    int inactive = _totalCustomers - _activeCustomers;
    if (_totalCustomers == 0) return const SizedBox();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: _activeCustomers.toDouble(),
                    title: '$_activeCustomers',
                    color: const Color(0xFF10B981),
                    radius: 40,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: inactive.toDouble(),
                    title: '$inactive',
                    color: const Color(0xFFEF4444),
                    radius: 40,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegend(const Color(0xFF10B981), "ක්‍රියාකාරී (Active)"),
              const SizedBox(height: 12),
              _buildLegend(const Color(0xFFEF4444), "අක්‍රිය (Inactive)"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingDistribution() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ශ්‍රේණිගත කිරීම් අනුව (By Rating)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildRatingImageWidget(
              'Platinum',
              '$_platinumCount',
              Colors.amber.shade900,
              'assets/badges/badge_diamond.png', // Diamond crystal for Platinum
            ),
            _buildRatingImageWidget(
              'Gold',
              '$_goldCount',
              Colors.orange.shade900,
              'assets/badges/badge_gold.png',
            ),
            _buildRatingImageWidget(
              'Silver',
              '$_silverCount',
              Colors.blueGrey.shade800,
              'assets/badges/badge_platinum.png', // Silver colored
            ),
            _buildRatingImageWidget(
              'Risk',
              '$_riskCount',
              Colors.red.shade800,
              'assets/badges/badge_ruby.png', // Red ruby for Risk
            ),
          ],
        ),
      ],
    );
  }

  void _showTierCustomers(
    String tier,
    String label,
    Color color,
    String imagePath,
  ) {
    List<Map<String, dynamic>> tierCustomers = _allCustomers
        .where((c) => _customerTiers[c['id'].toString()] == tier)
        .toList();
    tierCustomers.sort((a, b) {
      DateTime? dateA = _latestDates[a['id'].toString()];
      DateTime? dateB = _latestDates[b['id'].toString()];
      if (dateA == null && dateB == null)
        return (a['name'] ?? '').compareTo(b['name'] ?? '');
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TierCustomersScreen(
          tierName: label,
          color: color,
          customers: tierCustomers,
          latestMonthWeights: _latestMonthWeights,
          customerDebts: _customerDebts,
          latestDates: _latestDates,
          imagePath: imagePath,
        ),
      ),
    );
  }

  Widget _buildRatingImageWidget(
    String tierCode,
    String count,
    Color color,
    String imagePath,
  ) {
    return InkWell(
      onTap: () => _showTierCustomers(tierCode, tierCode, color, imagePath),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  imagePath,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              count,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String tier) {
    String label;
    Color bgColor;
    Color textColor;
    String imagePath;

    switch (tier) {
      case "Platinum":
        label = "Platinum";
        bgColor = Colors.amber.shade100;
        textColor = Colors.amber.shade900;
        imagePath = "assets/badges/badge_diamond.png";
        break;
      case "Gold":
        label = "Gold";
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        imagePath = "assets/badges/badge_gold.png";
        break;
      case "Risk":
        label = "Risk";
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        imagePath = "assets/badges/badge_ruby.png";
        break;
      default:
        label = "Silver";
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
        imagePath = "assets/badges/badge_platinum.png";
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Image.asset(imagePath, width: 60, height: 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'පාරිභෝගික විශ්ලේෂණය',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade200, height: 1.0),
        ),
      ),
      body: _isLoading
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonBox(width: 150, height: 24),
                      SkeletonBox(width: 120, height: 32),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: const [
                      Expanded(
                        child: SkeletonBox(width: double.infinity, height: 100),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: SkeletonBox(width: double.infinity, height: 100),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SkeletonBox(width: double.infinity, height: 200),
                  const SizedBox(height: 32),
                  const SkeletonBox(width: 200, height: 24),
                  const SizedBox(height: 12),
                  ...List.generate(
                    4,
                    (index) => const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: SkeletonBox(width: double.infinity, height: 80),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'සමස්ත දත්ත',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 450) {
                        return Column(
                          children: [
                        _buildStatCard(
                            'මුළු පාරිභෝගිකයින්',
                            '$_totalCustomers',
                            Icons.people_alt_rounded,
                            primaryAppColor,
                        ),
                            const SizedBox(height: 12),
                        _buildStatCard(
                            'ණය සහිත අය',
                            '$_debtorCustomers',
                            Icons.account_balance_wallet_rounded,
                            const Color(0xFFD32F2F),
                        ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                          'මුළු පාරිභෝගිකයින්',
                          '$_totalCustomers',
                          Icons.people_alt_rounded,
                          primaryAppColor,
                        ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                          'ණය සහිත අය',
                          '$_debtorCustomers',
                          Icons.account_balance_wallet_rounded,
                          const Color(0xFFD32F2F),
                        ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildPieChart(),
                  const SizedBox(height: 24),
                  _buildRatingDistribution(),
                  const SizedBox(height: 32),
                  const Text(
                    'අක්‍රිය පාරිභෝගිකයින්',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_inactiveCustomersList.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          "සියලුම පාරිභෝගිකයින් සක්‍රියයි!",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._inactiveCustomersList.map((customer) {
                      String cId = customer['id'].toString();
                      DateTime? lastDate = _latestDates[cId];
                      double lastMonthWeight = _latestMonthWeights[cId] ?? 0.0;
                      double debt = _customerDebts[cId] ?? 0.0;

                      String lastDateStr = lastDate != null
                          ? "${lastDate.year}-${lastDate.month.toString().padLeft(2, '0')}-${lastDate.day.toString().padLeft(2, '0')}"
                          : "දත්ත නොමැත";
                      String weightStr = lastDate != null
                          ? "${lastMonthWeight.toStringAsFixed(1)} Kg"
                          : "-";
                      String debtStr = debt > 0
                          ? "Rs. ${debt.toStringAsFixed(2)}"
                          : "නැත";
                      String tier = _customerTiers[cId] ?? "Silver";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFEE2E2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person_off_rounded,
                                      color: Color(0xFFEF4444),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          customer['name'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                        Text(
                                          'යොමුව: ${customer['refNumber']}',
                                          style: TextStyle(
                                            color: Colors.blueGrey.shade600,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildBadge(tier),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const Text(
                                          "එම මාසයේ දළු",
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
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          "හිඟ මුදල (ණය)",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blueGrey,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          debtStr,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: debt > 0
                                                ? const Color(0xFFDC2626)
                                                : Colors.blueGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class TierCustomersScreen extends StatelessWidget {
  final String tierName;
  final Color color;
  final List<Map<String, dynamic>> customers;
  final Map<String, double> latestMonthWeights;
  final Map<String, double> customerDebts;
  final Map<String, DateTime> latestDates;
  final String imagePath;

  const TierCustomersScreen({
    Key? key,
    required this.tierName,
    required this.color,
    required this.customers,
    required this.latestMonthWeights,
    required this.customerDebts,
    required this.latestDates,
    required this.imagePath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          '$tierName පාරිභෝගිකයින්',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        centerTitle: true,
      ),
      body: customers.isEmpty
          ? Center(
              child: Text(
                "මෙම ශ්‍රේණියේ පාරිභෝගිකයින් නැත.",
                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: customers.length,
              itemBuilder: (context, index) {
                var customer = customers[index];
                String cId = customer['id'].toString();
                double lastMonthWeight = latestMonthWeights[cId] ?? 0.0;
                double debt = customerDebts[cId] ?? 0.0;
                DateTime? lastDate = latestDates[cId];
                String dateStr = lastDate != null
                    ? "${lastDate.year}-${lastDate.month.toString().padLeft(2, '0')}-${lastDate.day.toString().padLeft(2, '0')}"
                    : "දත්ත නොමැත";

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // Per-tile watermark badge
                        Positioned(
                          right: -10,
                          bottom: -10,
                          child: Opacity(
                            opacity: 0.15,
                            child: Image.asset(
                              imagePath,
                              width: 130,
                              height: 130,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        // Tile content
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: color,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer['name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      debt > 0
                                          ? 'යොමුව: ${customer['refNumber']} | ණය: Rs.${debt.toStringAsFixed(2)}'
                                          : 'යොමුව: ${customer['refNumber']}',
                                      style: TextStyle(
                                        color: Colors.blueGrey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'අවසන් දින: $dateStr',
                                      style: TextStyle(
                                        color: Colors.blueGrey.shade400,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'අවසන් දළු ප්‍රමාණය',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                  Text(
                                    '${lastMonthWeight.toStringAsFixed(1)} Kg',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
