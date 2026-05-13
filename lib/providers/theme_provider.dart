import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

final themeProvider = Provider<ThemeData>((ref) {
  final mode = ref.watch(themeModeProvider);
  switch (mode) {
    case ThemeMode.light:
      return AppTheme.light;
    case ThemeMode.dark:
      return AppTheme.dark;
    default:
      return AppTheme.light;
  }
});
