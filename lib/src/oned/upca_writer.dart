import '../barcode_format.dart';
import '../common/bit_matrix.dart';
import '../encode_hint.dart';
import '../writer.dart';
import 'ean13_writer.dart';

/// This object renders a UPC-A code as a {@link BitMatrix}.
///
/// @author qwandor@google.com (Andrew Walbran)
class UPCAWriter implements Writer {
  final _subWriter = EAN13Writer();

  @override
  BitMatrix encode(String contents, BarcodeFormat format, int width, int height,
      {EncodeHints? hints}) {
    if (format != BarcodeFormat.upcA) {
      throw ArgumentError('Can only encode UPC-A, but got $format');
    }
    // Transform a UPC-A code into the equivalent EAN-13 code and write it that way
    return _subWriter.encode('0$contents', BarcodeFormat.ean13, width, height,
        hints: hints);
  }
}
