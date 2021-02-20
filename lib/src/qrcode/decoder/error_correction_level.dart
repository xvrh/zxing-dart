/// <p>See ISO 18004:2006, 6.5.1. This enum encapsulates the four error correction levels
/// defined by the QR code standard.</p>
///
/// @author Sean Owen
class ErrorCorrectionLevel {
  /// L = ~7% correction
  static final L = ErrorCorrectionLevel._(0, 0x01, 'L');

  /// M = ~15% correction
  static final M = ErrorCorrectionLevel._(1, 0x00, 'M');

  /// Q = ~25% correction
  static final Q = ErrorCorrectionLevel._(2, 0x03, 'Q');

  /// H = ~30% correction
  static final H = ErrorCorrectionLevel._(3, 0x02, 'H');

  static final FOR_BITS = [M, L, H, Q];

  final int ordinal;
  final int bits;
  final String name;

  ErrorCorrectionLevel._(this.ordinal, this.bits, this.name);

  /// @param bits int containing the two bits encoding a QR Code's error correction level
  /// @return ErrorCorrectionLevel representing the encoded error correction level
  static ErrorCorrectionLevel forBits(int bits) {
    if (bits < 0 || bits >= FOR_BITS.length) {
      throw ArgumentError();
    }
    return FOR_BITS[bits];
  }

  String toString() => 'ErrorCorrectionLevel.$name';
}
