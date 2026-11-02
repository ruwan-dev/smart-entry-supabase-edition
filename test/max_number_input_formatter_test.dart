import 'package:flutter_test/flutter_test.dart';
import 'package:smart_entry/core/localization/app_strings.dart';
import 'package:smart_entry/core/widgets/max_number_input_formatter.dart';

void main() {
  group('MaxNumberInputFormatter Tests', () {
    const formatter = MaxNumberInputFormatter.currency;

    test('Allows numbers up to 13 integer digits and 2 decimal places', () {
      // Maximum valid value: 9999999999999.99
      final valid = const TextEditingValue(text: '9999999999999.99');
      final res = formatter.formatEditUpdate(TextEditingValue.empty, valid);
      expect(res.text, '9999999999999.99');
    });

    test('Blocks 14th integer digit', () {
      final oldVal = const TextEditingValue(text: '9999999999999');
      final newVal = const TextEditingValue(text: '99999999999999');
      final res = formatter.formatEditUpdate(oldVal, newVal);
      expect(res.text, '9999999999999'); // Rejects 14th digit
    });

    test('Blocks 3rd decimal place', () {
      final oldVal = const TextEditingValue(text: '1250.50');
      final newVal = const TextEditingValue(text: '1250.505');
      final res = formatter.formatEditUpdate(oldVal, newVal);
      expect(res.text, '1250.50'); // Rejects 3rd decimal
    });

    test('Blocks non-numeric characters and multiple dots', () {
      final oldVal = const TextEditingValue(text: '500');
      final newValWithAlpha = const TextEditingValue(text: '500a');
      expect(formatter.formatEditUpdate(oldVal, newValWithAlpha).text, '500');

      final oldValDot = const TextEditingValue(text: '500.5');
      final newValDoubleDot = const TextEditingValue(text: '500.5.2');
      expect(formatter.formatEditUpdate(oldValDot, newValDoubleDot).text, '500.5');
    });

    test('Correctly strips commas when pasting formatted values', () {
      final pasted = const TextEditingValue(text: '9,999,999,999,999.99');
      final res = formatter.formatEditUpdate(TextEditingValue.empty, pasted);
      expect(res.text, '9999999999999.99');
    });

    test('Rejects pasted values that exceed the limit with commas', () {
      final pastedTooBig = const TextEditingValue(text: '10,000,000,000,000.00');
      final res = formatter.formatEditUpdate(TextEditingValue.empty, pastedTooBig);
      expect(res.text, '');
    });

    test('validate helper correctly checks maxValue boundary', () {
      expect(MaxNumberInputFormatter.validate('9999999999999.99'), isNull);
      expect(MaxNumberInputFormatter.validate('9,999,999,999,999.99'), isNull);
      expect(MaxNumberInputFormatter.validate('100.00'), isNull);

      // Exceeds 9,999,999,999,999.99
      expect(MaxNumberInputFormatter.validate('10000000000000'), AppStrings.maxNumberExceeded);
      expect(MaxNumberInputFormatter.validate('10000000000000.00'), AppStrings.maxNumberExceeded);
      expect(MaxNumberInputFormatter.validate('99999999999999'), AppStrings.maxNumberExceeded);
    });
  });
}
