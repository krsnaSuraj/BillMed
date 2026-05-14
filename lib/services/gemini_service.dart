import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const _models = [
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-flash-8b',
  ];

  static int _modelIndex = 0;
  static DateTime _lastReset = DateTime.now();
  static int _requestCount = 0;

  /// Call Gemini REST API directly with PDF bytes (base64 encoded).
  /// This bypasses PDF text extraction — Gemini reads the PDF natively.
  static Future<String?> parsePdf({
    required String apiKey,
    required List<int> pdfBytes,
  }) async {
    if (apiKey.isEmpty) return null;

    if (DateTime.now().difference(_lastReset).inMinutes >= 1) {
      _requestCount = 0;
      _lastReset = DateTime.now();
    }

    final base64 = base64Encode(pdfBytes);
    const prompt = '''Extract ALL transactions from this PDF bank statement.
Return ONLY a JSON array. No other text, no markdown.

Each object must have:
- date: "YYYY-MM-DD"
- description: string
- debit: number (0 if credit)
- credit: number (0 if debit)
- balance: number

Example: [{"date":"2026-01-15","description":"NEFT TRANSFER","debit":5000,"credit":0,"balance":45000}]

Parse EVERY transaction. Return ONLY JSON.''';

    for (int attempt = 0; attempt < 3; attempt++) {
      for (int m = 0; m < _models.length; m++) {
        final idx = (_modelIndex + m) % _models.length;
        final modelName = _models[idx];

        try {
          if (_requestCount >= 55) {
            await Future.delayed(const Duration(seconds: 5));
            _requestCount = 0;
          }

          final url = 'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey';
          final response = await http.post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [{
                'parts': [
                  {'text': prompt},
                  {'inline_data': {'mime_type': 'application/pdf', 'data': base64}}
                ]
              }],
              'generationConfig': {
                'temperature': 0.1,
                'maxOutputTokens': 8192,
              }
            }),
          );

          if (response.statusCode == 200) {
            _requestCount++;
            _modelIndex = idx;

            final data = jsonDecode(response.body);
            final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
            if (text != null && text.toString().isNotEmpty) return text.toString();
          } else if (response.statusCode == 429) {
            _modelIndex = (_modelIndex + 1) % _models.length;
            await Future.delayed(const Duration(seconds: 3));
          } else if (response.statusCode == 403) {
            return null; // Invalid key
          } else {
            if (attempt < 2) await Future.delayed(const Duration(seconds: 1));
          }
        } catch (_) {
          if (attempt < 2) await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    return null;
  }
}
