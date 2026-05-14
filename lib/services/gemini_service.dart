import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  // Models in order of preference — auto fallback on rate limit
  static const _models = [
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-flash-8b',
  ];

  static int _modelIndex = 0;
  static DateTime _lastReset = DateTime.now();
  static int _requestCount = 0;

  static Future<String?> call({
    required String apiKey,
    required String prompt,
    required String content,
    int maxRetries = 3,
  }) async {
    if (apiKey.isEmpty) return null;

    // Reset counter every minute
    if (DateTime.now().difference(_lastReset).inMinutes >= 1) {
      _requestCount = 0;
      _lastReset = DateTime.now();
    }

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      for (int m = 0; m < _models.length; m++) {
        final idx = (_modelIndex + m) % _models.length;
        final modelName = _models[idx];

        try {
          if (_requestCount >= 55) {
            await Future.delayed(const Duration(seconds: 5));
            _requestCount = 0;
          }

          final model = GenerativeModel(
            model: modelName,
            apiKey: apiKey,
            generationConfig: GenerationConfig(
              temperature: 0.1,
              maxOutputTokens: 8192,
            ),
          );

          final response = await model.generateContent([
            Content.text(prompt),
            Content.text(content),
          ]);

          _requestCount++;
          _modelIndex = idx; // Prefer this model next time

          final text = response.text;
          if (text != null && text.isNotEmpty) return text;

        } catch (e) {
          final msg = e.toString().toLowerCase();

          // Rate limited — switch model and retry
          if (msg.contains('429') || msg.contains('rate') || msg.contains('quota') || msg.contains('resource exhausted')) {
            _modelIndex = (_modelIndex + 1) % _models.length;
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }

          // Other API errors
          if (msg.contains('api key')) return null; // Invalid key
          if (attempt < maxRetries - 1) {
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
          return null;
        }
      }
    }
    return null;
  }

  /// Parse bank statement text into structured JSON
  static Future<String?> parseBankStatement({
    required String apiKey,
    required String text,
  }) async {
    final prompt = '''Extract ALL transactions from this bank statement. Return ONLY valid JSON array:
[
  {
    "date": "YYYY-MM-DD",
    "description": "transaction description",
    "debit": number (0 if credit),
    "credit": number (0 if debit),
    "balance": number
  }
]
Rules: Parse EVERY transaction. Return ONLY JSON. No other text.''';

    return call(apiKey: apiKey, prompt: prompt, content: text);
  }

  /// Correct OCR text — fix common recognition errors
  static Future<String?> correctOcr({
    required String apiKey,
    required String rawText,
  }) async {
    final prompt = '''Fix OCR errors in this bill text. Extract:
- bill_number (invoice number)
- date (DD/MM/YYYY)
- amount (total amount)
- supplier (company name)
Return as JSON only: {"bill_number":"","date":"","amount":0,"supplier":""}''';

    return call(apiKey: apiKey, prompt: prompt, content: rawText);
  }
}
