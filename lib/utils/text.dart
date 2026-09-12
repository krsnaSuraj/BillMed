/// "1 bill" vs "2 bills" — English pluralization for counts in UI strings.
String plural(int count, String singular, [String? plural]) {
  if (count == 1) return '1 $singular';
  return '$count ${plural ?? '${singular}s'}';
}

/// First-letter avatar glyph: trimmed, uppercased, '?' when nameless.
String initialLetter(String name) {
  final t = name.trim();
  return t.isEmpty ? '?' : t[0].toUpperCase();
}
