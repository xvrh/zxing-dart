import 'barcode_format.dart';
import 'result_point_callback.dart';

/// Encapsulates a type of hint that a caller may pass to a barcode reader to help it
/// more quickly or accurately decode it. It is up to implementations to decide what,
/// if anything, to do with the information that is supplied.
///
/// @author Sean Owen
/// @author dswitkin@google.com (Daniel Switkin)
/// @see Reader#decode(BinaryBitmap,java.util.Map)
class DecodeHintType<T> {
  /// Unspecified, application-specific hint. Maps to an unspecified {@link Object}.
  static final OTHER = DecodeHintType<Object>();

  /// Image is a pure monochrome image of a barcode. Doesn't matter what it maps to;
  /// use {@link Boolean#TRUE}.
  static final PURE_BARCODE = DecodeHintType<void>();

  /// Image is known to be of one of a few possible formats.
  /// Maps to a {@link List} of {@link BarcodeFormat}s.
  static final POSSIBLE_FORMATS = DecodeHintType<List<BarcodeFormat>>();

  /// Spend more time to try to find a barcode; optimize for accuracy, not speed.
  /// Doesn't matter what it maps to; use {@link Boolean#TRUE}.
  static final TRY_HARDER = DecodeHintType<void>();

  /// Specifies what character encoding to use when decoding, where applicable (type String)
  static final CHARACTER_SET = DecodeHintType<String>();

  /// Allowed lengths of encoded data -- reject anything else. Maps to an {@code int[]}.
  static final ALLOWED_LENGTHS = DecodeHintType<List<int>>();

  /// Assume Code 39 codes employ a check digit. Doesn't matter what it maps to;
  /// use {@link Boolean#TRUE}.
  static final ASSUME_CODE_39_CHECK_DIGIT = DecodeHintType<void>();

  /// Assume the barcode is being processed as a GS1 barcode, and modify behavior as needed.
  /// For example this affects FNC1 handling for Code 128 (aka GS1-128). Doesn't matter what it maps to;
  /// use {@link Boolean#TRUE}.
  static final ASSUME_GS1 = DecodeHintType<void>();

  /// If true, return the start and end digits in a Codabar barcode instead of stripping them. They
  /// are alpha, whereas the rest are numeric. By default, they are stripped, but this causes them
  /// to not be. Doesn't matter what it maps to; use {@link Boolean#TRUE}.
  static final RETURN_CODABAR_START_END = DecodeHintType<void>();

  /// The caller needs to be notified via callback when a possible {@link ResultPoint}
  /// is found. Maps to a {@link ResultPointCallback}.
  static final NEED_RESULT_POINT_CALLBACK =
      DecodeHintType<ResultPointCallback>();

  /// Allowed extension lengths for EAN or UPC barcodes. Other formats will ignore this.
  /// Maps to an {@code int[]} of the allowed extension lengths, for example [2], [5], or [2, 5].
  /// If it is optional to have an extension, do not set this hint. If this is set,
  /// and a UPC or EAN barcode is found but an extension is not, then no result will be returned
  /// at all.
  static final ALLOWED_EAN_EXTENSIONS = DecodeHintType<List<int>>();
}

class DecodeHints {
  final _hints = <DecodeHintType, Object?>{};

  void put<T>(DecodeHintType<T> type, [T? value]) {
    _hints[type] = value;
  }

  T? get<T>(DecodeHintType<T> type) {
    return _hints[type] as T?;
  }

  bool contains(DecodeHintType type) {
    return _hints.containsKey(type);
  }
}
