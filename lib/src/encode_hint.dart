import 'common/character_set_eci.dart';

/// These are a set of hints that you may pass to Writers to specify their behavior.
///
/// @author dswitkin@google.com (Daniel Switkin)
class EncodeHintType<T> {
  /// Specifies what degree of error correction to use, for example in QR Codes.
  /// Type depends on the encoder. For example for QR codes it's type
  /// {@link com.google.zxing.qrcode.decoder.ErrorCorrectionLevel ErrorCorrectionLevel}.
  /// For Aztec it is of type {@link Integer}, representing the minimal percentage of error correction words.
  /// For PDF417 it is of type {@link Integer}, valid values being 0 to 8.
  /// In all cases, it can also be a {@link String} representation of the desired value as well.
  /// Note: an Aztec symbol should have a minimum of 25% EC words.
  static final errorCorrection = EncodeHintType<Object>();

  /// Specifies what character encoding to use where applicable (type {@link String})
  static final characterSet = EncodeHintType<CharacterSetECI>();

  /// Specifies the matrix shape for Data Matrix (type {@link com.google.zxing.datamatrix.encoder.SymbolShapeHint})
  //static final DATA_MATRIX_SHAPE = EncodeHintType<SymbolShapeHint>();

  /// Specifies margin, in pixels, to use when generating the barcode. The meaning can vary
  /// by format; for example it controls margin before and after the barcode horizontally for
  /// most 1D formats. (Type {@link Integer}, or {@link String} representation of the integer value).
  static final margin = EncodeHintType<Object>();

  /// Specifies whether to use compact mode for PDF417 (type {@link Boolean}, or "true" or "false"
  /// {@link String} value).
  static final pdf417Compact = EncodeHintType<Object>();

  /// Specifies what compaction mode to use for PDF417 (type
  /// {@link com.google.zxing.pdf417.encoder.Compaction Compaction} or {@link String} value of one of its
  /// enum values).
  static final pdf417Compaction = EncodeHintType<Object>();

/// Specifies the minimum and maximum number of rows and columns for PDF417 (type
  /// {@link com.google.zxing.pdf417.encoder.Dimensions Dimensions}).
  //static final PDF417_DIMENSIONS = EncodeHintType<Dimensions>();

  /// Specifies the required number of layers for an Aztec code.
  /// A negative number (-1, -2, -3, -4) specifies a compact Aztec code.
  /// 0 indicates to use the minimum number of layers (the default).
  /// A positive number (1, 2, .. 32) specifies a normal (non-compact) Aztec code.
  /// (Type {@link Integer}, or {@link String} representation of the integer value).
  static final aztecLayers = EncodeHintType<Object>();

  /// Specifies the exact version of QR code to be encoded.
  /// (Type {@link Integer}, or {@link String} representation of the integer value).
  static final qrVersion = EncodeHintType<int>();

  /// Specifies the QR code mask pattern to be used. Allowed values are
  /// 0..QRCode.NUM_MASK_PATTERNS-1. By default the code will automatically select
  /// the optimal mask pattern.
  /// * (Type {@link Integer}, or {@link String} representation of the integer value).
  static final qrMaskPattern = EncodeHintType<int>();

  /// Specifies whether the data should be encoded to the GS1 standard (type {@link Boolean}, or "true" or "false"
  /// {@link String } value).
  static final gs1Format = EncodeHintType<bool>();
}

class EncodeHints {
  final _hints = <EncodeHintType, Object?>{};

  void put<T>(EncodeHintType<T> type, [T? value]) {
    _hints[type] = value;
  }

  T? get<T>(EncodeHintType<T> type) {
    return _hints[type] as T?;
  }

  bool contains(EncodeHintType type) {
    return _hints.containsKey(type);
  }
}
