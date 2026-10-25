import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_saatim/app.dart';
import 'package:ilac_saatim/models/app_settings.dart';

void main() {
  testWidgets('system appearance is used until the user selects a theme', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const IlacSaatimApp());
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(find.text('Bugün').first)).brightness,
        Brightness.dark);
    await tester.tap(find.byTooltip('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Açık'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Görünüm'))).brightness,
        Brightness.light);
    await tester.tap(find.text('Koyu'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Görünüm'))).brightness,
        Brightness.dark);
  });

  testWidgets('loaded theme is applied before the main content is shown', (
    tester,
  ) async {
    await tester.pumpWidget(IlacSaatimApp(
      settingsLoader: () async =>
          const AppSettings(themeMode: ThemeMode.dark),
    ));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Bugün').first)).brightness,
        Brightness.dark);
  });
}
