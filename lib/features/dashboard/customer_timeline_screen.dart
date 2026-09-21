import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/skeleton_box.dart';
import 'package:smart_entry/core/app_state.dart';

class CustomerTimelineScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String refNumber;

  const CustomerTimelineScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.refNumber,
  });

  @override
  State<CustomerTimelineScreen> createState() => _CustomerTimelineScreenState();
}

class _CustomerTimelineScreenState extends State<CustomerTimelineScreen> {
  final currencyF = NumberFormat('#,##0.00', 'en_US');
  bool _isLoading = true;
  List<Map<String, dynamic>> _timelineData = [];

  @override
  void initState() {
    super.initState();
    _fetchTimelineData();
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _fetchTimelineData() async {
    try {
      var billsSnap = await Supabase.instance.client
          .from('finalized_bills')
          .select('billData, finalizedAt').eq('organization_id', AppState.currentOrganizationId.value ?? '')
          .eq('customerId', widget.customerId)
          .order('finalizedAt', ascending: false);

      List<Map<String, dynamic>> data = [];
      for (var doc in billsSnap) {
        var b = doc['billData'];
        if (b != null) {
          double totalWeight = 0;
          double totalWeight2 = 0;
          double totalAdvances = 0;
          if (b['tableRows'] != null) {
             for(var r in b['tableRows']) {
                totalWeight += _parseDouble(r['weight']);
                totalWeight2 += _parseDouble(r['weight2']);
                if (r['items'] != null) {
                  for (var item in r['items']) {
                    if (item['desc'] == 'Advance') {
                      totalAdvances += _parseDouble(item['amt']);
                    }
                  }
                }
             }
          }

          data.add({
            'month': b['displayMonth'] ?? 'Unknown',
            'grossIncome': _parseDouble(b['grossIncome']),
            'netPayable': _parseDouble(b['netPayable']),
            'arrears': _parseDouble(b['arrears']),
            'weight': totalWeight,
            'weight2': totalWeight2,
            'advances': totalAdvances,
            'finalizedAt': doc['finalizedAt']
          });
        }
      }

      setState(() {
        _timelineData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text('${widget.customerName} - History', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
      ),
      body: _isLoading 
        ? _buildSkeleton()
        : _timelineData.isEmpty 
          ? const Center(child: Text('කිසිදු ඉතිහාසයක් නොමැත.', style: TextStyle(fontSize: 16, color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _timelineData.length,
              itemBuilder: (context, index) {
                var item = _timelineData[index];
                bool isDebt = item['netPayable'] < 0;
                return _buildTimelineNode(item, isLast: index == _timelineData.length - 1, isDebt: isDebt);
              },
            ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 25),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(width: 36, height: 36, shape: BoxShape.circle),
              const SizedBox(width: 15),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonBox(width: 120, height: 20),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          SkeletonBox(width: 80, height: 16),
                          SkeletonBox(width: 60, height: 16),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          SkeletonBox(width: 100, height: 16),
                          SkeletonBox(width: 70, height: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimelineNode(Map<String, dynamic> item, {required bool isLast, required bool isDebt}) {
    Color statusColor = isDebt ? Colors.red.shade400 : Colors.green.shade500;
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line and dot
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor, width: 2),
                ),
                child: Center(
                  child: Icon(isDebt ? Icons.trending_down : Icons.trending_up, color: statusColor, size: 18),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 15),
          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 25),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                  border: Border.all(color: Colors.grey.shade100)
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(item['month'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)))),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isDebt ? 'DEBT' : 'CLEARED',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    _infoRow('ලබාදුන් සාමාන්‍ය දළු බර:', '${item['weight'].toStringAsFixed(1)} Kg'),
                    if ((item['weight2'] ?? 0) > 0)
                      _infoRow('ලබාදුන් සුපිරි දළු බර:', '${item['weight2'].toStringAsFixed(1)} Kg'),
                    _infoRow('දළ ආදායම:', 'Rs. ${currencyF.format(item['grossIncome'])}'),
                    _infoRow('ලබාගත් අත්තිකාරම්:', 'Rs. ${currencyF.format(item['advances'])}', color: Colors.orange.shade700),
                    if (item['arrears'] > 0)
                      _infoRow('පසුගිය හිඟ මුදල:', 'Rs. ${currencyF.format(item['arrears'])}', color: Colors.red.shade400),
                    const Divider(height: 20, color: Color(0xFFF3F4F6)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(child: Text('ශුද්ධ ශේෂය (Net Balance):', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4B5563)))),
                        const SizedBox(width: 8),
                        Text(
                          'Rs. ${currencyF.format(item['netPayable'])}', 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: statusColor)
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)))),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? const Color(0xFF374151))),
        ],
      ),
    );
  }
}
