import 'package:test/test.dart';
import 'package:zxing/src/qrcode/decoder/error_correction_level.dart';

void main() {
  test('For bits', () {
    expect(ErrorCorrectionLevel.forBits(0), ErrorCorrectionLevel.m);
    expect(ErrorCorrectionLevel.forBits(1), ErrorCorrectionLevel.l);
    expect(ErrorCorrectionLevel.forBits(2), ErrorCorrectionLevel.h);
    expect(ErrorCorrectionLevel.forBits(3), ErrorCorrectionLevel.q);
  });

  test('Bad ECC level', () {
    expect(
        () => ErrorCorrectionLevel.forBits(4), throwsA(isA<ArgumentError>()));
  });
}
