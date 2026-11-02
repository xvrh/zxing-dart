import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zxing2/oned.dart';

void main() {
  BinaryBitmap render(BitMatrix matrix) {
    // Surround the barcode with some white space, like in a real picture
    const margin = 20;
    var width = matrix.width + 2 * margin;
    var height = matrix.height + 2 * margin;
    var pixels = Int32List(width * height)
      ..fillRange(0, width * height, 0xFFFFFFFF);
    for (var y = 0; y < matrix.height; y++) {
      for (var x = 0; x < matrix.width; x++) {
        if (matrix.get(x, y)) {
          pixels[(y + margin) * width + x + margin] = 0xFF000000;
        }
      }
    }
    return BinaryBitmap(
        HybridBinarizer(RGBLuminanceSource(width, height, pixels)));
  }

  var cases = [
    (EAN13Writer(), BarcodeFormat.ean13, '5901234123457', '5901234123457'),
    (EAN8Writer(), BarcodeFormat.ean8, '96385074', '96385074'),
    (UPCAWriter(), BarcodeFormat.upcA, '485963095124', '485963095124'),
    (UPCEWriter(), BarcodeFormat.upcE, '05096893', '05096893'),
    (Code39Writer(), BarcodeFormat.code39, 'ABC-1234', 'ABC-1234'),
    (Code93Writer(), BarcodeFormat.code93, 'CODE93', 'CODE93'),
    (Code128Writer(), BarcodeFormat.code128, 'Hello, World!', 'Hello, World!'),
    (ITFWriter(), BarcodeFormat.itf, '00123456789012', '00123456789012'),
    (CodaBarWriter(), BarcodeFormat.codabar, '123456', '123456'),
  ];

  for (var (writer, format, contents, expected) in cases) {
    test('Round trip $format', () {
      var bitmap = render(writer.encode(contents, format, 0, 30));

      var result = MultiFormatReader().decode(bitmap);
      expect(result.format, format);
      expect(result.text, expected);

      var restricted = MultiFormatReader().decode(bitmap,
          hints: DecodeHints()..put(DecodeHintType.possibleFormats, [format]));
      expect(restricted.format, format);
      expect(restricted.text, expected);
    });
  }

  test('Restricting the formats excludes the others', () {
    var bitmap = render(
        EAN13Writer().encode('5901234123457', BarcodeFormat.ean13, 0, 30));
    expect(
        () => MultiFormatReader().decode(bitmap,
            hints: DecodeHints()
              ..put(DecodeHintType.possibleFormats, [BarcodeFormat.code128])),
        throwsA(isA<NotFoundException>()));
  });

  test('decodeWithState reuses the hints', () {
    var bitmap =
        render(Code128Writer().encode('zxing', BarcodeFormat.code128, 0, 30));
    var reader = MultiFormatReader()
      ..setHints(DecodeHints()
        ..put(DecodeHintType.possibleFormats, [BarcodeFormat.code128]));
    expect(reader.decodeWithState(bitmap).text, 'zxing');
    expect(reader.decodeWithState(bitmap).text, 'zxing');
  });
}
