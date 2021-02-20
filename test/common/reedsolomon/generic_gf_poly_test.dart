import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zxing/src/common/reedsolomon/generic_gf.dart';
import 'package:zxing/src/common/reedsolomon/generic_gf_poly.dart';

final _field = GenericGF.qrCodeField256;

void main() {
  test('Polynomial string', () {
    expect(_field.zero.toString(), '0');
    expect(_field.buildMonomial(0, -1).toString(), '-1');
    var p = GenericGFPoly(_field, Int32List.fromList([3, 0, -2, 1, 1]));
    expect(p.toString(), 'a^25x^4 - ax^2 + x + 1');
    p = GenericGFPoly(_field, Int32List.fromList([3]));
    expect(p.toString(), 'a^25');
  });

  test('Zero', () {
    expect(_field.buildMonomial(1, 0), _field.zero);
    expect(_field.buildMonomial(1, 2).multiplyScalar(0), _field.zero);
  });

  test('Evaluate', () {
    expect(_field.buildMonomial(0, 3).evaluateAt(0), 3);
  });
}
