import 'package:test/test.dart';
import 'package:zxing/src/qrcode/decoder/error_correction_level.dart';

void main() {
  test('For bits', () {
    expect(ErrorCorrectionLevel.forBits(0), ErrorCorrectionLevel.M);
    expect(ErrorCorrectionLevel.forBits(1), ErrorCorrectionLevel.L);
    expect(ErrorCorrectionLevel.forBits(2), ErrorCorrectionLevel.H);
    expect(ErrorCorrectionLevel.forBits(3), ErrorCorrectionLevel.Q);
  });

  test('Bad ECC level', () {
    expect(
        () => ErrorCorrectionLevel.forBits(4), throwsA(isA<ArgumentError>()));
  });
}
