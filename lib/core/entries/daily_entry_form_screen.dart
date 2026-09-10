import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DailyEntryFormScreen extends StatefulWidget {
  final DateTime selectedDate;
  final String customerId;
  final String customerName;
  final String refNumber;

  const DailyEntryFormScreen({
    super.key, 
    required this.selectedDate,
    required this.customerId,
    required this.customerName,
    required this.refNumber,
  });

  @override
  State<DailyEntryFormScreen> createState() => _DailyEntryFormScreenState();
}

class _DailyEntryFormScreenState extends State<DailyEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _existingEntryId;
  
  final TextEditingController _grossWeightController = TextEditingController();
  final TextEditingController _deductionController = TextEditingController(text: '0');
  final TextEditingController _advanceController = TextEditingController();
  final TextEditingController _fertilizer1Controller = TextEditingController();
  final TextEditingController _fertilizer2Controller = TextEditingController();
  final TextEditingController _teaPacket1Controller = TextEditingController();
  final TextEditingController _teaPacket2Controller = TextEditingController();
  
  bool _isLoading = false;

  double _fert1Price = 0.0;
  double _fert2Price = 0.0;
  double _teaPkt1Price = 0.0;
  double _teaPkt2Price = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchGlobalPrices(); 
    _fetchExistingEntry(); 
  }

  Future<void> _fetchExistingEntry() async {
    try {
      String formattedDate = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
      
      var response = await Supabase.instance.client
          .from('daily_entries')
          .select()
          .eq('customerId', widget.customerId)
          .eq('date', formattedDate)
          .limit(1);

      if (response.isNotEmpty && mounted) {
        var doc = response.first;
        
        setState(() {
          _existingEntryId = doc['id']; 
          
          _grossWeightController.text = _formatValue(doc['grossWeight']);
          _deductionController.text = _formatValue(doc['deductions'], isDeduction: true);
          _advanceController.text = _formatValue(doc['advanceAmount']);
          _fertilizer1Controller.text = _formatValue(doc['fertilizer1Qty']);
          _fertilizer2Controller.text = _formatValue(doc['fertilizer2Qty']);
          _teaPacket1Controller.text = _formatValue(doc['teaPacket1Qty']);
          _teaPacket2Controller.text = _formatValue(doc['teaPacket2Qty']);
        });
      }
    } catch (e) {
      debugPrint("දත්ත ලබාගැනීමේදී දෝෂයක්: $e");
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

  Future<void> _fetchGlobalPrices() async {
    try {
      var response = await Supabase.instance.client.from('global_settings').select().eq('id', 'prices').maybeSingle();
      if (response != null && mounted) {
        setState(() {
          _fert1Price = (response['fertilizer1Price'] ?? 0.0).toDouble();
          _fert2Price = (response['fertilizer2Price'] ?? 0.0).toDouble();
          _teaPkt1Price = (response['teaPacket1Price'] ?? 0.0).toDouble();
          _teaPkt2Price = (response['teaPacket2Price'] ?? 0.0).toDouble();
        });
      }
    } catch (e) {
      debugPrint("මිල ගණන් ලබාගැනීමේදී දෝෂයක්: $e");
    }
  }

  String? _validateInput(String? value) {
    bool isAllEmpty = _grossWeightController.text.trim().isEmpty &&
        (_deductionController.text.trim().isEmpty || _deductionController.text.trim() == '0') &&
        _advanceController.text.trim().isEmpty &&
        _fertilizer1Controller.text.trim().isEmpty &&
        _fertilizer2Controller.text.trim().isEmpty &&
        _teaPacket1Controller.text.trim().isEmpty &&
        _teaPacket2Controller.text.trim().isEmpty;

    if (isAllEmpty) {
      return 'අවශ්‍ය වේ';
    }

    if (value != null && value.trim().isNotEmpty && value.trim() != '0') {
      if (double.tryParse(value.trim()) == null) {
        return 'නිවැරදි අගයක් ඇතුළත් කරන්න';
      }
    }
    return null;
  }

  void _confirmAndSave() {
    if (_formKey.currentState!.validate()) {
      if (_existingEntryId != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('තහවුරු කිරීම'),
            content: const Text('ඔබට මෙම දත්ත යාවත්කාලීන (Update) කිරීමට අවශ්‍යද?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('නැත', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveEntry(isUpdate: true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                child: const Text('ඔව්', style: TextStyle(color: Colors.white)),
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
    setState(() { _isLoading = true; });

    try {
      double grossWeight = double.tryParse(_grossWeightController.text.trim()) ?? 0.0;
      double deductions = double.tryParse(_deductionController.text.trim()) ?? 0.0;
      double netWeight = grossWeight - deductions;

      double advance = double.tryParse(_advanceController.text.trim()) ?? 0.0;
      double fertilizer1Qty = double.tryParse(_fertilizer1Controller.text.trim()) ?? 0.0;
      double fertilizer2Qty = double.tryParse(_fertilizer2Controller.text.trim()) ?? 0.0;
      double teaPacket1Qty = double.tryParse(_teaPacket1Controller.text.trim()) ?? 0.0;
      double teaPacket2Qty = double.tryParse(_teaPacket2Controller.text.trim()) ?? 0.0;

      Map<String, dynamic> entryData = {
        'grossWeight': grossWeight,
        'deductions': deductions,
        'netWeight': netWeight,
        'advanceAmount': advance,
        'fertilizer1Qty': fertilizer1Qty,
        'fertilizer2Qty': fertilizer2Qty,
        'teaPacket1Qty': teaPacket1Qty,
        'teaPacket2Qty': teaPacket2Qty,
      };

      if (isUpdate && _existingEntryId != null) {
        entryData['updatedAt'] = DateTime.now().toIso8601String();
        await Supabase.instance.client.from('daily_entries').update(entryData).eq('id', _existingEntryId!);
      } else {
        entryData['customerId'] = widget.customerId;
        entryData['customerName'] = widget.customerName;
        entryData['date'] = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
        entryData['timestamp'] = widget.selectedDate.toIso8601String();
        entryData['createdAt'] = DateTime.now().toIso8601String();
        
        await Supabase.instance.client.from('daily_entries').insert(entryData);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isUpdate ? 'දෛනික සටහන සාර්ථකව යාවත්කාලීන කරන ලදි!' : 'දෛනික සටහන සාර්ථකව සුරකින ලදි!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  @override
  void dispose() {
    _grossWeightController.dispose();
    _deductionController.dispose();
    _advanceController.dispose();
    _fertilizer1Controller.dispose();
    _fertilizer2Controller.dispose();
    _teaPacket1Controller.dispose();
    _teaPacket2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('yyyy MMM dd').format(widget.selectedDate);
    double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('$formattedDate දින සටහන', style: const TextStyle(fontSize: 18)),
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
                      color: Theme.of(context).primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
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
                  
                  const Text('තේ දළු විස්තර', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _grossWeightController,
                    decoration: InputDecoration(
                      labelText: 'මුළු තේ දළු ප්‍රමාණය (Gross Weight)',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.scale),
                      suffixText: 'Kg',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateInput, 
                  ),
                  
                  // අඩු කිරීම් (Deductions) Field එක Hide කර ඇත
                  /*
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _deductionController,
                    decoration: InputDecoration(
                      labelText: 'අඩු කිරීම් (වතුර/මළු බර)',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.remove_circle_outline),
                      suffixText: 'Kg',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateInput, 
                  ),
                  */
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Divider(),
                  ),

                  const Text('අමතර සටහන් සහ අඩු කිරීම්', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _advanceController,
                    decoration: InputDecoration(
                      labelText: 'අත්තිකාරම් මුදල (Advance)',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.money),
                      prefixText: 'Rs. ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateInput, 
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _fertilizer1Controller,
                          decoration: InputDecoration(
                            labelText: 'පොහොර 01 (Rs. $_fert1Price)',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.eco),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: _validateInput, 
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _fertilizer2Controller,
                          decoration: InputDecoration(
                            labelText: 'පොහොර 02 (Rs. $_fert2Price)',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.eco),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: _validateInput, 
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _teaPacket1Controller,
                          decoration: InputDecoration(
                            labelText: 'තේ පැකට් 01 (Rs. $_teaPkt1Price)',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.local_cafe),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: _validateInput, 
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _teaPacket2Controller,
                          decoration: InputDecoration(
                            labelText: 'තේ පැකට් 02 (Rs. $_teaPkt2Price)',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.local_cafe),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: _validateInput, 
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

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
                              _existingEntryId != null ? 'යාවත්කාලීන කරන්න' : 'දත්ත සුරකින්න', 
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}