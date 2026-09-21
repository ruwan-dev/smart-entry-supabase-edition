import os
import re

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Find Container containing padding, decoration, and child: Row(
            matches = re.finditer(r'Container\s*\(\s*padding:[^;]+?decoration:[^;]+?child:\s*Row\s*\(', content, re.DOTALL)
            for match in matches:
                print(f'Match in {filepath} at index {match.start()}')
                
            matches2 = re.finditer(r'Container\s*\(\s*decoration:[^;]+?padding:[^;]+?child:\s*Row\s*\(', content, re.DOTALL)
            for match in matches2:
                print(f'Match2 in {filepath} at index {match.start()}')
