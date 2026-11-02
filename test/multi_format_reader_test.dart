import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zxing2/datamatrix.dart';
import 'package:zxing2/oned.dart';
import 'package:zxing2/qrcode.dart';

void main() {
  BinaryBitmap render(BitMatrix matrix, {bool inverted = false}) {
    const white = 0xFFFFFFFF, black = 0xFF000000;
    // Surround the barcode with some white space, like in a real picture
    const margin = 20;
    var width = matrix.width + 2 * margin;
    var height = matrix.height + 2 * margin;
    var pixels = Int32List(width * height)
      ..fillRange(0, width * height, inverted ? black : white);
    for (var y = 0; y < matrix.height; y++) {
      for (var x = 0; x < matrix.width; x++) {
        if (matrix.get(x, y)) {
          pixels[(y + margin) * width + x + margin] = inverted ? white : black;
        }
      }
    }
    return BinaryBitmap(
        HybridBinarizer(RGBLuminanceSource(width, height, pixels)));
  }

  BitMatrix qrCode(String contents) {
    const scale = 4;
    var matrix = Encoder.encode(contents, ErrorCorrectionLevel.l).matrix!;
    var bits = BitMatrix(matrix.width * scale, matrix.height * scale);
    for (var y = 0; y < matrix.height; y++) {
      for (var x = 0; x < matrix.width; x++) {
        if (matrix.get(x, y) == 1) {
          bits.setRegion(x * scale, y * scale, scale, scale);
        }
      }
    }
    return bits;
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

  test('Decodes QR codes', () {
    var bitmap = render(qrCode('zxing'));
    expect(MultiFormatReader().decode(bitmap).format, BarcodeFormat.qrCode);
    var result = MultiFormatReader().decode(bitmap,
        hints: DecodeHints()
          ..put(DecodeHintType.possibleFormats, [BarcodeFormat.qrCode]));
    expect(result.text, 'zxing');
  });

  test('Decodes Data Matrix codes', () {
    var bitmap = render(
        DataMatrixWriter().encode('zxing', BarcodeFormat.dataMatrix, 48, 48));
    expect(MultiFormatReader().decode(bitmap).format, BarcodeFormat.dataMatrix);
    var result = MultiFormatReader().decode(bitmap,
        hints: DecodeHints()
          ..put(DecodeHintType.possibleFormats, [BarcodeFormat.dataMatrix]));
    expect(result.text, 'zxing');
  });

  test('alsoInverted decodes white on black codes', () {
    expect(
        () =>
            MultiFormatReader().decode(render(qrCode('zxing'), inverted: true)),
        throwsA(isA<NotFoundException>()));

    var result = MultiFormatReader().decode(
        render(qrCode('zxing'), inverted: true),
        hints: DecodeHints()..put(DecodeHintType.alsoInverted));
    expect(result.text, 'zxing');
  });

  test('UPC-A is reported as EAN-13 only when UPC-A is not requested', () {
    var bitmap =
        render(UPCAWriter().encode('485963095124', BarcodeFormat.upcA, 0, 30));
    DecodeHints formats(List<BarcodeFormat> formats) =>
        DecodeHints()..put(DecodeHintType.possibleFormats, formats);

    var upca = MultiFormatReader().decode(bitmap,
        hints: formats([BarcodeFormat.upcA, BarcodeFormat.ean13]));
    expect(upca.format, BarcodeFormat.upcA);
    expect(upca.text, '485963095124');

    var ean13 = MultiFormatReader()
        .decode(bitmap, hints: formats([BarcodeFormat.ean13]));
    expect(ean13.format, BarcodeFormat.ean13);
    expect(ean13.text, '0485963095124');
  });

  test('reset can be called before and after decoding', () {
    var reader = MultiFormatReader()..reset();
    reader.decode(
        render(Code128Writer().encode('zxing', BarcodeFormat.code128, 0, 30)));
    reader.reset();
  });
}
