import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/entries/daily_entry_form_screen.dart';
import '../billing/monthly_bill_screen.dart';
import 'customer_form_screen.dart'; 
import '../app_state.dart';
import 'package:smart_entry/core/localization/app_strings.dart';

class CustomerListScreen extends StatelessWidget {
  const CustomerListScreen({super.key});

  Future<void> _deleteCustomer(BuildContext context, String docId, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.deleteCustomerConfirm),
        content: Text(AppStrings.deleteCustomerPrompt(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.no),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppStrings.yes, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await Supabase.instance.client
            .from('daily_entries')
            .delete()
            .eq('customerId', docId)
            .eq('organization_id', AppState.currentOrganizationId.value ?? '');

        await Supabase.instance.client
            .from('customers')
            .delete()
            .eq('id', docId)
            .eq('organization_id', AppState.currentOrganizationId.value ?? '');

        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
          AppState.triggerRefresh();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.customerDeleted),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppStrings.errorPrefix}$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.customers, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: true,
      ),
      
      floatingActionButton: MediaQuery.of(context).size.width >= 600
          ? FloatingActionButton(
              heroTag: 'customer_list_add_fab',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CustomerFormScreen()),
                );
              },
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.person_add, color: Colors.white),
            )
          : null,

      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client.from('customers').stream(primaryKey: ['id']).eq('organization_id', AppState.currentOrganizationId.value ?? '').order('name'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No customers found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 80),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var data = snapshot.data![index];
              String docId = data['id'];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      data['refNumber'] ?? '', 
                      style: TextStyle(
                        color: Theme.of(context).primaryColor, 
                        fontSize: 12, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                  title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${data['phone'] ?? ''}\n${data['address'] ?? ''}'),
                  isThreeLine: true,
                  
                  trailing: PopupMenuButton<int>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 0) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DailyEntryFormScreen(
                              selectedDate: DateTime.now(),
                              customerId: docId,
                              customerName: data['name'] ?? '',
                              refNumber: data['refNumber'] ?? '',
                            ),
                          ),
                        );
                      } else if (value == 1) {
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
                      } else if (value == 2) {
                        _deleteCustomer(context, docId, data['name'] ?? '');
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 0,
                        child: Row(
                          children: [
                            const Icon(Icons.add_chart, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(AppStrings.dailyEntries),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 1,
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(AppStrings.monthlyBill),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 2,
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(AppStrings.delete),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}