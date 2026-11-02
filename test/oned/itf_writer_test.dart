import 'package:test/test.dart';
import 'package:zxing2/oned.dart';
import 'matrix_to_string.dart';

/// Tests [ITFWriter].
void main() {
  void doTest(String input, String expected) {
    var result = ITFWriter().encode(input, BarcodeFormat.itf, 0, 0);
    expect(matrixToString(result), expected);
  }

  test('Encode', () {
    doTest(
        '00123456789012',
        '0000010101010111000111000101110100010101110001110111010001010001110100011'
            '100010101000101011100011101011101000111000101110100010101110001110100000');
  });

  test('Encode illegal characters', () {
    expect(() => ITFWriter().encode('00123456789abc', BarcodeFormat.itf, 0, 0),
        throwsArgumentError);
  });
}
