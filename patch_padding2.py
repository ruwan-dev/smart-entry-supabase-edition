import sys

file_path = 'lib/core/customer/customer_list_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_code = '''          return ListView.builder(
            padding: const EdgeInsets.all(12),'''

new_code = '''          return ListView.builder(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 80),'''

content = content.replace(old_code, new_code)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Patched successfully!')
