import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/theme/app_surfaces.dart';

void main() {
  group('AppSurfaces.selectedItem', () {
    late ColorScheme lightScheme;
    late ColorScheme darkScheme;

    setUpAll(() {
      lightScheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      );
      darkScheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      );
    });

    test('מחזיר primaryContainer בשקיפות 30%', () {
      final result = AppSurfaces.selectedItem(lightScheme);
      final expected = lightScheme.primaryContainer.withValues(alpha: 0.3);
      expect(result, expected);
    });

    test('עובד גם עם ערכת צבעים כהה', () {
      final result = AppSurfaces.selectedItem(darkScheme);
      final expected = darkScheme.primaryContainer.withValues(alpha: 0.3);
      expect(result, expected);
    });

    test('צבע שונה מ-primaryContainer המלא', () {
      final selected = AppSurfaces.selectedItem(lightScheme);
      final full = lightScheme.primaryContainer;
      // alpha 30% שונה מ-alpha 100%
      expect(selected.a, isNot(equals(full.a)));
    });

    test('alpha קרוב ל-0.3 (סובלנות לעיגול float)', () {
      final selected = AppSurfaces.selectedItem(lightScheme);
      expect(selected.a, closeTo(0.3, 0.01));
    });
  });
}
