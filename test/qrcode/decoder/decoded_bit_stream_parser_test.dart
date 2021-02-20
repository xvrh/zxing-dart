import 'package:test/test.dart';
import 'package:zxing/src/decode_hint.dart';
import 'package:zxing/src/qrcode/decoder/decoded_bit_stream_parser.dart';
import 'package:zxing/src/qrcode/decoder/version.dart';
import '../../common/bit_source_builder.dart';

void main() {
  test('Simple Byte mode', () {
    BitSourceBuilder builder = BitSourceBuilder();
    builder.write(0x04, 4); // Byte mode
    builder.write(0x03, 8); // 3 bytes
    builder.write(0xF1, 8);
    builder.write(0xF2, 8);
    builder.write(0xF3, 8);
    String result = DecodedBitStreamParser.decode(builder.toByteArray(),
            Version.getVersionForNumber(1), null, DecodeHints())
        .text;
    //expect(result, "\u00f1\u00f2\u00f3");
    expect(result, hasLength(3));
  });
}

/*
/**
 * Tests {@link DecodedBitStreamParser}.
 *
 * @author Sean Owen
 */
public final class DecodedBitStreamParserTestCase extends Assert {

  @Test
  public void testSimpleSJIS() throws Exception {
    BitSourceBuilder builder = new BitSourceBuilder();
    builder.write(0x04, 4); // Byte mode
    builder.write(0x04, 8); // 4 bytes
    builder.write(0xA1, 8);
    builder.write(0xA2, 8);
    builder.write(0xA3, 8);
    builder.write(0xD0, 8);
    String result = DecodedBitStreamParser.decode(builder.toByteArray(),
        Version.getVersionForNumber(1), null, null).getText();
    assertEquals("\uff61\uff62\uff63\uff90", result);
  }

  @Test
  public void testECI() throws Exception {
    BitSourceBuilder builder = new BitSourceBuilder();
    builder.write(0x07, 4); // ECI mode
    builder.write(0x02, 8); // ECI 2 = CP437 encoding
    builder.write(0x04, 4); // Byte mode
    builder.write(0x03, 8); // 3 bytes
    builder.write(0xA1, 8);
    builder.write(0xA2, 8);
    builder.write(0xA3, 8);
    String result = DecodedBitStreamParser.decode(builder.toByteArray(),
        Version.getVersionForNumber(1), null, null).getText();
    assertEquals("\u00ed\u00f3\u00fa", result);
  }

  @Test
  public void testHanzi() throws Exception {
    BitSourceBuilder builder = new BitSourceBuilder();
    builder.write(0x0D, 4); // Hanzi mode
    builder.write(0x01, 4); // Subset 1 = GB2312 encoding
    builder.write(0x01, 8); // 1 characters
    builder.write(0x03C1, 13);
    String result = DecodedBitStreamParser.decode(builder.toByteArray(),
        Version.getVersionForNumber(1), null, null).getText();
    assertEquals("\u963f", result);
  }

  @Test
  public void testHanziLevel1() throws Exception {
    BitSourceBuilder builder = new BitSourceBuilder();
    builder.write(0x0D, 4); // Hanzi mode
    builder.write(0x01, 4); // Subset 1 = GB2312 encoding
    builder.write(0x01, 8); // 1 characters
    // A5A2 (U+30A2) => A5A2 - A1A1 = 401, 4*60 + 01 = 0181
    builder.write(0x0181, 13);
    String result = DecodedBitStreamParser.decode(builder.toByteArray(),
        Version.getVersionForNumber(1), null, null).getText();
    assertEquals("\u30a2", result);
  }

  // TODO definitely need more tests here

}
*/
