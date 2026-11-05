import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/skeleton_box.dart';
import '../../core/widgets/max_number_input_formatter.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import '../../core/app_state.dart';
import '../../core/items/item_model.dart';
import '../../core/items/item_service.dart';
import '../../core/localization/app_language.dart';
import '../../core/localization/app_strings.dart';
import 'dart:io' show Platform;
import '../../core/whatsapp/whatsapp_service.dart';
import '../../core/whatsapp/whatsapp_connect_dialog.dart';
import '../../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _passwordFormKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoadingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  final _monthlyFormKey = GlobalKey<FormState>();
  final TextEditingController _teaRateController = TextEditingController();
  final TextEditingController _teaRate2Controller = TextEditingController();
  final TextEditingController _transportRateController =
      TextEditingController();



  final TextEditingController _highVolumeThresholdController =
      TextEditingController(text: '150');

  late String _selectedMonth;
  late String _selectedYear;

  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  late List<String> _years;
  bool _isLoadingMonthly = false;
  bool _isLoadingGlobal = false;

  // Backup Loading State
  bool _isLoadingBackup = false;

  // Pagination Variables for Table
  int _currentRatesPage = 0;
  final int _ratesPerPage = 5;

  // Company Details & Address (4 rows), Contact Numbers, and Custom Page Size
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _companyLine1Controller = TextEditingController();
  final TextEditingController _companyLine2Controller = TextEditingController();
  final TextEditingController _companyLine3Controller = TextEditingController();
  final TextEditingController _companyLine4Controller = TextEditingController();
  final TextEditingController _contactNumbersController = TextEditingController();
  final TextEditingController _pageWidthController = TextEditingController(text: '21.07');
  final TextEditingController _pageHeightController = TextEditingController(text: '13.08');

  // App Theme Color
  final Color primaryAppColor = const Color(0xFF1976D2);

  // Custom Items Management
  List<CustomItem> _customItems = [];
  bool _isLoadingItems = false;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    _selectedMonth = _months[now.month - 1];
    _selectedYear = now.year.toString();
    _years = List.generate(5, (index) => (now.year - 1 + index).toString());

    _loadRatingConfig();
    _loadCompanyName();
    _loadCustomItems();
  }

  Future<void> _loadCustomItems() async {
    setState(() => _isLoadingItems = true);
    try {
      final items = await ItemService.getItems();
      if (mounted) {
        setState(() {
          _customItems = items;
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading custom items: $e');
      if (mounted) {
        setState(() => _isLoadingItems = false);
      }
    }
  }

  Future<void> _loadCompanyName() async {
    try {
      final res = await Supabase.instance.client
          .from('organizations')
          .select('company_line_1, company_line_2, company_line_3, company_line_4, company_line_5, name')
          .eq('id', AppState.currentOrganizationId.value ?? '')
          .maybeSingle();
      if (res != null) {
        setState(() {
          _orgNameController.text = res['name'] ?? '';
          _companyLine1Controller.text = res['company_line_1'] ?? '';
          _companyLine2Controller.text = res['company_line_2'] ?? '';
          _companyLine3Controller.text = res['company_line_3'] ?? '';
          _companyLine4Controller.text = res['company_line_4'] ?? '';

          String rawLine5 = (res['company_line_5'] ?? '').toString().trim();
          if (rawLine5.startsWith('{')) {
            try {
              final map = jsonDecode(rawLine5) as Map<String, dynamic>;
              _contactNumbersController.text = map['contact']?.toString() ?? '';
              _pageWidthController.text = (map['width'] ?? '21.07').toString();
              _pageHeightController.text = (map['height'] ?? '13.08').toString();
            } catch (_) {}
          } else {
            if (rawLine5.toLowerCase().contains('tel') || rawLine5.toLowerCase().contains('07')) {
              _contactNumbersController.text = rawLine5;
            } else if (_companyLine2Controller.text.toLowerCase().contains('tel') ||
                _companyLine2Controller.text.toLowerCase().contains('07')) {
              _contactNumbersController.text = _companyLine2Controller.text;
            }
            final match = RegExp(r'(\d+\.?\d*)\s*[xX*×]\s*(\d+\.?\d*)').firstMatch(rawLine5);
            if (match != null) {
              _pageWidthController.text = match.group(1)!;
              _pageHeightController.text = match.group(2)!;
            } else {
              _pageWidthController.text = '21.07';
              _pageHeightController.text = '13.08';
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading company name from org table: $e');
    }
  }

  Future<void> _loadRatingConfig() async {
    try {
      final orgId = AppState.currentOrganizationId.value ?? '';
      var doc = await Supabase.instance.client
          .from('global_settings')
          .select()
          .eq('organization_id', orgId)
          .or('id.eq.rating_config,id.eq.${orgId}_rating_config')
          .maybeSingle();
      if (doc != null) {
        setState(() {
          _highVolumeThresholdController.text =
              (doc['highVolumeThreshold'] ?? '150').toString();
        });
      }
    } catch (e) {
      // Ignore error initially
    }
  }


  Future<void> _exportDatabaseBackupWeb() async {
    setState(() {
      _isLoadingBackup = true;
    });
    try {
      Map<String, dynamic> fullBackupData = {};

      List<String> collections = [
        'customers',
        'daily_entries',
        'monthly_rates',
        'global_settings',
        'monthly_summaries',
      ];

      for (String col in collections) {
        var snapshot = await Supabase.instance.client.from(col).select().eq('organization_id', AppState.currentOrganizationId.value ?? '');
        fullBackupData[col] = snapshot;
      }

      String jsonString = const JsonEncoder.withIndent(
        '  ',
      ).convert(fullBackupData);
      String fileName =
          'smart_entry_backup_${DateTime.now().millisecondsSinceEpoch}.json';

      if (kIsWeb) {
        final bytes = utf8.encode(jsonString);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);

        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = fileName;

        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);

        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.isSinhala ? 'Backup එක Download වීම ආරම්භ විය!' : 'Backup download started!'),
              backgroundColor: Colors.green,
            ),
          );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.errorPrefix}$e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted)
        setState(() {
          _isLoadingBackup = false;
        });
    }
  }

  Future<void> _saveCompanyName() async {
    String name = _orgNameController.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.requiredField),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (name.length > 25) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.companyNameMaxChar),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    double width = double.tryParse(_pageWidthController.text.trim()) ?? 21.07;
    double height = double.tryParse(_pageHeightController.text.trim()) ?? 13.08;
    String configLine5 = jsonEncode({
      'contact': _contactNumbersController.text.trim(),
      'width': width,
      'height': height,
    });

    try {
      await Supabase.instance.client.from('organizations').update({
        'name': name,
        'company_line_1': _companyLine1Controller.text.trim(),
        'company_line_2': _companyLine2Controller.text.trim(),
        'company_line_3': _companyLine3Controller.text.trim(),
        'company_line_4': _companyLine4Controller.text.trim(),
        'company_line_5': configLine5,
      }).eq('id', AppState.currentOrganizationId.value ?? '');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.companyNameUpdated),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _savePageDimensions() async {
    double width = double.tryParse(_pageWidthController.text.trim()) ?? 21.07;
    double height = double.tryParse(_pageHeightController.text.trim()) ?? 13.08;

    try {
      final res = await Supabase.instance.client
          .from('organizations')
          .select('company_line_5')
          .eq('id', AppState.currentOrganizationId.value ?? '')
          .maybeSingle();

      String contact = _contactNumbersController.text.trim();
      if (res != null && res['company_line_5'] != null) {
        String raw = res['company_line_5'].toString().trim();
        if (raw.startsWith('{')) {
          try {
            final m = jsonDecode(raw) as Map<String, dynamic>;
            contact = m['contact']?.toString() ?? contact;
          } catch (_) {}
        }
      }

      String configLine5 = jsonEncode({
        'contact': contact,
        'width': width,
        'height': height,
      });

      await Supabase.instance.client.from('organizations').update({
        'company_line_5': configLine5,
      }).eq('id', AppState.currentOrganizationId.value ?? '');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('බිල්පත් පිටු ප්‍රමාණය සාර්ථකව සුරකින ලදී!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: '), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    if (_passwordFormKey.currentState!.validate()) {
      setState(() {
        _isLoadingPassword = true;
      });
      String currentInput = _currentPasswordController.text.trim();
      String newInput = _newPasswordController.text.trim();

      try {
        var authDoc = await Supabase.instance.client
            .from('app_users')
            .select().eq('organization_id', AppState.currentOrganizationId.value ?? '')
            .eq('username', AppState.username!)
            .maybeSingle();
        if (authDoc == null) throw Exception(AppStrings.isSinhala ? "පරිශීලක දත්ත සොයාගත නොහැක." : "User data not found.");
        String dbPassword = authDoc['password'].toString();

        if (currentInput != dbPassword) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppStrings.invalidPassword),
                backgroundColor: Colors.red,
              ),
            );
          setState(() {
            _isLoadingPassword = false;
          });
          return;
        }

        await Supabase.instance.client.from('app_users').update({
          'password': newInput,
        }).eq('username', AppState.username!);

        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.passwordUpdatedSuccess),
              backgroundColor: Colors.green,
            ),
          );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${AppStrings.errorPrefix}$e')));
      } finally {
        if (mounted)
          setState(() {
            _isLoadingPassword = false;
          });
      }
    }
  }

  Future<void> _saveMonthlyRates() async {
    if (_monthlyFormKey.currentState!.validate()) {
      setState(() {
        _isLoadingMonthly = true;
      });
      try {
        final orgId = AppState.currentOrganizationId.value ?? '';
        String rawMonthKey = '$_selectedYear-$_selectedMonth';
        // Prefix with organization_id to ensure strict multi-tenant isolation across all organizations
        String docId = '${orgId}_$rawMonthKey';
        String sortValue =
            '$_selectedYear-${(_months.indexOf(_selectedMonth) + 1).toString().padLeft(2, '0')}';

        // Clean up legacy un-prefixed record for this org if any exists
        await Supabase.instance.client
            .from('monthly_rates')
            .delete()
            .eq('organization_id', orgId)
            .eq('id', rawMonthKey);

        await Supabase.instance.client.from('monthly_rates').upsert({
          'organization_id': orgId,
          'id': docId,
          'year': _selectedYear,
          'month': _selectedMonth,
          'teaRate': double.parse(_teaRateController.text.trim()),
          'teaRate2': double.tryParse(_teaRate2Controller.text.trim()) ?? 0.0,
          'transportRate': double.parse(_transportRateController.text.trim()),
          'updatedAt': DateTime.now().toIso8601String(),
          'sortValue': sortValue,
        });

        _teaRateController.clear();
        _teaRate2Controller.clear();
        _transportRateController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.ratesSavedSuccess)),
          );
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${AppStrings.errorPrefix}$e')));
      } finally {
        if (mounted)
          setState(() {
            _isLoadingMonthly = false;
          });
      }
    }
  }


  Future<void> _saveRatingConfig() async {
    setState(() {
      _isLoadingGlobal = true;
    });
    try {
      final orgId = AppState.currentOrganizationId.value ?? '';
      await Supabase.instance.client.from('global_settings').upsert({
        'organization_id': orgId,
        'id': '${orgId}_rating_config',
        'highVolumeThreshold':
            double.tryParse(_highVolumeThresholdController.text.trim()) ??
            150.0,
      });

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.isSinhala ? 'පාරිභෝගික ශ්‍රේණිගත කිරීමේ සැකසුම් යාවත්කාලීන විය!' : 'Customer rating settings updated!'),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${AppStrings.errorPrefix}$e')));
    } finally {
      if (mounted)
        setState(() {
          _isLoadingGlobal = false;
        });
    }
  }

  Future<void> _deleteRate(String docId) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              AppStrings.isSinhala ? 'මකා දමන්නද?' : 'Delete Rates?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              AppStrings.isSinhala ? 'ඔබට විශ්වාසද මෙම මාසයේ ගාස්තු විස්තර මකා දැමිය යුතුයි කියා?' : 'Are you sure you want to delete rate details for this month?',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  AppStrings.no,
                  style: const TextStyle(color: Colors.blueGrey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppStrings.yesDelete,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await Supabase.instance.client
            .from('monthly_rates')
            .delete()
            .eq('organization_id', AppState.currentOrganizationId.value ?? '')
            .eq('id', docId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.isSinhala ? 'ගාස්තු සාර්ථකව මකා දමන ලදි!' : 'Rates deleted successfully!')),
          );
          setState(() {
            _currentRatesPage = 0;
          });
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${AppStrings.errorPrefix}$e')));
      }
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _teaRateController.dispose();
    _teaRate2Controller.dispose();
    _transportRateController.dispose();
    _highVolumeThresholdController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // UI Helper
  // ---------------------------------------------------------
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Colors.blueGrey),
      prefixIcon: Icon(icon, size: 20, color: Colors.blueGrey),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryAppColor, width: 1.5),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // UI BUILD
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F2937),
          elevation: 0,
          title: Text(
            AppStrings.settings,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 20),
            labelColor: primaryAppColor,
            unselectedLabelColor: Colors.blueGrey.shade400,
            indicatorColor: primaryAppColor,
            indicatorWeight: 4,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            tabs: [
              Tab(text: AppStrings.itemsTab),
              Tab(text: AppStrings.monthlyRatesTab),
              Tab(text: AppStrings.ratingsTab),
              Tab(text: AppStrings.securityTab),
              Tab(text: AppStrings.organizationTab),
              Tab(text: AppStrings.aboutTab),
            ],
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: TabBarView(
            children: [
              _buildGlobalPricesTab(), // Tab 1: Items
              _buildMonthlyRatesTab(), // Tab 2: Monthly Rates (Form + History Table)
              _buildRatingConfigTab(), // Tab 3: Ratings
              _buildSecurityTab(), // Tab 4: Security
              _buildOrganizationTab(), // Tab 5: Organization (2-Col Info)
              _buildAboutTab(), // Tab 6: About (OrbitView Innovations & App Updates)
            ],
          ),
        ),
      ),
    );
  }

  void _showAddEditItemDialog({CustomItem? item}) {
    if (item == null && _customItems.length >= ItemService.maxItemsPerOrg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.maxItemsReached),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: item?.name ?? '');
    final codeController = TextEditingController(text: item?.code ?? '');
    final priceController = TextEditingController(
      text: item != null ? item.unitPrice.toStringAsFixed(2) : '',
    );
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  item == null ? Icons.add_circle_outline_rounded : Icons.edit_note_rounded,
                  color: primaryAppColor,
                ),
                const SizedBox(width: 8),
                Text(
                  item == null ? AppStrings.addItem : AppStrings.editItem,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: AppStrings.itemName,
                        hintText: AppStrings.isSinhala ? 'උදා: පොහොර 1, තේ කොළ පැකට් 1' : 'e.g. Fertilizer 1',
                        prefixIcon: const Icon(Icons.inventory_2_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? AppStrings.requiredField : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: codeController,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 5,
                            decoration: InputDecoration(
                              labelText: AppStrings.itemCode,
                              hintText: 'F1, T1..',
                              counterText: '',
                              prefixIcon: const Icon(Icons.tag_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return AppStrings.requiredField;
                              if (v.trim().length > 5) return 'Max 5 chars';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: priceController,
                            decoration: InputDecoration(
                              labelText: AppStrings.unitPrice,
                              prefixText: 'Rs. ',
                              prefixIcon: const Icon(Icons.payments_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              MaxNumberInputFormatter.currency,
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return AppStrings.requiredField;
                              final err = MaxNumberInputFormatter.validate(v);
                              if (err != null) return err;
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text(AppStrings.no, style: const TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        final messenger = ScaffoldMessenger.of(context);
                        setDialogState(() => isSaving = true);
                        try {
                          final orgId = AppState.currentOrganizationId.value ?? '';
                          final parsedPrice = double.parse(priceController.text.trim());
                          final customItem = CustomItem(
                            id: item?.id ?? '',
                            organizationId: orgId,
                            slotIndex: item?.slotIndex ?? 0,
                            code: codeController.text.trim().toUpperCase(),
                            name: nameController.text.trim(),
                            unitPrice: parsedPrice,
                            isActive: true,
                          );

                          await ItemService.saveItem(customItem);
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadCustomItems();
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(AppStrings.itemSaved)),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('${AppStrings.errorPrefix}$e')),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryAppColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(AppStrings.save),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteItem(CustomItem item) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppStrings.confirm),
        content: Text('${AppStrings.deleteItemConfirm}\n\n"${item.name} (${item.code})"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.no, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ItemService.deleteItem(item);
                await _loadCustomItems();
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(AppStrings.itemDeleted)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('${AppStrings.errorPrefix}$e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.yes),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalPricesTab() {
    final reachedMax = _customItems.length >= ItemService.maxItemsPerOrg;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.itemsManagementTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppStrings.isSinhala
                          ? 'ආයතනයට අදාළ පොහොර, තේ පැකට් සහ වෙනත් අමතර භාණ්ඩ උපරිම 8ක් දක්වා මෙතැනින් කළමනාකරණය කළ හැක.'
                          : 'Manage up to 8 custom items (fertilizers, tea packets, agro chemicals) for this organization.',
                      style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: reachedMax ? Colors.orange.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: reachedMax ? Colors.orange.shade400 : Colors.blue.shade300,
                      ),
                    ),
                    child: Text(
                      '${_customItems.length} / ${ItemService.maxItemsPerOrg} ${AppStrings.isSinhala ? "භාණ්ඩ" : "Items"}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: reachedMax ? Colors.orange.shade900 : Colors.blue.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: reachedMax ? null : () => _showAddEditItemDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(AppStrings.addItem),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryAppColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_isLoadingItems)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_customItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.isSinhala ? 'භාණ්ඩ කිසිවක් සටහන් කර නොමැත' : 'No items configured yet',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 700 ? 2 : 1;
                final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: _customItems.map((item) {
                    return SizedBox(
                      width: itemWidth,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _cardDecoration(),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: primaryAppColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: primaryAppColor.withValues(alpha: 0.3),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                item.code,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: primaryAppColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF1F2937),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Slot ${item.slotIndex}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Rs. ${item.unitPrice.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              color: primaryAppColor,
                              tooltip: AppStrings.editItem,
                              onPressed: () => _showAddEditItemDialog(item: item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: Colors.red.shade400,
                              tooltip: 'Delete',
                              onPressed: () => _confirmDeleteItem(item),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlyRatesTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 900;

        final headerWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.monthlyTeaAndTransportRates,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.isSinhala
                  ? 'එක් එක් මාසය සඳහා ගෙවන දළු මිල සහ ප්‍රවාහන ගාස්තු මෙතැනින් ඇතුළත් කරන්න.'
                  : 'Enter monthly tea leaf and transport rates here.',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ],
        );

        final formCard = Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Form(
            key: _monthlyFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedYear,
                        decoration: _buildInputDecoration(
                          AppStrings.year,
                          Icons.calendar_month_rounded,
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.blueGrey,
                        ),
                        items: _years
                            .map(
                              (y) => DropdownMenuItem(value: y, child: Text(y)),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedYear = val!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedMonth,
                        decoration: _buildInputDecoration(
                          AppStrings.month,
                          Icons.date_range_rounded,
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.blueGrey,
                        ),
                        items: _months
                            .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedMonth = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _teaRateController,
                        decoration: _buildInputDecoration(
                          AppStrings.normalTeaRate,
                          Icons.monetization_on_outlined,
                        ),
                        inputFormatters: [MaxNumberInputFormatter.currency],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (val) =>
                            val!.isEmpty ? AppStrings.requiredField : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _teaRate2Controller,
                        decoration: _buildInputDecoration(
                          AppStrings.superTeaRate,
                          Icons.monetization_on_outlined,
                        ),
                        inputFormatters: [MaxNumberInputFormatter.currency],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: TextFormField(
                        controller: _transportRateController,
                        decoration: _buildInputDecoration(
                          AppStrings.transportRate,
                          Icons.local_shipping_outlined,
                        ),
                        inputFormatters: [MaxNumberInputFormatter.currency],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (val) =>
                            val!.isEmpty ? AppStrings.requiredField : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isLoadingMonthly ? null : _saveMonthlyRates,
                          icon: _isLoadingMonthly
                              ? const SizedBox.shrink()
                              : const Icon(Icons.save_rounded, size: 18),
                          label: _isLoadingMonthly
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  AppStrings.saveRates,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryAppColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        final tableCard = _buildSavedRatesTableSection();

        if (isWide) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                headerWidget,
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: formCard),
                    const SizedBox(width: 20),
                    Expanded(flex: 6, child: tableCard),
                  ],
                ),
              ],
            ),
          );
        } else {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerWidget,
                const SizedBox(height: 14),
                formCard,
                const SizedBox(height: 20),
                tableCard,
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildSavedRatesTableSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.isSinhala ? 'සුරැකි මාසික ගාස්තු ලැයිස්තුව' : 'Saved Monthly Rates History',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            Text(
              AppStrings.isSinhala ? '(පිටුවකට 5 බැගින්)' : '(5 per page)',
              style: const TextStyle(fontSize: 11.5, color: Colors.blueGrey),
            ),
          ],
        ),
        const SizedBox(height: 10),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('monthly_rates')
                .stream(primaryKey: ['id']).eq('organization_id', AppState.currentOrganizationId.value ?? ''),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  itemBuilder: (context, index) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SkeletonBox(width: double.infinity, height: 60),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: _cardDecoration(),
                  child: Center(
                    child: Text(
                      AppStrings.isSinhala ? 'දැනට කිසිදු ගාස්තුවක් ඇතුළත් කර නොමැත.' : 'No rates entered yet.',
                      style: const TextStyle(color: Colors.blueGrey),
                    ),
                  ),
                );
              }

              // Robust Local Sorting (Year DESC, Month DESC)
              List<Map<String, dynamic>> allDocs =
                  List<Map<String, dynamic>>.from(snapshot.data!);
              allDocs.sort((a, b) {
                int yearA = int.tryParse(a['year']?.toString() ?? '0') ?? 0;
                int yearB = int.tryParse(b['year']?.toString() ?? '0') ?? 0;
                if (yearA != yearB) return yearB.compareTo(yearA);

                int monthIdxA = _months.indexOf(a['month']?.toString() ?? '');
                int monthIdxB = _months.indexOf(b['month']?.toString() ?? '');
                return monthIdxB.compareTo(monthIdxA);
              });

              // Pagination calculation
              int totalPages = (allDocs.length / _ratesPerPage).ceil();
              if (totalPages < 1) totalPages = 1;

              if (_currentRatesPage >= totalPages) {
                _currentRatesPage = totalPages - 1;
              }
              if (_currentRatesPage < 0) _currentRatesPage = 0;

              List<Map<String, dynamic>> pageDocs = allDocs
                  .skip(_currentRatesPage * _ratesPerPage)
                  .take(_ratesPerPage)
                  .toList();

              return Column(
                children: [
                  Container(
                    decoration: _cardDecoration(),
                    clipBehavior: Clip.antiAlias,
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2.2),
                        1: FlexColumnWidth(1.5),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(1.0),
                      },
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9FAFB),
                          ),
                          children: [
                            _buildTableHeader(AppStrings.month),
                            _buildTableHeader(AppStrings.isSinhala ? 'දළු මිල\n(Rs)' : 'Leaf Rate\n(Rs)'),
                            _buildTableHeader(AppStrings.isSinhala ? 'ප්‍රවාහනය\n(Rs)' : 'Transport\n(Rs)'),
                            _buildTableHeader(''),
                          ],
                        ),
                        ...pageDocs.map((doc) {
                          return TableRow(
                            children: [
                              _buildTableCell(
                                '${doc['year'] ?? ''}\n${doc['month'] ?? ''}',
                                isBold: true,
                              ),
                              _buildTableCell(
                                ((doc['teaRate2'] as num? ?? 0) > 0)
                                    ? '${AppStrings.isSinhala ? "සාමාන්‍ය" : "Normal"}: ${(doc['teaRate'] as num? ?? 0).toDouble().toStringAsFixed(2)}\n${AppStrings.isSinhala ? "සුපිරි" : "Super"}: ${(doc['teaRate2'] as num? ?? 0).toDouble().toStringAsFixed(2)}'
                                    : (doc['teaRate'] as num? ?? 0).toDouble().toStringAsFixed(2),
                              ),
                              _buildTableCell(
                                (doc['transportRate'] as num? ?? 0)
                                    .toDouble()
                                    .toStringAsFixed(2),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                onPressed: () => _deleteRate(doc['id']),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Pagination Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _currentRatesPage > 0
                            ? () => setState(() => _currentRatesPage--)
                            : null,
                        icon: const Icon(Icons.chevron_left, size: 18),
                        label: Text(AppStrings.previous),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryAppColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      Text(
                        '${AppStrings.page} ${_currentRatesPage + 1} / $totalPages',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                          fontSize: 12,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _currentRatesPage < totalPages - 1
                            ? () => setState(() => _currentRatesPage++)
                            : null,
                        icon: const Icon(Icons.chevron_right, size: 16),
                        label: Text(AppStrings.next),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryAppColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      );
  }

  Widget _buildRatingConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.isSinhala ? 'පාරිභෝගික ශ්‍රේණිගත කිරීමේ සැකසුම්' : 'Customer Rating Settings',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.isSinhala ? 'පාරිභෝගිකයින්ගේ දළු සැපයීම සහ ණය මත පදනම්ව ඔවුන්ගේ ශ්‍රේණිය (Rating) ස්වයංක්‍රීයව තීරණය වන ආකාරය මෙහිදී දැකගත හැක.' : 'View how customer ratings are automatically determined based on leaf supply and debts.',
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.isSinhala ? 'ඉහළ දළු සැපයුම් ප්‍රමාණය' : 'High Volume Target',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _highVolumeThresholdController,
                  decoration: _buildInputDecoration(
                    AppStrings.isSinhala ? 'අවම කිලෝග්‍රෑම් ගණන (උදා: 150)' : 'Minimum Kilograms (e.g. 150)',
                    Icons.scale_rounded,
                  ),
                  inputFormatters: [MaxNumberInputFormatter.currency],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoadingGlobal ? null : _saveRatingConfig,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryAppColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoadingGlobal
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            AppStrings.saveConfig,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            AppStrings.isSinhala ? 'ශ්‍රේණිගත කිරීම් සිදුවන ආකාරය:' : 'How Ratings Work:',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),

          _buildTierInfoTile(
            title: AppStrings.isSinhala ? 'ප්ලැටිනම්' : 'Platinum',
            desc:
                AppStrings.isSinhala ? 'ඉහත සැකසූ ප්‍රමාණයට වඩා වැඩිපුර දළු ලබාදෙන, ණය නොමැති, සහ පසුගිය දින 45 තුළ ක්‍රියාකාරී පාරිභෝගිකයින්.' : 'Supplies more than the target above, has no arrears, and active within the last 45 days.',
            color: Colors.amber.shade700,
            imagePath: 'assets/badges/badge_diamond.png',
          ),
          _buildTierInfoTile(
            title: AppStrings.isSinhala ? 'රන්' : 'Gold',
            desc:
                AppStrings.isSinhala ? 'කිලෝග්‍රෑම් 50 ට වඩා වැඩිපුර දළු ලබාදෙන සහ කිසිදු ණය නොමැති පාරිභෝගිකයින්.' : 'Supplies more than 50 kg and has no arrears.',
            color: Colors.orange.shade600,
            imagePath: 'assets/badges/badge_gold.png',
          ),
          _buildTierInfoTile(
            title: AppStrings.isSinhala ? 'රිදී' : 'Silver',
            desc:
                AppStrings.isSinhala ? 'කිලෝග්‍රෑම් 50 ට අඩුවෙන් දළු ලබාදෙන (හෝ අක්‍රිය), එහෙත් කිසිදු ණය නොමැති පාරිභෝගිකයින්.' : 'Supplies less than 50 kg (or inactive), but has no arrears.',
            color: Colors.grey.shade600,
            imagePath: 'assets/badges/badge_platinum.png',
          ),
          _buildTierInfoTile(
            title: AppStrings.isSinhala ? 'අවදානම්' : 'Risk',
            desc:
                AppStrings.isSinhala ? 'අවසන් බිල්පතට අනුව හිඟ මුදල් පවතින ඕනෑම පාරිභෝගිකයෙකු මෙම කාණ්ඩයට අයත් වේ.' : 'Any customer who has an outstanding debt/arrears according to their latest bill.',
            color: Colors.red.shade600,
            imagePath: 'assets/badges/badge_ruby.png',
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.isSinhala ? 'සක්‍රිය සහ අක්‍රිය තත්ත්වයන්:' : 'Active vs Inactive Status:',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoBox(
            title: AppStrings.active,
            desc: AppStrings.isSinhala ? 'අවසන් වරට දළු ලබා දී දින 45ක් ඇතුළත සිටින පාරිභෝගිකයින්.' : 'Customers who supplied leaf within the last 45 days.',
            color: Colors.green.shade600,
            icon: Icons.check_circle_outline,
          ),
          _buildInfoBox(
            title: AppStrings.inactive,
            desc: AppStrings.isSinhala ? 'අවසන් වරට දළු ලබා දී දින 45කට වඩා ගත වී ඇති පාරිභෝගිකයින්.' : 'Customers who have not supplied leaf for more than 45 days.',
            color: Colors.red.shade400,
            icon: Icons.cancel_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({
    required String title,
    required String desc,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.blueGrey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierInfoTile({
    required String title,
    required String desc,
    required Color color,
    required String imagePath,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(imagePath, width: 20, height: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSettingsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.languageSettings,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.selectLanguage,
          style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildLanguageOptionTile(
                  title: 'සිංහල',
                  subtitle: 'Sinhala',
                  icon: Icons.language,
                  isSelected: AppLanguageService.isSinhala,
                  onTap: () {
                    AppLanguageService.setLanguage(AppLanguage.sinhala);
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildLanguageOptionTile(
                  title: 'English',
                  subtitle: 'ඉංග්‍රීසි',
                  icon: Icons.translate,
                  isSelected: AppLanguageService.isEnglish,
                  onTap: () {
                    AppLanguageService.setLanguage(AppLanguage.english);
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildLanguageOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryAppColor.withValues(alpha: 0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryAppColor : Colors.grey.shade300,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? primaryAppColor : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected ? primaryAppColor : const Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? primaryAppColor.withValues(alpha: 0.8) : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: primaryAppColor, size: 20)
            else
              Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatsAppServiceCard() {
    final service = WhatsAppService.instance;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ValueListenableBuilder<WhatsAppConnectionState>(
        valueListenable: service.state,
        builder: (context, state, _) {
          final bool isConnected = state == WhatsAppConnectionState.connected;
          final bool isStarting = state == WhatsAppConnectionState.starting;
          final bool isPairing = state == WhatsAppConnectionState.pairing;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      color: Color(0xFF25D366),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WhatsApp Automation Service',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Automated bill and monthly invoice delivery via WhatsApp Web',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? const Color(0xFFDCFCE7)
                          : (isPairing
                              ? const Color(0xFFFEF3C7)
                              : (isStarting ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9))),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isConnected
                            ? const Color(0xFF86EFAC)
                            : (isPairing
                                ? const Color(0xFFFCD34D)
                                : (isStarting ? const Color(0xFFBAE6FD) : const Color(0xFFCBD5E1))),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isConnected
                                ? const Color(0xFF16A34A)
                                : (isPairing
                                    ? const Color(0xFFD97706)
                                    : (isStarting ? const Color(0xFF0284C7) : const Color(0xFF64748B))),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isConnected
                              ? 'Connected'
                              : (isPairing
                                  ? 'QR Ready'
                                  : (isStarting ? 'Starting...' : 'Disconnected')),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isConnected
                                ? const Color(0xFF15803D)
                                : (isPairing
                                    ? const Color(0xFFB45309)
                                    : (isStarting ? const Color(0xFF0369A1) : const Color(0xFF475569))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (isConnected) ...[
                ValueListenableBuilder<String?>(
                  valueListenable: service.connectedPhone,
                  builder: (context, phone, _) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              phone != null && phone.isNotEmpty
                                  ? 'WhatsApp Linked (+${phone.trim()}). Ready to send invoices.'
                                  : 'WhatsApp Linked & Active. Ready to send invoices.',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isPairing ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isPairing ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPairing ? Icons.qr_code_2 : Icons.info_outline,
                        color: isPairing ? const Color(0xFFD97706) : Colors.blueGrey,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isPairing
                              ? 'Scan the QR code to pair your phone and start automated messaging.'
                              : 'Click "Connect WhatsApp" below to launch the background service.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isPairing ? const Color(0xFF92400E) : Colors.blueGrey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!isConnected) ...[
                    ElevatedButton.icon(
                      onPressed: () => WhatsAppConnectDialog.show(context),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: Text(isPairing ? 'Scan QR Code' : 'Connect WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: () => WhatsAppConnectDialog.show(context),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Manage Connection'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => WhatsAppConnectDialog.show(context),
                      icon: const Icon(Icons.link_off, size: 18, color: Colors.red),
                      label: const Text('Disconnect', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  OutlinedButton.icon(
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Checking WhatsApp service status...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                      await service.checkStatus();
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh Status'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Language Settings Card
          if (!kIsWeb && Platform.isWindows) ...[
            _buildWhatsAppServiceCard(),
            const SizedBox(height: 24),
          ],
          _buildLanguageSettingsCard(),

          if (kIsWeb) ...[
            Text(
              AppStrings.databaseBackupTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.databaseBackupSubtitle,
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoadingBackup ? null : _exportDatabaseBackupWeb,
                  icon: _isLoadingBackup
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.cloud_download_rounded, size: 22),
                  label: Text(
                    _isLoadingBackup
                        ? AppStrings.backupPreparing
                        : AppStrings.downloadBackup,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],

          Text(
            AppStrings.changePasswordTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.changePasswordSubtitle,
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Form(
              key: _passwordFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: _obscureCurrent,
                    decoration: InputDecoration(
                      labelText: AppStrings.currentPassword,
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.blueGrey,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 1.5,
                        ),
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        size: 20,
                        color: Colors.blueGrey,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrent
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.blueGrey,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                    ),
                    validator: (val) =>
                        val!.isEmpty ? AppStrings.enterCurrentPassword : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: AppStrings.newPassword,
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.blueGrey,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 1.5,
                        ),
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_reset,
                        size: 20,
                        color: Colors.blueGrey,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew ? Icons.visibility_off : Icons.visibility,
                          color: Colors.blueGrey,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    validator: (val) {
                      if (val!.isEmpty) return AppStrings.enterNewPassword;
                      if (val.length < 3) {
                        return AppStrings.requiredField;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: AppStrings.confirmNewPassword,
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.blueGrey,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 1.5,
                        ),
                      ),
                      prefixIcon: const Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: Colors.blueGrey,
                      ),
                    ),
                    validator: (val) {
                      if (val!.isEmpty) return AppStrings.confirmNewPassword;
                      if (val != _newPasswordController.text) {
                        return AppStrings.passwordsDoNotMatch;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoadingPassword ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoadingPassword
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              AppStrings.updatePassword,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Company Name & Address
          Text(
            AppStrings.companyNameTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.companyNameSubtitle,
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTwoCol = constraints.maxWidth >= 600;
                return Column(
                  children: [
                    _buildTwoColRow(
                      _buildCompanyLineField(
                        AppStrings.orgNameField,
                        _orgNameController,
                        maxLength: 25,
                        icon: Icons.store_rounded,
                        hintText: 'e.g. NALEEN SURANGA',
                      ),
                      _buildCompanyLineField(
                        AppStrings.contactNumbersField,
                        _contactNumbersController,
                        icon: Icons.phone_rounded,
                        hintText: 'e.g. Tel: 0713444934 / 0758258544',
                      ),
                      isTwoCol,
                    ),
                    _buildTwoColRow(
                      _buildCompanyLineField(
                        AppStrings.addressLine1,
                        _companyLine1Controller,
                        icon: Icons.location_on_rounded,
                        hintText: 'e.g. Authorized Green Dealer',
                      ),
                      _buildCompanyLineField(
                        AppStrings.addressLine2,
                        _companyLine2Controller,
                        icon: Icons.location_city_rounded,
                        hintText: 'e.g. Gangoda',
                      ),
                      isTwoCol,
                    ),
                    _buildTwoColRow(
                      _buildCompanyLineField(
                        AppStrings.addressLine3,
                        _companyLine3Controller,
                        icon: Icons.map_rounded,
                        hintText: 'e.g. Rakwana',
                      ),
                      _buildCompanyLineField(
                        AppStrings.addressLine4,
                        _companyLine4Controller,
                        icon: Icons.notes_rounded,
                        hintText: 'Optional Address Line 4',
                      ),
                      isTwoCol,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _saveCompanyName,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        label: Text(
                          AppStrings.saveName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 36),

          // Section 2: Bill Page Dimensions (Separate Section)
          Text(
            AppStrings.billPageSizeTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.billPageSizeSubtitle,
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 16),

          _buildCustomPageSizeInputs(),
        ],
      ),
    );
  }

  Widget _buildAboutTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Allow scrolling only on small mobile screens or when viewport height is too constrained (< 420px)
        final isConstrained = constraints.maxWidth < 600 || constraints.maxHeight < 420;

        if (isConstrained) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAppHeroHeader(),
                    const SizedBox(height: 10),
                    _buildSoftwareUpdateCard(),
                    const SizedBox(height: 10),
                    _buildDeveloperProfileCard(),
                    const SizedBox(height: 14),
                    _buildAboutFooter(),
                  ],
                ),
              ),
            ),
          );
        }

        // Desktop/Tablet: Fixed layout without any scrolling, footer pinned at bottom
        return Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAppHeroHeader(),
                  const SizedBox(height: 10),
                  _buildSoftwareUpdateCard(),
                  const SizedBox(height: 10),
                  _buildDeveloperProfileCard(),
                  const Spacer(),
                  _buildAboutFooter(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppHeroHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: const Color(0xFF1E40AF).withValues(alpha: 0.20),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF3B82F6),
                          Color(0xFF1D4ED8),
                          Color(0xFF1E3A8A),
                        ],
                        stops: [0.0, 0.55, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -10,
                    left: -10,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.60),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          radius: 0.75,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.12),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.eco_rounded,
                      color: Colors.white,
                      size: 26,
                      shadows: [
                        Shadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.40),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Smart Entry',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    FutureBuilder<String>(
                      future: UpdateService.getCurrentVersion(),
                      builder: (context, snapshot) {
                        final v = snapshot.data ?? '1.0.0';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            'v' + v,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        );
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Production Channel',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Automated Tea Leaf Collection, Real-Time Accounting & Billing Platform',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoftwareUpdateCard() {
    return FutureBuilder<String>(
      future: UpdateService.getCurrentVersion(),
      builder: (context, snapshot) {
        final currentVersion = snapshot.data ?? '1.0.0';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: primaryAppColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.system_update_rounded,
                      color: primaryAppColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Software Updates',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Automated client updates with hotfix and schema synchronization',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Installed Version: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                'v' + currentVersion,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Target Architecture: Windows x64 • Deployment: Native MSIX Package',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => UpdateService.checkForUpdate(
                        context,
                        showFeedbackIfUpToDate: true,
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text(
                        'Check for Updates',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryAppColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeveloperProfileCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF312E81)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.blur_on_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'OrbitView Innovations',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: const Text(
                            'Official System Provider',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4338CA),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Enterprise Software Architecture, Cloud Infrastructure & Dedicated Technical Support',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoCol = constraints.maxWidth >= 600;
              return isTwoCol
                  ? Row(
                      children: [
                        Expanded(
                          child: _buildEnterpriseContactTile(
                            icon: Icons.phone_in_talk_rounded,
                            iconColor: const Color(0xFF059669),
                            iconBg: const Color(0xFFECFDF5),
                            label: 'SUPPORT HOTLINE',
                            value: '0719362659',
                            description: 'Direct telephone line for operational assistance',
                            onCopy: () => _copyToClipboard('0719362659', 'Support Hotline'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEnterpriseContactTile(
                            icon: Icons.alternate_email_rounded,
                            iconColor: const Color(0xFF4F46E5),
                            iconBg: const Color(0xFFEEF2FF),
                            label: 'EMAIL SUPPORT',
                            value: 'orbitviewsupport@gmail.com',
                            description: 'Technical consultations, reports & inquiries',
                            onCopy: () => _copyToClipboard('orbitviewsupport@gmail.com', 'Support Email'),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildEnterpriseContactTile(
                          icon: Icons.phone_in_talk_rounded,
                          iconColor: const Color(0xFF059669),
                          iconBg: const Color(0xFFECFDF5),
                          label: 'SUPPORT HOTLINE',
                          value: '0719362659',
                          description: 'Direct telephone line for operational assistance',
                          onCopy: () => _copyToClipboard('0719362659', 'Support Hotline'),
                        ),
                        const SizedBox(height: 8),
                        _buildEnterpriseContactTile(
                          icon: Icons.alternate_email_rounded,
                          iconColor: const Color(0xFF4F46E5),
                          iconBg: const Color(0xFFEEF2FF),
                          label: 'EMAIL SUPPORT',
                          value: 'orbitviewsupport@gmail.com',
                          description: 'Technical consultations, reports & inquiries',
                          onCopy: () => _copyToClipboard('orbitviewsupport@gmail.com', 'Support Email'),
                        ),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEnterpriseContactTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    required String description,
    required VoidCallback onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 1),
                    SelectableText(
                      value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Copy to clipboard',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: onCopy,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutFooter() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '© 2026 OrbitView Innovations. All rights reserved.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'Smart Entry Enterprise Client',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(label + ' copied to clipboard: ' + text),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildTableHeader(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Color(0xFF4B5563),
        fontSize: 11.5,
      ),
    ),
  );
  Widget _buildTableCell(String text, {bool isBold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
        color: const Color(0xFF1F2937),
        fontSize: 12.5,
      ),
    ),
  );

  Widget _buildTwoColRow(Widget left, Widget right, bool isTwoCol) {
    if (isTwoCol) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 16),
          Expanded(child: right),
        ],
      );
    }
    return Column(
      children: [left, right],
    );
  }

  Widget _buildCompanyLineField(
    String label,
    TextEditingController controller, {
    int? maxLength,
    IconData icon = Icons.business,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        inputFormatters: maxLength != null
            ? [LengthLimitingTextInputFormatter(maxLength)]
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: const TextStyle(fontSize: 13, color: Colors.blueGrey),
          filled: true,
          fillColor: Colors.white,
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.indigo.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.indigo.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.indigo.shade400, width: 1.5),
          ),
          prefixIcon: Icon(
            icon,
            size: 20,
            color: Colors.blueGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomPageSizeInputs() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.print_rounded, size: 20, color: Color(0xFF16A34A)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.billPageSizeField,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Set printing width and height for invoice receipts & bills',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoCol = constraints.maxWidth >= 600;
              final widthField = TextField(
                controller: _pageWidthController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  MaxNumberInputFormatter.currency,
                ],
                decoration: InputDecoration(
                  labelText: AppStrings.pageLengthWidth,
                  hintText: '21.07',
                  suffixText: 'cm',
                  labelStyle: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              );

              final heightField = TextField(
                controller: _pageHeightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  MaxNumberInputFormatter.currency,
                ],
                decoration: InputDecoration(
                  labelText: AppStrings.pageHeight,
                  hintText: '13.08',
                  suffixText: 'cm',
                  labelStyle: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              );

              return isTwoCol
                  ? Row(
                      children: [
                        Expanded(child: widthField),
                        const SizedBox(width: 14),
                        Expanded(child: heightField),
                      ],
                    )
                  : Column(
                      children: [
                        widthField,
                        const SizedBox(height: 12),
                        heightField,
                      ],
                    );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                avatar: const Icon(Icons.receipt_long_rounded, size: 15, color: Color(0xFF16A34A)),
                label: const Text('Continuous (21.07 x 13.08 cm)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                onPressed: () {
                  setState(() {
                    _pageWidthController.text = '21.07';
                    _pageHeightController.text = '13.08';
                  });
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.crop_landscape_rounded, size: 15, color: Color(0xFF16A34A)),
                label: const Text('A5 Landscape (21.0 x 14.8 cm)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                onPressed: () {
                  setState(() {
                    _pageWidthController.text = '21.0';
                    _pageHeightController.text = '14.8';
                  });
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.description_outlined, size: 15, color: Color(0xFF16A34A)),
                label: const Text('A4 (21.0 x 29.7 cm)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                onPressed: () {
                  setState(() {
                    _pageWidthController.text = '21.0';
                    _pageHeightController.text = '29.7';
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _savePageDimensions,
              icon: const Icon(Icons.save_rounded, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              label: Text(
                AppStrings.saveConfig,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
