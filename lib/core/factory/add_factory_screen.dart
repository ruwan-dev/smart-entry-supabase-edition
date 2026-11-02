import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../localization/app_strings.dart';

class AddFactoryScreen extends StatefulWidget {
  const AddFactoryScreen({super.key});

  @override
  State<AddFactoryScreen> createState() => _AddFactoryScreenState();
}

class _AddFactoryScreenState extends State<AddFactoryScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _refNumberController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;

  final Color _primaryColor = const Color(0xFF06B6D4);
  final Color _backgroundColor = const Color(0xFFF9FAFC);
  final Color _cardColor = Colors.white;
  final Color _textColorPrimary = const Color(0xFF1E293B);
  final Color _textColorSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);

  Future<void> _saveFactory() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      try {
        String refNumber = _refNumberController.text.trim();
        String name = _nameController.text.trim();
        final orgId = AppState.currentOrganizationId.value ?? '';
        if (orgId.isEmpty) {
          throw Exception('No active organization selected.');
        }

        var querySnapshot = await Supabase.instance.client
            .from('factories')
            .select().eq('organization_id', orgId)
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

        await Supabase.instance.client.from('factories').insert({
          'refNumber': refNumber,
          'name': name,
          'address': _addressController.text.trim(),
          'phone': _phoneController.text.trim(),
          'organization_id': orgId,
        }).select();

        if (mounted) {
          AppState.triggerRefresh();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.factorySaved), backgroundColor: Colors.green),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          AppStrings.addFactory,
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
                AppStrings.registerNewFactory,
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
                      icon: Icons.business,
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
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveFactory,
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
                      : Text(AppStrings.saveFactory, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
