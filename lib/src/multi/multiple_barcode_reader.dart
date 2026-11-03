import '../binary_bitmap.dart';
import '../decode_hint.dart';
import '../result.dart';

/// Implementation of this interface attempt to read several barcodes from one image.
///
/// @see Reader
/// @author Sean Owen
abstract class MultipleBarcodeReader {
  List<Result> decodeMultiple(BinaryBitmap image, {DecodeHints? hints});
}
