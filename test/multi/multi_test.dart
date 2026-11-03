import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zxing2/multi.dart';
import 'package:zxing2/qrcode.dart';

/// Draws the barcodes black on white, each at its position.
BinaryBitmap render(
    int width, int height, List<(BitMatrix, int left, int top)> barcodes) {
  var pixels = Int32List(width * height)..fillRange(0, width * height, -1);
  for (var (matrix, left, top) in barcodes) {
    for (var y = 0; y < matrix.height; y++) {
      for (var x = 0; x < matrix.width; x++) {
        if (matrix.get(x, y)) {
          pixels[(y + top) * width + x + left] = 0xFF000000;
        }
      }
    }
  }
  return BinaryBitmap(
      HybridBinarizer(RGBLuminanceSource(width, height, pixels)));
}

BitMatrix qrCode(String contents) =>
    QRCodeWriter().encode(contents, BarcodeFormat.qrCode, 200, 200);

void main() {
  var fourQRCodes = render(600, 600, [
    (qrCode('You earned the class: A WEEK OF WHITE'), 50, 50),
    (qrCode('You earned the class: TERRORIZING'), 350, 50),
    (qrCode('You earned the class: SEASON OF THE WITCH'), 50, 350),
    (qrCode('You get to pick a class'), 350, 350),
  ]);
  var expectedTexts = {
    'You earned the class: A WEEK OF WHITE',
    'You earned the class: TERRORIZING',
    'You earned the class: SEASON OF THE WITCH',
    'You get to pick a class',
  };

  test('QRCodeMultiReader', () {
    var results = QRCodeMultiReader().decodeMultiple(fourQRCodes);
    expect(results.map((r) => r.text).toSet(), expectedTexts);
    for (var result in results) {
      expect(result.format, BarcodeFormat.qrCode);
      expect(result.resultPoints, hasLength(4));
    }
  });

  test('GenericMultipleBarcodeReader with QR codes', () {
    var reader = GenericMultipleBarcodeReader(QRCodeReader());
    var results = reader.decodeMultiple(fourQRCodes);
    expect(results.map((r) => r.text).toSet(), expectedTexts);
  });

  test('ByQuadrantReader', () {
    var result = ByQuadrantReader(QRCodeReader()).decode(fourQRCodes);
    expect(result.text, 'You earned the class: A WEEK OF WHITE');

    // The bottom right quadrant: points are relative to the whole image
    var image = render(600, 600, [(qrCode('Bottom right'), 350, 350)]);
    result = ByQuadrantReader(QRCodeReader()).decode(image);
    expect(result.text, 'Bottom right');
    expect(result.resultPoints.every((p) => p.x > 350 && p.y > 350), isTrue);
  });

  test('GenericMultipleBarcodeReader with several formats', () {
    var image = render(700, 400, [
      (qrCode('QR Code'), 30, 30),
      (
        MultiFormatWriter()
            .encode('5901234123457', BarcodeFormat.ean13, 250, 100),
        400,
        40
      ),
      (
        MultiFormatWriter().encode('Code 128', BarcodeFormat.code128, 250, 80),
        400,
        280
      ),
    ]);
    var results =
        GenericMultipleBarcodeReader(MultiFormatReader()).decodeMultiple(image);
    expect({
      for (var r in results) r.format: r.text
    }, {
      BarcodeFormat.qrCode: 'QR Code',
      BarcodeFormat.ean13: '5901234123457',
      BarcodeFormat.code128: 'Code 128',
    });
    // Points are translated back to the coordinates of the whole image
    var ean = results.firstWhere((r) => r.format == BarcodeFormat.ean13);
    expect(ean.resultPoints.every((p) => p.x >= 400), isTrue);
  });

  test('No barcode', () {
    var empty = render(300, 300, []);
    expect(
        () =>
            GenericMultipleBarcodeReader(QRCodeReader()).decodeMultiple(empty),
        throwsA(isA<NotFoundException>()));
    expect(() => QRCodeMultiReader().decodeMultiple(empty),
        throwsA(isA<NotFoundException>()));
  });

  test('Process structured append', () {
    Result result(String text, [int? sequence]) {
      var result = Result(text, Int8List(0), BarcodeFormat.qrCode, points: [])
        ..putMetadata(ResultMetadataType.errorCorrectionLevel, 'L');
      if (sequence != null) {
        result.putMetadata(
            ResultMetadataType.structuredAppendSequence, sequence);
      }
      return result;
    }

    var inputs = [
      result('SA3', (2 << 4) + 2),
      result('SA1', 2),
      result('NotSA'),
      result('SA2', (1 << 4) + 2),
    ];
    var results = QRCodeMultiReader.processStructuredAppend(inputs);
    expect(results.map((r) => r.text).toSet(), {'SA1SA2SA3', 'NotSA'});
  });
}
