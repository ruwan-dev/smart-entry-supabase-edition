import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_entry/core/entries/daily_entry_form_screen.dart'; 
import 'package:smart_entry/core/entries/factory_entry_form_screen.dart'; 
import '../app_state.dart';
import '../items/item_service.dart';
import '../localization/app_strings.dart';
import '../localization/app_language.dart';
import '../../services/billing_lock_service.dart';

class DailyEntriesScreen extends StatefulWidget {
  final String? initialCustomerId;
  final String? initialRefNumber;

  const DailyEntriesScreen({super.key, this.initialCustomerId, this.initialRefNumber});

  @override
  State<DailyEntriesScreen> createState() => _DailyEntriesScreenState();
}

class _DailyEntriesScreenState extends State<DailyEntriesScreen> {
  DateTime _selectedMonth = DateTime.now();

  String? _selectedCustomerId;
  final TextEditingController _refController = TextEditingController();
  List<Map<String, dynamic>> _allCustomers = []; 
  List<Map<String, dynamic>> _allFactories = []; 
  List<Map<String, dynamic>> _monthlyEntries = [];
  bool _isLoadingEntries = false;
  bool _isFactoryMode = false;

  @override
  void initState() {
    super.initState();
    AppLanguageService.currentLanguage.addListener(_onLanguageChanged);
    AppState.refreshTrigger.addListener(_onRefresh);

    if (widget.initialCustomerId != null) {
      _selectedCustomerId = widget.initialCustomerId;
      _refController.text = widget.initialRefNumber ?? '';
    }
    _loadData();
  }

  void _onRefresh() {
    if (mounted) {
      _loadData();
    }
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppLanguageService.currentLanguage.removeListener(_onLanguageChanged);
    AppState.refreshTrigger.removeListener(_onRefresh);
    _refController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      BillingLockService().fetchLatestFinalizedMonth(),
      _loadCustomersAndFactories(),
      _loadMonthlyEntries(),
    ]);
  }

  Future<void> _loadCustomersAndFactories() async {
    final orgId = AppState.currentOrganizationId.value ?? '';
    if (orgId.isEmpty) return;
    try {
      final customersRes = await Supabase.instance.client
          .from('customers')
          .select()
          .eq('organization_id', orgId)
          .order('name');
      final factoriesRes = await Supabase.instance.client
          .from('factories')
          .select()
          .eq('organization_id', orgId)
          .order('name');

      if (mounted) {
        setState(() {
          _allCustomers = List<Map<String, dynamic>>.from(customersRes);
          _allFactories = List<Map<String, dynamic>>.from(factoriesRes);
        });
      }
    } catch (e) {
      debugPrint('Error loading customers/factories: $e');
    }
  }

  Future<void> _loadMonthlyEntries() async {
    final orgId = AppState.currentOrganizationId.value ?? '';
    if (orgId.isEmpty) return;

    if (mounted) setState(() => _isLoadingEntries = true);
    try {
      String monthPrefix = DateFormat('yyyy-MM').format(_selectedMonth);
      int lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
      String lastDayStr = lastDay.toString().padLeft(2, '0');

      final res = await Supabase.instance.client
          .from(_isFactoryMode ? 'factory_entries' : 'daily_entries')
          .select()
          .eq('organization_id', orgId)
          .gte('date', '$monthPrefix-01')
          .lte('date', '$monthPrefix-$lastDayStr');

      if (mounted) {
        setState(() {
          _monthlyEntries = List<Map<String, dynamic>>.from(res);
          _isLoadingEntries = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading monthly entries: $e');
      if (mounted) setState(() => _isLoadingEntries = false);
    }
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + monthsToAdd, 1);
    });
    _loadMonthlyEntries();
  }

  void _onDateTapped(int day) {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFactoryMode
              ? (AppStrings.isSinhala ? 'කරුණාකර කර්මාන්තශාලාවක් තෝරන්න' : 'Please select a factory')
              : (AppStrings.isSinhala ? 'කරුණාකර පාරිභෝගිකයෙකු තෝරන්න' : 'Please select a customer')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final entryDate = DateTime(_selectedMonth.year, _selectedMonth.month, day);
    final isLocked = BillingLockService().isDateLocked(entryDate);

    if (_isFactoryMode) {
      var factory = _allFactories.firstWhere((c) => c['id'] == _selectedCustomerId);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FactoryEntryFormScreen(
            selectedDate: entryDate,
            factoryId: _selectedCustomerId!,
            factoryName: factory['name'],
            refNumber: factory['refNumber'],
            isReadOnly: isLocked,
          ),
        ),
      );
    } else {
      var customer = _allCustomers.firstWhere((c) => c['id'] == _selectedCustomerId);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DailyEntryFormScreen(
            selectedDate: entryDate,
            customerId: _selectedCustomerId!,
            customerName: customer['name'],
            refNumber: customer['refNumber'],
            isReadOnly: isLocked,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String monthName = DateFormat('MMMM yyyy').format(_selectedMonth);
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    
    Color activeColor = _isFactoryMode ? const Color(0xFF06B6D4) : Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: _isFactoryMode ? const Color(0xFFECFEFF) : null,
      appBar: AppBar(
        title: Text(AppStrings.dailyEntries),
        backgroundColor: _isFactoryMode ? const Color(0xFFECFEFF) : null, elevation: 0,
        foregroundColor: _isFactoryMode ? const Color(0xFF1F2937) : null,
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: AppState.refreshTrigger,
        builder: (context, triggerValue, child) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                color: Colors.transparent,
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<bool>(
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: activeColor.withValues(alpha: 0.2),
                          selectedForegroundColor: activeColor,
                        ),
                        segments: [
                          ButtonSegment<bool>(
                            value: false,
                            label: Text(AppStrings.isSinhala ? 'ගනුදෙනුකරු' : 'Customer'),
                            icon: const Icon(Icons.person),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            label: Text(AppStrings.isSinhala ? 'කර්මාන්තශාලාව' : 'Factory'),
                            icon: const Icon(Icons.business),
                          ),
                        ],
                        selected: <bool>{_isFactoryMode},
                        onSelectionChanged: (Set<bool> newSelection) {
                          setState(() {
                            _isFactoryMode = newSelection.first;
                            _selectedCustomerId = null;
                            _refController.clear();
                          });
                          _loadMonthlyEntries();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                color: Colors.transparent,
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _refController,
                        decoration: InputDecoration(
                          labelText: AppStrings.refNumber, 
                          border: const OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: activeColor)),
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          final activeList = _isFactoryMode ? _allFactories : _allCustomers;
                          final match = activeList.where((c) => c['refNumber']?.toString() == value.trim()).toList();
                          setState(() {
                            _selectedCustomerId = match.isNotEmpty ? match.first['id'] : null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: AppStrings.name, 
                          border: const OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: activeColor)),
                        ),
                        isExpanded: true,
                        initialValue: _selectedCustomerId,
                        items: (_isFactoryMode ? _allFactories : _allCustomers).map((doc) {
                          return DropdownMenuItem<String>(value: doc['id'] as String, child: Text(doc['name'] as String));
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCustomerId = val;
                            final activeList = _isFactoryMode ? _allFactories : _allCustomers;
                            final match = activeList.where((c) => c['id'] == val).toList();
                            if (match.isNotEmpty) {
                              _refController.text = match.first['refNumber']?.toString() ?? '';
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
                color: activeColor.withValues(alpha: 0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 18),
                      onPressed: () => _changeMonth(-1),
                      color: activeColor,
                    ),
                    Text(
                      AppStrings.formatDisplayMonth(monthName),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: activeColor),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 18),
                      onPressed: () => _changeMonth(1),
                      color: activeColor,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    Map<int, Map<String, double>> totals = {};
                    
                    if (_selectedCustomerId != null) {
                      for (var doc in _monthlyEntries) {
                        String matchIdField = _isFactoryMode ? 'factoryId' : 'customerId';
                        if (doc[matchIdField] == _selectedCustomerId) {
                          try {
                            int day = int.parse(doc['date'].split('-')[2]);
                            
                            if (!totals.containsKey(day)) {
                              totals[day] = {'weight': 0.0, 'weight2': 0.0, 'advance': 0.0, 'items': 0.0};
                            }
                            
                            totals[day]!['weight'] = totals[day]!['weight']! + (doc['netWeight'] ?? 0).toDouble();
                            totals[day]!['weight2'] = totals[day]!['weight2']! + (doc['netWeight2'] ?? 0).toDouble();
                            totals[day]!['advance'] = totals[day]!['advance']! + (doc['advanceAmount'] ?? 0).toDouble();
                            
                            final parsed = ItemService.parseDailyEntryItems(doc);
                            totals[day]!['items'] = totals[day]!['items']! + parsed.totalItemsQty;
                          } catch (e) {
                            debugPrint('Error parsing entry for day: $e');
                          }
                        }
                      }
                    }

                    if (_isLoadingEntries && _monthlyEntries.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        double crossAxisSpacing = 4.0;
                        int crossAxisCount = 7;
                        if (constraints.maxWidth >= 1200) {
                          crossAxisCount = 14;
                        } else if (constraints.maxWidth >= 800) {
                          crossAxisCount = 10;
                        } else if (constraints.maxWidth >= 600) {
                          crossAxisCount = 7;
                        } else if (constraints.maxWidth >= 400) {
                          crossAxisCount = 5;
                        } else {
                          crossAxisCount = 4;
                        }

                        double paddingHorizontal = 16.0;
                        double totalAvailableWidth = constraints.maxWidth - paddingHorizontal - (crossAxisSpacing * (crossAxisCount - 1));
                        double itemWidth = totalAvailableWidth / crossAxisCount;
                        double itemHeight = 130.0;
                        double responsiveAspectRatio = itemWidth / itemHeight;

                        return GridView.builder(
                          padding: const EdgeInsets.all(8.0),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: crossAxisSpacing,
                            mainAxisSpacing: 6,
                            childAspectRatio: responsiveAspectRatio,
                          ),
                          itemCount: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day,
                          itemBuilder: (context, index) {
                            int day = index + 1;
                            var dayData = totals[day] ?? {'weight': 0.0, 'weight2': 0.0, 'advance': 0.0, 'items': 0.0};
                            double weight = dayData['weight']!;
                            double weight2 = (dayData['weight2'] ?? 0.0);
                            double advance = dayData['advance']!;
                            double totalItems = dayData['items']!;
                            bool hasData = weight > 0 || weight2 > 0 || advance > 0 || totalItems > 0;

                            DateTime cellDate = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                            bool isFuture = cellDate.isAfter(today);

                            return InkWell(
                              onTap: isFuture ? null : () => _onDateTapped(day),
                              child: Container(
                                padding: const EdgeInsets.all(2.0),
                                decoration: BoxDecoration(
                                  color: isFuture 
                                      ? Colors.grey.shade200 
                                      : (hasData ? activeColor.withValues(alpha: 0.15) : Colors.white),
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(
                                    color: isFuture 
                                        ? Colors.grey.shade300 
                                        : (hasData ? activeColor : activeColor.withValues(alpha: 0.4))
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      day.toString(), 
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        color: isFuture 
                                            ? Colors.grey.shade400 
                                            : (hasData ? Colors.black87 : Colors.grey)
                                      ),
                                    ),
                                    const SizedBox(height: 2), 
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            if (weight > 0) 
                                              _buildAlignedRow(prefix: 'N', color: Colors.green.shade800, text: weight.toStringAsFixed(1)),
                                            if (weight2 > 0) 
                                              _buildAlignedRow(prefix: 'S', color: Colors.green.shade600, text: weight2.toStringAsFixed(1)),
                                            if (advance > 0) 
                                              _buildAlignedRow(icon: Icons.payments_rounded, color: Colors.blue.shade700, text: NumberFormat.compact().format(advance)),
                                            if (totalItems > 0) 
                                              _buildAlignedRow(assetIcon: 'assets/trolley_badge.png', color: const Color(0xFFD97706), text: totalItems % 1 == 0 ? totalItems.toInt().toString() : totalItems.toStringAsFixed(1)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAlignedRow({IconData? icon, String? assetIcon, String? prefix, required Color color, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerRight,
              child: prefix != null
                  ? Text(prefix, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color))
                  : assetIcon != null
                      ? Image.asset(assetIcon, width: 13, height: 13, color: color, colorBlendMode: BlendMode.srcIn,)
                      : Icon(icon, size: 12, color: color),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 6,
            child: Text(
              text,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis, 
            ),
          ),
        ],
      ),
    );
  }
}
