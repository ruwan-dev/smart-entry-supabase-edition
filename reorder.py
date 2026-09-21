import os

filepath = r'lib/features/settings/settings_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

org_block = '''                _buildCompanyLineField(
                  '?????? ?? (Organization Name)',
                  _orgNameController,
                ),
'''

line1_target = '''                _buildCompanyLineField(
                  '???? ????? (Company Name - Line 1)',
                  _companyLine1Controller,
                ),'''

# First remove the org block from where it currently is
content = content.replace(org_block, '')

# Now insert it right before line 1
content = content.replace(line1_target, org_block + line1_target)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print('Reordered successfully')
