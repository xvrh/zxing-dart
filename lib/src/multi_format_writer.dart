import 'barcode_format.dart';
import 'common/bit_matrix.dart';
import 'encode_hint.dart';
import 'oned/coda_bar_writer.dart';
import 'oned/code128_writer.dart';
import 'oned/code39_writer.dart';
import 'oned/code93_writer.dart';
import 'oned/ean13_writer.dart';
import 'oned/ean8_writer.dart';
import 'oned/itf_writer.dart';
import 'oned/upca_writer.dart';
import 'oned/upce_writer.dart';
import 'qrcode/qrcode_writer.dart';
import 'writer.dart';

/// This is a factory class which finds the appropriate Writer subclass for the BarcodeFormat
/// requested and encodes the barcode with the supplied contents.
///
/// @author dswitkin@google.com (Daniel Switkin)
class MultiFormatWriter implements Writer {
  @override
  BitMatrix encode(String contents, BarcodeFormat format, int width, int height,
      {EncodeHints? hints}) {
    Writer writer;
    switch (format) {
      case BarcodeFormat.ean8:
        writer = EAN8Writer();
        break;
      case BarcodeFormat.upcE:
        writer = UPCEWriter();
        break;
      case BarcodeFormat.ean13:
        writer = EAN13Writer();
        break;
      case BarcodeFormat.upcA:
        writer = UPCAWriter();
        break;
      case BarcodeFormat.qrCode:
        writer = QRCodeWriter();
        break;
      case BarcodeFormat.code39:
        writer = Code39Writer();
        break;
      case BarcodeFormat.code93:
        writer = Code93Writer();
        break;
      case BarcodeFormat.code128:
        writer = Code128Writer();
        break;
      case BarcodeFormat.itf:
        writer = ITFWriter();
        break;
      case BarcodeFormat.codabar:
        writer = CodaBarWriter();
        break;
      case BarcodeFormat.aztec:
      case BarcodeFormat.dataMatrix:
      case BarcodeFormat.maxicode:
      case BarcodeFormat.pdf417:
      case BarcodeFormat.rss14:
      case BarcodeFormat.rssExpanded:
      case BarcodeFormat.upcEanExtension:
        throw ArgumentError('No encoder available for format $format');
    }
    return writer.encode(contents, format, width, height, hints: hints);
  }
}
