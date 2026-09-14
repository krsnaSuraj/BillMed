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

/// Digit grouping accepted in the amount fields: the Indian `1,250` /
/// `12,50,000` and the Western `1,234,567` shapes, last group always three
/// digits, middle groups of two or three.
bool _isValidGrouping(String whole) {
  final List<String> groups = whole.split(',');
  if (groups.length < 2) return false;
  if (groups.any((String g) => g.isEmpty)) return false;
  if (groups.first.length > 3) return false;
  if (groups.last.length != 3) return false;
  for (int i = 1; i < groups.length - 1; i++) {
    final int len = groups[i].length;
    if (len != 2 && len != 3) return false;
  }
  return true;
}

/// Rupees (as typed) → integer paise, or 0 when the input is not a valid
/// amount. 0 is the app's "invalid" signal: every form validates with
/// [isValidRupeesInput] and refuses to save, so a rejected amount is always
/// visible to the user.
///
/// Commas are honoured only as digit grouping. They used to be stripped
/// blindly, which turned "12,50" (meant ₹12.50) into ₹1,250 and "1,2,3" into
/// ₹123 — a hundred-fold money error nothing in the UI echoed back.
int rupeesInputToPaise(String input) {
  final String trimmed = input.trim();
  final int dot = trimmed.indexOf('.');
  final String whole = dot < 0 ? trimmed : trimmed.substring(0, dot);
  final String fraction = dot < 0 ? '' : trimmed.substring(dot);
  // A comma after the decimal point is never grouping.
  if (fraction.contains(',')) return 0;

  String cleanedWhole = whole;
  if (whole.contains(',')) {
    if (!_isValidGrouping(whole)) return 0;
    cleanedWhole = whole.replaceAll(',', '');
  }

  final String cleaned = '$cleanedWhole$fraction';
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
