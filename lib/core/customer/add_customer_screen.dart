import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../localization/app_strings.dart';
import 'dart:math';

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
  bool _isPinVisible = false;

  final Color _primaryColor = const Color(0xFF4A4ECA);
  final Color _backgroundColor = const Color(0xFFF9FAFC);
  final Color _cardColor = Colors.white;
  final Color _textColorPrimary = const Color(0xFF1E293B);
  final Color _textColorSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);

  // Auto-generate a random 6-digit PIN
  void _generatePin() {
    final random = Random.secure();
    final pin = (100000 + random.nextInt(900000)).toString();
    setState(() {
      _pinController.text = pin;
      _isPinVisible = true; // Show it so admin can note it down
    });
  }

  Future<void> _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      try {
        String refNumber = _refNumberController.text.trim();
        String name = _nameController.text.trim();

        var querySnapshot = await Supabase.instance.client
            .from('customers')
            .select().eq('organization_id', AppState.currentOrganizationId.value ?? '')
            .eq('refNumber', refNumber);

        if (querySnapshot.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppStrings.refNumberExists),
                backgroundColor: Colors.red,
              ),
            );
            setState(() { _isLoading = false; });
          }
          return;
        }

        await Supabase.instance.client.from('customers').insert({
          'refNumber': refNumber,
          'name': name,
          'address': _addressController.text.trim(),
          'phone': _phoneController.text.trim(),
          'pin': _pinController.text.trim(),
          'organization_id': AppState.currentOrganizationId.value ?? '',
        }).select();

        if (mounted) {
          AppState.triggerRefresh();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.customerSaved), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppStrings.errorPrefix}$e'), backgroundColor: Colors.red),
          );
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
    _pinController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _textColorSecondary, fontSize: 14),
        prefixIcon: Icon(icon, color: _textColorSecondary, size: 20),
        filled: true,
        fillColor: _backgroundColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primaryColor),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      style: TextStyle(color: _textColorPrimary, fontSize: 14),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
      validator: (value) => value == null || value.isEmpty ? AppStrings.requiredField : null,
    );
  }

  Widget _buildPinField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PIN field with visibility toggle
        TextFormField(
          controller: _pinController,
          obscureText: !_isPinVisible,
          maxLength: 6,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: AppStrings.pin,
            labelStyle: TextStyle(color: _textColorSecondary, fontSize: 14),
            prefixIcon: Icon(Icons.lock, color: _textColorSecondary, size: 20),
            filled: true,
            fillColor: _backgroundColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _primaryColor),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            suffixIcon: IconButton(
              icon: Icon(_isPinVisible ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _isPinVisible = !_isPinVisible),
            ),
          ),
          style: TextStyle(color: _textColorPrimary, fontSize: 14, letterSpacing: 4),
          validator: (value) {
            if (value == null || value.isEmpty) return AppStrings.requiredField;
            if (value.length != 6) {
              return AppStrings.isSinhala ? 'PIN ඉලක්කම් 6ක් විය යුතුය' : 'PIN must be 6 digits';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        // Auto-generate and Copy buttons
        Row(
          children: [
            // Auto Generate button
            OutlinedButton.icon(
              onPressed: _generatePin,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(AppStrings.isSinhala ? 'ස්වයංක්‍රීයව ජනනය කරන්න' : 'Auto Generate'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryColor,
                side: BorderSide(color: _primaryColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            // Copy to clipboard button
            OutlinedButton.icon(
              onPressed: _pinController.text.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: _pinController.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppStrings.isSinhala ? 'PIN පිටපත් කරන ලදී!' : 'PIN copied to clipboard!'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal,
                side: const BorderSide(color: Colors.teal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          AppStrings.addCustomer,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
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
              Text(
                AppStrings.isSinhala ? 'අලුත් පාරිභෝගිකයෙකු ලියාපදිංචි කිරීම' : 'Register New Customer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textColorPrimary),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _refNumberController,
                      label: AppStrings.refNumber,
                      icon: Icons.numbers,
                      isNumber: true,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _nameController,
                      label: AppStrings.name,
                      icon: Icons.person,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _addressController,
                      label: AppStrings.address,
                      icon: Icons.location_on,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _phoneController,
                      label: AppStrings.phone,
                      icon: Icons.phone,
                      isNumber: true,
                    ),
                    const SizedBox(height: 12),
                    _buildPinField(),
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
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(AppStrings.isSinhala ? 'පාරිභෝගිකයා සුරකින්න' : 'Save Customer', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
