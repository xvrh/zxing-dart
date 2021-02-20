import 'version.dart';

/// <p>See ISO 18004:2006, 6.4.1, Tables 2 and 3. This enum encapsulates the various modes in which
/// data can be encoded to bits in the QR code standard.</p>
///
/// @author Sean Owen
class Mode {
  static const TERMINATOR = Mode._([0, 0, 0], 0x00); // Not really a mode...
  static const NUMERIC = Mode._([10, 12, 14], 0x01);
  static const ALPHANUMERIC = Mode._([9, 11, 13], 0x02);
  static const STRUCTURED_APPEND = Mode._([0, 0, 0], 0x03); // Not supported
  static const BYTE = Mode._([8, 16, 16], 0x04);
  static const ECI = Mode._([0, 0, 0], 0x07); // character counts don't apply
  static const KANJI = Mode._([8, 10, 12], 0x08);
  static const FNC1_FIRST_POSITION = Mode._([0, 0, 0], 0x05);
  static const FNC1_SECOND_POSITION = Mode._([0, 0, 0], 0x09);

  /// See GBT 18284-2000; "Hanzi" is a transliteration of this mode name.
  static const HANZI = Mode._([8, 10, 12], 0x0D);

  final List<int> _characterCountBitsForVersions;
  final int bits;

  const Mode._(this._characterCountBitsForVersions, this.bits);

  /// @param bits four bits encoding a QR Code data mode
  /// @return Mode encoded by these bits
  /// @throws IllegalArgumentException if bits do not correspond to a known mode
  static Mode forBits(int bits) {
    switch (bits) {
      case 0x0:
        return TERMINATOR;
      case 0x1:
        return NUMERIC;
      case 0x2:
        return ALPHANUMERIC;
      case 0x3:
        return STRUCTURED_APPEND;
      case 0x4:
        return BYTE;
      case 0x5:
        return FNC1_FIRST_POSITION;
      case 0x7:
        return ECI;
      case 0x8:
        return KANJI;
      case 0x9:
        return FNC1_SECOND_POSITION;
      case 0xD:
        // 0xD is defined in GBT 18284-2000, may not be supported in foreign country
        return HANZI;
      default:
        throw ArgumentError();
    }
  }

  /// @param version version in question
  /// @return number of bits used, in this QR Code symbol {@link Version}, to encode the
  ///         count of characters that will follow encoded in this Mode
  int getCharacterCountBits(Version version) {
    int number = version.versionNumber;
    int offset;
    if (number <= 9) {
      offset = 0;
    } else if (number <= 26) {
      offset = 1;
    } else {
      offset = 2;
    }
    return _characterCountBitsForVersions[offset];
  }
}
