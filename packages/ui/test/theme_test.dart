import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

void main() {
  test('tokens 有預期值', () {
    expect(AppSpacing.md, 16);
    expect(AppRadii.md, 12);
    expect(AppDurations.fast, const Duration(milliseconds: 150));
  });

  test('buildAppTheme 產出 M3 主題且明暗各自成立', () {
    final light = buildAppTheme(brightness: Brightness.light);
    final dark = buildAppTheme(brightness: Brightness.dark);
    expect(light.useMaterial3, isTrue);
    expect(light.colorScheme.brightness, Brightness.light);
    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(light.appBarTheme.centerTitle, isTrue);
  });

  test('seedColor 影響 colorScheme', () {
    final a = buildAppTheme(
      brightness: Brightness.light,
      seedColor: const Color(0xFFE11D48),
    );
    final b = buildAppTheme(brightness: Brightness.light);
    expect(a.colorScheme.primary, isNot(b.colorScheme.primary));
  });
}
