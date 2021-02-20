import 'version.dart';

/// <p>See ISO 18004:2006, 6.4.1, Tables 2 and 3. This enum encapsulates the various modes in which
/// data can be encoded to bits in the QR code standard.</p>
///
/// @author Sean Owen
class Mode {
  static const terminator = Mode._([0, 0, 0], 0x00); // Not really a mode...
  static const numeric = Mode._([10, 12, 14], 0x01);
  static const alphanumeric = Mode._([9, 11, 13], 0x02);
  static const structuredAppend = Mode._([0, 0, 0], 0x03); // Not supported
  static const byte = Mode._([8, 16, 16], 0x04);
  static const eci = Mode._([0, 0, 0], 0x07); // character counts don't apply
  static const kanji = Mode._([8, 10, 12], 0x08);
  static const fnc1FirstPosition = Mode._([0, 0, 0], 0x05);
  static const fnc1SecondPosition = Mode._([0, 0, 0], 0x09);

  /// See GBT 18284-2000; "Hanzi" is a transliteration of this mode name.
  static const hanzi = Mode._([8, 10, 12], 0x0D);

  final List<int> _characterCountBitsForVersions;
  final int bits;

  const Mode._(this._characterCountBitsForVersions, this.bits);

  /// @param bits four bits encoding a QR Code data mode
  /// @return Mode encoded by these bits
  /// @throws IllegalArgumentException if bits do not correspond to a known mode
  static Mode forBits(int bits) {
    switch (bits) {
      case 0x0:
        return terminator;
      case 0x1:
        return numeric;
      case 0x2:
        return alphanumeric;
      case 0x3:
        return structuredAppend;
      case 0x4:
        return byte;
      case 0x5:
        return fnc1FirstPosition;
      case 0x7:
        return eci;
      case 0x8:
        return kanji;
      case 0x9:
        return fnc1SecondPosition;
      case 0xD:
        // 0xD is defined in GBT 18284-2000, may not be supported in foreign country
        return hanzi;
      default:
        throw ArgumentError();
    }
  }

  /// @param version version in question
  /// @return number of bits used, in this QR Code symbol {@link Version}, to encode the
  ///         count of characters that will follow encoded in this Mode
  int getCharacterCountBits(Version version) {
    var number = version.versionNumber;
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
