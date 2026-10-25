import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_saatim/app.dart';
import 'package:ilac_saatim/models/app_settings.dart';

void main() {
  testWidgets('startup waits for settings and retries a failed load', (
    tester,
  ) async {
    final settings = Completer<AppSettings>();
    var attempts = 0;
    await tester.pumpWidget(IlacSaatimApp(settingsLoader: () {
      attempts++;
      return attempts == 1
          ? settings.future
          : Future.value(const AppSettings(themeMode: ThemeMode.dark));
    }));
    expect(find.text('Bugün'), findsNothing);
    settings.completeError(StateError('storage unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.textContaining('storage unavailable'), findsNothing);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('Bugün'), findsWidgets);
    expect(Theme.of(tester.element(find.text('Bugün').first)).brightness,
        Brightness.dark);
  });

  testWidgets('tabs navigate and settings return to the originating tab', (
    tester,
  ) async {
    await tester.pumpWidget(const IlacSaatimApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('İlaçlarım'));
    await tester.pumpAndSettle();
    expect(find.text('Henüz ilaç eklemediniz'), findsOneWidget);
    await tester.tap(find.byTooltip('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Henüz ilaç eklemediniz'), findsOneWidget);
    await tester.tap(find.text('Geçmiş'));
    await tester.pumpAndSettle();
    expect(find.text('Henüz kullanım kaydı yok'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(640, 320),
  ]) {
    testWidgets('shell and appearance controls fit $size with large text', (
      tester,
    ) async {
      tester.view.reset();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(const IlacSaatimApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Ayarlar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Çok büyük'));
      await tester.tap(find.text('Çok büyük'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(MediaQuery.textScalerOf(tester.element(find.text('Görünüm')))
          .scale(20), closeTo(52, .001));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
