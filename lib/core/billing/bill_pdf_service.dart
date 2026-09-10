import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BillPdfService {
  static Future<void> printFastDotMatrix({
    required Map<String, dynamic> bill,
    required String customerName,
    required String refNumber,
  }) async {
    final pdf = pw.Document();

    // Dot Matrix සඳහා ගැළපෙන Courier Font එක
    final font = await PdfGoogleFonts.courierPrimeRegular();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context context) {
          // --- ගණනය කිරීම් මෙතැන සිදු කරයි ---
          double teaRate = (bill['teaRate'] ?? 0.0).toDouble();
          double grossIncome = (bill['grossIncome'] ?? 0.0).toDouble();
          double transportCost = (bill['transportCost'] ?? 0.0).toDouble();

          double totalWeight = 0;
          if (teaRate != 0) {
            totalWeight = grossIncome / teaRate;
          }
          
          double transRate = 0;
          if (totalWeight > 0) {
            transRate = transportCost / totalWeight;
          }

          // --- Widget එක Return කිරීම ආරම්භය ---
          return pw.Container(
            padding: const pw.EdgeInsets.all(10),
            child: pw.DefaultTextStyle(
              style: pw.TextStyle(font: font, fontSize: 9),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Heading Section
                  pw.Center(child: pw.Text('NALEEN SURANGA', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
                  pw.Center(child: pw.Text('Authorized Green Leaf Dealer')),
                  pw.Center(child: pw.Text('Gangoda, Rakwana')),
                  pw.Center(child: pw.Text('Tel: 0713444934 / 0758258544')),
                  pw.SizedBox(height: 5),
                  pw.Text('=' * 65),
                  
                  pw.Text('Name: $customerName'.padRight(40) + 'Ref: $refNumber'),
                  pw.Text('Month: ${bill['displayMonth']}'),
                  pw.Text('Tea Rate: Rs.${teaRate.toStringAsFixed(2)} | Trans. Rate: Rs.${transRate.toStringAsFixed(2)}'),
                  pw.Text('-' * 65),
                  
                  // Table Header
                  pw.Row(children: [
                    pw.Expanded(flex: 2, child: pw.Text('Date')),
                    pw.Expanded(flex: 2, child: pw.Text('Qty(kg)')),
                    pw.Expanded(flex: 4, child: pw.Text('Item Desc')),
                    pw.Expanded(flex: 2, child: pw.Text('I.Qty')),
                    pw.Expanded(flex: 2, child: pw.Text('Amount')),
                  ]),
                  pw.Text('-' * 65),

                  // Table Data Rows
                  ...(bill['tableRows'] as List).map((row) {
                    List items = row['items'];
                    if (items.isEmpty) {
                      return pw.Row(children: [
                        pw.Expanded(flex: 2, child: pw.Text(row['date'])),
                        pw.Expanded(flex: 2, child: pw.Text(row['weight'].toStringAsFixed(1))),
                        pw.Expanded(flex: 4, child: pw.Text('-')),
                        pw.Expanded(flex: 2, child: pw.Text('-')),
                        pw.Expanded(flex: 2, child: pw.Text('-')),
                      ]);
                    } else {
                      return pw.Column(
                        children: items.map((item) {
                          bool isFirst = items.indexOf(item) == 0;
                          String fullDesc = item['desc'].toString();
                          String descOnly = fullDesc.split(' (')[0];
                          String qtyOnly = fullDesc.contains('(') 
                              ? fullDesc.split('(')[1].split(')')[0] 
                              : '-';

                          return pw.Row(children: [
                            pw.Expanded(flex: 2, child: pw.Text(isFirst ? row['date'] : '')),
                            pw.Expanded(flex: 2, child: pw.Text(isFirst ? row['weight'].toStringAsFixed(1) : '')),
                            pw.Expanded(flex: 4, child: pw.Text(descOnly)),
                            pw.Expanded(flex: 2, child: pw.Text(qtyOnly)),
                            pw.Expanded(flex: 2, child: pw.Text(item['amt'].toStringAsFixed(2))),
                          ]);
                        }).toList()
                      );
                    }
                  }).toList(),

                  pw.Text('-' * 65),
                  
                  // Summary Section
                  pw.Text('GROSS INCOME    : Rs. ${grossIncome.toStringAsFixed(2)}'),
                  pw.Text('TRANSPORT COST  : Rs. ${transportCost.toStringAsFixed(2)}'),
                  pw.Text('OTHER DEDUCTIONS: Rs. ${(bill['otherCosts'] ?? 0.0).toStringAsFixed(2)}'),
                  if ((bill['previousArrears'] ?? 0.0) > 0)
                    pw.Text('PREV. ARREARS   : Rs. ${(bill['previousArrears']).toStringAsFixed(2)}'),
                  
                  pw.Text('=' * 65),
                  pw.Text('NET PAYABLE     : Rs. ${(bill['netPayable'] ?? 0.0).toStringAsFixed(2)}', 
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text('=' * 65),
                  
                  pw.SizedBox(height: 10),
                  pw.Center(child: pw.Text('THANK YOU!')),
                  pw.Center(child: pw.Text('Powered by OrbitView Innovations', style: pw.TextStyle(fontSize: 7))),
                ],
              ),
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}