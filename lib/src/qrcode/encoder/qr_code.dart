import 'package:zxing/src/qrcode/decoder/error_correction_level.dart';
import 'package:zxing/src/qrcode/decoder/mode.dart';
import 'package:zxing/src/qrcode/decoder/version.dart';

import 'byte_matrix.dart';

/**
 * @author satorux@google.com (Satoru Takabayashi) - creator
 * @author dswitkin@google.com (Daniel Switkin) - ported from C++
 */
class QRCode {
  static final int NUM_MASK_PATTERNS = 8;

  Mode? mode;
  ErrorCorrectionLevel? ecLevel;
  Version? version;
  int maskPattern = -1;
  ByteMatrix? matrix;

  @override
  String toString() {
    var result = new StringBuffer();
    result.write("<<\n");
    result.write(" mode: ");
    result.write(mode);
    result.write("\n ecLevel: ");
    result.write(ecLevel);
    result.write("\n version: ");
    result.write(version);
    result.write("\n maskPattern: ");
    result.write(maskPattern);
    if (matrix == null) {
      result.write("\n matrix: null\n");
    } else {
      result.write("\n matrix:\n");
      result.write(matrix);
    }
    result.write(">>\n");
    return result.toString();
  }

  // Check if "mask_pattern" is valid.
  static bool isValidMaskPattern(int maskPattern) {
    return maskPattern >= 0 && maskPattern < NUM_MASK_PATTERNS;
  }
}
