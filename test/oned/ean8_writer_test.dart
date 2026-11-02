import 'package:test/test.dart';
import 'package:zxing2/oned.dart';
import 'matrix_to_string.dart';

/// @author Ari Pollak
void main() {
  test('Encode', () {
    var testStr =
        '0000001010001011010111101111010110111010101001110111001010001001011100101000000';
    var result =
        EAN8Writer().encode('96385074', BarcodeFormat.ean8, testStr.length, 0);
    expect(matrixToString(result), testStr);
  });

  test('Add checksum and encode', () {
    var testStr =
        '0000001010001011010111101111010110111010101001110111001010001001011100101000000';
    var result =
        EAN8Writer().encode('9638507', BarcodeFormat.ean8, testStr.length, 0);
    expect(matrixToString(result), testStr);
  });

  test('Encode illegal characters', () {
    expect(() => EAN8Writer().encode('96385abc', BarcodeFormat.ean8, 0, 0),
        throwsArgumentError);
  });
}
