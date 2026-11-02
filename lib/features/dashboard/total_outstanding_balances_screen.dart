import 'package:smart_entry/core/localization/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'customer_timeline_screen.dart';

class TotalOutstandingBalancesScreen extends StatefulWidget {
  final List<Map<String, dynamic>> arrearsList;

  const TotalOutstandingBalancesScreen({super.key, required this.arrearsList});

  @override
  State<TotalOutstandingBalancesScreen> createState() => _TotalOutstandingBalancesScreenState();
}

class _TotalOutstandingBalancesScreenState extends State<TotalOutstandingBalancesScreen> {
  final currencyF = NumberFormat('#,##0.00', 'en_US');

  // Pagination & Sorting State
  List<Map<String, dynamic>> _displayList = [];
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  String _sortOption = 'amount_desc'; 

  @override
  void initState() {
    super.initState();
    _displayList = List.from(widget.arrearsList);
    _applySorting();
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
        _displayList.sort((a, b) => (b['name'] ?? '').toString().compareTo((a['name'] ?? '').toString()));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Customer Outstanding Balances', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
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
              const PopupMenuItem(value: 'amount_desc', child: Text('Highest Balance First')),
              const PopupMenuItem(value: 'amount_asc', child: Text('Lowest Balance First')),
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
          // List View Area 
          Expanded(
            child: _displayList.isEmpty
                ? Center(child: Text(AppStrings.noOutstandingBalances, style: const TextStyle(fontSize: 16, color: Color(0xFF10B981), fontWeight: FontWeight.w600)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _paginatedList.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                    itemBuilder: (context, index) {
                      var arrear = _paginatedList[index];
                      String cId = arrear['id'] ?? 'N/A';
                      String cNum = arrear['customerNumber']?.toString() ?? '';
                      if (cNum.isEmpty) cNum = cId; 
                      
                      double loanAmount = (arrear['amount'] ?? 0).toDouble();
                      int actualRowNumber = ((_currentPage - 1) * _itemsPerPage) + index + 1;

                      return Material(
                        color: Colors.white,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CustomerTimelineScreen(
                                  customerId: cId,
                                  customerName: arrear['name'] ?? 'Unknown',
                                  refNumber: cNum,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Row(
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Rs. ${currencyF.format(loanAmount)}',
                                      style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w800, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('View History', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                                        SizedBox(width: 4),
                                        Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF2563EB)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
                  Expanded(
                    child: Text(
                      'Showing ${((_currentPage - 1) * _itemsPerPage) + 1} to ${((_currentPage * _itemsPerPage) > _displayList.length) ? _displayList.length : (_currentPage * _itemsPerPage)} of ${_displayList.length}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
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
}
