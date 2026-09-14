import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/skeleton_box.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // --- නව මුරපද Controllers ---
  final _passwordFormKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoadingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  // මාසික ගාස්තු සඳහා Controllers
  final _monthlyFormKey = GlobalKey<FormState>();
  final TextEditingController _teaRateController = TextEditingController();
  final TextEditingController _teaRate2Controller = TextEditingController();
  final TextEditingController _transportRateController =
      TextEditingController();

  // ස්ථිර (Global) අමතර භාණ්ඩ මිල සඳහා Controllers
  final _globalFormKey = GlobalKey<FormState>();
  final TextEditingController _fert1PriceController = TextEditingController();
  final TextEditingController _fert2PriceController = TextEditingController();
  final TextEditingController _teaPkt1PriceController = TextEditingController();
  final TextEditingController _teaPkt2PriceController = TextEditingController();

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

  // Company Details (5 lines)
  final TextEditingController _companyLine1Controller = TextEditingController(
    text: 'SmartEntry',
  );
  final TextEditingController _companyLine2Controller = TextEditingController();
  final TextEditingController _companyLine3Controller = TextEditingController();
  final TextEditingController _companyLine4Controller = TextEditingController();
  final TextEditingController _companyLine5Controller = TextEditingController();

  // App Theme Color
  final Color primaryAppColor = const Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    _selectedMonth = _months[now.month - 1];
    _selectedYear = now.year.toString();
    _years = List.generate(5, (index) => (now.year - 1 + index).toString());

    _loadGlobalPrices();
    _loadRatingConfig();
    _loadCompanyName();
  }

  Future<void> _loadCompanyName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _companyLine1Controller.text =
          prefs.getString('company_line_1') ?? 'SmartEntry';
      _companyLine2Controller.text = prefs.getString('company_line_2') ?? '';
      _companyLine3Controller.text = prefs.getString('company_line_3') ?? '';
      _companyLine4Controller.text = prefs.getString('company_line_4') ?? '';
      _companyLine5Controller.text = prefs.getString('company_line_5') ?? '';
    });
  }

  Future<void> _loadRatingConfig() async {
    try {
      var doc = await Supabase.instance.client
          .from('global_settings')
          .select()
          .eq('id', 'rating_config')
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

  Future<void> _loadGlobalPrices() async {
    try {
      var doc = await Supabase.instance.client
          .from('global_settings')
          .select()
          .eq('id', 'prices')
          .maybeSingle();
      if (doc != null) {
        setState(() {
          _fert1PriceController.text = (doc['fertilizer1Price'] ?? '')
              .toString();
          _fert2PriceController.text = (doc['fertilizer2Price'] ?? '')
              .toString();
          _teaPkt1PriceController.text = (doc['teaPacket1Price'] ?? '')
              .toString();
          _teaPkt2PriceController.text = (doc['teaPacket2Price'] ?? '')
              .toString();
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
        var snapshot = await Supabase.instance.client.from(col).select();
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
            const SnackBar(
              content: Text('Backup එක Download වීම ආරම්භ විය!'),
              backgroundColor: Colors.green,
            ),
          );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup ලබා ගැනීමේදී දෝෂයක්: $e'),
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'company_line_1',
      _companyLine1Controller.text.trim(),
    );
    await prefs.setString(
      'company_line_2',
      _companyLine2Controller.text.trim(),
    );
    await prefs.setString(
      'company_line_3',
      _companyLine3Controller.text.trim(),
    );
    await prefs.setString(
      'company_line_4',
      _companyLine4Controller.text.trim(),
    );
    await prefs.setString(
      'company_line_5',
      _companyLine5Controller.text.trim(),
    );
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ආයතනයේ නම සාර්ථකව සුරැකිණි!'),
          backgroundColor: Colors.green,
        ),
      );
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
            .from('global_settings')
            .select()
            .eq('id', 'auth')
            .maybeSingle();
        if (authDoc == null) throw Exception("මුරපද දත්ත සොයාගත නොහැක.");
        String dbPassword = authDoc['password'].toString();

        if (currentInput != dbPassword) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('වත්මන් මුරපදය වැරදියි!'),
                backgroundColor: Colors.red,
              ),
            );
          setState(() {
            _isLoadingPassword = false;
          });
          return;
        }

        await Supabase.instance.client.from('global_settings').upsert({
          'id': 'auth',
          'password': newInput,
        });

        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('මුරපදය සාර්ථකව යාවත්කාලීන විය!'),
              backgroundColor: Colors.green,
            ),
          );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('දෝෂයක්: $e')));
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
        String docId = '$_selectedYear-$_selectedMonth';
        String sortValue =
            '$_selectedYear-${(_months.indexOf(_selectedMonth) + 1).toString().padLeft(2, '0')}';

        await Supabase.instance.client.from('monthly_rates').upsert({
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

        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('මාසික ගාස්තු සාර්ථකව සුරකින ලදි!')),
          );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('දෝෂයක් මතු විය: $e')));
      } finally {
        if (mounted)
          setState(() {
            _isLoadingMonthly = false;
          });
      }
    }
  }

  Future<void> _saveGlobalPrices() async {
    if (_globalFormKey.currentState!.validate()) {
      setState(() {
        _isLoadingGlobal = true;
      });
      try {
        await Supabase.instance.client.from('global_settings').upsert({
          'id': 'prices',
          'fertilizer1Price': double.parse(_fert1PriceController.text.trim()),
          'fertilizer2Price': double.parse(_fert2PriceController.text.trim()),
          'teaPacket1Price': double.parse(_teaPkt1PriceController.text.trim()),
          'teaPacket2Price': double.parse(_teaPkt2PriceController.text.trim()),
        });

        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('අමතර භාණ්ඩ මිල ගණන් සාර්ථකව යාවත්කාලීන විය!'),
            ),
          );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('දෝෂයක් මතු විය: $e')));
      } finally {
        if (mounted)
          setState(() {
            _isLoadingGlobal = false;
          });
      }
    }
  }

  Future<void> _saveRatingConfig() async {
    setState(() {
      _isLoadingGlobal = true;
    });
    try {
      await Supabase.instance.client.from('global_settings').upsert({
        'id': 'rating_config',
        'highVolumeThreshold':
            double.tryParse(_highVolumeThresholdController.text.trim()) ??
            150.0,
      });

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('පාරිභෝගික ශ්‍රේණිගත කිරීමේ සැකසුම් යාවත්කාලීන විය!'),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('දෝෂයක් මතු විය: $e')));
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
            title: const Text(
              'මකා දමන්නද?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'ඔබට විශ්වාසද මෙම මාසයේ ගාස්තු විස්තර මකා දැමිය යුතුයි කියා?',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'නැහැ',
                  style: TextStyle(color: Colors.blueGrey),
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
                child: const Text(
                  'ඔව්, මකන්න',
                  style: TextStyle(color: Colors.white),
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
            .eq('id', docId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ගාස්තු සාර්ථකව මකා දමන ලදි!')),
          );
          setState(() {
            _currentRatesPage = 0;
          });
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('දෝෂයක්: $e')));
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
    _fert1PriceController.dispose();
    _fert2PriceController.dispose();
    _teaPkt1PriceController.dispose();
    _teaPkt2PriceController.dispose();
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
          color: Colors.black.withOpacity(0.02),
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
      length: 5, // Tabs 5k thiyenawa
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F2937),
          elevation: 0,
          title: const Text(
            'සැකසුම් (Settings)',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          bottom: TabBar(
            isScrollable: true, // Mobile ekata scroll karanna damma
            tabAlignment: TabAlignment.start, // Left align wenna
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
            tabs: const [
              Tab(text: 'අමතර භාණ්ඩ'),
              Tab(text: 'මාසික ගාස්තු'),
              Tab(text: 'ගාස්තු ලැයිස්තුව'),
              Tab(text: 'ශ්‍රේණිගත කිරීම්'),
              Tab(text: 'ආරක්ෂිත/දත්ත'),
            ],
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: TabBarView(
            children: [
              _buildGlobalPricesTab(), // Tab 1
              _buildMonthlyRatesTab(), // Tab 2
              _buildSavedRatesTab(), // Tab 3 (Pagination added)
              _buildRatingConfigTab(), // Tab 4
              _buildSecurityTab(), // Tab 5
            ],
          ),
        ),
      ),
    );
  }

  // --- Tab 1: අමතර භාණ්ඩ මිල ගණන් ---
  Widget _buildGlobalPricesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'අමතර භාණ්ඩ මිල ගණන් (ස්ථිර)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'මෙම මිල ගණන් මින් ඉදිරියට නිකුත් කරන සියලුම පොහොර සහ තේ පැකට් සඳහා අදාළ වේ.',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(),
            child: Form(
              key: _globalFormKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _fert1PriceController,
                          decoration: _buildInputDecoration(
                            'පොහොර 1 (Rs)',
                            Icons.eco_rounded,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (val) => val!.isEmpty ? 'මිල දෙන්න' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _fert2PriceController,
                          decoration: _buildInputDecoration(
                            'පොහොර 2 (Rs)',
                            Icons.eco_rounded,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (val) => val!.isEmpty ? 'මිල දෙන්න' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _teaPkt1PriceController,
                          decoration: _buildInputDecoration(
                            'තේ පැකට් 1 (Rs)',
                            Icons.local_cafe_rounded,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (val) => val!.isEmpty ? 'මිල දෙන්න' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _teaPkt2PriceController,
                          decoration: _buildInputDecoration(
                            'තේ පැකට් 2 (Rs)',
                            Icons.local_cafe_rounded,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (val) => val!.isEmpty ? 'මිල දෙන්න' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoadingGlobal ? null : _saveGlobalPrices,
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
                          : const Text(
                              'මිල ගණන් යාවත්කාලීන කරන්න',
                              style: TextStyle(
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

  // --- Tab 2: මාසික ගාස්තු සැකසුම් ---
  Widget _buildMonthlyRatesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'මාසික ගාස්තු සැකසුම්',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'එක් එක් මාසය සඳහා ගෙවන දළු මිල සහ ප්‍රවාහන ගාස්තු මෙතැනින් ඇතුළත් කරන්න.',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(),
            child: Form(
              key: _monthlyFormKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedYear,
                          decoration: _buildInputDecoration(
                            'වර්ෂය',
                            Icons.calendar_month_rounded,
                          ),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.blueGrey,
                          ),
                          items: _years
                              .map(
                                (y) =>
                                    DropdownMenuItem(value: y, child: Text(y)),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedYear = val!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedMonth,
                          decoration: _buildInputDecoration(
                            'මාසය',
                            Icons.date_range_rounded,
                          ),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.blueGrey,
                          ),
                          items: _months
                              .map(
                                (m) =>
                                    DropdownMenuItem(value: m, child: Text(m)),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedMonth = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _teaRateController,
                          decoration: _buildInputDecoration(
                            'සාමාන්‍ය දළු මිල (Rs)',
                            Icons.monetization_on_outlined,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (val) =>
                              val!.isEmpty ? 'මිල ඇතුළත් කරන්න' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _teaRate2Controller,
                          decoration: _buildInputDecoration(
                            'සුපිරි දළු (Rs) - Option',
                            Icons.monetization_on_outlined,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _transportRateController,
                          decoration: _buildInputDecoration(
                            'ප්‍රවාහනය (Rs)',
                            Icons.local_shipping_outlined,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (val) =>
                              val!.isEmpty ? 'ගාස්තුව ඇතුළත් කරන්න' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoadingMonthly ? null : _saveMonthlyRates,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryAppColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoadingMonthly
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'මාසික ගාස්තු සුරකින්න',
                              style: TextStyle(
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

  // --- Tab 3: සුරැකි මාසික ගාස්තු ලැයිස්තුව (With Pagination) ---
  Widget _buildSavedRatesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'සුරැකි මාසික ගාස්තු ලැයිස්තුව',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'දැනට පද්ධතියේ සුරකී ඇති සියලුම මාසික ගාස්තු. (පිටුවකට 5 බැගින්)',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 16),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('monthly_rates')
                .stream(primaryKey: ['id']),
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
                  child: const Center(
                    child: Text(
                      'දැනට කිසිදු ගාස්තුවක් ඇතුළත් කර නොමැත.',
                      style: TextStyle(color: Colors.blueGrey),
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
                            _buildTableHeader('මාසය'),
                            _buildTableHeader('දළු මිල\n(Rs)'),
                            _buildTableHeader('ප්‍රවාහනය\n(Rs)'),
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
                                    ? 'සාමාන්‍ය: ${(doc['teaRate'] as num? ?? 0).toDouble().toStringAsFixed(2)}\nසුපිරි: ${(doc['teaRate2'] as num? ?? 0).toDouble().toStringAsFixed(2)}'
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
                        label: const Text("පෙර"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryAppColor,
                          elevation: 0,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      Text(
                        'පිටුව ${_currentRatesPage + 1} / $totalPages',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                          fontSize: 13,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _currentRatesPage < totalPages - 1
                            ? () => setState(() => _currentRatesPage++)
                            : null,
                        icon: const Icon(Icons.chevron_right, size: 18),
                        label: const Text("ඊළඟ"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryAppColor,
                          elevation: 0,
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
      ),
    );
  }

  // --- Tab 4: පාරිභෝගික ශ්‍රේණිගත කිරීම් සැකසුම් ---
  Widget _buildRatingConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'පාරිභෝගික ශ්‍රේණිගත කිරීමේ සැකසුම්',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'පාරිභෝගිකයින්ගේ දළු සැපයීම සහ ණය මත පදනම්ව ඔවුන්ගේ ශ්‍රේණිය (Rating) ස්වයංක්‍රීයව තීරණය වන ආකාරය මෙහිදී දැකගත හැක.',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ඉහළ දළු සැපයුම් ප්‍රමාණය (High Volume)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _highVolumeThresholdController,
                  decoration: _buildInputDecoration(
                    'අවම කිලෝග්‍රෑම් ගණන (උදා: 150)',
                    Icons.scale_rounded,
                  ),
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
                        : const Text(
                            'සැකසුම සුරකින්න',
                            style: TextStyle(
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
          const Text(
            'ශ්‍රේණිගත කිරීම් සිදුවන ආකාරය:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),

          _buildTierInfoTile(
            title: 'Platinum (විශිෂ්ට)',
            desc:
                'ඉහත සැකසූ ප්‍රමාණයට වඩා වැඩිපුර දළු ලබාදෙන, ණය (Arrears) නොමැති, සහ පසුගිය දින 45 තුළ ක්‍රියාකාරී පාරිභෝගිකයින්.',
            color: Colors.amber.shade700,
            imagePath: 'assets/badges/badge_diamond.png',
          ),
          _buildTierInfoTile(
            title: 'Gold (ඉතා හොඳ)',
            desc:
                'කිලෝග්‍රෑම් 50 ට වඩා වැඩිපුර දළු ලබාදෙන සහ කිසිදු ණය (Arrears) නොමැති පාරිභෝගිකයින්.',
            color: Colors.orange.shade600,
            imagePath: 'assets/badges/badge_gold.png',
          ),
          _buildTierInfoTile(
            title: 'Silver (සාමාන්‍ය)',
            desc:
                'කිලෝග්‍රෑම් 50 ට අඩුවෙන් දළු ලබාදෙන (හෝ අක්‍රිය), එහෙත් කිසිදු ණය නොමැති පාරිභෝගිකයින්.',
            color: Colors.grey.shade600,
            imagePath: 'assets/badges/badge_platinum.png',
          ),
          _buildTierInfoTile(
            title: 'Risk (අවදානම්)',
            desc:
                'අවසන් බිල්පතට අනුව හිඟ මුදල් (Arrears/Debt) පවතින ඕනෑම පාරිභෝගිකයෙකු මෙම කාණ්ඩයට අයත් වේ.',
            color: Colors.red.shade600,
            imagePath: 'assets/badges/badge_ruby.png',
          ),
          const SizedBox(height: 24),
          const Text(
            'සක්‍රිය සහ අක්‍රිය තත්ත්වයන් (Active vs Inactive):',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoBox(
            title: 'Active (සක්‍රිය)',
            desc: 'අවසන් වරට දළු ලබා දී දින 45ක් ඇතුළත සිටින පාරිභෝගිකයින්.',
            color: Colors.green.shade600,
            icon: Icons.check_circle_outline,
          ),
          _buildInfoBox(
            title: 'Inactive (අක්‍රිය)',
            desc: 'අවසන් වරට දළු ලබා දී දින 45කට වඩා ගත වී ඇති පාරිභෝගිකයින්.',
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
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
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
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
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

  // --- Tab 5: ආරක්ෂිත සහ දත්ත ---
  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kIsWeb) ...[
            const Text(
              'Database Backup (දත්ත සංරක්ෂණය)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ඔබගේ සියලුම දත්ත (.json) ගොනුවක් ලෙස ඔබගේ උපාංගයට සෘජුවම Download කරගන්න.',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF), // Light Blue tint
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
                        ? 'Backup සැකසෙමින් පවතී...'
                        : 'Backup එක Download කරන්න',
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

          const Text(
            'ආයතනයේ නම සැකසීම (Company Name)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'බිල්පත් සහ WhatsApp පණිවිඩ සඳහා භාවිතා කරන ආයතනයේ නම.',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: Column(
              children: [
                _buildCompanyLineField(
                  'පළමු පේළිය (Company Name - Line 1)',
                  _companyLine1Controller,
                ),
                _buildCompanyLineField(
                  'දෙවන පේළිය (Line 2 - Optional)',
                  _companyLine2Controller,
                ),
                _buildCompanyLineField(
                  'තෙවන පේළිය (Line 3 - Optional)',
                  _companyLine3Controller,
                ),
                _buildCompanyLineField(
                  'හතරවන පේළිය (Line 4 - Optional)',
                  _companyLine4Controller,
                ),
                _buildCompanyLineField(
                  'පස්වන පේළිය (Line 5 - Optional)',
                  _companyLine5Controller,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saveCompanyName,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'නම සුරකින්න (Save Name)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          const Text(
            'පරිපාලක මුරපදය වෙනස් කිරීම',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'පද්ධතියට ඇතුල්වීමේදී භාවිතා කරන මුරපදය (Password) මෙතැනින් වෙනස් කළ හැක.',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2), // Light Red tint
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
                      labelText: 'වත්මන් මුරපදය',
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
                        val!.isEmpty ? 'වත්මන් මුරපදය ඇතුළත් කරන්න' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: 'අලුත් මුරපදය',
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
                      if (val!.isEmpty) return 'අලුත් මුරපදයක් ඇතුළත් කරන්න';
                      if (val.length < 3)
                        return 'අවම වශයෙන් අකුරු/ඉලක්කම් 3ක් ඕනෑ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: 'අලුත් මුරපදය තහවුරු කරන්න',
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
                      if (val!.isEmpty) return 'මුරපදය තහවුරු කරන්න';
                      if (val != _newPasswordController.text)
                        return 'මුරපද එකිනෙකට නොගැලපේ';
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
                          : const Text(
                              'මුරපදය යාවත්කාලීන කරන්න',
                              style: TextStyle(
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

  Widget _buildTableHeader(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 4.0),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Color(0xFF4B5563),
        fontSize: 12,
      ),
    ),
  );
  Widget _buildTableCell(String text, {bool isBold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 4.0),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
        color: const Color(0xFF1F2937),
        fontSize: 13,
      ),
    ),
  );

  Widget _buildCompanyLineField(
    String label,
    TextEditingController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Colors.blueGrey),
          filled: true,
          fillColor: Colors.white,
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
          prefixIcon: const Icon(
            Icons.business,
            size: 20,
            color: Colors.blueGrey,
          ),
        ),
      ),
    );
  }
}
