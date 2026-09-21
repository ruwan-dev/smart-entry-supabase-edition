import os
import re

directory = 'lib/'

# Files we should skip if they don't have queries or are auth/init related
skip_files = ['login_screen.dart', 'app_state.dart', 'import_supabase.dart']

def inject_import(content):
    if 'AppState.currentOrganizationId' in content and 'app_state.dart' not in content:
        # find the last import and add it
        lines = content.split('\n')
        last_import = -1
        for i, line in enumerate(lines):
            if line.startswith('import '):
                last_import = i
        if last_import != -1:
            # We need to compute relative path to lib/core/app_state.dart
            # But wait, it's easier to just use package absolute import:
            lines.insert(last_import + 1, "import 'package:smart_entry/core/app_state.dart';")
            return '\n'.join(lines)
    return content

for root, dirs, files in os.walk(directory):
    for file in files:
        if file.endswith('.dart') and file not in skip_files:
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()

            original = content
            
            # Simple regex replacements for Supabase calls
            # 1. .select()
            content = re.sub(r'(\.select\([^)]*\))(?![\s\S]*?\.eq\(\'organization_id\')', r"\1.eq('organization_id', AppState.currentOrganizationId.value)", content)
            
            # 2. .stream()
            content = re.sub(r'(\.stream\([^)]*\))(?![\s\S]*?\.eq\(\'organization_id\')', r"\1.eq('organization_id', AppState.currentOrganizationId.value)", content)
            
            # 3. .delete()
            content = re.sub(r'(\.delete\(\))(?![\s\S]*?\.eq\(\'organization_id\')', r"\1.eq('organization_id', AppState.currentOrganizationId.value)", content)

            if content != original:
                content = inject_import(content)
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"Patched: {filepath}")

