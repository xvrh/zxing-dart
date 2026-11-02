import 'package:test/test.dart';
import 'package:zxing2/oned.dart';
import 'matrix_to_string.dart';

/// @author Ari Pollak
void main() {
  test('Encode', () {
    var testStr =
        '00001010001011010011101100110010011011110100111010101011001101101100100001010111001001110100010010100000';
    var result = EAN13Writer()
        .encode('5901234123457', BarcodeFormat.ean13, testStr.length, 0);
    expect(matrixToString(result), testStr);
  });

  test('Add checksum and encode', () {
    var testStr =
        '00001010001011010011101100110010011011110100111010101011001101101100100001010111001001110100010010100000';
    var result = EAN13Writer()
        .encode('590123412345', BarcodeFormat.ean13, testStr.length, 0);
    expect(matrixToString(result), testStr);
  });

  test('Encode illegal characters', () {
    expect(
        () => EAN13Writer().encode('5901234123abc', BarcodeFormat.ean13, 0, 0),
        throwsArgumentError);
  });
}
