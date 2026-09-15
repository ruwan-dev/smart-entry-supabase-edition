import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_entry/core/entries/daily_entries_screen.dart';

class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _refNumberController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  
  bool _isLoading = false;

  final Color _primaryColor = const Color(0xFF4A4ECA); 
  final Color _backgroundColor = const Color(0xFFF9FAFC); 
  final Color _cardColor = Colors.white;
  final Color _textColorPrimary = const Color(0xFF1E293B); 
  final Color _textColorSecondary = const Color(0xFF64748B); 
  final Color _borderColor = const Color(0xFFE2E8F0); 

  Future<void> _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      try {
        String refNumber = _refNumberController.text.trim();
        String name = _nameController.text.trim();

        var querySnapshot = await Supabase.instance.client
            .from('customers')
            .select()
            .eq('refNumber', refNumber);

        if (querySnapshot.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('මෙම යොමු අංකය භාවිතා කර ඇත!'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() { _isLoading = false; });
          }
          return; 
        }

        var response = await Supabase.instance.client.from('customers').insert({
          'refNumber': refNumber,
          'name': name,
          'address': _addressController.text.trim(),
          'phone': _phoneController.text.trim(),
          'pin': _pinController.text.trim(),
        }).select();

        String docId = response.first['id'];

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('පාරිභෝගිකයා සාර්ථකව සුරකින ලදී'), backgroundColor: Colors.green),
          );

          // Pop back to list and optionally navigate to daily entries
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('දෝෂයකි: $e'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) { setState(() { _isLoading = false; }); }
      }
    }
  }

  @override
  void dispose() {
    _refNumberController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _textColorSecondary, fontSize: 14),
        prefixIcon: Icon(icon, color: _textColorSecondary, size: 20),
        filled: true,
        fillColor: _backgroundColor,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _primaryColor)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      style: TextStyle(color: _textColorPrimary, fontSize: 14),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
      validator: (value) => value == null || value.isEmpty ? 'අවශ්‍ය වේ' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('නව පාරිභෝගිකයෙකු එකතු කරන්න', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _textColorPrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: _borderColor, height: 1.0),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('අලුත් පාරිභෝගිකයෙකු ලියාපදිංචි කිරීම', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textColorPrimary)),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _refNumberController,
                      label: 'යොමු අංකය (Ref Number)',
                      icon: Icons.numbers,
                      isNumber: true,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _nameController,
                      label: 'නම',
                      icon: Icons.person,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _addressController,
                      label: 'ලිපිනය',
                      icon: Icons.location_on,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'දුරකථන අංකය',
                      icon: Icons.phone,
                      isNumber: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveCustomer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('පාරිභෝගිකයා සුරකින්න', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
