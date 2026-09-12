import 'package:intl/intl.dart';

final NumberFormat _inrWhole = NumberFormat.currency(
    locale: 'en_IN', symbol: '\u{20B9}', decimalDigits: 0);
final NumberFormat _inrPaise = NumberFormat.currency(
    locale: 'en_IN', symbol: '\u{20B9}', decimalDigits: 2);

String formatPaise(int paise, {bool forcePaise = false}) {
  final bool hasPaise = paise % 100 != 0;
  final NumberFormat f = (forcePaise || hasPaise) ? _inrPaise : _inrWhole;
  return f.format(paise / 100);
}

int rupeesInputToPaise(String input) {
  final String cleaned = input.replaceAll(',', '').trim();
  if (!RegExp(r'^\d{1,11}(\.\d{1,2})?$').hasMatch(cleaned)) return 0;
  final double value = double.tryParse(cleaned) ?? 0;
  if (value <= 0 || !value.isFinite) return 0;
  final int paise = (value * 100).round();
  return paise > 0 ? paise : 0;
}

bool isValidRupeesInput(String input) => rupeesInputToPaise(input) > 0;

String paiseToEditableString(int paise) {
  final int rupees = paise ~/ 100;
  final int rest = paise % 100;
  return rest == 0 ? '$rupees' : '$rupees.${rest.toString().padLeft(2, '0')}';
}
