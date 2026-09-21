import sys
import re

file_path = 'lib/core/customer/customer_form_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Hide PIN tag
old_pin_tag = '''                  // PIN tag
                  if ((data['pin'] ?? '').toString().isNotEmpty)'''

new_pin_tag = '''                  // PIN tag
                  if ((data['pin'] ?? '').toString().isNotEmpty && MediaQuery.of(context).size.width >= 600)'''

content = content.replace(old_pin_tag, new_pin_tag)


# 2. Hide PIN button and Delete button
# Let's find the Exact match.
old_buttons = '''              _buildActionButton(
                label: 'PIN',
                icon: Icons.lock_reset,
                color: Colors.orange.shade400,
                onTap: () => _showEditPinDialog(context, docId, data['name'] ?? ''),
              ),'''

new_buttons = '''              if (MediaQuery.of(context).size.width >= 600) ...[
                _buildActionButton(
                  label: 'PIN',
                  icon: Icons.lock_reset,
                  color: Colors.orange.shade400,
                  onTap: () => _showEditPinDialog(context, docId, data['name'] ?? ''),
                ),'''

content = content.replace(old_buttons, new_buttons)

old_delete = '''              // Delete බොත්තම
              InkWell(
                onTap: () =>
                    _deleteCustomer(context, docId, data['name'] ?? ''),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.shade300.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.red.shade50,
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade400,
                    size: 16,
                  ),
                ),
              ),
            ],'''

new_delete = '''              // Delete බොත්තම
                InkWell(
                  onTap: () =>
                      _deleteCustomer(context, docId, data['name'] ?? ''),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red.shade300.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.red.shade50,
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ],'''

content = content.replace(old_delete, new_delete)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Patch applied successfully.")
