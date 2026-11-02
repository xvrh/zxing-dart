import 'package:test/test.dart';
import 'package:zxing2/oned.dart';
import 'matrix_to_string.dart';

/// Tests {@link UPCEWriter}.
void main() {
  void doTest(String content, String encoding) {
    var result =
        UPCEWriter().encode(content, BarcodeFormat.upcE, encoding.length, 0);
    expect(matrixToString(result), encoding);
  }

  test('Encode', () {
    doTest('05096893',
        '0000000000010101110010100111000101101011110110111001011101010100000000000');
  });

  test('Encode system 1', () {
    doTest('12345670',
        '0000000000010100100110111101010001101110010000101001000101010100000000000');
  });

  test('Add checksum and encode', () {
    doTest('0509689',
        '0000000000010101110010100111000101101011110110111001011101010100000000000');
  });

  test('Encode illegal characters', () {
    expect(() => UPCEWriter().encode('05096abc', BarcodeFormat.upcE, 0, 0),
        throwsArgumentError);
  });
}
