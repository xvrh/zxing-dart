import 'package:fixnum/fixnum.dart';
import '../../common/bit_array.dart';
import '../../writer_exception.dart';
import '../decoder/error_correction_level.dart';
import '../decoder/version.dart';
import 'byte_matrix.dart';
import 'mask_util.dart';
import 'qr_code.dart';

/// @author satorux@google.com (Satoru Takabayashi) - creator
/// @author dswitkin@google.com (Daniel Switkin) - ported from C++
class MatrixUtil {
  static final List<List<int>> _positionDetectionPattern = [
    [1, 1, 1, 1, 1, 1, 1],
    [1, 0, 0, 0, 0, 0, 1],
    [1, 0, 1, 1, 1, 0, 1],
    [1, 0, 1, 1, 1, 0, 1],
    [1, 0, 1, 1, 1, 0, 1],
    [1, 0, 0, 0, 0, 0, 1],
    [1, 1, 1, 1, 1, 1, 1],
  ];

  static final List<List<int>> _positionAdjustmentPattern = [
    [1, 1, 1, 1, 1],
    [1, 0, 0, 0, 1],
    [1, 0, 1, 0, 1],
    [1, 0, 0, 0, 1],
    [1, 1, 1, 1, 1],
  ];

  // From Appendix E. Table 1, JIS0510X:2004 (p 71). The table was double-checked by komatsu.
  static final List<List<int>> _positionAdjustmentPatternCoordinateTable = [
    [-1, -1, -1, -1, -1, -1, -1], // Version 1
    [6, 18, -1, -1, -1, -1, -1], // Version 2
    [6, 22, -1, -1, -1, -1, -1], // Version 3
    [6, 26, -1, -1, -1, -1, -1], // Version 4
    [6, 30, -1, -1, -1, -1, -1], // Version 5
    [6, 34, -1, -1, -1, -1, -1], // Version 6
    [6, 22, 38, -1, -1, -1, -1], // Version 7
    [6, 24, 42, -1, -1, -1, -1], // Version 8
    [6, 26, 46, -1, -1, -1, -1], // Version 9
    [6, 28, 50, -1, -1, -1, -1], // Version 10
    [6, 30, 54, -1, -1, -1, -1], // Version 11
    [6, 32, 58, -1, -1, -1, -1], // Version 12
    [6, 34, 62, -1, -1, -1, -1], // Version 13
    [6, 26, 46, 66, -1, -1, -1], // Version 14
    [6, 26, 48, 70, -1, -1, -1], // Version 15
    [6, 26, 50, 74, -1, -1, -1], // Version 16
    [6, 30, 54, 78, -1, -1, -1], // Version 17
    [6, 30, 56, 82, -1, -1, -1], // Version 18
    [6, 30, 58, 86, -1, -1, -1], // Version 19
    [6, 34, 62, 90, -1, -1, -1], // Version 20
    [6, 28, 50, 72, 94, -1, -1], // Version 21
    [6, 26, 50, 74, 98, -1, -1], // Version 22
    [6, 30, 54, 78, 102, -1, -1], // Version 23
    [6, 28, 54, 80, 106, -1, -1], // Version 24
    [6, 32, 58, 84, 110, -1, -1], // Version 25
    [6, 30, 58, 86, 114, -1, -1], // Version 26
    [6, 34, 62, 90, 118, -1, -1], // Version 27
    [6, 26, 50, 74, 98, 122, -1], // Version 28
    [6, 30, 54, 78, 102, 126, -1], // Version 29
    [6, 26, 52, 78, 104, 130, -1], // Version 30
    [6, 30, 56, 82, 108, 134, -1], // Version 31
    [6, 34, 60, 86, 112, 138, -1], // Version 32
    [6, 30, 58, 86, 114, 142, -1], // Version 33
    [6, 34, 62, 90, 118, 146, -1], // Version 34
    [6, 30, 54, 78, 102, 126, 150], // Version 35
    [6, 24, 50, 76, 102, 128, 154], // Version 36
    [6, 28, 54, 80, 106, 132, 158], // Version 37
    [6, 32, 58, 84, 110, 136, 162], // Version 38
    [6, 26, 54, 82, 110, 138, 166], // Version 39
    [6, 30, 58, 86, 114, 142, 170], // Version 40
  ];

  // Type info cells at the left top corner.
  static final List<List<int>> _typeInfoCoordinates = [
    [8, 0],
    [8, 1],
    [8, 2],
    [8, 3],
    [8, 4],
    [8, 5],
    [8, 7],
    [8, 8],
    [7, 8],
    [5, 8],
    [4, 8],
    [3, 8],
    [2, 8],
    [1, 8],
    [0, 8],
  ];

  // From Appendix D in JISX0510:2004 (p. 67)
  static final int _versionInfoPoly = 0x1f25; // 1 1111 0010 0101

  // From Appendix C in JISX0510:2004 (p.65).
  static final int _typeInfoPoly = 0x537;
  static final int _typeInfoMaskPattern = 0x5412;

  MatrixUtil._();

  // Set all cells to -1.  -1 means that the cell is empty (not set yet).
  //
  // JAVAPORT: We shouldn't need to do this at all. The code should be rewritten to begin encoding
  // with the ByteMatrix initialized all to zero.
  static void clearMatrix(ByteMatrix matrix) {
    matrix.clear(-1);
  }

  // Build 2D matrix of QR Code from "dataBits" with "ecLevel", "version" and "getMaskPattern". On
  // success, store the result in "matrix" and return true.
  static void buildMatrix(BitArray dataBits, ErrorCorrectionLevel ecLevel,
      Version version, int maskPattern, ByteMatrix matrix) {
    clearMatrix(matrix);
    embedBasicPatterns(version, matrix);
    // Type information appear with any version.
    embedTypeInfo(ecLevel, maskPattern, matrix);
    // Version info appear if version >= 7.
    maybeEmbedVersionInfo(version, matrix);
    // Data should be embedded at end.
    embedDataBits(dataBits, maskPattern, matrix);
  }

  // Embed basic patterns. On success, modify the matrix and return true.
  // The basic patterns are:
  // - Position detection patterns
  // - Timing patterns
  // - Dark dot at the left bottom corner
  // - Position adjustment patterns, if need be
  static void embedBasicPatterns(Version version, ByteMatrix matrix) {
    // Let's get started with embedding big squares at corners.
    _embedPositionDetectionPatternsAndSeparators(matrix);
    // Then, embed the dark dot at the left bottom corner.
    _embedDarkDotAtLeftBottomCorner(matrix);

    // Position adjustment patterns appear if version >= 2.
    _maybeEmbedPositionAdjustmentPatterns(version, matrix);
    // Timing patterns should be embedded after position adj. patterns.
    _embedTimingPatterns(matrix);
  }

  // Embed type information. On success, modify the matrix.
  static void embedTypeInfo(
      ErrorCorrectionLevel ecLevel, int maskPattern, ByteMatrix matrix) {
    var typeInfoBits = BitArray();
    makeTypeInfoBits(ecLevel, maskPattern, typeInfoBits);

    for (var i = 0; i < typeInfoBits.size; ++i) {
      // Place bits in LSB to MSB order.  LSB (least significant bit) is the last value in
      // "typeInfoBits".
      var bit = typeInfoBits.get(typeInfoBits.size - 1 - i);

      // Type info bits at the left top corner. See 8.9 of JISX0510:2004 (p.46).
      var coordinates = _typeInfoCoordinates[i];
      var x1 = coordinates[0];
      var y1 = coordinates[1];
      matrix.setBool(x1, y1, bit);

      int x2;
      int y2;
      if (i < 8) {
        // Right top corner.
        x2 = matrix.width - i - 1;
        y2 = 8;
      } else {
        // Left bottom corner.
        x2 = 8;
        y2 = matrix.height - 7 + (i - 8);
      }
      matrix.setBool(x2, y2, bit);
    }
  }

  // Embed version information if need be. On success, modify the matrix and return true.
  // See 8.10 of JISX0510:2004 (p.47) for how to embed version information.
  static void maybeEmbedVersionInfo(Version version, ByteMatrix matrix) {
    if (version.versionNumber < 7) {
      // Version info is necessary if version >= 7.
      return; // Don't need version info.
    }
    var versionInfoBits = BitArray();
    makeVersionInfoBits(version, versionInfoBits);

    var bitIndex = 6 * 3 - 1; // It will decrease from 17 to 0.
    for (var i = 0; i < 6; ++i) {
      for (var j = 0; j < 3; ++j) {
        // Place bits in LSB (least significant bit) to MSB order.
        var bit = versionInfoBits.get(bitIndex);
        bitIndex--;
        // Left bottom corner.
        matrix.setBool(i, matrix.height - 11 + j, bit);
        // Right bottom corner.
        matrix.setBool(matrix.height - 11 + j, i, bit);
      }
    }
  }

  // Embed "dataBits" using "getMaskPattern". On success, modify the matrix and return true.
  // For debugging purposes, it skips masking process if "getMaskPattern" is -1.
  // See 8.7 of JISX0510:2004 (p.38) for how to embed data bits.
  static void embedDataBits(
      BitArray dataBits, int maskPattern, ByteMatrix matrix) {
    var bitIndex = 0;
    var direction = -1;
    // Start from the right bottom cell.
    var x = matrix.width - 1;
    var y = matrix.height - 1;
    while (x > 0) {
      // Skip the vertical timing pattern.
      if (x == 6) {
        x -= 1;
      }
      while (y >= 0 && y < matrix.height) {
        for (var i = 0; i < 2; ++i) {
          var xx = x - i;
          // Skip the cell if it's not empty.
          if (!_isEmpty(matrix.get(xx, y))) {
            continue;
          }
          bool bit;
          if (bitIndex < dataBits.size) {
            bit = dataBits.get(bitIndex);
            ++bitIndex;
          } else {
            // Padding bit. If there is no bit left, we'll fill the left cells with 0, as described
            // in 8.4.9 of JISX0510:2004 (p. 24).
            bit = false;
          }

          // Skip masking if mask_pattern is -1.
          if (maskPattern != -1 &&
              MaskUtil.getDataMaskBit(maskPattern, xx, y)) {
            bit = !bit;
          }
          matrix.setBool(xx, y, bit);
        }
        y += direction;
      }
      direction = -direction; // Reverse the direction.
      y += direction;
      x -= 2; // Move to the left.
    }
    // All bits should be consumed.
    if (bitIndex != dataBits.size) {
      throw WriterException(
          'Not all bits consumed: $bitIndex/${dataBits.size}');
    }
  }

  // Return the position of the most significant bit set (to one) in the "value". The most
  // significant bit is position 32. If there is no bit set, return 0. Examples:
  // - findMSBSet(0) => 0
  // - findMSBSet(1) => 1
  // - findMSBSet(255) => 8
  static int findMSBSet(int value) {
    return 32 - Int32(value).numberOfLeadingZeros();
  }

  // Calculate BCH (Bose-Chaudhuri-Hocquenghem) code for "value" using polynomial "poly". The BCH
  // code is used for encoding type information and version information.
  // Example: Calculation of version information of 7.
  // f(x) is created from 7.
  //   - 7 = 000111 in 6 bits
  //   - f(x) = x^2 + x^1 + x^0
  // g(x) is given by the standard (p. 67)
  //   - g(x) = x^12 + x^11 + x^10 + x^9 + x^8 + x^5 + x^2 + 1
  // Multiply f(x) by x^(18 - 6)
  //   - f'(x) = f(x) * x^(18 - 6)
  //   - f'(x) = x^14 + x^13 + x^12
  // Calculate the remainder of f'(x) / g(x)
  //         x^2
  //         __________________________________________________
  //   g(x) )x^14 + x^13 + x^12
  //         x^14 + x^13 + x^12 + x^11 + x^10 + x^7 + x^4 + x^2
  //         --------------------------------------------------
  //                              x^11 + x^10 + x^7 + x^4 + x^2
  //
  // The remainder is x^11 + x^10 + x^7 + x^4 + x^2
  // Encode it in binary: 110010010100
  // The return value is 0xc94 (1100 1001 0100)
  //
  // Since all coefficients in the polynomials are 1 or 0, we can do the calculation by bit
  // operations. We don't care if coefficients are positive or negative.
  static int calculateBCHCode(int value, int poly) {
    if (poly == 0) {
      throw ArgumentError('0 polynomial');
    }
    // If poly is "1 1111 0010 0101" (version info poly), msbSetInPoly is 13. We'll subtract 1
    // from 13 to make it 12.
    var msbSetInPoly = findMSBSet(poly);
    value <<= msbSetInPoly - 1;
    // Do the division business using exclusive-or operations.
    while (findMSBSet(value) >= msbSetInPoly) {
      value ^= poly << (findMSBSet(value) - msbSetInPoly);
    }
    // Now the "value" is the remainder (i.e. the BCH code)
    return value;
  }

  // Make bit vector of type information. On success, store the result in "bits" and return true.
  // Encode error correction level and mask pattern. See 8.9 of
  // JISX0510:2004 (p.45) for details.
  static void makeTypeInfoBits(
      ErrorCorrectionLevel ecLevel, int maskPattern, BitArray bits) {
    if (!QRCode.isValidMaskPattern(maskPattern)) {
      throw WriterException('Invalid mask pattern');
    }
    var typeInfo = (ecLevel.bits << 3) | maskPattern;
    bits.appendBits(typeInfo, 5);

    var bchCode = calculateBCHCode(typeInfo, _typeInfoPoly);
    bits.appendBits(bchCode, 10);

    var maskBits = BitArray();
    maskBits.appendBits(_typeInfoMaskPattern, 15);
    bits.xor(maskBits);

    if (bits.size != 15) {
      // Just in case.
      throw WriterException('should not happen but we got: ${bits.size}');
    }
  }

  // Make bit vector of version information. On success, store the result in "bits" and return true.
  // See 8.10 of JISX0510:2004 (p.45) for details.
  static void makeVersionInfoBits(Version version, BitArray bits) {
    bits.appendBits(version.versionNumber, 6);
    var bchCode = calculateBCHCode(version.versionNumber, _versionInfoPoly);
    bits.appendBits(bchCode, 12);

    if (bits.size != 18) {
      // Just in case.
      throw WriterException('should not happen but we got: ${bits.size}');
    }
  }

  // Check if "value" is empty.
  static bool _isEmpty(int value) {
    return value == -1;
  }

  static void _embedTimingPatterns(ByteMatrix matrix) {
    // -8 is for skipping position detection patterns (size 7), and two horizontal/vertical
    // separation patterns (size 1). Thus, 8 = 7 + 1.
    for (var i = 8; i < matrix.width - 8; ++i) {
      var bit = (i + 1) % 2;
      // Horizontal line.
      if (_isEmpty(matrix.get(i, 6))) {
        matrix.set(i, 6, bit);
      }
      // Vertical line.
      if (_isEmpty(matrix.get(6, i))) {
        matrix.set(6, i, bit);
      }
    }
  }

  // Embed the lonely dark dot at left bottom corner. JISX0510:2004 (p.46)
  static void _embedDarkDotAtLeftBottomCorner(ByteMatrix matrix) {
    if (matrix.get(8, matrix.height - 8) == 0) {
      throw WriterException('');
    }
    matrix.set(8, matrix.height - 8, 1);
  }

  static void _embedHorizontalSeparationPattern(
      int xStart, int yStart, ByteMatrix matrix) {
    for (var x = 0; x < 8; ++x) {
      if (!_isEmpty(matrix.get(xStart + x, yStart))) {
        throw WriterException('');
      }
      matrix.set(xStart + x, yStart, 0);
    }
  }

  static void _embedVerticalSeparationPattern(
      int xStart, int yStart, ByteMatrix matrix) {
    for (var y = 0; y < 7; ++y) {
      if (!_isEmpty(matrix.get(xStart, yStart + y))) {
        throw WriterException('');
      }
      matrix.set(xStart, yStart + y, 0);
    }
  }

  static void _embedPositionAdjustmentPattern(
      int xStart, int yStart, ByteMatrix matrix) {
    for (var y = 0; y < 5; ++y) {
      var patternY = _positionAdjustmentPattern[y];
      for (var x = 0; x < 5; ++x) {
        matrix.set(xStart + x, yStart + y, patternY[x]);
      }
    }
  }

  static void _embedPositionDetectionPattern(
      int xStart, int yStart, ByteMatrix matrix) {
    for (var y = 0; y < 7; ++y) {
      var patternY = _positionDetectionPattern[y];
      for (var x = 0; x < 7; ++x) {
        matrix.set(xStart + x, yStart + y, patternY[x]);
      }
    }
  }

  // Embed position detection patterns and surrounding vertical/horizontal separators.
  static void _embedPositionDetectionPatternsAndSeparators(ByteMatrix matrix) {
    // Embed three big squares at corners.
    var pdpWidth = _positionDetectionPattern[0].length;
    // Left top corner.
    _embedPositionDetectionPattern(0, 0, matrix);
    // Right top corner.
    _embedPositionDetectionPattern(matrix.width - pdpWidth, 0, matrix);
    // Left bottom corner.
    _embedPositionDetectionPattern(0, matrix.width - pdpWidth, matrix);

    // Embed horizontal separation patterns around the squares.
    var hspWidth = 8;
    // Left top corner.
    _embedHorizontalSeparationPattern(0, hspWidth - 1, matrix);
    // Right top corner.
    _embedHorizontalSeparationPattern(
        matrix.width - hspWidth, hspWidth - 1, matrix);
    // Left bottom corner.
    _embedHorizontalSeparationPattern(0, matrix.width - hspWidth, matrix);

    // Embed vertical separation patterns around the squares.
    var vspSize = 7;
    // Left top corner.
    _embedVerticalSeparationPattern(vspSize, 0, matrix);
    // Right top corner.
    _embedVerticalSeparationPattern(matrix.height - vspSize - 1, 0, matrix);
    // Left bottom corner.
    _embedVerticalSeparationPattern(vspSize, matrix.height - vspSize, matrix);
  }

  // Embed position adjustment patterns if need be.
  static void _maybeEmbedPositionAdjustmentPatterns(
      Version version, ByteMatrix matrix) {
    if (version.versionNumber < 2) {
      // The patterns appear if version >= 2
      return;
    }
    var index = version.versionNumber - 1;
    var coordinates = _positionAdjustmentPatternCoordinateTable[index];
    for (var y in coordinates) {
      if (y >= 0) {
        for (var x in coordinates) {
          if (x >= 0 && _isEmpty(matrix.get(x, y))) {
            // If the cell is unset, we embed the position adjustment pattern here.
            // -2 is necessary since the x/y coordinates point to the center of the pattern, not the
            // left top corner.
            _embedPositionAdjustmentPattern(x - 2, y - 2, matrix);
          }
        }
      }
    }
  }
}
