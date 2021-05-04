import 'package:test/test.dart';
import 'package:zxing2/src/qrcode/decoder/mode.dart';
import 'package:zxing2/src/qrcode/decoder/version.dart';

void main() {
  test('For bits', () {
    expect(Mode.forBits(0x00), Mode.terminator);
    expect(Mode.forBits(0x01), Mode.numeric);
    expect(Mode.forBits(0x02), Mode.alphanumeric);
    expect(Mode.forBits(0x04), Mode.byte);
    expect(Mode.forBits(0x08), Mode.kanji);
  });

  test('Bad mode', () {
    expect(() => Mode.forBits(0x10), throwsA(isA<ArgumentError>()));
  });

  test('Character count', () {
    // Spot check a few values
    expect(
        Mode.numeric.getCharacterCountBits(Version.getVersionForNumber(5)), 10);
    expect(Mode.numeric.getCharacterCountBits(Version.getVersionForNumber(26)),
        12);
    expect(Mode.numeric.getCharacterCountBits(Version.getVersionForNumber(40)),
        14);
    expect(
        Mode.alphanumeric.getCharacterCountBits(Version.getVersionForNumber(6)),
        9);
    expect(Mode.byte.getCharacterCountBits(Version.getVersionForNumber(7)), 8);
    expect(Mode.kanji.getCharacterCountBits(Version.getVersionForNumber(8)), 8);
  });
}

/*
/**
 * @author Sean Owen
 */
public final class ModeTestCase extends Assert {



  @Test(expected = IllegalArgumentException.class)
  public void testBadMode() {
    Mode.forBits(0x10);
  }

  @Test
  public void testCharacterCount() {
    // Spot check a few values
    assertEquals(10, Mode.NUMERIC.getCharacterCountBits(Version.getVersionForNumber(5)));
    assertEquals(12, Mode.NUMERIC.getCharacterCountBits(Version.getVersionForNumber(26)));
    assertEquals(14, Mode.NUMERIC.getCharacterCountBits(Version.getVersionForNumber(40)));
    assertEquals(9, Mode.ALPHANUMERIC.getCharacterCountBits(Version.getVersionForNumber(6)));
    assertEquals(8, Mode.BYTE.getCharacterCountBits(Version.getVersionForNumber(7)));
    assertEquals(8, Mode.KANJI.getCharacterCountBits(Version.getVersionForNumber(8)));
  }

}
*/
