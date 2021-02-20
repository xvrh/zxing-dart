import 'package:test/test.dart';
import 'package:zxing/src/qrcode/decoder/error_correction_level.dart';
import 'package:zxing/src/qrcode/decoder/format_information.dart';

final int _maskedTestFormatInfo = 0x2BED;
final int _unmaskedTestFormatInfo = _maskedTestFormatInfo ^ 0x5412;

void main() {
  test('Bit differing', () {
    expect(FormatInformation.numBitsDiffering(1, 1), 0);
    expect(FormatInformation.numBitsDiffering(0, 2), 1);
    expect(FormatInformation.numBitsDiffering(1, 2), 2);
    expect(FormatInformation.numBitsDiffering(-1, 0), 32);
  });

  test('Decode', () {
    // Normal case
    var expected = FormatInformation.decodeFormatInformation(
        _maskedTestFormatInfo, _maskedTestFormatInfo);
    expect(expected, isNotNull);
    expect(expected!.dataMask, 0x07);
    expect(expected.errorCorrectionLevel, ErrorCorrectionLevel.q);
    // where the code forgot the mask!
    expect(
        FormatInformation.decodeFormatInformation(
            _unmaskedTestFormatInfo, _maskedTestFormatInfo),
        expected);
  });

  test('Decode with bit difference', () {
    var expected = FormatInformation.decodeFormatInformation(
        _maskedTestFormatInfo, _maskedTestFormatInfo);
    // 1,2,3,4 bits difference
    expect(
      FormatInformation.decodeFormatInformation(
          _maskedTestFormatInfo ^ 0x01, _maskedTestFormatInfo ^ 0x01),
      expected,
    );
    expect(
      FormatInformation.decodeFormatInformation(
          _maskedTestFormatInfo ^ 0x03, _maskedTestFormatInfo ^ 0x03),
      expected,
    );
    expect(
      FormatInformation.decodeFormatInformation(
          _maskedTestFormatInfo ^ 0x07, _maskedTestFormatInfo ^ 0x07),
      expected,
    );
    expect(
      FormatInformation.decodeFormatInformation(
          _maskedTestFormatInfo ^ 0x0F, _maskedTestFormatInfo ^ 0x0F),
      isNull,
    );
  });

  test('Decode with missread', () {
    var expected = FormatInformation.decodeFormatInformation(
        _maskedTestFormatInfo, _maskedTestFormatInfo);
    expect(
      FormatInformation.decodeFormatInformation(
          _maskedTestFormatInfo ^ 0x03, _maskedTestFormatInfo ^ 0x0F),
      expected,
    );
  });
}
/*
/**
 * @author Sean Owen
 */
public final class FormatInformationTestCase extends Assert {

  @Test
  public void testDecodeWithMisread() {
    FormatInformation expected =
        FormatInformation.decodeFormatInformation(MASKED_TEST_FORMAT_INFO, MASKED_TEST_FORMAT_INFO);
    assertEquals(expected, FormatInformation.decodeFormatInformation(
        MASKED_TEST_FORMAT_INFO ^ 0x03, MASKED_TEST_FORMAT_INFO ^ 0x0F));
  }

}
 */
