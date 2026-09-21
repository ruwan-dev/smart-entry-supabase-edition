import os
import re

directory = 'lib/'
for root, dirs, files in os.walk(directory):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()

            original = content
            content = content.replace("AppState.currentOrganizationId.value)", "AppState.currentOrganizationId.value ?? '')")
            content = content.replace("AppState.currentOrganizationId.value,", "AppState.currentOrganizationId.value ?? '',")

            if content != original:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"Patched nullability: {filepath}")
