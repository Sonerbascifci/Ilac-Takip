import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilac_saatim/ui/app_text_scaler.dart';

class _NonlinearScaler extends TextScaler {
  const _NonlinearScaler();

  @override
  double scale(double fontSize) => fontSize < 20 ? fontSize * 2 : fontSize * 1.5;

  @override
  double get textScaleFactor => 2;
}

void main() {
  test('app enlargement preserves the nonlinear system text curve', () {
    const scaler = AppTextScaler(system: _NonlinearScaler(), factor: 1.3);
    expect(scaler.scale(16), closeTo(41.6, .001));
    expect(scaler.scale(32), closeTo(62.4, .001));
  });

  test('system size does not clamp large accessibility text', () {
    const scaler = AppTextScaler(system: TextScaler.linear(3), factor: 1);
    expect(scaler.scale(20), 60);
  });
}
