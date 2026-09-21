import sys

file_path = 'lib/core/customer/customer_form_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_code = '''      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column('''

new_code = '''      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 100.0),
        child: Column('''

content = content.replace(old_code, new_code)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Patched successfully!')
