import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class RawTextPrintService {
  static String _buildBillString({
    required Map<String, dynamic> bill,
    required String customerName,
    required String refNumber,
    String orgName = '',
    String addressText = '',
    String contactNumbers = '',
    String companyLine1 = '',
    String companyLine2 = '',
  }) {
    StringBuffer txt = StringBuffer();
    
    int totalWidth = 67; 
    
    String center(String text, int width) => text.length >= width 
        ? text 
        : text.padLeft(((width - text.length) / 2).floor() + text.length).padRight(width);
    
    double totalWeight = 0;

    final effectiveOrgName = orgName.trim().isNotEmpty ? orgName.trim() : 'SMART ENTRY';
    final effectiveAddress = addressText.trim().isNotEmpty ? addressText.trim() : companyLine1.trim();
    final effectiveContact = contactNumbers.trim().isNotEmpty ? contactNumbers.trim() : companyLine2.trim();

    // --- Header Section ---
    txt.writeln('=' * totalWidth);
    txt.writeln(center(effectiveOrgName.toUpperCase(), totalWidth));
    if (effectiveAddress.isNotEmpty) {
      txt.writeln(center(effectiveAddress, totalWidth));
    }
    if (effectiveContact.isNotEmpty) {
      txt.writeln(center(effectiveContact, totalWidth));
    }
    txt.writeln('=' * totalWidth);

    txt.writeln('Name : ${customerName.padRight(35)} Ref: $refNumber');
    txt.writeln('Month: ${bill['displayMonth']}');
    txt.writeln('=' * totalWidth);

    // --- Table Header ---
    // Day(4) + Desc(22) + Qty(12) + Price(12) + Total(15) + (Spaces: 2) = 67
    txt.writeln('Day  Description            Qty          Price            Total');
    txt.writeln('---  --------------------  ----------  ------------  --------------');

    for (var row in bill['tableRows']) {
      String day = row['date'].toString().split('-').last;
      double weight = (row['weight'] ?? 0.0).toDouble();
      double teaRate = (bill['teaRate'] ?? 0.0).toDouble();
      totalWeight += weight;

      if (weight > 0) {
        txt.writeln(
          '${day.padRight(5)}${'Tea Leaves'.padRight(22)}${('${weight.toStringAsFixed(1)} Kg').padLeft(10)}  ${teaRate.toStringAsFixed(2).padLeft(12)}  ${(weight * teaRate).toStringAsFixed(2).padLeft(14)}'
        );
      }

      List items = row['items'];
      for (var item in items) {
        String desc = item['desc'].toString();
        double amt = (item['amt'] ?? 0.0).toDouble();
        double qty = (item['qty'] ?? 0.0).toDouble();
        double uPrice = (item['uPrice'] ?? 0.0).toDouble();
        bool isAdv = desc.toLowerCase().contains('advance') || desc.contains('අත්තිකාරම්');

        txt.writeln(
          '${(weight > 0 ? "".padRight(5) : day.padRight(5))}${(isAdv ? "Advance" : desc).padRight(22)}${(isAdv ? "-".padLeft(10) : qty.toStringAsFixed(0).padLeft(10))}  ${(isAdv ? "-".padLeft(12) : uPrice.toStringAsFixed(2).padLeft(12))}  ${amt.toStringAsFixed(2).padLeft(14)}'
        );
      }
      txt.writeln('-' * totalWidth);
    }

    String summaryLine(String label, String value) {
      return label.padRight(53) + value.padLeft(14);
    }

    txt.writeln(summaryLine('Total Tea Leaves Weight', '${totalWeight.toStringAsFixed(1)} Kg'));
    txt.writeln(summaryLine('Gross Income (Tea)', bill['grossIncome'].toStringAsFixed(2)));
    txt.writeln(summaryLine('Transport Deductions', '-${bill['transportCost'].toStringAsFixed(2)}'));
    txt.writeln(summaryLine('Other Deductions', '-${bill['otherCosts'].toStringAsFixed(2)}'));
    
    if ((bill['previousArrears'] ?? 0) > 0) {
      txt.writeln(summaryLine('Previous Arrears', '-${bill['previousArrears'].toStringAsFixed(2)}'));
    }

    txt.writeln(' ' * 53 + '-' * 14);
    txt.writeln(summaryLine('NET PAYABLE (Rs.)', bill['netPayable'].toStringAsFixed(2)));
    txt.writeln('=' * totalWidth);
    
    txt.writeln('\n${center('THANK YOU!', totalWidth)}');
    txt.writeln(center('Powered by OrbitView Innovations', totalWidth));
    txt.writeln('\n\n\n\n'); 
    return txt.toString();
  }

  static Future<bool> printToWindows({
    required Map<String, dynamic> bill,
    required String customerName,
    required String refNumber,
    String orgName = '',
    String addressText = '',
    String contactNumbers = '',
    String companyLine1 = '',
    String companyLine2 = '',
  }) async {
    try {
      String content = _buildBillString(
        bill: bill,
        customerName: customerName,
        refNumber: refNumber,
        orgName: orgName,
        addressText: addressText,
        contactNumbers: contactNumbers,
        companyLine1: companyLine1,
        companyLine2: companyLine2,
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}\\print_job.txt');
      await file.writeAsString(content);
      var result = await Process.run('notepad', ['/p', file.path]);
      return result.exitCode == 0;
    } catch (e, stack) {
      debugPrint('Error printing to Windows: $e\n$stack');
      return false;
    }
  }
}