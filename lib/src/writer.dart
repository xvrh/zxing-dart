import 'barcode_format.dart';
import 'common/bit_matrix.dart';
import 'encode_hint.dart';

/// The base class for all objects which encode/generate a barcode image.
///
/// @author dswitkin@google.com (Daniel Switkin)
abstract class Writer {
  /// @param contents The contents to encode in the barcode
  /// @param format The barcode format to generate
  /// @param width The preferred width in pixels
  /// @param height The preferred height in pixels
  /// @param hints Additional parameters to supply to the encoder
  /// @return {@link BitMatrix} representing encoded barcode image
  /// @throws WriterException if contents cannot be encoded legally in a format
  BitMatrix encode(String contents, BarcodeFormat format, int width, int height,
      {EncodeHints? hints});
}
