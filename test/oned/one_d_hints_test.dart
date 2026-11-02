import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:zxing2/oned.dart';
import '../image_luminance_source.dart';

/// Covers the decode hints and reader options that the blackbox images don't exercise.
void main() {
  test('assumeGs1 converts FNC1 for Code 128', () {
    var bitmap = _render(Code128Writer().encode(
        'ñ01034531200000111719112510ñ10ABCD1234',
        BarcodeFormat.code128,
        0,
        30));

    var result = Code128Reader().decode(bitmap);
    expect(result.text, '0103453120000011171911251010ABCD1234');
    expect(
        result.resultMetadata[ResultMetadataType.symbologyIdentifier], ']C1');

    var gs1 = Code128Reader()
        .decode(bitmap, hints: DecodeHints()..put(DecodeHintType.assumeGs1));
    expect(gs1.text, ']C101034531200000111719112510\u001d10ABCD1234');
  });

  group('Code 39 check digit', () {
    // C=12, O=24, D=13, E=14, 3, 9: 75 % 43 = 32 = 'W'
    var valid = Code39Writer().encode('CODE39W', BarcodeFormat.code39, 0, 30);

    test('is kept by default', () {
      expect(Code39Reader().decode(_render(valid)).text, 'CODE39W');
    });

    test('is checked and removed when enabled', () {
      expect(Code39Reader(true).decode(_render(valid)).text, 'CODE39');

      var hints = DecodeHints()
        ..put(DecodeHintType.possibleFormats, [BarcodeFormat.code39])
        ..put(DecodeHintType.assumeCode39CheckDigit);
      expect(MultiFormatReader().decode(_render(valid), hints: hints).text,
          'CODE39');
    });

    test('rejects a wrong check digit', () {
      var invalid =
          Code39Writer().encode('CODE39X', BarcodeFormat.code39, 0, 30);
      expect(() => Code39Reader(true).decode(_render(invalid)),
          throwsA(isA<NotFoundException>()));
    });
  });

  test('returnCodabarStartEnd keeps the start and end characters', () {
    var bitmap = _render(
        CodaBarWriter().encode('A123456B', BarcodeFormat.codabar, 0, 30));

    expect(CodaBarReader().decode(bitmap).text, '123456');
    expect(
        CodaBarReader()
            .decode(bitmap,
                hints: DecodeHints()..put(DecodeHintType.returnCodabarStartEnd))
            .text,
        'A123456B');
  });

  test('allowedLengths accepts non standard ITF lengths', () {
    var bitmap = _render(ITFWriter().encode('1234', BarcodeFormat.itf, 0, 30));

    expect(() => ITFReader().decode(bitmap), throwsA(isA<NotFoundException>()));
    expect(
        ITFReader()
            .decode(bitmap,
                hints: DecodeHints()..put(DecodeHintType.allowedLengths, [4]))
            .text,
        '1234');
  });

  group('allowedEanExtensions', () {
    BinaryBitmap withExtension() {
      var image = img.decodePng(
          File('test/resources/blackbox/upcean-extension-1/1.png')
              .readAsBytesSync())!;
      return BinaryBitmap(HybridBinarizer(ImageLuminanceSource(image)));
    }

    DecodeHints allowed(List<int> lengths) =>
        DecodeHints()..put(DecodeHintType.allowedEanExtensions, lengths);

    test('reports the extension when not set', () {
      var result = EAN13Reader().decode(withExtension());
      expect(result.text, '9780735200449');
      expect(
          result.resultMetadata[ResultMetadataType.upcEanExtension], '51299');
      expect(
          result.resultMetadata[ResultMetadataType.suggestedPrice], r'$12.99');
    });

    test('accepts an allowed extension length', () {
      var result = EAN13Reader().decode(withExtension(), hints: allowed([5]));
      expect(result.text, '9780735200449');
    });

    test('rejects other extension lengths', () {
      expect(() => EAN13Reader().decode(withExtension(), hints: allowed([2])),
          throwsA(isA<NotFoundException>()));
    });

    test('requires an extension', () {
      var bitmap = _render(
          EAN13Writer().encode('5901234123457', BarcodeFormat.ean13, 0, 30));
      expect(EAN13Reader().decode(bitmap).text, '5901234123457');
      expect(() => EAN13Reader().decode(bitmap, hints: allowed([2, 5])),
          throwsA(isA<NotFoundException>()));
    });
  });

  test('needResultPointCallback reports the guard patterns', () {
    var points = <ResultPoint>[];
    var bitmap = _render(
        EAN13Writer().encode('5901234123457', BarcodeFormat.ean13, 0, 30));

    var result = EAN13Reader().decode(bitmap,
        hints: DecodeHints()
          ..put(DecodeHintType.needResultPointCallback, points.add));

    // Start guard, end of the middle and end guard
    expect(points, hasLength(3));
    expect(points.map((p) => p.y), everyElement(result.resultPoints.first.y));
    expect(points.first.x, lessThan(points.last.x));
  });

  test('tryHarder decodes barcodes rotated by 90 degrees', () {
    var image = img.copyRotate(
        _toImage(
            EAN13Writer().encode('5901234123457', BarcodeFormat.ean13, 0, 30)),
        angle: 90);
    BinaryBitmap bitmap() =>
        BinaryBitmap(HybridBinarizer(ImageLuminanceSource(image)));

    expect(() => EAN13Reader().decode(bitmap()),
        throwsA(isA<NotFoundException>()));

    var result = EAN13Reader()
        .decode(bitmap(), hints: DecodeHints()..put(DecodeHintType.tryHarder));
    expect(result.text, '5901234123457');
    expect(result.resultMetadata[ResultMetadataType.orientation], 270);
  });

  group('UPCAReader', () {
    test('decodes UPC-A', () {
      var bitmap = _render(
          UPCAWriter().encode('485963095124', BarcodeFormat.upcA, 0, 30));
      var result = UPCAReader().decode(bitmap);
      expect(result.text, '485963095124');
      expect(result.format, BarcodeFormat.upcA);
    });

    test('decodes a single row', () {
      var matrix =
          UPCAWriter().encode('485963095124', BarcodeFormat.upcA, 0, 1);
      var result =
          UPCAReader().decodeRow(0, matrix.getRow(0, null), DecodeHints());
      expect(result.text, '485963095124');
      expect(result.format, BarcodeFormat.upcA);
    });

    test('rejects EAN-13 codes that are not UPC-A', () {
      var bitmap = _render(
          EAN13Writer().encode('5901234123457', BarcodeFormat.ean13, 0, 30));
      expect(() => UPCAReader().decode(bitmap),
          throwsA(isA<FormatReaderException>()));
    });
  });
}

img.Image _toImage(BitMatrix matrix) {
  // Surround the barcode with some white space, like in a real picture
  const margin = 20;
  var image = img.Image(
      width: matrix.width + 2 * margin, height: matrix.height + 2 * margin);
  img.fill(image, color: img.ColorRgb8(0xFF, 0xFF, 0xFF));
  for (var y = 0; y < matrix.height; y++) {
    for (var x = 0; x < matrix.width; x++) {
      if (matrix.get(x, y)) {
        image.setPixelRgb(x + margin, y + margin, 0, 0, 0);
      }
    }
  }
  return image;
}

BinaryBitmap _render(BitMatrix matrix) =>
    BinaryBitmap(HybridBinarizer(ImageLuminanceSource(_toImage(matrix))));
