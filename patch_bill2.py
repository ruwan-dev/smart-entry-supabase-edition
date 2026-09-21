import sys
import re

file_path = 'lib/core/billing/monthly_bill_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Header regex replacement
header_pattern = re.compile(r"// Header\s*Row\(\s*crossAxisAlignment: CrossAxisAlignment\.start,\s*mainAxisAlignment: MainAxisAlignment\.spaceBetween,\s*children: \[\s*Column\(\s*crossAxisAlignment: CrossAxisAlignment\.start,\s*children: const \[\s*Text\(\s*'NALEEN SURANGA',\s*style: TextStyle\(\s*fontSize: 18,\s*fontWeight: FontWeight\.bold,\s*\),\s*\),\s*Text\(\s*'Authorized Green Dealer - Gangoda, Rakwana',\s*style: TextStyle\(fontSize: 12\),\s*\),\s*Text\(\s*'Tel: 0713444934 / 0758258544',\s*style: TextStyle\(fontSize: 12\),\s*\),\s*\]\,\s*\),\s*Column\(\s*crossAxisAlignment: CrossAxisAlignment\.end,\s*children: \[\s*Text\(\s*'Name: \$\{widget\.customerName\} \| Ref: \$\{widget\.refNumber\}',\s*style: const TextStyle\(fontSize: 12\),\s*\),\s*Text\(\s*'Month: \$\{bill\['displayMonth'\]\}',\s*style: const TextStyle\(fontSize: 12\),\s*\),\s*\]\,\s*\),\s*\]\,\s*\),", re.DOTALL)

new_header = '''// Header
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NALEEN SURANGA',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Authorized Green Dealer - Gangoda, Rakwana',
                        style: TextStyle(fontSize: 12),
                      ),
                      const Text(
                        'Tel: 0713444934 / 0758258544',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Name:  | Ref: ',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Month: ',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'NALEEN SURANGA',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Authorized Green Dealer - Gangoda, Rakwana',
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Tel: 0713444934 / 0758258544',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Name:  | Ref: ',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Month: ',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),'''

content = header_pattern.sub(new_header, content)

# Now Bottom Section
bottom_start_str = "// Bottom Section"
row_start_idx = content.find(bottom_start_str)

if row_start_idx != -1:
    # We want to replace the Row( with isMobile ? Column( ... ) : Row( ... )
    # Let's extract the left column content and right container content.
    # Actually, it's simpler:
    
    # Let's just use string replacement on the exact structure.
    old_row_start = '''                // Bottom Section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column - Deductions Info
                    Expanded(
                      flex: 5,
                      child: Column('''
                      
    new_row_start = '''                // Bottom Section
                if (isMobile) ...[
                  // Summary Box first on mobile
                  Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: Column(
                          children: [
                            if (totalWeight > 0 || totalWeight2 == 0)
                              _summaryGridRow(
                                'සාමාන්‍ය දළු',
                                ' Kg',
                                'Rs. ',
                                isBold: true,
                              ),
                            if (totalWeight2 > 0)
                              _summaryGridRow(
                                'සුපිරි දළු',
                                ' Kg',
                                'Rs. ',
                                isBold: true,
                              ),
                            const Divider(
                              color: Colors.black,
                              thickness: 1,
                              height: 15,
                            ),

                            _summaryRow(
                              'දළ ආදායම',
                              'Rs. ',
                            ),
                            const SizedBox(height: 5),
                            _summaryRow(
                              'මුළු අත්තිකාරම්',
                              '-',
                            ),
                            _summaryRow(
                              'පොහොර සහ තේ කොළ',
                              '-',
                            ),
                            _summaryRow(
                              'ප්‍රවාහන ගාස්තු',
                              '-',
                            ),
                            if (bill['previousArrears'] > 0)
                              _summaryRow(
                                'පසුගිය හිඟ මුදල',
                                '-',
                              ),

                            const Divider(
                              color: Colors.black,
                              thickness: 1,
                              height: 15,
                            ),
                            _summaryRow(
                              'මුළු අඩු කිරීම්',
                              '-',
                            ),

                            const Divider(
                              color: Colors.black,
                              thickness: 1,
                              height: 15,
                            ),
                            _summaryRow(
                              'ගෙවිය යුතු ශුද්ධ මුදල',
                              'Rs. ',
                              isBold: true,
                            ),
                            const Divider(
                              color: Colors.black,
                              thickness: 2,
                              height: 5,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      
                      // Deductions List on mobile
                      Column('''
                      
    content = content.replace(old_row_start, new_row_start)
    
    # We replaced Row( with if (isMobile) ...[ ... ]
    # Now we need to handle the else branch (the original Row).
    # Since we can't easily parse matching brackets in python regex without pain,
    # let's just do it manually or write a full replacement of the bottom section.

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
