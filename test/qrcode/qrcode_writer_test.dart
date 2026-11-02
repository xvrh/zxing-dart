import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zxing2/qrcode.dart';

/// Decodes a writer output, rendered black on white.
Result decodeMatrix(BitMatrix matrix, {DecodeHints? hints}) {
  var pixels = Int32List(matrix.width * matrix.height);
  for (var y = 0; y < matrix.height; y++) {
    for (var x = 0; x < matrix.width; x++) {
      pixels[y * matrix.width + x] = matrix.get(x, y) ? 0xFF000000 : 0xFFFFFFFF;
    }
  }
  var source = RGBLuminanceSource(matrix.width, matrix.height, pixels);
  return QRCodeReader()
      .decode(BinaryBitmap(HybridBinarizer(source)), hints: hints);
}

void main() {
  test('Renders to the requested size with a quiet zone', () {
    var matrix = QRCodeWriter().encode('ABC', BarcodeFormat.qrCode, 87, 87);
    expect(matrix.width, 87);
    expect(matrix.height, 87);
    // Version 1 (21 modules) + 2 * 4 quiet zone = 29 modules, scaled by 3
    for (var i = 0; i < 12; i++) {
      expect(matrix.get(i, i), isFalse);
    }
    expect(matrix.get(12, 12), isTrue);
  });

  test('Never renders smaller than the code', () {
    var matrix = QRCodeWriter().encode('ABC', BarcodeFormat.qrCode, 0, 0);
    // Version 1 (21 modules) + 2 * 4 quiet zone
    expect(matrix.width, 29);
    expect(matrix.height, 29);
  });

  test('Margin hint', () {
    var matrix = QRCodeWriter().encode('ABC', BarcodeFormat.qrCode, 0, 0,
        hints: EncodeHints()..put(EncodeHintType.margin, 1));
    expect(matrix.width, 23);
    expect(matrix.get(0, 0), isFalse);
    expect(matrix.get(1, 1), isTrue);
  });

  test('Error correction hint accepts a name', () {
    var matrix = QRCodeWriter().encode('ABC', BarcodeFormat.qrCode, 100, 100,
        hints: EncodeHints()..put(EncodeHintType.errorCorrection, 'Q'));
    var result = decodeMatrix(matrix);
    expect(result.resultMetadata[ResultMetadataType.errorCorrectionLevel], 'Q');
  });

  test('Result metadata', () {
    var code = Encoder.encode('Hello, World!', ErrorCorrectionLevel.h);
    var result = decodeMatrix(QRCodeWriter.renderResult(code, 200, 200, 4));
    expect(result.resultMetadata[ResultMetadataType.errorsCorrected], 0);
    expect(
        result.resultMetadata[ResultMetadataType.symbologyIdentifier], ']Q1');

    // Damage a few data modules
    var modules = code.matrix!;
    for (var x = 10; x < 14; x++) {
      modules.set(x, 14, 1 - modules.get(x, 14));
    }
    result = decodeMatrix(QRCodeWriter.renderResult(code, 200, 200, 4));
    expect(result.text, 'Hello, World!');
    expect(result.resultMetadata[ResultMetadataType.errorsCorrected],
        greaterThan(0));
  });

  test('Rejects other formats and empty contents', () {
    expect(() => QRCodeWriter().encode('ABC', BarcodeFormat.ean13, 10, 10),
        throwsArgumentError);
    expect(() => QRCodeWriter().encode('', BarcodeFormat.qrCode, 10, 10),
        throwsArgumentError);
  });

  group('Round trip', () {
    for (var content in [
      'ABCDEF',
      '0123456789',
      'Hello, World!',
      'café crème',
      '这是一个二维码', // https://github.com/xvrh/zxing-dart/issues/21
      'Привет мир',
      'emoji 👋🏽',
    ]) {
      test(content, () {
        var matrix =
            QRCodeWriter().encode(content, BarcodeFormat.qrCode, 200, 200);
        expect(decodeMatrix(matrix).text, content);
      });
    }

    test('With UTF-8 hints', () {
      var matrix = QRCodeWriter().encode(
          '这是一个二维码', BarcodeFormat.qrCode, 200, 200,
          hints: EncodeHints()
            ..put(EncodeHintType.characterSet, CharacterSetECI.UTF8));
      var result = decodeMatrix(matrix,
          hints: DecodeHints()..put(DecodeHintType.characterSet, 'UTF-8'));
      expect(result.text, '这是一个二维码');
    });

    test('Shift_JIS', () {
      var matrix = QRCodeWriter().encode(
          'こんにちは', BarcodeFormat.qrCode, 200, 200,
          hints: EncodeHints()
            ..put(EncodeHintType.characterSet, CharacterSetECI.SJIS));
      expect(decodeMatrix(matrix).text, 'こんにちは');
    });
  });
}
