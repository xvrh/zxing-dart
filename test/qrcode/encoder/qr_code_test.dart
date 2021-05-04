import 'package:test/test.dart';
import 'package:zxing2/src/qrcode/decoder/error_correction_level.dart';
import 'package:zxing2/src/qrcode/decoder/mode.dart';
import 'package:zxing2/src/qrcode/decoder/version.dart';
import 'package:zxing2/src/qrcode/encoder/byte_matrix.dart';
import 'package:zxing2/src/qrcode/encoder/qr_code.dart';

void main() {
  test('QrCode', () {
    var qrCode = QRCode();

    // First, test simple setters and getters.
    // We use numbers of version 7-H.
    qrCode
      ..mode = Mode.byte
      ..ecLevel = ErrorCorrectionLevel.h
      ..version = Version.getVersionForNumber(7)
      ..maskPattern = 3;

    expect(Mode.byte, qrCode.mode);
    expect(ErrorCorrectionLevel.h, qrCode.ecLevel);
    expect(7, qrCode.version!.versionNumber);
    expect(3, qrCode.maskPattern);

    // Prepare the matrix.
    var matrix = ByteMatrix(45, 45);
    // Just set bogus zero/one values.
    for (var y = 0; y < 45; ++y) {
      for (var x = 0; x < 45; ++x) {
        matrix.set(x, y, (y + x) % 2);
      }
    }

    // Set the matrix.
    qrCode.matrix = matrix;
    expect(matrix, qrCode.matrix);
  });

  test('ToString 1', () {
    var qrCode = QRCode();
    var expected =
        '<<\n mode: null\n ecLevel: null\n version: null\n maskPattern: -1\n matrix: null\n>>\n';
    expect(expected, qrCode.toString());
  });

  test('ToString 2', () {
    var qrCode = QRCode()
      ..mode = Mode.byte
      ..ecLevel = ErrorCorrectionLevel.h
      ..version = Version.getVersionForNumber(1)
      ..maskPattern = 3;

    var matrix = ByteMatrix(21, 21);
    for (var y = 0; y < 21; ++y) {
      for (var x = 0; x < 21; ++x) {
        matrix.set(x, y, (y + x) % 2);
      }
    }
    qrCode.matrix = matrix;
    var expected = '''
<<
 mode: BYTE
 ecLevel: H
 version: 1
 maskPattern: 3
 matrix:
 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0
 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1
 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0
 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1
 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0
 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1
 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0
 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1
 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0
 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1
 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0
 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1
 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0
 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1
 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0
 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1
 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0
 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1
 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0
 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1
 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0
>>
''';
    expect(qrCode.toString(), expected);
  });

  test('Is valid mask pattern', () {
    expect(QRCode.isValidMaskPattern(-1), isFalse);
    expect(QRCode.isValidMaskPattern(0), isTrue);
    expect(QRCode.isValidMaskPattern(7), isTrue);
    expect(QRCode.isValidMaskPattern(8), isFalse);
  });
}
