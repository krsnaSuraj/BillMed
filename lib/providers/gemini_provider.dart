import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final geminiKeyProvider = StateNotifierProvider<GeminiKeyNotifier, String>((ref) {
  return GeminiKeyNotifier();
});

class GeminiKeyNotifier extends StateNotifier<String> {
  GeminiKeyNotifier() : super('') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('gemini_key') ?? '';
  }

  Future<void> setKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_key', key);
    state = key;
  }
}
