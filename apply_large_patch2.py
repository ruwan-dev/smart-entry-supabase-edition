import sys

file_path = 'lib/core/billing/monthly_bill_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Get the exact bounds of _buildInvoiceCard
start_str = '''  Widget _buildInvoiceCard(Map<String, dynamic> bill) {'''
end_str = '''                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),
                const Center('''

start_idx = content.find(start_str)
end_idx = content.find(end_str)

if start_idx == -1 or end_idx == -1:
    print("Could not find bounds.")
    sys.exit(1)

end_idx += len(end_str)

old_block = content[start_idx:end_idx]

# Let's craft the new block
new_block = '''  Widget _buildInvoiceCard(Map<String, dynamic> bill) {
    // Calculate totals and extract days
    Map<int, double> weightByDay = {};
    Map<int, double> weight2ByDay = {};
    Map<int, double> advanceByDay = {};
    double totalAdvance = 0;
    double totalWeight = 0;
    double totalWeight2 = 0;

    for (var row in bill['tableRows']) {
      String dateStr = row['date'] ?? '';
      if (dateStr.isEmpty) continue;

      int day = int.tryParse(dateStr.split('-').last) ?? 0;
      if (day == 0) continue;

      double weight = _parseDouble(row['weight']);
      double weight2 = _parseDouble(row['weight2']);
      
      weightByDay[day] = weight;
      weight2ByDay[day] = weight2;
      
      if (weight > 0) totalWeight += weight;
      if (weight2 > 0) totalWeight2 += weight2;

      // Extract advance by day
      List<dynamic> deductions = row['deductions'] ?? [];
      for (var item in deductions) {
        if (item['desc'] == 'Advance') {
          double amt = _parseDouble(item['amt']);
          if (amt > 0) {
            totalAdvance += amt;
            advanceByDay[day] = (advanceByDay[day] ?? 0) + amt;
          }
        }
      }
    }

    bool isMobile = MediaQuery.of(context).size.width < 600;
    int colsCount = isMobile ? 4 : 8;
    int rowsCount = isMobile ? 8 : 4;

    // Grid Rows
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
        int day = r * colsCount + c + 1;
        if (day <= 31) {
          rowChildren.add(_gridCell(day.toString()));
          double w = weightByDay[day] ?? 0;
          double w2 = weight2ByDay[day] ?? 0;
          
          String formatW(double val) => val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
          String wStr = '-';
          if (w > 0 && w2 > 0) {
            wStr = '${formatW(w)}/${formatW(w2)}';
          } else if (w > 0) {
            wStr = formatW(w);
          } else if (w2 > 0) {
            wStr = '-/${formatW(w2)}';
          }
          
          rowChildren.add(_gridCell(wStr));
        } else {
          rowChildren.add(_gridCell(''));
          rowChildren.add(_gridCell(''));
        }
      }
      gridRows.add(TableRow(children: rowChildren));
    }

    Widget summaryBox = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Column(
        children: [
          if (totalWeight > 0 || totalWeight2 == 0)
            _summaryGridRow(
              'සාමාන්‍ය දළු',
              '${totalWeight % 1 == 0 ? totalWeight.toInt() : totalWeight.toStringAsFixed(1)} Kg',
              'Rs. ${_parseDouble(bill['teaRate']).toStringAsFixed(2)}',
              isBold: true,
            ),
          if (totalWeight2 > 0)
            _summaryGridRow(
              'සුපිරි දළු',
              '${totalWeight2 % 1 == 0 ? totalWeight2.toInt() : totalWeight2.toStringAsFixed(1)} Kg',
              'Rs. ${(_parseDouble(bill['teaRate2']) == 0 && _parseDouble(bill['grossIncome']) > 0 ? ((_parseDouble(bill['grossIncome']) - (totalWeight * _parseDouble(bill['teaRate']))) / totalWeight2) : _parseDouble(bill['teaRate2'])).toStringAsFixed(2)}',
              isBold: true,
            ),
          const Divider(color: Colors.black, thickness: 1, height: 15),
          _summaryRow('දළ ආදායම', 'Rs. ${bill['grossIncome'].toStringAsFixed(2)}'),
          const SizedBox(height: 5),
          _summaryRow('මුළු අත්තිකාරම්', '-${totalAdvance.toStringAsFixed(2)}'),
          _summaryRow('පොහොර සහ තේ කොළ', '-${bill['otherCosts'].toStringAsFixed(2)}'),
          _summaryRow('ප්‍රවාහන ගාස්තු', '-${bill['transportCost'].toStringAsFixed(2)}'),
          if (bill['previousArrears'] > 0)
            _summaryRow('පසුගිය හිඟ මුදල', '-${bill['previousArrears'].toStringAsFixed(2)}'),
          const Divider(color: Colors.black, thickness: 1, height: 15),
          _summaryRow('මුළු අඩු කිරීම්', '-${bill['totalDeductions'].toStringAsFixed(2)}'),
          const Divider(color: Colors.black, thickness: 1, height: 15),
          _summaryRow('ගෙවිය යුතු ශුද්ධ මුදල', 'Rs. ${bill['netPayable'].toStringAsFixed(2)}', isBold: true),
          const Divider(color: Colors.black, thickness: 2, height: 5),
        ],
      ),
    );

    Widget deductionsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'අඩු කිරීම් විස්තරය',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
        ),
        const SizedBox(height: 10),
        Text(
          'අත්තිකාරම් (Total: Rs.${totalAdvance.toStringAsFixed(2)})',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: advanceByDay.entries.map((e) {
            String dayStr = e.key.toString().padLeft(2, '0');
            return SizedBox(
              width: 90,
              child: Text(
                'D$dayStr: Rs.${e.value.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Text(
          'ප්‍රවාහන ගාස්තු (${((totalWeight + totalWeight2) % 1 == 0) ? (totalWeight + totalWeight2).toInt() : (totalWeight + totalWeight2).toStringAsFixed(1)}kg) : Rs.${bill['transportCost'].toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        title: Text(
          bill['displayMonth'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(
          'ශුද්ධ ගෙවීම: Rs. ${bill['netPayable'].toStringAsFixed(2)}',
          style: TextStyle(
            color: bill['netPayable'] < 0 ? Colors.red : Colors.green.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('NALEEN SURANGA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Text('Authorized Green Dealer - Gangoda, Rakwana', style: TextStyle(fontSize: 12)),
                      const Text('Tel: 0713444934 / 0758258544', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      Text('Name: ${widget.customerName} | Ref: ${widget.refNumber}', style: const TextStyle(fontSize: 12)),
                      Text('Month: ${bill['displayMonth']}', style: const TextStyle(fontSize: 12)),
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
                          Text('NALEEN SURANGA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Authorized Green Dealer - Gangoda, Rakwana', style: TextStyle(fontSize: 12)),
                          Text('Tel: 0713444934 / 0758258544', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Name: ${widget.customerName} | Ref: ${widget.refNumber}', style: const TextStyle(fontSize: 12)),
                          Text('Month: ${bill['displayMonth']}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                const SizedBox(height: 15),

                // Day / Kg Grid
                Table(
                  border: TableBorder.all(color: Colors.black, width: 0.5),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: gridRows,
                ),
                const SizedBox(height: 15),

                // Bottom Section
                if (isMobile) ...[
                  summaryBox,
                  const SizedBox(height: 15),
                  deductionsColumn,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: deductionsColumn),
                      const SizedBox(width: 15),
                      Expanded(flex: 4, child: summaryBox),
                    ],
                  ),

                const SizedBox(height: 25),
                const Center('''

content = content.replace(old_block, new_block)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Applied huge block successfully!")
