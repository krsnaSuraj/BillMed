import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ThemeMode initialMode = ThemeMode.system;
  try {
    final prefs = await SharedPreferences.getInstance();
    initialMode = themeModeFromName(prefs.getString(themePrefKey));
  } catch (_) {
    initialMode = ThemeMode.system;
  }
  runApp(ProviderScope(
    overrides: [themeModeProvider.overrideWith((_) => initialMode)],
    child: const BillMedApp(),
  ));
}

class BillMedApp extends ConsumerWidget {
  const BillMedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'BillMed',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
