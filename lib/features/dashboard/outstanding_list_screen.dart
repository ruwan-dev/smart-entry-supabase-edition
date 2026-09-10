import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OutstandingListScreen extends StatefulWidget {
  final List<Map<String, dynamic>> arrearsList;

  const OutstandingListScreen({super.key, required this.arrearsList});

  @override
  State<OutstandingListScreen> createState() => _OutstandingListScreenState();
}

class _OutstandingListScreenState extends State<OutstandingListScreen> {
  final currencyF = NumberFormat('#,##0.00', 'en_US');
  final weightF = NumberFormat('#,##0.##', 'en_US');

  bool _isLoading = true;
  Map<String, double> _avgLeavesMap = {};

  // Settings
  double _deductionPercentage = 40.0;
  final TextEditingController _rateController = TextEditingController(text: "200");
  int _selectedMonths = 3;

  // Pagination & Sorting State
  List<Map<String, dynamic>> _displayList = [];
  int _currentPage = 1;
  final int _itemsPerPage = 5;
  String _sortOption = 'amount_desc'; 

  @override
  void initState() {
    super.initState();
    _displayList = List.from(widget.arrearsList);
    _applySorting();
    _fetchAllAverages();
  }

  Future<void> _fetchAllAverages() async {
    setState(() => _isLoading = true);
    try {
      int daysToSubtract = _selectedMonths * 30;
      DateTime targetPastDate = DateTime.now().subtract(Duration(days: daysToSubtract));
      
      var snapshot = await Supabase.instance.client
          .from('daily_entries') 
          .select('customerId, netWeight')
          .gte('timestamp', targetPastDate.toIso8601String());

      Map<String, double> totals = {};
      
      for (var data in snapshot) {
        String cId = data['customerId'] ?? '';
        double w = (data['netWeight'] ?? 0).toDouble();
        totals[cId] = (totals[cId] ?? 0.0) + w;
      }

      Map<String, double> averages = {};
      totals.forEach((key, value) {
        averages[key] = value / _selectedMonths; 
      });

      if (mounted) {
        setState(() {
          _avgLeavesMap = averages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('දත්ත ලබාගැනීමේ දෝෂයක්: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _applySorting() {
    setState(() {
      if (_sortOption == 'amount_desc') {
        _displayList.sort((a, b) => (b['amount'] ?? 0).toDouble().compareTo((a['amount'] ?? 0).toDouble()));
      } else if (_sortOption == 'amount_asc') {
        _displayList.sort((a, b) => (a['amount'] ?? 0).toDouble().compareTo((b['amount'] ?? 0).toDouble()));
      } else if (_sortOption == 'name_asc') {
        _displayList.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      } else if (_sortOption == 'name_desc') {
        _displayList.sort((a, b) => (b['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      } else if (_sortOption == 'ref_asc') {
        _displayList.sort((a, b) {
          String refA = (a['customerNumber'] ?? '').toString();
          String refB = (b['customerNumber'] ?? '').toString();
          
          double? numA = double.tryParse(refA);
          double? numB = double.tryParse(refB);
          
          if (numA != null && numB != null) {
            return numA.compareTo(numB);
          }
          return refA.compareTo(refB);
        });
      }
      _currentPage = 1; 
    });
  }

  int get _totalPages => (_displayList.isEmpty) ? 1 : (_displayList.length / _itemsPerPage).ceil();

  List<Map<String, dynamic>> get _paginatedList {
    int start = (_currentPage - 1) * _itemsPerPage;
    int end = start + _itemsPerPage;
    if (end > _displayList.length) end = _displayList.length;
    if (start >= _displayList.length) return [];
    return _displayList.sublist(start, end);
  }

  // සංශෝධනය කරන ලද Recovery Time Function එක
  String _getRecoveryTime(double loan, double monthlyDeduction) {
    if (monthlyDeduction <= 0) return "අයකරගත නොහැක";
    
    // ආසන්නතම අගයට රවුම් කිරීම (round)
    int totalMonths = (loan / monthlyDeduction).round();
    
    // මාස 1කට වඩා අඩු නම් අවම වශයෙන් මාස 1ක් ලෙස පෙන්වීම
    if (totalMonths < 1) {
      totalMonths = 1;
    }
    
    return "මාස $totalMonths";
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Widget _buildSkeletonItem() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonBox(width: 40, height: 40, shape: BoxShape.circle),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 150, height: 16),
                    SizedBox(height: 8),
                    SkeletonBox(width: 80, height: 12),
                  ],
                ),
              ),
              const SkeletonBox(width: 80, height: 20),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: const [
                    SkeletonBox(width: 60, height: 10),
                    SizedBox(height: 8),
                    SkeletonBox(width: 50, height: 12),
                  ],
                ),
                Container(width: 1, height: 30, color: const Color(0xFFE5E7EB)),
                Column(
                  children: const [
                    SkeletonBox(width: 60, height: 10),
                    SizedBox(height: 8),
                    SkeletonBox(width: 70, height: 12),
                  ],
                ),
                Container(width: 1, height: 30, color: const Color(0xFFE5E7EB)),
                Column(
                  children: const [
                    SkeletonBox(width: 60, height: 10),
                    SizedBox(height: 8),
                    SkeletonBox(width: 50, height: 12),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: 5, 
      separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
      itemBuilder: (context, index) => _buildSkeletonItem(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Outstanding Balance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: Color(0xFF4B5563)),
            tooltip: 'Sort List',
            onSelected: (value) {
              _sortOption = value;
              _applySorting();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'amount_desc', child: Text('Highest Loan First')),
              const PopupMenuItem(value: 'amount_asc', child: Text('Lowest Loan First')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'name_asc', child: Text('Name (A-Z)')),
              const PopupMenuItem(value: 'name_desc', child: Text('Name (Z-A)')),
              const PopupMenuItem(value: 'ref_asc', child: Text('Ref Num (0-9)')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Control Panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      flex: 3,
                      child: Text('මාසික කපාගැනීමේ %', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF374151))),
                    ),
                    Expanded(
                      flex: 5,
                      child: Slider(
                        value: _deductionPercentage,
                        min: 10,
                        max: 100,
                        divisions: 18,
                        label: '${_deductionPercentage.round()}%',
                        activeColor: const Color(0xFF2563EB), 
                        inactiveColor: Colors.blue.shade100,
                        onChanged: (val) => setState(() => _deductionPercentage = val),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text('${_deductionPercentage.round()}%', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2563EB), fontSize: 14), textAlign: TextAlign.right),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('තේ දළු කිලෝ 1 ක මිල: Rs.', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF374151))),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 80,
                          height: 36,
                          child: TextField(
                            controller: _rateController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF3F4F6),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                            onChanged: (val) => setState(() {}), 
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('සාමාන්‍යය සඳහා මාස ගණන:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF374151))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [3, 6, 12, 24].map((month) {
                          bool isSelected = _selectedMonths == month;
                          return InkWell(
                            onTap: () {
                              if (_selectedMonths != month) {
                                setState(() {
                                  _selectedMonths = month;
                                });
                                _fetchAllAverages(); 
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isSelected ? const Color(0xFF2563EB) : Colors.transparent),
                              ),
                              child: Text(
                                '$month',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // List View Area 
          Expanded(
            child: _displayList.isEmpty
                ? const Center(child: Text('කිසිදු හිඟ මුදලක් නොමැත 🎉', style: TextStyle(fontSize: 16, color: Color(0xFF10B981), fontWeight: FontWeight.w600)))
                : _isLoading
                    ? _buildSkeletonList() 
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: _paginatedList.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                        itemBuilder: (context, index) {
                          var arrear = _paginatedList[index];
                          String cId = arrear['id'] ?? 'N/A';
                          String cNum = arrear['customerNumber']?.toString() ?? '';
                          if (cNum.isEmpty) cNum = cId; 
                          
                          // Calculations
                          double avgKilos = _avgLeavesMap[cId] ?? 0.0;
                          double rate = double.tryParse(_rateController.text) ?? 200.0;
                          double estimatedMonthlyIncome = avgKilos * rate;
                          double monthlyDeductionLimit = estimatedMonthlyIncome * (_deductionPercentage / 100);
                          double loanAmount = (arrear['amount'] ?? 0).toDouble();
                          String recoveryTime = _getRecoveryTime(loanAmount, monthlyDeductionLimit);

                          int actualRowNumber = ((_currentPage - 1) * _itemsPerPage) + index + 1;

                          return Container(
                            color: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: const Color(0xFFEFF6FF), 
                                      child: Text(
                                        '$actualRowNumber', 
                                        style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w700, fontSize: 14)
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            arrear['name'] ?? 'Unknown', 
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF111827))
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Ref: $cNum', 
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Rs. ${currencyF.format(loanAmount)}',
                                      style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w800, fontSize: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFF3F4F6)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildMetric('Avg Leaves', '${weightF.format(avgKilos)} Kg', const Color(0xFF059669)),
                                      Container(width: 1, height: 30, color: const Color(0xFFE5E7EB)),
                                      _buildMetric('Credit Limit', 'Rs. ${currencyF.format(monthlyDeductionLimit)}', const Color(0xFF2563EB)),
                                      Container(width: 1, height: 30, color: const Color(0xFFE5E7EB)),
                                      _buildMetric('Recovery Time', recoveryTime, const Color(0xFFD97706)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Pagination Controls
          if (_displayList.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${((_currentPage - 1) * _itemsPerPage) + 1} to ${((_currentPage * _itemsPerPage) > _displayList.length) ? _displayList.length : (_currentPage * _itemsPerPage)} of ${_displayList.length}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            border: Border.all(color: _currentPage > 1 ? const Color(0xFFD1D5DB) : Colors.transparent),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.chevron_left_rounded, size: 20, color: _currentPage > 1 ? const Color(0xFF374151) : const Color(0xFFD1D5DB)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Page $_currentPage of $_totalPages',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                      ),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            border: Border.all(color: _currentPage < _totalPages ? const Color(0xFFD1D5DB) : Colors.transparent),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.chevron_right_rounded, size: 20, color: _currentPage < _totalPages ? const Color(0xFF374151) : const Color(0xFFD1D5DB)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }
}

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const SkeletonBox({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
  }) : super(key: key);

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _colorAnimation = ColorTween(begin: const Color(0xFFE5E7EB), end: const Color(0xFFF3F4F6)).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: _colorAnimation.value,
          borderRadius: widget.shape == BoxShape.circle ? null : BorderRadius.circular(widget.borderRadius),
          shape: widget.shape,
        ),
      ),
    );
  }
}