import 'package:test/test.dart';
import 'package:zxing2/src/format_reader_exception.dart';
import 'package:zxing2/src/qrcode/decoder/error_correction_level.dart';
import 'package:zxing2/src/qrcode/decoder/version.dart';

void main() {
  test('Bad version', () {
    expect(() => Version.getVersionForNumber(0), throwsA(isA<ArgumentError>()));
  });

  test('Version for number', () {
    for (var i = 1; i <= 40; i++) {
      checkVersion(Version.getVersionForNumber(i), i, 4 * i + 17);
    }
  });

  test('Provisional version for dimension', () {
    for (var i = 1; i <= 40; i++) {
      expect(
          Version.getProvisionalVersionForDimension(4 * i + 17).versionNumber,
          i);
    }
  });

  test('Bad dimension', () {
    for (var dimension in [16, 17, 22, 185]) {
      expect(() => Version.getProvisionalVersionForDimension(dimension),
          throwsA(isA<FormatReaderException>()));
    }
  });

  test('Decode version information', () {
    // Spot check
    expect(Version.decodeVersionInformation(0x07C94)!.versionNumber, 7);
    expect(Version.decodeVersionInformation(0x0C762)!.versionNumber, 12);
    expect(Version.decodeVersionInformation(0x1145D)!.versionNumber, 17);
    expect(Version.decodeVersionInformation(0x168C9)!.versionNumber, 22);
    expect(Version.decodeVersionInformation(0x1B08E)!.versionNumber, 27);
    expect(Version.decodeVersionInformation(0x209D5)!.versionNumber, 32);
  });
}

void checkVersion(Version version, int number, int dimension) {
  expect(version, isNotNull);
  expect(version.versionNumber, number);
  if (number > 1) {
    expect(version.alignmentPatternCenters.isNotEmpty, isTrue);
  }
  expect(version.dimensionForVersion, dimension);
  expect(version.getECBlocksForLevel(ErrorCorrectionLevel.h), isNotNull);
  expect(version.getECBlocksForLevel(ErrorCorrectionLevel.l), isNotNull);
  expect(version.getECBlocksForLevel(ErrorCorrectionLevel.m), isNotNull);
  expect(version.getECBlocksForLevel(ErrorCorrectionLevel.q), isNotNull);
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
