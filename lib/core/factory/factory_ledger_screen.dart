import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:smart_entry/core/app_state.dart';
import '../widgets/skeleton_box.dart';
import '../widgets/max_number_input_formatter.dart';
import '../localization/app_strings.dart';

class FactoryLedgerScreen extends StatefulWidget {
  final String factoryId;
  final String factoryName;
  final String refNumber;

  const FactoryLedgerScreen({
    super.key,
    required this.factoryId,
    required this.factoryName,
    required this.refNumber,
  });

  @override
  State<FactoryLedgerScreen> createState() => _FactoryLedgerScreenState();
}

class _FactoryLedgerScreenState extends State<FactoryLedgerScreen> {
  bool _isLoading = false;
  bool _isEditingLeafRates = false;
  
  String? _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  final TextEditingController _normalRateController = TextEditingController();
  final TextEditingController _superRateController = TextEditingController();
  
  final List<Map<String, dynamic>> _itemControllers = [];

  void _addItem() {
    setState(() {
      _itemControllers.add({
        'name': TextEditingController(),
        'price': TextEditingController(),
        'isEditing': true,
        'isNew': true,
        'originalName': '',
        'originalPrice': '',
      });
    });
  }

  void _removeItem(int index) {
    String name = _itemControllers[index]['name']?.text ?? '';
    String price = _itemControllers[index]['price']?.text ?? '';
    setState(() {
      _itemControllers[index]['name']?.dispose();
      _itemControllers[index]['price']?.dispose();
      _itemControllers.removeAt(index);
    });
    _saveItems(logAction: 'DELETE', logDesc: 'Item: $name (Rs.$price)');
  }

  

  
  
  List<Map<String, dynamic>> _savedRates = [];
  List<Map<String, dynamic>> _activityLogs = [];

  int _currentPage = 0;
  final int _itemsPerPage = 5;

  final Color _cyanColor = const Color(0xFF06B6D4);
  final Color _bgCyan = const Color(0xFFECFEFF);

  @override
  void initState() {
    super.initState();
    _fetchSavedRates();
    _fetchActivityLogs();
    _fetchFactorySettings();
  }

  @override
  void dispose() {
    _normalRateController.dispose();
    _superRateController.dispose();
    super.dispose();
  }

  
  void _populateFormForMonth(String? month) {
    if (month == null) return;
    var existingRow = _savedRates.where((r) => r['month'] == month).toList();
    if (existingRow.isNotEmpty) {
      _isEditingLeafRates = false; // Locked mode
      var row = existingRow.first;
      _normalRateController.text = row['normalRate'] != null ? (row['normalRate'] as num).toDouble().toStringAsFixed(2) : '';
      _superRateController.text = row['superRate'] != null ? (row['superRate'] as num).toDouble().toStringAsFixed(2) : '';
    } else {
      _isEditingLeafRates = true; // Auto-enabled mode for new data
      _normalRateController.clear();
      _superRateController.clear();
    }
  }


  Future<void> _fetchActivityLogs() async {
    try {
      final response = await Supabase.instance.client
          .from('factory_activity_logs')
          .select()
          .eq('organization_id', AppState.currentOrganizationId.value ?? '')
          .eq('factory_id', widget.factoryId)
          .order('created_at', ascending: false)
          .limit(50);
          
      if (mounted) {
        setState(() {
          _activityLogs = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error fetching logs: $e');
    }
  }

  Future<void> _logActivity(String actionName, String description) async {
    try {
      await Supabase.instance.client.from('factory_activity_logs').insert({
        'organization_id': AppState.currentOrganizationId.value ?? '',
        'factory_id': widget.factoryId,
        'action_name': actionName,
        'description': description,
      });
      _fetchActivityLogs(); // Refresh logs
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }


  Future<void> _fetchFactorySettings() async {
    try {
      final response = await Supabase.instance.client
          .from('factories')
          .select()
          .eq('organization_id', AppState.currentOrganizationId.value ?? '')
          .eq('id', widget.factoryId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _itemControllers.clear();
          List<dynamic> itemsList = [];
          if (response['items'] != null && (response['items'] as List).isNotEmpty) {
            itemsList = response['items'];
          } else {
            if (response['fertilizers'] != null) {
              itemsList.addAll(response['fertilizers'] as List);
            }
            if (response['tea_packets'] != null) {
              itemsList.addAll(response['tea_packets'] as List);
            }
          }
          for (var f in itemsList) {
            _itemControllers.add({
              'name': TextEditingController(text: f['name']?.toString() ?? ''),
              'price': TextEditingController(text: (f['price'] != null ? (f['price'] as num).toDouble() : 0.0).toStringAsFixed(2)),
              'isEditing': false,
              'originalName': f['name']?.toString() ?? '',
              'originalPrice': f['price']?.toString() ?? '0',
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching factory settings: $e');
    }
  }

  Future<void> _fetchSavedRates() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('factory_monthly_rates')
          .select()
          .eq('organization_id', AppState.currentOrganizationId.value ?? '')
          .eq('factoryId', widget.factoryId)
          .order('month', ascending: false);

      List<Map<String, dynamic>> fetched = List<Map<String, dynamic>>.from(response);
      fetched.sort((a, b) {
        String mA = a['month']?.toString() ?? '';
        String mB = b['month']?.toString() ?? '';
        return mB.compareTo(mA); // Descending
      });

            setState(() {
        _savedRates = fetched;
        _isLoading = false;
        if (_selectedMonth != null) {
          _populateFormForMonth(_selectedMonth);
        }
      });
    } catch (e) {
      debugPrint('Error loading rates: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _upsertMonthlyData(Map<String, dynamic> data) async {
    if (_selectedMonth == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.noMonthSelected)));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final existing = await Supabase.instance.client
          .from('factory_monthly_rates')
          .select('id')
          .eq('organization_id', AppState.currentOrganizationId.value ?? '')
          .eq('factoryId', widget.factoryId)
          .eq('month', _selectedMonth!)
          .maybeSingle();
      if (existing != null) {
        await Supabase.instance.client
            .from('factory_monthly_rates')
            .update(data)
            .eq('organization_id', AppState.currentOrganizationId.value ?? '')
            .eq('id', existing['id']);
      } else {
        data['organization_id'] = AppState.currentOrganizationId.value ?? '';
        data['factoryId'] = widget.factoryId;
        data['month'] = _selectedMonth!;
        data.putIfAbsent('normalRate', () => 0.0);
        data.putIfAbsent('superRate', () => 0.0);
        await Supabase.instance.client.from('factory_monthly_rates').insert(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.savedSuccess), backgroundColor: Colors.green));
      }
      await _fetchSavedRates();
    } catch (e) {
      debugPrint('Error saving rate: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppStrings.errorPrefix}$e'), backgroundColor: Colors.red));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLeafRates() async {
    if (_normalRateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.pleaseEnterNormalLeafRate)));
      return;
    }
    double normalRate = double.tryParse(_normalRateController.text) ?? 0.0;
    double superRate = double.tryParse(_superRateController.text) ?? 0.0;
    await _upsertMonthlyData({'normalRate': normalRate, 'superRate': superRate});
    _normalRateController.clear();
    _superRateController.clear();
  }

  Future<void> _saveItems({String? logAction, String? logDesc}) async {
    List<Map<String, dynamic>> itemsData = _itemControllers.map((c) => {
      'name': (c['name'] as TextEditingController).text.trim(),
      'price': double.parse((double.tryParse((c['price'] as TextEditingController).text) ?? 0.0).toStringAsFixed(2)),
    }).where((f) => f['name'].toString().isNotEmpty).toList();

    try {
      await Supabase.instance.client.from('factories').update({
        'items': itemsData,
      }).eq('organization_id', AppState.currentOrganizationId.value ?? '').eq('id', widget.factoryId);
    } catch (e) {
      debugPrint('Error saving factory items: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppStrings.errorPrefix}$e')));
      }
      return;
    }

    if (logAction != null && logDesc != null) {
      await _logActivity(logAction, logDesc);
    }
    if (mounted) {
      setState(() {
        for (var c in _itemControllers) {
          c['isEditing'] = false;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.itemsSavedSuccess), backgroundColor: Colors.green),
      );
    }
  }



  Widget _buildSkeletonRatesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: 4,
      itemBuilder: (context, index) => Card(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _cyanColor.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  SkeletonBox(width: 20, height: 20, borderRadius: 4),
                  SizedBox(width: 8),
                  SkeletonBox(width: 140, height: 16, borderRadius: 4),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 80, height: 12, borderRadius: 3),
                      SizedBox(height: 6),
                      SkeletonBox(width: 70, height: 16, borderRadius: 4),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      SkeletonBox(width: 80, height: 12, borderRadius: 3),
                      SizedBox(height: 6),
                      SkeletonBox(width: 70, height: 16, borderRadius: 4),
                    ],
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
    int totalPages = (_savedRates.length / _itemsPerPage).ceil();
    if (totalPages < 1) totalPages = 1;

    if (_currentPage >= totalPages) {
      _currentPage = totalPages - 1;
    }
    if (_currentPage < 0) _currentPage = 0;

    List<Map<String, dynamic>> pageDocs = _savedRates
        .skip(_currentPage * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    
    List<DropdownMenuItem<String>> availableItems = [];
    for (int index = 0; index < 15; index++) {
      int monthOffset = 0 - index;
      DateTime dt = DateTime(DateTime.now().year, DateTime.now().month + monthOffset, 1);
      String val = DateFormat('yyyy-MM').format(dt);
      
        String display = DateFormat('MMMM yyyy').format(dt);
        availableItems.add(DropdownMenuItem(value: val, child: Text(display, style: const TextStyle(color: Colors.black87))));
    }

    if (availableItems.isEmpty) {
      _selectedMonth = null;
    } else if (_selectedMonth == null || !availableItems.any((item) => item.value == _selectedMonth)) {
      _selectedMonth = availableItems.first.value;
    }

        return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _bgCyan,
        appBar: AppBar(
          title: Text(widget.factoryName),
          backgroundColor: _cyanColor,
          foregroundColor: Colors.white,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: AppStrings.newRates),
              Tab(text: AppStrings.savedRates),
              Tab(text: AppStrings.activities),
            ],
          ),
        ),
        body: TabBarView(
        children: [
          // Top Section: Insert Form
            SingleChildScrollView(
              child: Container(
            color: _bgCyan,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        dropdownColor: _bgCyan,
                        decoration: InputDecoration(
                          labelText: AppStrings.month, 
                          border: const OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _cyanColor, width: 2.0)),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _cyanColor.withValues(alpha: 0.5))),
                        ),
                        initialValue: _selectedMonth,

                        items: availableItems.isNotEmpty ? availableItems : null,
                        onChanged: availableItems.isNotEmpty
                            ? (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedMonth = val;
                                    
                                    _populateFormForMonth(val);
                                  });
                                }
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _normalRateController,
                        enabled: _isEditingLeafRates,
                        inputFormatters: [MaxNumberInputFormatter.currency],
                        decoration: InputDecoration(labelText: AppStrings.normalLeaf, border: const OutlineInputBorder(), prefixText: 'Rs. '),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _superRateController,
                        enabled: _isEditingLeafRates,
                        inputFormatters: [MaxNumberInputFormatter.currency],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: AppStrings.superLeaf, border: const OutlineInputBorder(), prefixText: 'Rs. '),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(_isEditingLeafRates ? Icons.check : Icons.edit, color: _cyanColor),
                      onPressed: _isLoading ? null : () {
                        if (_isEditingLeafRates) {
                          _saveLeafRates();
                        } else {
                          setState(() => _isEditingLeafRates = true);
                        }
                      },
                      tooltip: _isEditingLeafRates ? AppStrings.save : AppStrings.edit,
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                const Divider(thickness: 2),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft, 
                  child: Text(
                    AppStrings.factoryFixedSettings, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)
                  )
                ),
                const SizedBox(height: 8),

                // Dynamic Fertilizer Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppStrings.extraItems, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    IconButton(icon: Icon(Icons.add_circle, color: _cyanColor), onPressed: _addItem),
                  ],
                ),
                ..._itemControllers.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var val = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(controller: val['name'], enabled: val['isEditing'], decoration: InputDecoration(labelText: AppStrings.name, border: const OutlineInputBorder(), isDense: true)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextFormField(controller: val['price'], enabled: val['isEditing'], keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [MaxNumberInputFormatter.currency], decoration: InputDecoration(labelText: AppStrings.price, border: const OutlineInputBorder(), isDense: true)),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(val['isEditing'] ? Icons.check : Icons.edit, color: _cyanColor),
                          onPressed: _isLoading ? null : () {
                            if (val['isEditing']) {
                              bool isNew = val['isNew'] == true;
                              val['isNew'] = false;
                              String name = val['name'].text;
                              String price = double.tryParse(val['price'].text)?.toStringAsFixed(2) ?? val['price'].text;
                              String oldName = val['originalName'] ?? '';
                              String oldPrice = val['originalPrice'] ?? '';
                              
                              String desc = '';
                              if (isNew) {
                                desc = 'Added Item: $name (Rs.$price)';
                              } else {
                                if (oldName != name && oldPrice != price) {
                                  desc = 'Item: $oldName (Rs.$oldPrice) -> $name (Rs.${double.tryParse(price)?.toStringAsFixed(2) ?? price})';
                                } else if (oldName != name) {
                                  desc = 'Item Name: $oldName -> $name (Rs.$price)';
                                } else if (oldPrice != price) {
                                  desc = 'Fertilizer $name Price: Rs.$oldPrice -> Rs.$price';
                                } else {
                                  desc = 'Fertilizer $name saved without changes';
                                }
                              }
                              val['originalName'] = name;
                              val['originalPrice'] = price;
                              
                              _saveItems(
                                logAction: isNew ? 'ADD' : 'UPDATE', 
                                logDesc: desc
                              );
                            } else {
                              setState(() => val['isEditing'] = true);
                            }
                          },
                          tooltip: val['isEditing'] ? AppStrings.save : AppStrings.edit,
                        ),
                        const SizedBox(width: 4),
                        IconButton(icon: Icon(Icons.delete, color: _cyanColor), onPressed: () => _removeItem(idx)),
                      ],
                    ),
                  );
                }),
                
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),

                ],
            ),
          ),
            ),

          // Tab 2: Saved Monthly Rates
          Container(
            color: _bgCyan,
            child: _isLoading
                ? _buildSkeletonRatesList()
                : _savedRates.isEmpty 
                  ? Center(child: Text(AppStrings.noDataFound, style: const TextStyle(color: Colors.grey)))
                  : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: pageDocs.length,
                          itemBuilder: (context, index) {
                            var row = pageDocs[index];
                        String rawMonth = row['month']?.toString() ?? '';
                        String displayMonth = rawMonth;
                        if (rawMonth.contains('-')) {
                          try {
                            int monthNum = int.parse(rawMonth.split('-')[1]);
                            int yearNum = int.parse(rawMonth.split('-')[0]);
                            displayMonth = '${AppStrings.getMonthName(monthNum)} $yearNum';
                          } catch (e) {
                            // Format exception fallback to rawMonth
                          }
                        }
                        
                        double nRate = row['normalRate'] != null ? (row['normalRate'] as num).toDouble() : 0.0;
                        double sRate = row['superRate'] != null ? (row['superRate'] as num).toDouble() : 0.0;

                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          surfaceTintColor: Colors.transparent,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: _cyanColor.withValues(alpha: 0.4), width: 1.5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.calendar_month, color: _cyanColor, size: 20),
                                    const SizedBox(width: 8),
                                    Text(displayMonth, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(AppStrings.normalLeaf, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        Text('Rs. ${nRate.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(AppStrings.superLeaf, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        Text('Rs. ${sRate.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                          },
                        ),
                      ),
                      if (totalPages > 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _currentPage > 0 ? () {
                                  setState(() {
                                    _currentPage--;
                                  });
                                } : null,
                                icon: const Icon(Icons.chevron_left, size: 18),
                                label: Text(AppStrings.previous),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: _cyanColor,
                                  elevation: 0,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              Text('${AppStrings.page} ${_currentPage + 1} / $totalPages', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 13)),
                              ElevatedButton.icon(
                                onPressed: _currentPage < totalPages - 1 ? () {
                                  setState(() {
                                    _currentPage++;
                                  });
                                } : null,
                                icon: const Icon(Icons.chevron_right, size: 18),
                                label: Text(AppStrings.next),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: _cyanColor,
                                  elevation: 0,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          // Tab 3: Activity Logs
          Container(
            child: _activityLogs.isEmpty 
              ? Center(child: Text(AppStrings.noActivitiesFound, style: const TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _activityLogs.length,
                  itemBuilder: (context, index) {
                    var log = _activityLogs[index];
                    Color actionColor = _cyanColor;
                    if (log['action_name'] == 'ADD') {
                      actionColor = Colors.cyan.shade600;
                    } else if (log['action_name'] == 'DELETE') {
                      actionColor = Colors.blueGrey.shade600;
                    } else {
                      actionColor = Colors.cyan.shade400;
                    }
                    DateTime dt = DateTime.parse(log['created_at']).toLocal();
                    String formattedDate = DateFormat('yyyy-MM-dd • hh:mm a').format(dt);
                    
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 45,
                            child: Column(
                              children: [
                                Expanded(flex: 1, child: Container(width: 2, color: index == 0 ? Colors.transparent : Colors.grey.shade300)),
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    color: actionColor, 
                                    shape: BoxShape.circle
                                  ),
                                  child: Icon(
                                    log['action_name'] == 'ADD' ? Icons.add : log['action_name'] == 'DELETE' ? Icons.delete_outline : Icons.edit_outlined,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                Expanded(flex: 3, child: Container(width: 2, color: index == _activityLogs.length - 1 ? Colors.transparent : Colors.grey.shade300)),
                              ],
                            )
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Builder(
                                    builder: (context) {
                                      String fullDesc = log['description'] ?? '';
                                      List<String> descParts = fullDesc.split('\n');
                                      String titlePart = descParts.first;
                                      String bodyPart = descParts.length > 1 ? descParts.sublist(1).join('\n') : '';

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(titlePart, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
                                          if (bodyPart.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(bodyPart, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                          ],
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: actionColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: actionColor.withValues(alpha: 0.4)),
                                                ),
                                                child: Text(log['action_name'] ?? 'Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: actionColor)),
                                              ),
                                              Text(formattedDate, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                            ]
                                          )
                                        ],
                                      );
                                    }
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
      ),
    );
  }
  }
