import sys
import re

# PATCH 1: customer_form_screen.dart
file_path_1 = 'lib/core/customer/customer_form_screen.dart'
with open(file_path_1, 'r', encoding='utf-8') as f:
    content_1 = f.read()

old_fab_1 = '''      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddCustomerScreen()),
          );
          _fetchCustomers(); // Refresh the list after adding a new customer
        },
        backgroundColor: _primaryColor,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'නව පාරිභෝගිකයෙකු',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),'''

new_fab_1 = '''      floatingActionButton: MediaQuery.of(context).size.width >= 600
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddCustomerScreen()),
                );
                _fetchCustomers(); // Refresh the list after adding a new customer
              },
              backgroundColor: _primaryColor,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text(
                'නව පාරිභෝගිකයෙකු',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,'''

if old_fab_1 in content_1:
    content_1 = content_1.replace(old_fab_1, new_fab_1)
    with open(file_path_1, 'w', encoding='utf-8') as f:
        f.write(content_1)
    print('Patched customer_form_screen.dart successfully!')
else:
    print('Warning: old_fab_1 not found in customer_form_screen.dart')

# PATCH 2: customer_list_screen.dart
file_path_2 = 'lib/core/customer/customer_list_screen.dart'
with open(file_path_2, 'r', encoding='utf-8') as f:
    content_2 = f.read()

old_fab_2 = '''      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CustomerFormScreen()),
          );
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),'''

new_fab_2 = '''      floatingActionButton: MediaQuery.of(context).size.width >= 600
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CustomerFormScreen()),
                );
              },
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.person_add, color: Colors.white),
            )
          : null,'''

if old_fab_2 in content_2:
    content_2 = content_2.replace(old_fab_2, new_fab_2)
    with open(file_path_2, 'w', encoding='utf-8') as f:
        f.write(content_2)
    print('Patched customer_list_screen.dart successfully!')
else:
    print('Warning: old_fab_2 not found in customer_list_screen.dart')

