import 'package:test/test.dart';
import 'package:zxing2/oned.dart';
import 'matrix_to_string.dart';

/// @author qwandor@google.com (Andrew Walbran)
void main() {
  test('Encode', () {
    var testStr =
        '00001010100011011011101100010001011010111101111010101011100101110100100111011001101101100101110010100000';
    var result = UPCAWriter()
        .encode('485963095124', BarcodeFormat.upcA, testStr.length, 0);
    expect(matrixToString(result), testStr);
  });

  test('Add checksum and encode', () {
    var testStr =
        '00001010011001001001101111010100011011000101011110101010001001001000111010011100101100110110110010100000';
    var result = UPCAWriter()
        .encode('12345678901', BarcodeFormat.upcA, testStr.length, 0);
    expect(matrixToString(result), testStr);
  });
}
