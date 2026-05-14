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
    final prompt = '''You are a bank statement parser.

Here is a bank statement PDF. Extract ALL transactions from it and return ONLY a JSON array.

Each transaction object MUST have these exact fields:
- "date": the date in YYYY-MM-DD format
- "description": the transaction description or narration  
- "debit": the debit amount as a number (0 if this is a credit)
- "credit": the credit amount as a number (0 if this is a debit)
- "balance": the running balance after this transaction as a number

Rules:
1. Return ONLY the JSON array, nothing else
2. Parse EVERY single transaction in the statement
3. Convert dates to YYYY-MM-DD format
4. Debit = money going out, Credit = money coming in
5. If a description is empty, use "NA"

Example output format:
[{"date":"2026-01-15","description":"NEFT TRANSFER","debit":5000,"credit":0,"balance":45000}]''';

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
