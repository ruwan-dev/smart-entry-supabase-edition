import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:smart_entry/core/app_state.dart';
import '../localization/app_strings.dart';
import '../localization/app_language.dart';
import '../../services/billing_lock_service.dart';
import '../widgets/max_number_input_formatter.dart';

class FactoryEntryFormScreen extends StatefulWidget {
  final DateTime selectedDate;
  final String factoryId;
  final String factoryName;
  final String refNumber;
  final bool isReadOnly;

  const FactoryEntryFormScreen({
    super.key, 
    required this.selectedDate,
    required this.factoryId,
    required this.factoryName,
    required this.refNumber,
    this.isReadOnly = false,
  });

  @override
  State<FactoryEntryFormScreen> createState() => _FactoryEntryFormScreenState();
}

class _FactoryEntryFormScreenState extends State<FactoryEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _existingEntryId;
  bool _isLocked = false;
  
  final TextEditingController _grossWeightController = TextEditingController();
  final TextEditingController _netWeight2Controller = TextEditingController();
  final TextEditingController _deductionController = TextEditingController(text: '0');
  final TextEditingController _advanceController = TextEditingController();
  
  List<Map<String, dynamic>> _factoryItems = [];
  
  // Controllers mapping name -> controller
  final Map<String, TextEditingController> _dynamicControllers = {};
  
  bool _isLoading = false;

  // Daily supplier collection
  double _dailyCollectedNormal = 0.0;
  double _dailyCollectedSuper = 0.0;
  double get _dailyCollectedTotal => _dailyCollectedNormal + _dailyCollectedSuper;

  // Allocations to other factories on this date
  List<Map<String, dynamic>> _otherFactoryAllocations = [];
  double _otherAllocatedNormal = 0.0;
  double _otherAllocatedSuper = 0.0;
  double get _otherAllocatedTotal => _otherAllocatedNormal + _otherAllocatedSuper;

  // Available for this factory
  double get _availableNormal => _dailyCollectedNormal - _otherAllocatedNormal;
  double get _availableSuper => _dailyCollectedSuper - _otherAllocatedSuper;
  double get _availableTotal => _dailyCollectedTotal - _otherAllocatedTotal;

  // Real-time entered values
  double get _currentEnteredNormal => double.tryParse(_grossWeightController.text.trim()) ?? 0.0;
  double get _currentEnteredSuper => double.tryParse(_netWeight2Controller.text.trim()) ?? 0.0;
  double get _currentEnteredTotal => _currentEnteredNormal + _currentEnteredSuper;


  @override
  void initState() {
    _isLocked = widget.isReadOnly || BillingLockService().isDateLocked(widget.selectedDate);
    super.initState();
    AppLanguageService.currentLanguage.addListener(_onLanguageChanged);
    _grossWeightController.addListener(_onWeightChanged);
    _netWeight2Controller.addListener(_onWeightChanged);
    _initializeData();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  void _onWeightChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeData() async {
    setState(() { _isLoading = true; });
    await Future.wait([
      _fetchFactorySettings(),
      _fetchExistingEntry(),
      _fetchDailyCollectionAndAllocations(),
    ]);
    if (mounted) {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _fetchFactorySettings() async {
    try {
      var response = await Supabase.instance.client
          .from('factories')
          .select()
          .eq('organization_id', AppState.currentOrganizationId.value ?? '')
          .eq('id', widget.factoryId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _factoryItems = [];
          if (response['items'] != null && (response['items'] as List).isNotEmpty) {
            _factoryItems = List<Map<String, dynamic>>.from(response['items']);
          } else {
            if (response['fertilizers'] != null) {
              _factoryItems.addAll(List<Map<String, dynamic>>.from(response['fertilizers']));
            }
            if (response['tea_packets'] != null) {
              _factoryItems.addAll(List<Map<String, dynamic>>.from(response['tea_packets']));
            }
          }
          for (var item in _factoryItems) {
            _dynamicControllers[item['name']] = TextEditingController();
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching factory settings: $e");
    }
  }

  Future<void> _fetchExistingEntry() async {
    try {
      String formattedDate = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
      
      var response = await Supabase.instance.client
          .from('factory_entries')
          .select()
          .eq('organization_id', AppState.currentOrganizationId.value ?? '')
          .eq('factoryId', widget.factoryId)
          .eq('date', formattedDate)
          .limit(1);

      if (response.isNotEmpty && mounted) {
        var doc = response.first;
        
        setState(() {
          _existingEntryId = doc['id']; 
          
          _grossWeightController.text = _formatValue(doc['grossWeight']);
          _netWeight2Controller.text = _formatValue(doc['netWeight2']);
          _deductionController.text = _formatValue(doc['deductions'], isDeduction: true);
          _advanceController.text = _formatValue(doc['advanceAmount']);
          
          Map<String, dynamic> dynItems = {};
          if (doc['dynamic_items'] != null) {
            dynItems.addAll(Map<String, dynamic>.from(doc['dynamic_items']));
          }
          if (doc['dynamic_fertilizers'] != null) {
            dynItems.addAll(Map<String, dynamic>.from(doc['dynamic_fertilizers']));
          }
          if (doc['dynamic_tea_packets'] != null) {
            dynItems.addAll(Map<String, dynamic>.from(doc['dynamic_tea_packets']));
          }
          dynItems.forEach((key, value) {
            if (_dynamicControllers.containsKey(key)) {
              _dynamicControllers[key]!.text = _formatValue(value);
            }
          });
        });
      }
    } catch (e) {
      debugPrint("Error fetching entry: $e");
    }
  }

  Future<void> _fetchDailyCollectionAndAllocations() async {
    final orgId = AppState.currentOrganizationId.value ?? '';
    if (orgId.isEmpty) return;

    try {
      String formattedDate = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

      // 1. Fetch supplier entries for this date
      final supplierRes = await Supabase.instance.client
          .from('daily_entries')
          .select('netWeight, netWeight2')
          .eq('organization_id', orgId)
          .eq('date', formattedDate);

      double collectedNormal = 0.0;
      double collectedSuper = 0.0;
      for (var row in supplierRes) {
        collectedNormal += ((row['netWeight'] ?? 0) as num).toDouble();
        collectedSuper += ((row['netWeight2'] ?? 0) as num).toDouble();
      }

      // 2. Fetch all factories to resolve names and ref numbers
      final factoriesRes = await Supabase.instance.client
          .from('factories')
          .select('id, name, refNumber')
          .eq('organization_id', orgId);

      Map<String, Map<String, dynamic>> factoriesMap = {};
      for (var f in factoriesRes) {
        factoriesMap[f['id'].toString()] = Map<String, dynamic>.from(f);
      }

      // 3. Fetch factory entries on this date
      final factoryEntriesRes = await Supabase.instance.client
          .from('factory_entries')
          .select('id, factoryId, factoryName, grossWeight, netWeight, netWeight2, deductions')
          .eq('organization_id', orgId)
          .eq('date', formattedDate);

      List<Map<String, dynamic>> otherAllocations = [];
      double otherNormal = 0.0;
      double otherSuper = 0.0;

      for (var entry in factoryEntriesRes) {
        String fId = (entry['factoryId'] ?? '').toString();
        // Ignore current factory AND ignore factories that no longer exist / were deleted
        if (fId != widget.factoryId && factoriesMap.containsKey(fId)) {
          final fInfo = factoriesMap[fId]!;
          double normal = ((entry['grossWeight'] ?? entry['netWeight'] ?? 0) as num).toDouble();
          double superLeaf = ((entry['netWeight2'] ?? 0) as num).toDouble();
          double total = normal + superLeaf;

          otherNormal += normal;
          otherSuper += superLeaf;

          String name = fInfo['name']?.toString() ?? (entry['factoryName']?.toString() ?? 'Factory');
          String ref = fInfo['refNumber']?.toString() ?? '';

          otherAllocations.add({
            'factoryId': fId,
            'name': name,
            'refNumber': ref,
            'normal': normal,
            'super': superLeaf,
            'total': total,
          });
        }
      }

      otherAllocations.sort((a, b) => (a['refNumber'] as String).compareTo(b['refNumber'] as String));

      if (mounted) {
        setState(() {
          _dailyCollectedNormal = collectedNormal;
          _dailyCollectedSuper = collectedSuper;
          _otherFactoryAllocations = otherAllocations;
          _otherAllocatedNormal = otherNormal;
          _otherAllocatedSuper = otherSuper;
        });
      }
    } catch (e) {
      debugPrint("Error fetching daily collection and allocations: $e");
    }
  }

  void _applyAvailableToInputs() {
    if (_isLocked) return;
    if (_availableNormal > 0) {
      _grossWeightController.text = _availableNormal == _availableNormal.toInt()
          ? _availableNormal.toInt().toString()
          : _availableNormal.toStringAsFixed(1);
    }
    if (_availableSuper > 0) {
      _netWeight2Controller.text = _availableSuper == _availableSuper.toInt()
          ? _availableSuper.toInt().toString()
          : _availableSuper.toStringAsFixed(1);
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
    if (value != null && value.trim().isNotEmpty && value.trim() != '0') {
      final maxErr = MaxNumberInputFormatter.validate(value);
      if (maxErr != null) return maxErr;
      if (double.tryParse(value.trim()) == null) {
        return AppStrings.correctValueRequired;
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
            title: Text(AppStrings.updateConfirm),
            content: Text(AppStrings.updateConfirmPrompt),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
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
      
      Map<String, dynamic> dynItems = {};
      _dynamicControllers.forEach((name, controller) {
        double qty = double.tryParse(controller.text.trim()) ?? 0.0;
        if (qty > 0) dynItems[name] = qty;
      });

      Map<String, dynamic> entryData = {
        'grossWeight': grossWeight,
        'deductions': deductions,
        'netWeight': netWeight,
        'netWeight2': netWeight2,
        'advanceAmount': advance,
      };

      if (dynItems.isNotEmpty) {
        entryData['dynamic_items'] = dynItems;
      }

      try {
        if (isUpdate && _existingEntryId != null) {
          entryData['updatedAt'] = DateTime.now().toIso8601String();
          await Supabase.instance.client
              .from('factory_entries')
              .update(entryData)
              .eq('organization_id', AppState.currentOrganizationId.value ?? '')
              .eq('id', _existingEntryId!);
        } else {
          entryData['factoryId'] = widget.factoryId;
          entryData['factoryName'] = widget.factoryName;
          entryData['date'] = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
          entryData['timestamp'] = widget.selectedDate.toIso8601String();
          entryData['createdAt'] = DateTime.now().toIso8601String();
          entryData['organization_id'] = AppState.currentOrganizationId.value;

          await Supabase.instance.client.from('factory_entries').insert(entryData);
        }
      } on PostgrestException catch (pe) {
        if (pe.code == 'PGRST204' && entryData.containsKey('dynamic_items')) {
          entryData.remove('dynamic_items');
          if (isUpdate && _existingEntryId != null) {
            await Supabase.instance.client
                .from('factory_entries')
                .update(entryData)
                .eq('organization_id', AppState.currentOrganizationId.value ?? '')
                .eq('id', _existingEntryId!);
          } else {
            await Supabase.instance.client.from('factory_entries').insert(entryData);
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
    AppLanguageService.currentLanguage.removeListener(_onLanguageChanged);
    _grossWeightController.removeListener(_onWeightChanged);
    _netWeight2Controller.removeListener(_onWeightChanged);
    _grossWeightController.dispose();
    _netWeight2Controller.dispose();
    _deductionController.dispose();
    _advanceController.dispose();
    for (var c in _dynamicControllers.values) { c.dispose(); }
    super.dispose();
  }

  Widget _buildDailySummaryCard(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 620;
        if (isMobile) {
          return _buildMobileSummaryWidget(context);
        } else {
          return _buildDesktopSummaryCard(context);
        }
      },
    );
  }

  Widget _buildMobileSummaryWidget(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Total Collected Mini Tile
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.eco,
                  label: AppStrings.isSinhala ? 'එකතුව' : 'Total',
                  value: '${_dailyCollectedTotal.toStringAsFixed(1)} Kg',
                  color: const Color(0xFF10B981),
                  bgColor: const Color(0xFFF0FDF4),
                ),
              ),
              const SizedBox(width: 8),
              // Other Factories Mini Tile
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.factory,
                  label: AppStrings.isSinhala ? 'වෙනත්' : 'Others',
                  value: '${_otherAllocatedTotal.toStringAsFixed(1)} Kg',
                  color: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB),
                ),
              ),
              const SizedBox(width: 8),
              // Available Mini Tile
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.account_balance_wallet_outlined,
                  label: AppStrings.isSinhala ? 'ඉතිරි' : 'Available',
                  value: '${_availableTotal.toStringAsFixed(1)} Kg',
                  color: const Color(0xFF06B6D4),
                  bgColor: const Color(0xFFECFEFF),
                  highlight: true,
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color.withValues(alpha: highlight ? 0.4 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSummaryCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: const Icon(
                    Icons.analytics_outlined,
                    color: Color(0xFF0891B2),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.dailyCollectionAndAllocations,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('yyyy MMMM dd').format(widget.selectedDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isLocked && _availableTotal > 0 && _currentEnteredTotal == 0)
                  TextButton.icon(
                    onPressed: _applyAvailableToInputs,
                    icon: const Icon(Icons.flash_on, size: 16),
                    label: Text(AppStrings.applyAvailable, style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0891B2),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Equal Height Tiles (IntrinsicHeight + CrossAxisAlignment.stretch)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      title: AppStrings.totalCollectedLeafToday,
                      totalValue: _dailyCollectedTotal,
                      normalValue: _dailyCollectedNormal,
                      superValue: _dailyCollectedSuper,
                      icon: Icons.eco,
                      accentColor: const Color(0xFF10B981),
                      bgColor: const Color(0xFFF0FDF4),
                      borderColor: const Color(0xFFA7F3D0),
                      subtitleExtra: AppStrings.isSinhala ? 'සැපයුම්කරුවන්ගේ එකතුව' : 'Supplier collections',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      title: AppStrings.allocatedToOtherFactories,
                      totalValue: _otherAllocatedTotal,
                      normalValue: _otherAllocatedNormal,
                      superValue: _otherAllocatedSuper,
                      icon: Icons.factory,
                      accentColor: const Color(0xFFF59E0B),
                      bgColor: const Color(0xFFFFFBEB),
                      borderColor: const Color(0xFFFDE68A),
                      subtitleExtra: _otherFactoryAllocations.isEmpty
                          ? AppStrings.noOtherFactoryAllocations
                          : '${_otherFactoryAllocations.length} ${AppStrings.isSinhala ? 'කර්මාන්තශාලා' : 'factories'}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      title: AppStrings.availableForThisFactory,
                      totalValue: _availableTotal,
                      normalValue: _availableNormal,
                      superValue: _availableSuper,
                      icon: Icons.account_balance_wallet_outlined,
                      accentColor: const Color(0xFF06B6D4),
                      bgColor: const Color(0xFFECFEFF),
                      borderColor: const Color(0xFFA5F3FC),
                      highlight: true,
                      subtitleExtra: AppStrings.isSinhala ? 'වෙන් කිරීමට ඇති ප්‍රමාණය' : 'Available to allocate',
                    ),
                  ),
                ],
              ),
            ),



            // Other Factories Allocation Detail list (if other factories allocated)
            if (_otherFactoryAllocations.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.list_alt_rounded, size: 16, color: Colors.grey.shade700),
                  const SizedBox(width: 6),
                  Text(
                    AppStrings.otherFactoriesBreakdown,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildOtherFactoriesList(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required double totalValue,
    required double normalValue,
    required double superValue,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
    String? subtitleExtra,
    bool highlight = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: borderColor, width: highlight ? 1.5 : 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: accentColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${totalValue.toStringAsFixed(1)} Kg',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${AppStrings.normalLeaf}: ${normalValue.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (superValue > 0) ...[
                    Text(
                      ' | ${AppStrings.superLeaf}: ${superValue.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitleExtra ?? '',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: subtitleExtra != null ? Colors.grey.shade600 : Colors.transparent,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtherFactoriesList(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 620;

        if (isCompact) {
          // Vertical stacked list on mobile
          return Column(
            children: _otherFactoryAllocations.map((alloc) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6.0),
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.factory_outlined, size: 18, color: Color(0xFF0891B2)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${alloc['refNumber'].isNotEmpty ? 'No: ${alloc['refNumber']} - ' : ''}${alloc['name']}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(alloc['total'] as double).toStringAsFixed(1)} Kg',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0891B2)),
                        ),
                        Text(
                          '${AppStrings.normalLeaf}: ${(alloc['normal'] as double).toStringAsFixed(1)}${alloc['super'] > 0 ? ' | S: ${(alloc['super'] as double).toStringAsFixed(1)}' : ''}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        } else {
          // Wrap with chips on tablet, web, and desktop
          return Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            children: _otherFactoryAllocations.map((alloc) {
              return Container(
                constraints: const BoxConstraints(minWidth: 220),
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.factory_outlined, size: 18, color: Color(0xFF0891B2)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${alloc['refNumber'].isNotEmpty ? 'No: ${alloc['refNumber']} - ' : ''}${alloc['name']}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${AppStrings.normalLeaf}: ${(alloc['normal'] as double).toStringAsFixed(1)}${alloc['super'] > 0 ? ' | S: ${(alloc['super'] as double).toStringAsFixed(1)}' : ''}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${(alloc['total'] as double).toStringAsFixed(1)} Kg',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0891B2)),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('yyyy MMM dd').format(widget.selectedDate);
    double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.isSinhala ? '$formattedDate දින සටහන' : '$formattedDate Entry'),
          backgroundColor: const Color(0xFF06B6D4),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          AppStrings.isSinhala ? '$formattedDate දින සටහන' : '$formattedDate Entry',
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: const Color(0xFF06B6D4),
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
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      'No: ${widget.refNumber} - ${widget.factoryName}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF06B6D4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Daily collection and allocations summary card
                  _buildDailySummaryCard(context),

                  Text(AppStrings.leafDetails, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _grossWeightController,
                    enabled: !_isLocked,
                    style: TextStyle(color: _isLocked ? Colors.grey.shade700 : Colors.black87, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: AppStrings.normalLeafWeight,
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
                      labelText: AppStrings.superLeafWeight,
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

                  Text(AppStrings.additionalNotesAndDeductions, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _advanceController,
                    enabled: !_isLocked,
                    style: TextStyle(color: _isLocked ? Colors.grey.shade700 : Colors.black87, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: AppStrings.advanceAmount,
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
                  
                  if (_factoryItems.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(AppStrings.extraItems, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 8),
                    ..._factoryItems.map((f) {
                      String name = f['name'];
                      double price = (f['price'] as num).toDouble();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: TextFormField(
                          controller: _dynamicControllers[name],
                          enabled: !_isLocked,
                          style: TextStyle(color: _isLocked ? Colors.grey.shade700 : Colors.black87, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            labelText: '$name (Rs. $price)',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                            filled: _isLocked,
                            fillColor: _isLocked ? const Color(0xFFF3F4F6) : null,
                            prefixIcon: const Icon(Icons.shopping_bag),
                          ),
                          inputFormatters: [MaxNumberInputFormatter.currency],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: _validateInput, 
                        ),
                      );
                    }),
                  ],

                  if (!_isLocked) ...[
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _confirmAndSave, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          elevation: 2,
                        ),
                        child: Text(
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
}
