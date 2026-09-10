import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:universal_html/html.dart' as html; 

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // --- නව මුරපද Controllers ---
  final _passwordFormKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoadingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  // මාසික ගාස්තු සඳහා Controllers
  final _monthlyFormKey = GlobalKey<FormState>();
  final TextEditingController _teaRateController = TextEditingController();
  final TextEditingController _transportRateController = TextEditingController();

  // ස්ථිර (Global) අමතර භාණ්ඩ මිල සඳහා Controllers
  final _globalFormKey = GlobalKey<FormState>();
  final TextEditingController _fert1PriceController = TextEditingController();
  final TextEditingController _fert2PriceController = TextEditingController();
  final TextEditingController _teaPkt1PriceController = TextEditingController();
  final TextEditingController _teaPkt2PriceController = TextEditingController();

  late String _selectedMonth;
  late String _selectedYear;

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  
  late List<String> _years;
  bool _isLoadingMonthly = false;
  bool _isLoadingGlobal = false;
  
  // Backup Loading State
  bool _isLoadingBackup = false;

  // Pagination Variables for Table
  int _currentRatesPage = 0;
  final int _ratesPerPage = 5;

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
  }

  Future<void> _loadGlobalPrices() async {
    try {
      var doc = await Supabase.instance.client.from('global_settings').select().eq('id', 'prices').maybeSingle();
      if (doc != null) {
        setState(() {
          _fert1PriceController.text = (doc['fertilizer1Price'] ?? '').toString();
          _fert2PriceController.text = (doc['fertilizer2Price'] ?? '').toString();
          _teaPkt1PriceController.text = (doc['teaPacket1Price'] ?? '').toString();
          _teaPkt2PriceController.text = (doc['teaPacket2Price'] ?? '').toString();
        });
      }
    } catch (e) {
      // Ignore error initially
    }
  }
  
  Future<void> _exportDatabaseBackupWeb() async {
    setState(() { _isLoadingBackup = true; });
    try {
      Map<String, dynamic> fullBackupData = {};
      
      List<String> collections = ['customers', 'daily_entries', 'monthly_rates', 'global_settings', 'monthly_summaries'];

      for (String col in collections) {
        var snapshot = await Supabase.instance.client.from(col).select();
        fullBackupData[col] = snapshot;
      }

      String jsonString = const JsonEncoder.withIndent('  ').convert(fullBackupData);
      String fileName = 'smart_entry_backup_${DateTime.now().millisecondsSinceEpoch}.json';

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

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup එක Download වීම ආරම්භ විය!'), backgroundColor: Colors.green));
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup ලබා ගැනීමේදී දෝෂයක්: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isLoadingBackup = false; });
    }
  }

  Future<void> _changePassword() async {
    if (_passwordFormKey.currentState!.validate()) {
      setState(() { _isLoadingPassword = true; });
      String currentInput = _currentPasswordController.text.trim();
      String newInput = _newPasswordController.text.trim();

      try {
        var authDoc = await Supabase.instance.client.from('global_settings').select().eq('id', 'auth').maybeSingle();
        if (authDoc == null) throw Exception("මුරපද දත්ත සොයාගත නොහැක.");
        String dbPassword = authDoc['password'].toString();

        if (currentInput != dbPassword) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('වත්මන් මුරපදය වැරදියි!'), backgroundColor: Colors.red));
          setState(() { _isLoadingPassword = false; });
          return; 
        }

        await Supabase.instance.client.from('global_settings').upsert({
          'id': 'auth',
          'password': newInput,
        });

        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('මුරපදය සාර්ථකව යාවත්කාලීන විය!'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('දෝෂයක්: $e')));
      } finally {
        if (mounted) setState(() { _isLoadingPassword = false; });
      }
    }
  }

  Future<void> _saveMonthlyRates() async {
    if (_monthlyFormKey.currentState!.validate()) {
      setState(() { _isLoadingMonthly = true; });
      try {
        String docId = '$_selectedYear-$_selectedMonth';
        String sortValue = '$_selectedYear-${(_months.indexOf(_selectedMonth) + 1).toString().padLeft(2, '0')}';

        await Supabase.instance.client.from('monthly_rates').upsert({
          'id': docId,
          'year': _selectedYear,
          'month': _selectedMonth,
          'teaRate': double.parse(_teaRateController.text.trim()),
          'transportRate': double.parse(_transportRateController.text.trim()),
          'updatedAt': DateTime.now().toIso8601String(),
          'sortValue': sortValue,
        });

        _teaRateController.clear();
        _transportRateController.clear();

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('මාසික ගාස්තු සාර්ථකව සුරකින ලදි!')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('දෝෂයක් මතු විය: $e')));
      } finally {
        if (mounted) setState(() { _isLoadingMonthly = false; });
      }
    }
  }

  Future<void> _saveGlobalPrices() async {
    if (_globalFormKey.currentState!.validate()) {
      setState(() { _isLoadingGlobal = true; });
      try {
        await Supabase.instance.client.from('global_settings').upsert({
          'id': 'prices',
          'fertilizer1Price': double.parse(_fert1PriceController.text.trim()),
          'fertilizer2Price': double.parse(_fert2PriceController.text.trim()),
          'teaPacket1Price': double.parse(_teaPkt1PriceController.text.trim()),
          'teaPacket2Price': double.parse(_teaPkt2PriceController.text.trim()),
        });

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('අමතර භාණ්ඩ මිල ගණන් සාර්ථකව යාවත්කාලීන විය!')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('දෝෂයක් මතු විය: $e')));
      } finally {
        if (mounted) setState(() { _isLoadingGlobal = false; });
      }
    }
  }

  Future<void> _deleteRate(String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('මකා දමන්නද?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('ඔබට විශ්වාසද මෙම මාසයේ ගාස්තු විස්තර මකා දැමිය යුතුයි කියා?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('නැහැ', style: TextStyle(color: Colors.blueGrey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('ඔව්, මකන්න', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await Supabase.instance.client.from('monthly_rates').delete().eq('id', docId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ගාස්තු සාර්ථකව මකා දමන ලදි!')));
          setState(() { _currentRatesPage = 0; });
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('දෝෂයක්: $e')));
      }
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _teaRateController.dispose();
    _transportRateController.dispose();
    _fert1PriceController.dispose();
    _fert2PriceController.dispose();
    _teaPkt1PriceController.dispose();
    _teaPkt2PriceController.dispose();
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryAppColor, width: 1.5)),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
    );
  }

  // ---------------------------------------------------------
  // UI BUILD 
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // Tabs 4k thiyenawa
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8), 
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F2937),
          elevation: 0,
          title: const Text('සැකසුම් (Settings)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          bottom: TabBar(
            isScrollable: true, // Mobile ekata scroll karanna damma
            tabAlignment: TabAlignment.start, // Left align wenna
            labelPadding: const EdgeInsets.symmetric(horizontal: 20),
            labelColor: primaryAppColor,
            unselectedLabelColor: Colors.blueGrey.shade400,
            indicatorColor: primaryAppColor,
            indicatorWeight: 4,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [
              Tab(text: 'අමතර භාණ්ඩ'),
              Tab(text: 'මාසික ගාස්තු'),
              Tab(text: 'ගාස්තු ලැයිස්තුව'),
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
              _buildSavedRatesTab(),   // Tab 3 (Pagination added)
              _buildSecurityTab(),     // Tab 4
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
          const Text('අමතර භාණ්ඩ මිල ගණන් (ස්ථිර)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          const Text('මෙම මිල ගණන් මින් ඉදිරියට නිකුත් කරන සියලුම පොහොර සහ තේ පැකට් සඳහා අදාළ වේ.', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
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
                          decoration: _buildInputDecoration('පොහොර 1 (Rs)', Icons.eco_rounded),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) => val!.isEmpty ? 'මිල දෙන්න' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _fert2PriceController,
                          decoration: _buildInputDecoration('පොහොර 2 (Rs)', Icons.eco_rounded),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                          decoration: _buildInputDecoration('තේ පැකට් 1 (Rs)', Icons.local_cafe_rounded),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) => val!.isEmpty ? 'මිල දෙන්න' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _teaPkt2PriceController,
                          decoration: _buildInputDecoration('තේ පැකට් 2 (Rs)', Icons.local_cafe_rounded),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      style: ElevatedButton.styleFrom(backgroundColor: primaryAppColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _isLoadingGlobal 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('මිල ගණන් යාවත්කාලීන කරන්න', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
          const Text('මාසික ගාස්තු සැකසුම්', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          const Text('එක් එක් මාසය සඳහා ගෙවන දළු මිල සහ ප්‍රවාහන ගාස්තු මෙතැනින් ඇතුළත් කරන්න.', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
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
                          decoration: _buildInputDecoration('වර්ෂය', Icons.calendar_month_rounded),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blueGrey),
                          items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                          onChanged: (val) => setState(() => _selectedYear = val!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedMonth,
                          decoration: _buildInputDecoration('මාසය', Icons.date_range_rounded),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blueGrey),
                          items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (val) => setState(() => _selectedMonth = val!),
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
                          decoration: _buildInputDecoration('තේ දළු මිල (Rs)', Icons.monetization_on_outlined),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) => val!.isEmpty ? 'මිල ඇතුළත් කරන්න' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _transportRateController,
                          decoration: _buildInputDecoration('ප්‍රවාහනය (Rs)', Icons.local_shipping_outlined),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) => val!.isEmpty ? 'ගාස්තුව ඇතුළත් කරන්න' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoadingMonthly ? null : _saveMonthlyRates,
                      style: ElevatedButton.styleFrom(backgroundColor: primaryAppColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _isLoadingMonthly 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('මාසික ගාස්තු සුරකින්න', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
          const Text('සුරැකි මාසික ගාස්තු ලැයිස්තුව', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          const Text('දැනට පද්ධතියේ සුරකී ඇති සියලුම මාසික ගාස්තු. (පිටුවකට 5 බැගින්)', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
          const SizedBox(height: 16),
          
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client.from('monthly_rates').stream(primaryKey: ['id']).order('sortValue', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: _cardDecoration(),
                  child: const Center(child: Text('දැනට කිසිදු ගාස්තුවක් ඇතුළත් කර නොමැත.', style: TextStyle(color: Colors.blueGrey))),
                );
              }

              // Pagination calculation
              List<Map<String, dynamic>> allDocs = snapshot.data!;
              int totalPages = (allDocs.length / _ratesPerPage).ceil();
              
              if (_currentRatesPage >= totalPages && totalPages > 0) {
                _currentRatesPage = totalPages - 1; // Safely adjust if a record is deleted
              }
              
              List<Map<String, dynamic>> pageDocs = allDocs.skip(_currentRatesPage * _ratesPerPage).take(_ratesPerPage).toList();

              return Column(
                children: [
                  Container(
                    decoration: _cardDecoration(),
                    clipBehavior: Clip.antiAlias, 
                    child: Table(
                      columnWidths: const { 0: FlexColumnWidth(2.2), 1: FlexColumnWidth(1.5), 2: FlexColumnWidth(1.5), 3: FlexColumnWidth(1.0) },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1)),
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
                          children: [
                            _buildTableHeader('මාසය'), _buildTableHeader('තේ දළු\n(Rs)'), _buildTableHeader('ප්‍රවාහනය\n(Rs)'), _buildTableHeader(''),
                          ],
                        ),
                        ...pageDocs.map((doc) {
                          return TableRow(
                            children: [
                              _buildTableCell('${doc['year'] ?? ''}\n${doc['month'] ?? ''}', isBold: true),
                              _buildTableCell((doc['teaRate'] as num? ?? 0).toDouble().toStringAsFixed(2)),
                              _buildTableCell((doc['transportRate'] as num? ?? 0).toDouble().toStringAsFixed(2)),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: () => _deleteRate(doc['id'])),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Pagination Controls
                  if (totalPages > 1) 
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _currentRatesPage > 0 ? () => setState(() => _currentRatesPage--) : null,
                          icon: const Icon(Icons.chevron_left, size: 18),
                          label: const Text("පෙර"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: primaryAppColor,
                            elevation: 0,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                          ),
                        ),
                        Text('පිටුව ${_currentRatesPage + 1} / $totalPages', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 13)),
                        ElevatedButton.icon(
                          onPressed: _currentRatesPage < totalPages - 1 ? () => setState(() => _currentRatesPage++) : null,
                          icon: const Icon(Icons.chevron_right, size: 18),
                          label: const Text("ඊළඟ"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: primaryAppColor,
                            elevation: 0,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                          ),
                        ),
                      ],
                    )
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Tab 4: ආරක්ෂිත සහ දත්ත ---
  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          if (kIsWeb) ...[
            const Text('Database Backup (දත්ත සංරක්ෂණය)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
            const SizedBox(height: 8),
            const Text('ඔබගේ සියලුම දත්ත (.json) ගොනුවක් ලෙස ඔබගේ උපාංගයට සෘජුවම Download කරගන්න.', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
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
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.cloud_download_rounded, size: 22),
                  label: Text(_isLoadingBackup ? 'Backup සැකසෙමින් පවතී...' : 'Backup එක Download කරන්න', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],

          const Text('පරිපාලක මුරපදය වෙනස් කිරීම', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          const Text('පද්ධතියට ඇතුල්වීමේදී භාවිතා කරන මුරපදය (Password) මෙතැනින් වෙනස් කළ හැක.', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
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
                      labelStyle: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.shade200)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
                      prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Colors.blueGrey),
                      suffixIcon: IconButton(icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility, color: Colors.blueGrey, size: 20), onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent))
                    ),
                    validator: (val) => val!.isEmpty ? 'වත්මන් මුරපදය ඇතුළත් කරන්න' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: 'අලුත් මුරපදය',
                      labelStyle: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.shade200)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
                      prefixIcon: const Icon(Icons.lock_reset, size: 20, color: Colors.blueGrey),
                      suffixIcon: IconButton(icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, color: Colors.blueGrey, size: 20), onPressed: () => setState(() => _obscureNew = !_obscureNew))
                    ),
                    validator: (val) {
                      if (val!.isEmpty) return 'අලුත් මුරපදයක් ඇතුළත් කරන්න';
                      if (val.length < 3) return 'අවම වශයෙන් අකුරු/ඉලක්කම් 3ක් ඕනෑ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureNew, 
                    decoration: InputDecoration(
                      labelText: 'අලුත් මුරපදය තහවුරු කරන්න',
                      labelStyle: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.shade200)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
                      prefixIcon: const Icon(Icons.check_circle_outline, size: 20, color: Colors.blueGrey),
                    ),
                    validator: (val) {
                      if (val!.isEmpty) return 'මුරපදය තහවුරු කරන්න';
                      if (val != _newPasswordController.text) return 'මුරපද එකිනෙකට නොගැලපේ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoadingPassword ? null : _changePassword,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _isLoadingPassword 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('මුරපදය යාවත්කාලීන කරන්න', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

  Widget _buildTableHeader(String text) => Padding(padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 4.0), child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4B5563), fontSize: 12)));
  Widget _buildTableCell(String text, {bool isBold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 4.0), child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: const Color(0xFF1F2937), fontSize: 13)));
}