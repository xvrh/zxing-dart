import 'package:test/test.dart';
import 'package:zxing2/oned.dart';
import 'package:zxing2/qrcode.dart';

void main() {
  var cases = [
    (EAN13Writer(), BarcodeFormat.ean13, '5901234123457'),
    (EAN8Writer(), BarcodeFormat.ean8, '96385074'),
    (UPCAWriter(), BarcodeFormat.upcA, '485963095124'),
    (UPCEWriter(), BarcodeFormat.upcE, '05096893'),
    (Code39Writer(), BarcodeFormat.code39, 'ABC-1234'),
    (Code93Writer(), BarcodeFormat.code93, 'CODE93'),
    (Code128Writer(), BarcodeFormat.code128, 'Hello, World!'),
    (ITFWriter(), BarcodeFormat.itf, '00123456789012'),
    (CodaBarWriter(), BarcodeFormat.codabar, '123456'),
    (QRCodeWriter(), BarcodeFormat.qrCode, 'Hello, World!'),
  ];

  for (var (writer, format, contents) in cases) {
    test('Uses the writer of $format', () {
      var hints = EncodeHints()..put(EncodeHintType.margin, 2);
      expect(
          MultiFormatWriter().encode(contents, format, 100, 50, hints: hints),
          writer.encode(contents, format, 100, 50, hints: hints));
    });
  }

  test('Rejects the formats without a writer', () {
    for (var format in [
      BarcodeFormat.aztec,
      BarcodeFormat.maxicode,
      BarcodeFormat.pdf417,
      BarcodeFormat.rss14,
      BarcodeFormat.rssExpanded,
      BarcodeFormat.upcEanExtension,
    ]) {
      expect(() => MultiFormatWriter().encode('123', format, 100, 100),
          throwsArgumentError);
    }
  });
}
