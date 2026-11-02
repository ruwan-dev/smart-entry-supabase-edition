import 'package:flutter/services.dart';
import '../localization/app_strings.dart';

/// Formatter and validator for all currency, amount, weight, and rate inputs in Smart Entry.
/// Enforces a hard ceiling of 9,999,999,999,999.99 (up to 13 digits before decimal, up to 2 decimal places).
/// Inputs exceeding this cannot be typed, pasted, or submitted.
class MaxNumberInputFormatter extends TextInputFormatter {
  final int maxIntegerDigits;
  final int maxDecimalDigits;

  const MaxNumberInputFormatter({
    this.maxIntegerDigits = 13,
    this.maxDecimalDigits = 2,
  });

  /// Standard application-wide formatter allowing numbers up to 9,999,999,999,999.99
  static const MaxNumberInputFormatter currency = MaxNumberInputFormatter(
    maxIntegerDigits: 13,
    maxDecimalDigits: 2,
  );

  /// Maximum permissible numerical value
  static const double maxValue = 9999999999999.99;

  /// Human-readable maximum string representation
  static const String maxDisplayValue = '9,999,999,999,999.99';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }

    // Auto-strip comma separators if pasted from formatted text (e.g. "9,999,999.50")
    if (text.contains(',')) {
      final sanitized = text.replaceAll(',', '');
      final regExp = RegExp('^\\d{0,$maxIntegerDigits}(\\.\\d{0,$maxDecimalDigits})?\$');
      if (regExp.hasMatch(sanitized)) {
        return TextEditingValue(
          text: sanitized,
          selection: TextSelection.collapsed(offset: sanitized.length),
        );
      }
      return oldValue;
    }

    final regExp = RegExp('^\\d{0,$maxIntegerDigits}(\\.\\d{0,$maxDecimalDigits})?\$');
    if (regExp.hasMatch(text)) {
      return newValue;
    }

    // Reject the change if it exceeds 13 digits or 2 decimals
    return oldValue;
  }

  /// Reusable form validator enforcing numerical validity and the maximum cap of 9,999,999,999,999.99
  static String? validate(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? AppStrings.requiredField : null;
    }
    final clean = value.trim().replaceAll(',', '');
    final numVal = double.tryParse(clean);
    if (numVal == null) {
      return AppStrings.isSinhala ? 'නිවැරදි අගයක් ඇතුළත් කරන්න' : 'Please enter a valid number';
    }
    if (numVal > maxValue) {
      return AppStrings.maxNumberExceeded;
    }
    return null;
  }
}
