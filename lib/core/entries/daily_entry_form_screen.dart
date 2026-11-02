import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:smart_entry/core/app_state.dart';
import '../items/item_model.dart';
import '../items/item_service.dart';
import '../localization/app_strings.dart';
import '../../services/billing_lock_service.dart';
import '../widgets/max_number_input_formatter.dart';

class DailyEntryFormScreen extends StatefulWidget {
  final DateTime selectedDate;
  final String customerId;
  final String customerName;
  final String refNumber;
  final bool isReadOnly;

  const DailyEntryFormScreen({
    super.key, 
    required this.selectedDate,
    required this.customerId,
    required this.customerName,
    required this.refNumber,
    this.isReadOnly = false,
  });

  @override
  State<DailyEntryFormScreen> createState() => _DailyEntryFormScreenState();
}

class _DailyEntryFormScreenState extends State<DailyEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _existingEntryId;
  bool _isLocked = false;
  
  final TextEditingController _grossWeightController = TextEditingController();
  final TextEditingController _netWeight2Controller = TextEditingController();
  final TextEditingController _deductionController = TextEditingController(text: '0');
  final TextEditingController _advanceController = TextEditingController();
  final TextEditingController _fertilizer1Controller = TextEditingController();
  final TextEditingController _fertilizer2Controller = TextEditingController();
  final TextEditingController _teaPacket1Controller = TextEditingController();
  final TextEditingController _teaPacket2Controller = TextEditingController();
  
  // Custom items support (Slots 1 to 8)
  List<CustomItem> _customItems = [];
  final Map<int, TextEditingController> _itemControllers = {};

  bool _isLoading = false;

  double _fert1Price = 0.0;
  double _fert2Price = 0.0;
  double _teaPkt1Price = 0.0;
  double _teaPkt2Price = 0.0;

  Map<String, dynamic>? _existingEntryDoc;

  TextEditingController _getOrCreateController(int slotIndex) {
    if (!_itemControllers.containsKey(slotIndex)) {
      _itemControllers[slotIndex] = TextEditingController();
    }
    return _itemControllers[slotIndex]!;
  }

  @override
  void initState() {
    _isLocked = widget.isReadOnly || BillingLockService().isDateLocked(widget.selectedDate);
    super.initState();
    _itemControllers[1] = _fertilizer1Controller;
    _itemControllers[2] = _fertilizer2Controller;
    _itemControllers[3] = _teaPacket1Controller;
    _itemControllers[4] = _teaPacket2Controller;

    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _fetchGlobalPricesAndItems();
    await _fetchExistingEntry();
  }

  Future<void> _fetchGlobalPricesAndItems() async {
    try {
      final items = await ItemService.getItems();
      if (mounted) {
        setState(() {
          _customItems = items;
          for (var item in items) {
            _getOrCreateController(item.slotIndex);
            if (item.slotIndex == 1) _fert1Price = item.unitPrice;
            if (item.slotIndex == 2) _fert2Price = item.unitPrice;
            if (item.slotIndex == 3) _teaPkt1Price = item.unitPrice;
            if (item.slotIndex == 4) _teaPkt2Price = item.unitPrice;
          }
          if (_existingEntryDoc != null) {
            _populateFromDoc(_existingEntryDoc!);
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching items: $e");
    }
  }

  Future<void> _fetchExistingEntry() async {
    try {
      String formattedDate = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

      var response = await Supabase.instance.client
          .from('daily_entries')
          .select()
          .eq('organization_id', AppState.currentOrganizationId.value ?? '')
          .eq('customerId', widget.customerId)
          .eq('date', formattedDate)
          .limit(1);

      if (response.isNotEmpty && mounted) {
        final doc = response.first;
        setState(() {
          _existingEntryDoc = doc;
          _populateFromDoc(doc);
        });
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
    }
  }

  void _populateFromDoc(Map<String, dynamic> doc) {
    _existingEntryId = doc['id'];

    _grossWeightController.text = _formatValue(doc['grossWeight']);
    _netWeight2Controller.text = _formatValue(doc['netWeight2']);
    _deductionController.text = _formatValue(doc['deductions'], isDeduction: true);
    _advanceController.text = _formatValue(doc['advanceAmount']);

    // 1. Parse items using ItemService parser (handles Map, JSON String, dynamic_items, and legacy columns)
    final parsed = ItemService.parseDailyEntryItems(doc);

    // Populate legacy slot quantities from parsed / direct columns
    if (parsed.f1Qty > 0) {
      _getOrCreateController(1).text = _formatValue(parsed.f1Qty);
    } else if (doc['fertilizer1Qty'] != null) {
      _getOrCreateController(1).text = _formatValue(doc['fertilizer1Qty']);
    }

    if (parsed.f2Qty > 0) {
      _getOrCreateController(2).text = _formatValue(parsed.f2Qty);
    } else if (doc['fertilizer2Qty'] != null) {
      _getOrCreateController(2).text = _formatValue(doc['fertilizer2Qty']);
    }

    if (parsed.t1Qty > 0) {
      _getOrCreateController(3).text = _formatValue(parsed.t1Qty);
    } else if (doc['teaPacket1Qty'] != null) {
      _getOrCreateController(3).text = _formatValue(doc['teaPacket1Qty']);
    }

    if (parsed.t2Qty > 0) {
      _getOrCreateController(4).text = _formatValue(parsed.t2Qty);
    } else if (doc['teaPacket2Qty'] != null) {
      _getOrCreateController(4).text = _formatValue(doc['teaPacket2Qty']);
    }

    // 2. Populate dynamic items from parsed.itemsList
    for (var parsedItem in parsed.itemsList) {
      int slot = (parsedItem['slot'] as num?)?.toInt() ?? 0;
      double qty = (parsedItem['qty'] as num?)?.toDouble() ?? 0.0;
      String code = (parsedItem['code'] ?? '').toString();
      String id = (parsedItem['id'] ?? '').toString();
      String desc = (parsedItem['desc'] ?? '').toString().toLowerCase();

      if (qty <= 0) continue;

      if (slot == 0 && _customItems.isNotEmpty) {
        for (var ci in _customItems) {
          if (ci.id == id || ci.code == code || ci.name.toLowerCase() == desc) {
            slot = ci.slotIndex;
            break;
          }
        }
      }

      if (slot > 0) {
        _getOrCreateController(slot).text = _formatValue(qty);
      }
    }

    // 3. Fallback direct inspection of dynamic_items (Map or JSON string)
    dynamic rawDyn = doc['dynamic_items'];
    Map<dynamic, dynamic>? dyn;
    if (rawDyn is Map) {
      dyn = rawDyn;
    } else if (rawDyn is String && rawDyn.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDyn);
        if (decoded is Map) dyn = decoded;
      } catch (_) {}
    }

    if (dyn != null) {
      dyn.forEach((key, val) {
        double qty = 0.0;
        int slot = 0;
        String id = '';
        String code = '';
        String name = '';

        if (val is Map) {
          qty = (val['qty'] as num?)?.toDouble() ?? (double.tryParse(val['qty']?.toString() ?? '') ?? 0.0);
          slot = (val['slot'] as num?)?.toInt() ?? 0;
          id = (val['id'] ?? '').toString();
          code = (val['code'] ?? '').toString();
          name = (val['name'] ?? '').toString().toLowerCase();
        } else if (val is num) {
          qty = val.toDouble();
        } else if (val is String) {
          qty = double.tryParse(val.trim()) ?? 0.0;
        }

        if (qty > 0) {
          if (slot == 0) {
            String k = key.toString();
            for (var ci in _customItems) {
              if (k == 'item_${ci.id}' || k == 'slot_${ci.slotIndex}' || k == ci.code || k == ci.id || ci.name.toLowerCase() == name) {
                slot = ci.slotIndex;
                break;
              }
            }
          }
          if (slot > 0) {
            _getOrCreateController(slot).text = _formatValue(qty);
          }
        }
      });
    }
  }

  String _formatValue(dynamic val, {bool isDeduction = false}) {
    if (val == null) return isDeduction ? '0' : '';
    
    double parsedValue = 0.0;
    
    if (val is String) {
      parsedValue = double.tryParse(val.trim()) ?? 0.0;
    } else if (val is num) {
      parsedValue = val.toDouble();
    }
    
    if (parsedValue == 0) return isDeduction ? '0' : '';
    
    if (parsedValue == parsedValue.toInt()) {
      return parsedValue.toInt().toString();
    }
    return parsedValue.toString();
  }

  String? _validateInput(String? value) {
    bool isAllEmpty = _grossWeightController.text.trim().isEmpty &&
        _netWeight2Controller.text.trim().isEmpty &&
        (_deductionController.text.trim().isEmpty || _deductionController.text.trim() == '0') &&
        _advanceController.text.trim().isEmpty &&
        _itemControllers.values.every((c) => c.text.trim().isEmpty);

    if (isAllEmpty) {
      return AppStrings.requiredField;
    }

    if (value != null && value.trim().isNotEmpty && value.trim() != '0') {
      final maxErr = MaxNumberInputFormatter.validate(value);
      if (maxErr != null) return maxErr;
      if (double.tryParse(value.trim()) == null) {
        return AppStrings.isSinhala ? 'නිවැරදි අගයක් ඇතුළත් කරන්න' : 'Enter a valid number';
      }
    }
    return null;
  }

  void _confirmAndSave() {
    if (_isLocked) return;
    if (_formKey.currentState!.validate()) {
      if (_existingEntryId != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppStrings.confirm),
            content: Text(AppStrings.isSinhala ? 'ඔබට මෙම දත්ත යාවත්කාලීන කිරීමට අවශ්‍යද?' : 'Do you want to update this entry?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppStrings.no, style: const TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveEntry(isUpdate: true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                child: Text(AppStrings.yes, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else {
        _saveEntry(isUpdate: false);
      }
    }
  }

  Future<void> _saveEntry({required bool isUpdate}) async {
    if (_isLocked) return;
    setState(() { _isLoading = true; });

    try {
      double grossWeight = double.tryParse(_grossWeightController.text.trim()) ?? 0.0;
      double deductions = double.tryParse(_deductionController.text.trim()) ?? 0.0;
      double netWeight = grossWeight - deductions;
      double netWeight2 = double.tryParse(_netWeight2Controller.text.trim()) ?? 0.0;

      double advance = double.tryParse(_advanceController.text.trim()) ?? 0.0;
      Map<String, dynamic> dynamicItems = {};
      for (var item in _customItems) {
        double qty = double.tryParse(_itemControllers[item.slotIndex]?.text.trim() ?? '') ?? 0.0;
        if (qty > 0) {
          dynamicItems[item.code] = qty;
          dynamicItems['item_${item.id}'] = {
            'id': item.id,
            'slot': item.slotIndex,
            'code': item.code,
            'name': item.name,
            'unitPrice': item.unitPrice,
            'qty': qty,
            'amt': qty * item.unitPrice,
          };
        }
      }

      // Legacy shadow copy for slots 1-4 for database column compatibility
      double fertilizer1Qty = double.tryParse(_itemControllers[1]?.text.trim() ?? '') ?? 0.0;
      double fertilizer2Qty = double.tryParse(_itemControllers[2]?.text.trim() ?? '') ?? 0.0;
      double teaPacket1Qty = double.tryParse(_itemControllers[3]?.text.trim() ?? '') ?? 0.0;
      double teaPacket2Qty = double.tryParse(_itemControllers[4]?.text.trim() ?? '') ?? 0.0;

      Map<String, dynamic> entryData = {
        'grossWeight': grossWeight,
        'deductions': deductions,
        'netWeight': netWeight,
        'netWeight2': netWeight2,
        'advanceAmount': advance,
        'fertilizer1Qty': fertilizer1Qty,
        'fertilizer2Qty': fertilizer2Qty,
        'teaPacket1Qty': teaPacket1Qty,
        'teaPacket2Qty': teaPacket2Qty,
      };

      if (dynamicItems.isNotEmpty) {
        entryData['dynamic_items'] = dynamicItems;
      }

      try {
        if (isUpdate && _existingEntryId != null) {
          entryData['updatedAt'] = DateTime.now().toIso8601String();
          await Supabase.instance.client
              .from('daily_entries')
              .update(entryData)
              .eq('organization_id', AppState.currentOrganizationId.value ?? '')
              .eq('id', _existingEntryId!);
        } else {
          entryData['customerId'] = widget.customerId;
          entryData['customerName'] = widget.customerName;
          entryData['date'] = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
          entryData['timestamp'] = widget.selectedDate.toIso8601String();
          entryData['createdAt'] = DateTime.now().toIso8601String();
          entryData['organization_id'] = AppState.currentOrganizationId.value;

          await Supabase.instance.client.from('daily_entries').insert(entryData);
        }
      } on PostgrestException catch (pe) {
        // Fallback if dynamic_items column has not yet been added to the daily_entries table
        if (pe.code == 'PGRST204' && entryData.containsKey('dynamic_items')) {
          entryData.remove('dynamic_items');
          if (isUpdate && _existingEntryId != null) {
            await Supabase.instance.client
                .from('daily_entries')
                .update(entryData)
                .eq('organization_id', AppState.currentOrganizationId.value ?? '')
                .eq('id', _existingEntryId!);
          } else {
            await Supabase.instance.client.from('daily_entries').insert(entryData);
          }
        } else {
          rethrow;
        }
      }

      if (mounted) {
        AppState.triggerRefresh();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isUpdate ? AppStrings.entryUpdated : AppStrings.entrySaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppStrings.errorPrefix}$e')));
      }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  @override
  void dispose() {
    _grossWeightController.dispose();
    _netWeight2Controller.dispose();
    _deductionController.dispose();
    _advanceController.dispose();
    _fertilizer1Controller.dispose();
    _fertilizer2Controller.dispose();
    _teaPacket1Controller.dispose();
    _teaPacket2Controller.dispose();
    for (var entry in _itemControllers.entries) {
      if (entry.key > 4) {
        entry.value.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('yyyy MMM dd').format(widget.selectedDate);
    double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(AppStrings.isSinhala ? '$formattedDate දින සටහන' : 'Entry for $formattedDate', style: const TextStyle(fontSize: 18)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SizedBox.expand(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16.0, 
              right: 16.0, 
              top: 16.0, 
              bottom: bottomInset > 0 ? bottomInset + 24.0 : 24.0, 
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      'No: ${widget.refNumber} - ${widget.customerName}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(AppStrings.isSinhala ? 'තේ දළු විස්තර' : 'Tea Leaf Details', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _grossWeightController,
                    enabled: !_isLocked,
                    style: TextStyle(color: _isLocked ? Colors.grey.shade700 : Colors.black87, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: AppStrings.isSinhala ? 'සාමාන්‍ය දළු ප්‍රමාණය' : 'Normal Leaf Weight',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      filled: _isLocked,
                      fillColor: _isLocked ? const Color(0xFFF3F4F6) : null,
                      prefixIcon: const Icon(Icons.scale),
                      suffixText: 'Kg',
                    ),
                    inputFormatters: [MaxNumberInputFormatter.currency],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateInput, 
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _netWeight2Controller,
                    enabled: !_isLocked,
                    style: TextStyle(color: _isLocked ? Colors.grey.shade700 : Colors.black87, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: AppStrings.isSinhala ? 'සුපිරි දළු ප්‍රමාණය (විකල්ප)' : 'Super Leaf Weight (Optional)',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      filled: _isLocked,
                      fillColor: _isLocked ? const Color(0xFFF3F4F6) : null,
                      prefixIcon: const Icon(Icons.star_border),
                      suffixText: 'Kg',
                    ),
                    inputFormatters: [MaxNumberInputFormatter.currency],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateInput, 
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Divider(),
                  ),

                  Text(AppStrings.isSinhala ? 'අමතර සටහන් සහ අඩු කිරීම්' : 'Extra Items & Deductions', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _advanceController,
                    enabled: !_isLocked,
                    style: TextStyle(color: _isLocked ? Colors.grey.shade700 : Colors.black87, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: AppStrings.isSinhala ? 'අත්තිකාරම් මුදල' : 'Advance Amount',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      filled: _isLocked,
                      fillColor: _isLocked ? const Color(0xFFF3F4F6) : null,
                      prefixIcon: const Icon(Icons.money),
                      prefixText: 'Rs. ',
                    ),
                    inputFormatters: [MaxNumberInputFormatter.currency],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateInput, 
                  ),
                  const SizedBox(height: 20),

                  ..._buildItemInputFields(),
                  if (!_isLocked) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _confirmAndSave, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          elevation: 2,
                        ),
                        child: _isLoading 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                _existingEntryId != null ? AppStrings.update : AppStrings.save, 
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildItemInputFields() {
    final itemsToDisplay = _customItems.isNotEmpty
        ? _customItems
        : [
            CustomItem(
              id: 'slot_1',
              organizationId: AppState.currentOrganizationId.value ?? '',
              slotIndex: 1,
              code: 'F1',
              name: AppStrings.fertilizer1,
              unitPrice: _fert1Price,
            ),
            CustomItem(
              id: 'slot_2',
              organizationId: AppState.currentOrganizationId.value ?? '',
              slotIndex: 2,
              code: 'F2',
              name: AppStrings.fertilizer2,
              unitPrice: _fert2Price,
            ),
            CustomItem(
              id: 'slot_3',
              organizationId: AppState.currentOrganizationId.value ?? '',
              slotIndex: 3,
              code: 'T1',
              name: AppStrings.teaPacket1,
              unitPrice: _teaPkt1Price,
            ),
            CustomItem(
              id: 'slot_4',
              organizationId: AppState.currentOrganizationId.value ?? '',
              slotIndex: 4,
              code: 'T2',
              name: AppStrings.teaPacket2,
              unitPrice: _teaPkt2Price,
            ),
          ];

    List<Widget> widgets = [];
    for (int i = 0; i < itemsToDisplay.length; i += 2) {
      final item1 = itemsToDisplay[i];
      final item2 = (i + 1 < itemsToDisplay.length) ? itemsToDisplay[i + 1] : null;

      widgets.add(
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _itemControllers[item1.slotIndex],
                enabled: !_isLocked,
                    style: TextStyle(color: _isLocked ? Colors.grey.shade700 : Colors.black87, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: '${item1.name} (Rs. ${item1.unitPrice.toStringAsFixed(0)})',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      filled: _isLocked,
                      fillColor: _isLocked ? const Color(0xFFF3F4F6) : null,
                  prefixIcon: Icon(
                    item1.code.toUpperCase().startsWith('T') ? Icons.local_cafe : Icons.shopping_bag,
                  ),
                ),
                inputFormatters: [MaxNumberInputFormatter.currency],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validateInput,
              ),
            ),
            const SizedBox(width: 12),
            if (item2 != null)
              Expanded(
                child: TextFormField(
                  controller: _itemControllers[item2.slotIndex],
                  enabled: !_isLocked,
                    style: TextStyle(color: _isLocked ? Colors.grey.shade700 : Colors.black87, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: '${item2.name} (Rs. ${item2.unitPrice.toStringAsFixed(0)})',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      filled: _isLocked,
                      fillColor: _isLocked ? const Color(0xFFF3F4F6) : null,
                    prefixIcon: Icon(
                      item2.code.toUpperCase().startsWith('T') ? Icons.local_cafe : Icons.shopping_bag,
                    ),
                  ),
                  inputFormatters: [MaxNumberInputFormatter.currency],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _validateInput,
                ),
              )
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }
}