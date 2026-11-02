import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BillPdfService {
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static pw.Widget _pdfCell(
    String text,
    pw.Font font, {
    bool bold = false,
    double? fontSize,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: font,
          fontSize: fontSize ?? 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _pdfGridSummaryRow(
    String fmLabel,
    String weightVal,
    String rateVal,
    pw.Font fmFont,
    pw.Font engFont, {
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 5,
            child: pw.Text(
              fmLabel,
              style: pw.TextStyle(
                font: fmFont,
                fontSize: 11,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              weightVal,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: engFont,
                fontSize: 8,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Expanded(
            flex: 4,
            child: pw.Text(
              rateVal,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                font: engFont,
                fontSize: 8,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfSummaryRow(
    String fmLabel,
    String value,
    pw.Font fmFont,
    pw.Font engFont, {
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            fmLabel,
            style: pw.TextStyle(
              font: fmFont,
              fontSize: 11,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: engFont,
              fontSize: 8,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget buildFinalizedBillPdfWidget({
    required Map<String, dynamic> bill,
    required String customerName,
    required String refNumber,
    required String orgName,
    required String addressText,
    required String contactNumbers,
    required pw.Font engFont,
    required pw.Font fmFont,
    bool isSuperseded = false,
    String versionTag = '',
  }) {
    Map<int, double> dailyWeights = {};
    Map<int, double> dailyWeights2 = {};
    List<String> advanceRecords = [];
    final Map<int, double> f1ByDay = {};
    final Map<int, double> f2ByDay = {};
    final Map<int, double> t1ByDay = {};
    final Map<int, double> t2ByDay = {};
    final Map<String, Map<int, double>> dynamicByCodeByDay = {};
    double totalW = 0;
    double totalW2 = 0;

    for (var row in (bill['tableRows'] as List? ?? [])) {
      int day = int.tryParse(row['date'].toString().split('-').last) ?? 0;
      if (day == 0) continue;
      double w = _parseDouble(row['weight']);
      double w2 = _parseDouble(row['weight2']);
      if (w > 0) {
        dailyWeights[day] = (dailyWeights[day] ?? 0.0) + w;
        totalW += w;
      }
      if (w2 > 0) {
        dailyWeights2[day] = (dailyWeights2[day] ?? 0.0) + w2;
        totalW2 += w2;
      }

      List items = row['items'] ?? row['deductions'] ?? [];
      for (var it in items) {
        String desc = (it['desc'] ?? '').toString().toLowerCase();
        double amt = _parseDouble(it['amt']);
        double qty = _parseDouble(it['qty']);
        if ((desc.contains('advance') || desc.contains('අත්තිකාරම්')) && amt > 0) {
          advanceRecords.add('D${day.toString().padLeft(2, '0')}: Rs.${amt.toStringAsFixed(0)}');
        } else if (desc.contains('fert 01') || desc.contains('fertilizer 1') || desc.contains('fmdfydr 01') || desc.contains('පොහොර 1')) {
          if (qty > 0) f1ByDay[day] = (f1ByDay[day] ?? 0) + qty;
        } else if (desc.contains('fert 02') || desc.contains('fertilizer 2') || desc.contains('fmdfydr 02') || desc.contains('පොහොර 2')) {
          if (qty > 0) f2ByDay[day] = (f2ByDay[day] ?? 0) + qty;
        } else if (desc.contains('tea pkt 01') || desc.contains('tea packet 1') || desc.contains('f;a fld< 01') || desc.contains('තේ පැකට් 1') || desc.contains('තේ කොළ 1')) {
          if (qty > 0) t1ByDay[day] = (t1ByDay[day] ?? 0) + qty;
        } else if (desc.contains('tea pkt 02') || desc.contains('tea packet 2') || desc.contains('f;a fld< 02') || desc.contains('තේ පැකට් 2') || desc.contains('තේ කොළ 2')) {
          if (qty > 0) t2ByDay[day] = (t2ByDay[day] ?? 0) + qty;
        } else if (qty > 0) {
          String c = (it['code'] ?? '').toString().trim().toUpperCase();
          if (c.isEmpty) {
            c = (it['desc'] ?? '').toString().trim().split(' ').first.toUpperCase();
            if (c.length > 4) c = c.substring(0, 4);
          }
          if (c.isNotEmpty) {
            dynamicByCodeByDay.putIfAbsent(c, () => {})[day] = (dynamicByCodeByDay[c]![day] ?? 0) + qty;
          }
        }
      }
    }

    if (totalW == 0 && bill['totalWeight'] != null) {
      totalW = _parseDouble(bill['totalWeight']);
    }
    if (totalW2 == 0 && bill['totalWeight2'] != null) {
      totalW2 = _parseDouble(bill['totalWeight2']);
    }

    final gridRows = <pw.TableRow>[];
    gridRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          for (int i = 0; i < 8; i++) ...[
            _pdfCell('Day', engFont, bold: true),
            _pdfCell('Kg', engFont, bold: true),
          ],
        ],
      ),
    );

    for (int r = 0; r < 4; r++) {
      final rowChildren = <pw.Widget>[];
      for (int c = 0; c < 8; c++) {
        int day = (r * 8) + c + 1;
        if (day > 31) {
          rowChildren.addAll([_pdfCell('', engFont), _pdfCell('', engFont)]);
        } else {
          double w = dailyWeights[day] ?? 0.0;
          double w2 = dailyWeights2[day] ?? 0.0;
          String wStr = '-';
          double customFontSize = 8.0;

          String formatW(double val) => val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);

          if (w > 0 && w2 > 0) {
            wStr = '${formatW(w)}/${formatW(w2)}';
          } else if (w > 0) {
            wStr = formatW(w);
          } else if (w2 > 0) {
            wStr = '-/${formatW(w2)}';
          }

          if (wStr.length >= 8) {
            customFontSize = 5.5;
          } else if (wStr.length >= 6) {
            customFontSize = 6.5;
          }

          rowChildren.addAll([
            _pdfCell(day.toString(), engFont),
            _pdfCell(wStr, engFont, fontSize: customFontSize),
          ]);
        }
      }
      gridRows.add(pw.TableRow(children: rowChildren));
    }

    double advTotal = _parseDouble(bill['advTotal']);
    if (advTotal == 0) {
      for (var row in (bill['tableRows'] as List? ?? [])) {
        List items = row['items'] ?? row['deductions'] ?? [];
        for (var it in items) {
          String desc = (it['desc'] ?? '').toString().toLowerCase();
          if (desc.contains('advance') || desc.contains('අත්තිකාරම්')) {
            advTotal += _parseDouble(it['amt']);
          }
        }
      }
    }

    double f1Qty = _parseDouble(bill['f1Qty']);
    double f1Total = _parseDouble(bill['f1Total']);
    double f2Qty = _parseDouble(bill['f2Qty']);
    double f2Total = _parseDouble(bill['f2Total']);
    double t1Qty = _parseDouble(bill['t1Qty']);
    double t1Total = _parseDouble(bill['t1Total']);
    double t2Qty = _parseDouble(bill['t2Qty']);
    double t2Total = _parseDouble(bill['t2Total']);

    if (f1Qty == 0 && f1Total == 0 && f2Qty == 0 && f2Total == 0 && t1Qty == 0 && t1Total == 0 && t2Qty == 0 && t2Total == 0) {
      for (var row in (bill['tableRows'] as List? ?? [])) {
        List items = row['items'] ?? row['deductions'] ?? [];
        for (var it in items) {
          String desc = (it['desc'] ?? '').toString().toLowerCase();
          double qty = _parseDouble(it['qty']);
          double amt = _parseDouble(it['amt']);
          if (desc.contains('fert 01') || desc.contains('fertilizer 1') || desc.contains('fmdfydr 01') || desc.contains('පොහොර 1')) {
            f1Qty += qty;
            f1Total += amt;
          } else if (desc.contains('fert 02') || desc.contains('fertilizer 2') || desc.contains('fmdfydr 02') || desc.contains('පොහොර 2')) {
            f2Qty += qty;
            f2Total += amt;
          } else if (desc.contains('tea pkt 01') || desc.contains('tea packet 1') || desc.contains('f;a fld< 01') || desc.contains('තේ පැකට් 1') || desc.contains('තේ කොළ 1')) {
            t1Qty += qty;
            t1Total += amt;
          } else if (desc.contains('tea pkt 02') || desc.contains('tea packet 2') || desc.contains('f;a fld< 02') || desc.contains('තේ පැකට් 2') || desc.contains('තේ කොළ 2')) {
            t2Qty += qty;
            t2Total += amt;
          }
        }
      }
    }

    double otherCosts = _parseDouble(bill['otherCosts']);
    double transportCost = _parseDouble(bill['transportCost']);
    double arrears = _parseDouble(bill['arrears'] ?? bill['previousArrears']);
    double grossIncome = _parseDouble(bill['grossIncome']);
    double teaRate = _parseDouble(bill['teaRate']);
    double teaRate2 = _parseDouble(bill['teaRate2']);
    if (teaRate2 == 0 && totalW2 > 0 && grossIncome > 0) {
      teaRate2 = (grossIncome - (totalW * teaRate)) / totalW2;
    }
    double totalDeductions = _parseDouble(bill['totalDeductions']);
    if (totalDeductions == 0) {
      totalDeductions = advTotal +
          (f1Total + f2Total + t1Total + t2Total > 0
              ? (f1Total + f2Total + t1Total + t2Total)
              : otherCosts) +
          transportCost +
          arrears;
    }
    double netPayable = _parseDouble(bill['netPayable']);
    if (netPayable == 0 && grossIncome > 0) {
      netPayable = grossIncome - totalDeductions;
    }

    double totalItemsCost = f1Total + f2Total + t1Total + t2Total;
    if (totalItemsCost == 0 && otherCosts > 0) {
      totalItemsCost = otherCosts;
    }

    String formatQty(double q) => q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(1);
    List<String> itemRecords = [];
    Set<int> allItemDays = {...f1ByDay.keys, ...f2ByDay.keys, ...t1ByDay.keys, ...t2ByDay.keys};
    for (var m in dynamicByCodeByDay.values) {
      allItemDays.addAll(m.keys);
    }
    List<int> sortedItemDays = allItemDays.toList()..sort();
    for (int d in sortedItemDays) {
      if ((f1ByDay[d] ?? 0) > 0) itemRecords.add('D$d:F1x${formatQty(f1ByDay[d]!)}');
      if ((f2ByDay[d] ?? 0) > 0) itemRecords.add('D$d:F2x${formatQty(f2ByDay[d]!)}');
      if ((t1ByDay[d] ?? 0) > 0) itemRecords.add('D$d:T1x${formatQty(t1ByDay[d]!)}');
      if ((t2ByDay[d] ?? 0) > 0) itemRecords.add('D$d:T2x${formatQty(t2ByDay[d]!)}');
      for (var entry in dynamicByCodeByDay.entries) {
        if ((entry.value[d] ?? 0) > 0) {
          itemRecords.add('D$d:${entry.key}x${formatQty(entry.value[d]!)}');
        }
      }
    }

    final effectiveOrgName = orgName.trim().isNotEmpty ? orgName.trim() : 'SMART ENTRY';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  effectiveOrgName.toUpperCase(),
                  style: pw.TextStyle(
                    font: engFont,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (addressText.isNotEmpty)
                  pw.Text(
                    addressText,
                    style: pw.TextStyle(font: engFont, fontSize: 8),
                  ),
                if (contactNumbers.isNotEmpty)
                  pw.Text(
                    contactNumbers,
                    style: pw.TextStyle(font: engFont, fontSize: 8),
                  ),
              ],
            ),
            if (isSuperseded)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 2),
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red100,
                  border: pw.Border.all(color: PdfColors.red800, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
                child: pw.Text(
                  '*** SUPERSEDED / OLD COPY ${versionTag.isNotEmpty ? '($versionTag)' : ''} ***',
                  style: pw.TextStyle(
                    font: engFont,
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red900,
                  ),
                ),
              )
            else if (bill['isRevised'] == true || (versionTag.isNotEmpty && versionTag != 'Rev 1'))
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 2),
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber100,
                  border: pw.Border.all(color: PdfColors.amber800, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
                child: pw.Text(
                  '*** REVISED & UPDATED BILL ${versionTag.isNotEmpty ? '($versionTag)' : ''} ***',
                  style: pw.TextStyle(
                    font: engFont,
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.amber900,
                  ),
                ),
              ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Name: $customerName | Ref: ${refNumber.padLeft(3, '0')}',
                  style: pw.TextStyle(
                    font: engFont,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Month: ${bill['displayMonth'] ?? ''}',
                  style: pw.TextStyle(font: engFont, fontSize: 9),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 4),

        // 8-column Day / Kg table
        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey700),
          defaultColumnWidth: const pw.FlexColumnWidth(),
          children: gridRows,
        ),
        pw.SizedBox(height: 6),

        // Lower Section: Left = Deductions, Right = Summary
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left Column: Deductions Breakdown
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                padding: const pw.EdgeInsets.only(right: 15),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'wvq lsÍï úia;rh',
                      style: pw.TextStyle(
                        font: fmFont,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                    pw.SizedBox(height: 5),

                    if (advTotal > 0) ...[
                      pw.Row(
                        children: [
                          pw.Text(
                            'w;a;sldrï ',
                            style: pw.TextStyle(
                              font: fmFont,
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '(Total: Rs.${advTotal.toStringAsFixed(2)})',
                            style: pw.TextStyle(
                              font: engFont,
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children: advanceRecords
                            .map(
                              (e) => pw.Text(
                                e,
                                style: pw.TextStyle(
                                  font: engFont,
                                  fontSize: 8,
                                  color: PdfColors.grey800,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      pw.SizedBox(height: 4),
                    ],

                    if (totalItemsCost > 0 || otherCosts > 0) ...[
                      pw.Row(
                        children: [
                          pw.Text(
                            'fmdfydr iy f;a fld< ',
                            style: pw.TextStyle(
                              font: fmFont,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '(Total: Rs.${totalItemsCost.toStringAsFixed(2)})',
                            style: pw.TextStyle(
                              font: engFont,
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      if (itemRecords.isNotEmpty)
                        pw.Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          children: itemRecords
                              .map(
                                (e) => pw.Text(
                                  e,
                                  style: pw.TextStyle(
                                    font: engFont,
                                    fontSize: 8,
                                    color: PdfColors.grey800,
                                  ),
                                ),
                              )
                              .toList(),
                        )
                      else
                        pw.Text(
                          'Rs.${totalItemsCost.toStringAsFixed(2)}',
                          style: pw.TextStyle(font: engFont, fontSize: 8),
                        ),
                      pw.SizedBox(height: 3),
                    ],

                    pw.SizedBox(height: 2),
                    pw.Row(
                      children: [
                        pw.Text(
                          'm%jdyk .dia;= ',
                          style: pw.TextStyle(font: fmFont, fontSize: 9.5),
                        ),
                        pw.Text(
                          '(${((totalW + totalW2) % 1 == 0) ? (totalW + totalW2).toInt() : (totalW + totalW2).toStringAsFixed(1)}kg) : Rs.${transportCost.toStringAsFixed(2)}',
                          style: pw.TextStyle(font: engFont, fontSize: 8),
                        ),
                      ],
                    ),

                    if (arrears > 0) ...[
                      pw.SizedBox(height: 2),
                      pw.Row(
                        children: [
                          pw.Text(
                            'miq.sh udifha ysÕ uqo,a  ',
                            style: pw.TextStyle(
                              font: fmFont,
                              fontSize: 10,
                              color: PdfColors.red800,
                            ),
                          ),
                          pw.Text(
                            'Rs.${arrears.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              font: engFont,
                              fontSize: 8,
                              color: PdfColors.red800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Right Column: Summary Table Box
            pw.Expanded(
              flex: 1,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5, color: PdfColors.grey700),
                ),
                child: pw.Column(
                  children: [
                    if (totalW > 0 || totalW2 == 0)
                      _pdfGridSummaryRow(
                        'idudkH o¿',
                        '${totalW % 1 == 0 ? totalW.toInt() : totalW.toStringAsFixed(1)} Kg',
                        'Rs. ${teaRate.toStringAsFixed(2)}',
                        fmFont,
                        engFont,
                        bold: true,
                      ),
                    if (totalW2 > 0)
                      _pdfGridSummaryRow(
                        'iqmsß o¿',
                        '${totalW2 % 1 == 0 ? totalW2.toInt() : totalW2.toStringAsFixed(1)} Kg',
                        'Rs. ${teaRate2.toStringAsFixed(2)}',
                        fmFont,
                        engFont,
                        bold: true,
                      ),
                    pw.Divider(thickness: 0.5),
                    _pdfSummaryRow(
                      'o< wdodhu',
                      'Rs. ${grossIncome.toStringAsFixed(2)}',
                      fmFont,
                      engFont,
                      bold: true,
                    ),
                    pw.SizedBox(height: 5),

                    _pdfSummaryRow(
                      'uq¿ w;a;sldrï',
                      '-${advTotal.toStringAsFixed(2)}',
                      fmFont,
                      engFont,
                    ),
                    _pdfSummaryRow(
                      'fmdfydr iy f;a fld<',
                      '-${totalItemsCost.toStringAsFixed(2)}',
                      fmFont,
                      engFont,
                    ),
                    _pdfSummaryRow(
                      'm%jdyk .dia;=',
                      '-${transportCost.toStringAsFixed(2)}',
                      fmFont,
                      engFont,
                    ),
                    if (arrears > 0)
                      _pdfSummaryRow(
                        'ysÕ uqo,a',
                        '-${arrears.toStringAsFixed(2)}',
                        fmFont,
                        engFont,
                      ),

                    pw.Divider(thickness: 0.5),
                    _pdfSummaryRow(
                      'uq¿ wvq lsÍï',
                      '-${totalDeductions.toStringAsFixed(2)}',
                      fmFont,
                      engFont,
                      bold: true,
                    ),
                    pw.Divider(thickness: 1.5),
                    _pdfSummaryRow(
                      'f.úh hq;= Y=oaO uqo,',
                      'Rs. ${netPayable.toStringAsFixed(2)}',
                      fmFont,
                      engFont,
                      bold: true,
                    ),
                    pw.Divider(thickness: 1.5),
                  ],
                ),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 6),
        pw.Divider(thickness: 0.5),
        pw.Center(
          child: pw.Text(
            'Thank You! | Powered by OrbitView Innovations',
            style: pw.TextStyle(
              font: engFont,
              fontSize: 7,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
        ),
      ],
    );
  }

  static Future<void> printFastDotMatrix({
    required Map<String, dynamic> bill,
    required String customerName,
    required String refNumber,
    bool isSuperseded = false,
    String versionTag = '',
    String orgName = '',
    String addressText = '',
    String contactNumbers = '',
    double? widthCm,
    double? heightCm,
    String companyLine1 = '',
    String companyLine2 = '',
    String pageSize = '',
  }) async {
    final pdf = pw.Document();

    final fmFontData = await rootBundle.load("assets/fonts/FM-Abhaya.ttf");
    final fmFont = pw.Font.ttf(fmFontData);
    final engFont = pw.Font.helvetica();

    double effectiveWidth = widthCm ?? 21.07;
    double effectiveHeight = heightCm ?? 13.08;

    if (widthCm == null || heightCm == null) {
      String val = pageSize.toLowerCase();
      if (val.contains('a5')) {
        effectiveWidth = 21.0;
        effectiveHeight = 14.8;
      } else if (val.contains('a4')) {
        effectiveWidth = 21.0;
        effectiveHeight = 29.7;
      } else {
        final match = RegExp(r'(\d+\.?\d*)\s*[xX*×]\s*(\d+\.?\d*)').firstMatch(pageSize);
        if (match != null) {
          effectiveWidth = double.tryParse(match.group(1)!) ?? effectiveWidth;
          effectiveHeight = double.tryParse(match.group(2)!) ?? effectiveHeight;
        }
      }
    }

    final format = PdfPageFormat(
      effectiveWidth * PdfPageFormat.cm,
      effectiveHeight * PdfPageFormat.cm,
    );
    final effectiveOrgName = orgName.trim().isNotEmpty ? orgName.trim() : 'SmartEntry';
    final effectiveAddress = addressText.trim().isNotEmpty ? addressText.trim() : companyLine1.trim();
    final effectiveContact = contactNumbers.trim().isNotEmpty ? contactNumbers.trim() : companyLine2.trim();

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        build: (pw.Context context) {
          return buildFinalizedBillPdfWidget(
            bill: bill,
            customerName: customerName,
            refNumber: refNumber,
            orgName: effectiveOrgName,
            addressText: effectiveAddress,
            contactNumbers: effectiveContact,
            engFont: engFont,
            fmFont: fmFont,
            isSuperseded: isSuperseded,
            versionTag: versionTag,
          );
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'Bill_${refNumber}_${bill['displayMonth'] ?? 'slip'}',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}