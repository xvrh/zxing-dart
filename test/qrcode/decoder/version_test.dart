import 'package:test/test.dart';
import 'package:zxing/src/qrcode/decoder/error_correction_level.dart';
import 'package:zxing/src/qrcode/decoder/version.dart';

void main() {
  test('Bad version', () {
    expect(() => Version.getVersionForNumber(0), throwsA(isA<ArgumentError>()));
  });

  test('Version for number', () {
    for (int i = 1; i <= 40; i++) {
      checkVersion(Version.getVersionForNumber(i), i, 4 * i + 17);
    }
  });
}

void checkVersion(Version version, int number, int dimension) {
  expect(version, isNotNull);
  expect(version.versionNumber, number);
  if (number > 1) {
    expect(version.alignmentPatternCenters.length > 0, isTrue);
  }
  expect(version.dimensionForVersion, dimension);
  expect(version.getECBlocksForLevel(ErrorCorrectionLevel.H), isNotNull);
  expect(version.getECBlocksForLevel(ErrorCorrectionLevel.L), isNotNull);
  expect(version.getECBlocksForLevel(ErrorCorrectionLevel.M), isNotNull);
  expect(version.getECBlocksForLevel(ErrorCorrectionLevel.Q), isNotNull);
  expect(version.buildFunctionPattern(), isNotNull);
}

/*
/**
 * @author Sean Owen
 */
public final class VersionTestCase extends Assert {
  @Test
  public void testVersionForNumber() {
    for (int i = 1; i <= 40; i++) {
      checkVersion(Version.getVersionForNumber(i), i, 4 * i + 17);
    }
  }

  private static void checkVersion(Version version, int number, int dimension) {
    assertNotNull(version);
    assertEquals(number, version.getVersionNumber());
    assertNotNull(version.getAlignmentPatternCenters());
    if (number > 1) {
      assertTrue(version.getAlignmentPatternCenters().length > 0);
    }
    assertEquals(dimension, version.getDimensionForVersion());
    assertNotNull(version.getECBlocksForLevel(ErrorCorrectionLevel.H));
    assertNotNull(version.getECBlocksForLevel(ErrorCorrectionLevel.L));
    assertNotNull(version.getECBlocksForLevel(ErrorCorrectionLevel.M));
    assertNotNull(version.getECBlocksForLevel(ErrorCorrectionLevel.Q));
    assertNotNull(version.buildFunctionPattern());
  }

  @Test
  public void testGetProvisionalVersionForDimension() throws Exception {
    for (int i = 1; i <= 40; i++) {
      assertEquals(i, Version.getProvisionalVersionForDimension(4 * i + 17).getVersionNumber());
    }
  }

  @Test
  public void testDecodeVersionInformation() {
    // Spot check
    doTestVersion(7, 0x07C94);
    doTestVersion(12, 0x0C762);
    doTestVersion(17, 0x1145D);
    doTestVersion(22, 0x168C9);
    doTestVersion(27, 0x1B08E);
    doTestVersion(32, 0x209D5);
  }

  private static void doTestVersion(int expectedVersion, int mask) {
    Version version = Version.decodeVersionInformation(mask);
    assertNotNull(version);
    assertEquals(expectedVersion, version.getVersionNumber());
  }

}
*/
