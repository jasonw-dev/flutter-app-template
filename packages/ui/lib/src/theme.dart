import 'package:flutter/material.dart';
import 'package:ui/src/tokens.dart';

/// 建立 app 主題(Material 3);light/dark 各呼叫一次。
ThemeData buildAppTheme({
  required Brightness brightness,
  Color seedColor = const Color(0xFF3B82F6),
}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    appBarTheme: const AppBarTheme(centerTitle: true),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
    ),
  );
}
