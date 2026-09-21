import sys
import re

file_path = 'lib/core/customer/customer_form_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix the top Row overflow by using a Wrap
old_top_row = '''          // 1. උඩ පේළිය: යොමු අංකය සහ දුරකථන අංකය
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // යොමු අංකය'''

new_top_row = '''          // 1. උඩ පේළිය: යොමු අංකය සහ දුරකථන අංකය
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              // යොමු අංකය'''

content = content.replace(old_top_row, new_top_row)

old_phone_pin = '''              // දුරකථන අංකය සහ PIN
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container('''

new_phone_pin = '''              // දුරකථන අංකය සහ PIN
                  Container('''

content = content.replace(old_phone_pin, new_phone_pin)

old_pin_gap = '''                  ),
                  const SizedBox(width: 6),
                  // PIN tag
                  if ((data['pin'] ?? '').toString().isNotEmpty)'''

new_pin_gap = '''                  ),
                  // PIN tag
                  if ((data['pin'] ?? '').toString().isNotEmpty)'''

content = content.replace(old_pin_gap, new_pin_gap)

old_close_row = '''                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),'''

new_close_row = '''                            ),
                          ),
                        ],
                      ),
                    ),
            ],
          ),

          const SizedBox(height: 12),'''

content = content.replace(old_close_row, new_close_row)


# 2. Hide PIN and Delete buttons on mobile
old_action_buttons = '''              _buildActionButton(
                label: 'PIN',
                icon: Icons.password,
                color: Colors.orange.shade400,
                onTap: () => _showEditPinDialog(context, docId, data['name'] ?? ''),
              ),
              // Delete බොත්තම
              InkWell(
                onTap: () =>
                    _deleteCustomer(context, docId, data['name'] ?? ''),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Icon(Icons.delete_outline,
                      color: Colors.red.shade400, size: 18),
                ),
              ),'''

new_action_buttons = '''              if (MediaQuery.of(context).size.width >= 600) ...[
                _buildActionButton(
                  label: 'PIN',
                  icon: Icons.password,
                  color: Colors.orange.shade400,
                  onTap: () => _showEditPinDialog(context, docId, data['name'] ?? ''),
                ),
                // Delete බොත්තම
                InkWell(
                  onTap: () =>
                      _deleteCustomer(context, docId, data['name'] ?? ''),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Icon(Icons.delete_outline,
                        color: Colors.red.shade400, size: 18),
                  ),
                ),
              ],'''

content = content.replace(old_action_buttons, new_action_buttons)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Patch applied successfully.")
