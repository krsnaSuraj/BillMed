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
  /// Returns JSON text on success, null on failure.
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
    final prompt = '''You are a precise bank statement data extractor.

Extract ALL individual transactions from this bank statement PDF and return ONLY a valid JSON array. No explanation, no markdown, no code fences.

Each transaction object MUST have EXACTLY these fields with correct types:
{
  "date": "YYYY-MM-DD",          // transaction date as string
  "description": "string",        // narration/description text
  "debit": 0.00,                  // amount debited as NUMBER (0 if credit transaction)
  "credit": 0.00,                 // amount credited as NUMBER (0 if debit transaction)
  "balance": 0.00                 // running balance AFTER this transaction as NUMBER
}

CRITICAL RULES:
1. Return ONLY the JSON array — no other text whatsoever
2. "debit", "credit", "balance" MUST be numbers, NOT strings (no quotes around them)
3. Do NOT include opening balance or closing balance rows — only actual transactions
4. For debit transactions: debit > 0, credit = 0
5. For credit transactions: credit > 0, debit = 0
6. "balance" is the running account balance AFTER the transaction
7. Include EVERY transaction — do not skip any
8. Remove commas from numbers (e.g. 1,234.56 → 1234.56)

Example of correct output:
[{"date":"2025-01-10","description":"NEFT FROM XYZ","debit":0,"credit":5000.00,"balance":25000.00},{"date":"2025-01-11","description":"ATM WITHDRAWAL","debit":2000.00,"credit":0,"balance":23000.00}]''';

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
            
            // Check for blocked content
            if (data['promptFeedback']?['blockReason'] != null) {
              return null;
            }
            
            final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
            if (text != null && text.toString().isNotEmpty) return text.toString();
            return null;
          } else if (response.statusCode == 429) {
            _modelIndex = (_modelIndex + 1) % _models.length;
            await Future.delayed(const Duration(seconds: 3));
          } else if (response.statusCode == 403 || response.statusCode == 400) {
            // Key issue or bad request - don't retry
            final body = jsonDecode(response.body);
            final errMsg = body['error']?['message'] ?? 'Invalid API key or request';
            return 'ERROR: $errMsg';
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
