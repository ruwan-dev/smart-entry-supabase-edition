import os

filepath = r'lib/features/dashboard/outstanding_list_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find the row for '...1...: Rs.'
start_idx_1 = -1
for i, line in enumerate(lines):
    if 'Row(' in line and 'mainAxisAlignment: MainAxisAlignment.spaceBetween,' in lines[i+1] and 'children: [' in lines[i+2] and 'Row(' in lines[i+3]:
        # This matches the double Row block
        start_idx_1 = i
        break

if start_idx_1 != -1:
    print('Found first block at', start_idx_1)
    
    # We want to change the structure from:
    # Row(
    #   mainAxisAlignment: ...
    #   children: [
    #     Row(
    #       children: [
    #         const Text(
    #           ...
    #         ),
    #         const SizedBox(width: 12),
    #         SizedBox( ... TextField ... ),
    #       ],
    #     ),
    #   ],
    # )
    
    # Just replacing the first few lines:
    lines[start_idx_1] = '                Row(\n'
    lines[start_idx_1+1] = '                  children: [\n'
    lines[start_idx_1+2] = '                    const Expanded(\n'
    lines[start_idx_1+3] = '                      child: Text(\n'
    
    # Text is at start_idx_1+6
    # Let's find the 'const SizedBox(width: 12),' which comes after the Text
    sizedbox_idx = -1
    for i in range(start_idx_1+4, start_idx_1+20):
        if 'const SizedBox(width: 12),' in lines[i]:
            sizedbox_idx = i
            break
            
    if sizedbox_idx != -1:
        # Close the Expanded after the Text
        lines[sizedbox_idx-1] = '                        ),\n                      ),\n                    ),\n'
    
    # Find the closing brackets of the inner Row
    end_idx_1 = -1
    for i in range(sizedbox_idx, sizedbox_idx + 40):
        if '                      ],' in lines[i] and '                    ),' in lines[i+1] and '                  ],' in lines[i+2]:
            end_idx_1 = i
            break
            
    if end_idx_1 != -1:
        # We need to remove the outer Row's closing brackets, since we merged them
        lines[end_idx_1] = ''
        lines[end_idx_1+1] = ''
        
with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(lines)
    
print('Patched first Row')
