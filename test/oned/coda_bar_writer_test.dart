import 'package:test/test.dart';
import 'package:zxing2/oned.dart';
import 'matrix_to_string.dart';

/// @author dsbnatut@gmail.com (Kazuki Nishiura)
/// @author Sean Owen
void main() {
  BitMatrix encode(String input) {
    return CodaBarWriter().encode(input, BarcodeFormat.codabar, 0, 0);
  }

  void doTest(String input, String expected) {
    var result = encode(input);
    expect(matrixToString(result), expected);
  }

  test('Encode', () {
    doTest(
        'B515-3/B',
        '00000'
            '1001001011'
            '0110101001'
            '0101011001'
            '0110101001'
            '0101001101'
            '0110010101'
            '01101101011'
            '01001001011'
            '00000');
  });

  test('Encode 2', () {
    doTest(
        'T123T',
        '00000'
            '1011001001'
            '0101011001'
            '0101001011'
            '0110010101'
            '01011001001'
            '00000');
  });

  test('Alt start end', () {
    expect(encode(r'T123456789-$T'), encode(r'A123456789-$A'));
  });
}
