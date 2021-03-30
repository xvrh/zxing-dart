/// <p>See ISO 18004:2006, 6.5.1. This enum encapsulates the four error correction levels
/// defined by the QR code standard.</p>
///
/// @author Sean Owen
class ErrorCorrectionLevel {
  /// L = ~7% correction
  static final l = ErrorCorrectionLevel._(0, 0x01, 'L');

  /// M = ~15% correction
  static final m = ErrorCorrectionLevel._(1, 0x00, 'M');

  /// Q = ~25% correction
  static final q = ErrorCorrectionLevel._(2, 0x03, 'Q');

  /// H = ~30% correction
  static final h = ErrorCorrectionLevel._(3, 0x02, 'H');

  static final _forBits = [m, l, h, q];

  final int ordinal;
  final int bits;
  final String name;

  ErrorCorrectionLevel._(this.ordinal, this.bits, this.name);

  /// @param bits int containing the two bits encoding a QR Code's error correction level
  /// @return ErrorCorrectionLevel representing the encoded error correction level
  static ErrorCorrectionLevel forBits(int bits) {
    if (bits < 0 || bits >= _forBits.length) {
      throw ArgumentError();
    }
    return _forBits[bits];
  }

  @override
  String toString() => '$name';
}
