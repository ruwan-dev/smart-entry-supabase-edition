import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_entry/core/entries/daily_entries_screen.dart';
import '../billing/monthly_bill_screen.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _refNumberController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isLoading = false;
  String _searchQuery = '';
  
  // Pagination සඳහා අවශ්‍ය විචල්‍යයන් (Variables)
  int _currentPage = 0;
  final int _itemsPerPage = 5; // එක පිටුවකට පෙන්වන ප්‍රමාණය

  // ----------------------------------------------------------------------
  // UI වර්ණ රටාව
  // ----------------------------------------------------------------------
  final Color _primaryColor = const Color(0xFF4A4ECA); 
  final Color _backgroundColor = const Color(0xFFF9FAFC); 
  final Color _cardColor = Colors.white;
  final Color _textColorPrimary = const Color(0xFF1E293B); 
  final Color _textColorSecondary = const Color(0xFF64748B); 
  final Color _borderColor = const Color(0xFFE2E8F0); 
  
  final Color _statusGreenBg = const Color(0xFFECFDF5);
  final Color _statusGreenText = const Color(0xFF10B981);
  final Color _tagPurpleBg = const Color(0xFFF3E8FF);
  final Color _tagPurpleText = const Color(0xFF9333EA);

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
                content: Text('මෙම යොමු අංකය දැනටමත් භාවිතයේ පවතී'),
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
        }).select();

        String docId = response.first['id'];

        _refNumberController.clear();
        _nameController.clear();
        _addressController.clear();
        _phoneController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('පාරිභෝගිකයා සාර්ථකව සුරකින ලදී')),
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DailyEntriesScreen(
                initialCustomerId: docId,
                initialRefNumber: refNumber,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('දෝෂයකි: $e')));
        }
      } finally {
        if (mounted) { setState(() { _isLoading = false; }); }
      }
    }
  }

  Future<void> _deleteCustomer(BuildContext context, String docId, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('පාරිභෝගිකයා ඉවත් කරන්නද?'),
        content: Text('ඔබ ස්ථිරවම $name සහ ඔහුට/ඇයට අදාළ සියලුම තේ දළු හා අත්තිකාරම් සටහන් පද්ධතියෙන් ඉවත් කිරීමට අවශ්‍යද?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('නැත', style: TextStyle(color: _textColorSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              elevation: 0,
              foregroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('ඔව්, ඉවත් කරන්න'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await Supabase.instance.client
            .from('daily_entries')
            .delete()
            .eq('customerId', docId);

        await Supabase.instance.client.from('customers').delete().eq('id', docId);

        if (context.mounted) {
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('පාරිභෝගිකයා සහ අදාළ සියලුම සටහන් සාර්ථකව ඉවත් කරන ලදී'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('දෝෂයකි: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('පාරිභෝගික ලියාපදිංචිය', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _textColorPrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: _borderColor, height: 1.0),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), // Padding මඳක් අඩු කළා mobile එකට ගැලපෙන්න
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- පාරිභෝගික ලියාපදිංචි කිරීමේ Form එක ---
            Container(
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
                  SLongButton(
                    onPressed: _isLoading ? null : _saveCustomer,
                    primaryColor: _primaryColor,
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('පාරිභෝගිකයා සුරකින්න', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // --- ශීර්ෂය සහ සෙවීම් තීරුව (Responsive කර ඇත) ---
            Text('පාරිභෝගික ලැයිස්තුව', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textColorPrimary)),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'නම හෝ අංකය මගින් සොයන්න',
                  labelStyle: TextStyle(color: _textColorSecondary, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: _textColorSecondary, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _primaryColor)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                    _currentPage = 0; // Search කරන විට මුල් පිටුවට යාමට
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // --- පාරිභෝගික ලැයිස්තුව සහ Pagination ---
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client.from('customers').stream(primaryKey: ['id']).order('name'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                
                // 1. Search කිරීම (Filter)
                var filteredDocs = snapshot.data!.where((data) {
                  String name = (data['name'] ?? '').toString().toLowerCase();
                  String ref = (data['refNumber'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || ref.contains(_searchQuery);
                }).toList();

                if(filteredDocs.isEmpty) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("පාරිභෝගිකයින් කිසිවෙකු හමුවුණේ නැත.")));
                }

                // 2. Pagination Logic
                int totalPages = (filteredDocs.length / _itemsPerPage).ceil();
                
                // (ආරක්ෂිත පියවරක්: currentPage එක totalPages වලට වඩා වැඩි නම්)
                if (_currentPage >= totalPages && totalPages > 0) {
                  _currentPage = totalPages - 1; 
                }

                var paginatedDocs = filteredDocs
                    .skip(_currentPage * _itemsPerPage)
                    .take(_itemsPerPage)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // List එක පෙන්වීම
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: paginatedDocs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12), 
                      itemBuilder: (context, index) {
                        var data = paginatedDocs[index];
                        
                        return _buildResponsiveCustomerItem(data['id'], data);
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // --- Pagination Controls පෙන්වීම ---
                    if (totalPages > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios, size: 16),
                            color: _currentPage > 0 ? _primaryColor : Colors.grey,
                            onPressed: _currentPage > 0 
                                ? () => setState(() => _currentPage--) 
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _borderColor),
                            ),
                            child: Text(
                              'පිටුව ${_currentPage + 1} / $totalPages',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 16),
                            color: _currentPage < totalPages - 1 ? _primaryColor : Colors.grey,
                            onPressed: _currentPage < totalPages - 1 
                                ? () => setState(() => _currentPage++) 
                                : null,
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Input Field Component ---
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

  // --- Responsive Customer Item (RenderFlex Overflow එක විසඳීම සඳහා) ---
  Widget _buildResponsiveCustomerItem(String docId, Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      padding: const EdgeInsets.all(16), // Padding එක
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. උඩ පේළිය: යොමු අංකය සහ දුරකථන අංකය
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // යොමු අංකය
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusGreenBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _statusGreenText.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: _statusGreenText, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      'යොමුව: ${data['refNumber'] ?? ''}', 
                      style: TextStyle(color: _statusGreenText, fontWeight: FontWeight.bold, fontSize: 12)
                    ),
                  ],
                ),
              ),
              // දුරකථන අංකය
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _tagPurpleBg, borderRadius: BorderRadius.circular(4)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone, size: 12, color: _tagPurpleText),
                    const SizedBox(width: 4),
                    Text(
                      data['phone'] ?? '',
                      style: TextStyle(fontSize: 12, color: _tagPurpleText, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 2. මැද කොටස: නම සහ ලිපිනය
          Text(
            data['name'] ?? '',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _textColorPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            data['address'] ?? '',
            style: TextStyle(fontSize: 12, color: _textColorSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 16),

          // 3. යට පේළිය: ක්‍රියාකාරකම් බොත්තම් (Wrap භාවිතා කර ඇත, එබැවින් ඉඩ මදි නම් ඊළඟ පේළියට යයි)
          Wrap(
            spacing: 8, // බොත්තම් අතර තිරස් පරතරය
            runSpacing: 8, // පේළි අතර සිරස් පරතරය
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildActionButton(
                label: 'සටහන්',
                icon: Icons.add_chart,
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DailyEntriesScreen(
                        initialCustomerId: docId,
                        initialRefNumber: data['refNumber'] ?? '',
                      ),
                    ),
                  );
                },
              ),
              _buildActionButton(
                label: 'බිල්පත',
                icon: Icons.receipt_long,
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MonthlyBillScreen(
                        customerId: docId,
                        customerName: data['name'] ?? '',
                        refNumber: data['refNumber'] ?? '',
                      ),
                    ),
                  );
                },
              ),
              // Delete බොත්තම
              InkWell(
                onTap: () => _deleteCustomer(context, docId, data['name'] ?? ''),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.red.withOpacity(0.05),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Action Button Component ---
  Widget _buildActionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// --- Submit Button Component ---
class SLongButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color primaryColor;
  const SLongButton({super.key, required this.onPressed, required this.child, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
        child: child,
      ),
    );
  }
}