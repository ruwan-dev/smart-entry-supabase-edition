import sys
import re

file_path = 'lib/core/billing/monthly_bill_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix grid
old_grid = '''    // Grid Rows
    List<TableRow> gridRows = [];
    gridRows.add(
      TableRow(
        decoration: BoxDecoration(color: Colors.grey.shade200),
        children: List.generate(
          8,
          (index) => [
            _gridCell('Day', isHeader: true),
            _gridCell('Kg', isHeader: true),
          ],
        ).expand((x) => x).toList(),
      ),
    );

    for (int r = 0; r < 4; r++) {
      List<Widget> rowChildren = [];
      for (int c = 0; c < 8; c++) {
        int day = r * 8 + c + 1;'''

new_grid = '''    // Grid Rows
    bool isMobile = MediaQuery.of(context).size.width < 600;
    int colsCount = isMobile ? 4 : 8;
    int rowsCount = isMobile ? 8 : 4;
    
    List<TableRow> gridRows = [];
    gridRows.add(
      TableRow(
        decoration: BoxDecoration(color: Colors.grey.shade200),
        children: List.generate(
          colsCount,
          (index) => [
            _gridCell('Day', isHeader: true),
            _gridCell('Kg', isHeader: true),
          ],
        ).expand((x) => x).toList(),
      ),
    );

    for (int r = 0; r < rowsCount; r++) {
      List<Widget> rowChildren = [];
      for (int c = 0; c < colsCount; c++) {
        int day = r * colsCount + c + 1;'''

if old_grid in content:
    content = content.replace(old_grid, new_grid)
    print("Grid fixed.")
else:
    print("Could not find grid setup.")

# 2. Fix Header
old_header = '''                // Header
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

new_header = '''                // Header
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

if old_header in content:
    content = content.replace(old_header, new_header)
    print("Header fixed.")
else:
    print("Could not find header setup.")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
