import 'package:flutter_test/flutter_test.dart';
import 'package:billmed/utils/money.dart';

void main() {
  group('formatPaise', () {
    test('zero renders as ₹0', () {
      expect(formatPaise(0), '\u{20B9}0');
    });

    test('whole rupees use Indian grouping without decimals', () {
      expect(formatPaise(100000), '\u{20B9}1,000');
      expect(formatPaise(123456700), '\u{20B9}12,34,567');
      expect(formatPaise(12345678900), '\u{20B9}12,34,56,789');
    });

    test('paise shown automatically when non-zero', () {
      final s = formatPaise(100075);
      expect(s.startsWith('\u{20B9}'), isTrue);
      expect(s.endsWith('.75'), isTrue);
    });

    test('forcePaise always shows two decimals', () {
      expect(formatPaise(5000000, forcePaise: true).endsWith('.00'), isTrue);
    });
  });

  group('rupeesInputToPaise', () {
    test('parses plain numbers', () {
      expect(rupeesInputToPaise('100'), 10000);
      expect(rupeesInputToPaise('100.75'), 10075);
      expect(rupeesInputToPaise('0.5'), 50);
    });

    test('strips Indian comma grouping', () {
      expect(rupeesInputToPaise('12,34,567'), 123456700);
      expect(rupeesInputToPaise('1,000.25'), 100025);
      // Western grouping is accepted too.
      expect(rupeesInputToPaise('1,234,567'), 123456700);
      expect(rupeesInputToPaise('9,99,999.99'), 99999999);
    });

    test('a comma that is not grouping is REJECTED, never reinterpreted', () {
      // "12,50" means ₹12.50 to the person typing it. Stripping the comma
      // blindly used to record ₹1,250 — a hundred-fold error that nothing in
      // the UI echoed back, so the invalid signal (0 → form error) is the only
      // safe answer.
      expect(rupeesInputToPaise('12,50'), 0);
      expect(rupeesInputToPaise('1,50'), 0);
      expect(rupeesInputToPaise('1,2,3'), 0);
      expect(rupeesInputToPaise('1,,000'), 0);
      expect(rupeesInputToPaise('1250,'), 0);
      expect(rupeesInputToPaise(',250'), 0);
      expect(rupeesInputToPaise('1,2345'), 0);
      expect(rupeesInputToPaise('1234,567'), 0);
      expect(rupeesInputToPaise('1,000.2,5'), 0);
      expect(isValidRupeesInput('12,50'), isFalse);
    });

    test('rejects invalid input as zero', () {
      expect(rupeesInputToPaise(''), 0);
      expect(rupeesInputToPaise('abc'), 0);
      expect(rupeesInputToPaise('-500'), 0);
      expect(rupeesInputToPaise('-0.01'), 0);
      expect(rupeesInputToPaise('.'), 0);
    });

    test('literal paise for tricky decimals (catches a truncating parser)', () {
      // Asserting the round-trip only proves the parser and the formatter
      // agree; these literals pin the rounding itself.
      expect(rupeesInputToPaise('0.07'), 7);
      expect(rupeesInputToPaise('19.99'), 1999);
      expect(rupeesInputToPaise('1234.57'), 123457);
      expect(rupeesInputToPaise('8.85'), 885);
      expect(rupeesInputToPaise('0.005'), 0, reason: '3 decimals are invalid');
    });

    test('no float drift on tricky decimals', () {
      for (final input in ['0.07', '19.99', '1234.57', '8.85']) {
        final p = rupeesInputToPaise(input);
        expect(p % 100, lessThan(100));
        expect(
          paiseToEditableString(p),
          input,
          reason: 'round-trip failed for $input',
        );
      }
    });

    test('caps absurd amounts at zero (rejected)', () {
      expect(rupeesInputToPaise('99999999999'), greaterThan(0));
      expect(rupeesInputToPaise('100000000000'), 0);
    });
  });

  group('isValidRupeesInput', () {
    test('mirrors rupeesInputToPaise > 0', () {
      expect(isValidRupeesInput('10'), isTrue);
      expect(isValidRupeesInput('0'), isFalse);
      expect(isValidRupeesInput('x'), isFalse);
    });
  });
}
