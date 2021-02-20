import 'dart:convert';
import 'dart:typed_data';
import '../../common/bit_source.dart';
import '../../common/character_set_eci.dart';
import '../../common/decoder_result.dart';
import '../../common/string_utils.dart';
import '../../decode_hint.dart';
import '../../format_reader_exception.dart';
import 'error_correction_level.dart';
import 'mode.dart';
import 'version.dart';

/// <p>QR Codes can encode text as bits in one of several modes, and can use multiple modes
/// in one QR Code. This class decodes the bits back into text.</p>
///
/// <p>See ISO 18004:2006, 6.4.3 - 6.4.7</p>
///
/// @author Sean Owen
class DecodedBitStreamParser {
  /// See ISO 18004:2006, 6.4.4 Table 5
  static final List<String> _alphanumericChars =
      r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:'.split('');
  static final int _gb2312Subset = 1;

  DecodedBitStreamParser._();

  static DecoderResult decode(Int8List bytes, Version version,
      ErrorCorrectionLevel? ecLevel, DecodeHints hints) {
    var bits = BitSource(bytes);
    var result = StringBuffer();
    var byteSegments = <Int8List>[];
    var symbolSequence = -1;
    var parityData = -1;

    try {
      CharacterSetECI? currentCharacterSetECI;
      var fc1InEffect = false;
      Mode mode;
      do {
        // While still another segment to read...
        if (bits.available() < 4) {
          // OK, assume we're done. Really, a TERMINATOR mode should have been recorded here
          mode = Mode.terminator;
        } else {
          mode = Mode.forBits(bits.readBits(4)); // mode is encoded by 4 bits
        }
        switch (mode) {
          case Mode.terminator:
            break;
          case Mode.fnc1FirstPosition:
          case Mode.fnc1SecondPosition:
            // We do little with FNC1 except alter the parsed result a bit according to the spec
            fc1InEffect = true;
            break;
          case Mode.structuredAppend:
            if (bits.available() < 16) {
              throw FormatReaderException();
            }
            // sequence number and parity is added later to the result metadata
            // Read next 8 bits (symbol sequence #) and 8 bits (parity data), then continue
            symbolSequence = bits.readBits(8);
            parityData = bits.readBits(8);
            break;
          case Mode.eci:
            // Count doesn't apply to ECI
            var value = _parseECIValue(bits);
            currentCharacterSetECI =
                CharacterSetECI.getCharacterSetECIByValue(value);
            if (currentCharacterSetECI == null) {
              throw FormatReaderException();
            }
            break;
          case Mode.hanzi:
            // First handle Hanzi mode which does not start with character count
            // Chinese mode contains a sub set indicator right after mode indicator
            var subset = bits.readBits(4);
            var countHanzi = bits.readBits(mode.getCharacterCountBits(version));
            if (subset == _gb2312Subset) {
              _decodeHanziSegment(bits, result, countHanzi);
            }
            break;
          default:
            // "Normal" QR code modes:
            // How many characters will follow, encoded in this mode?
            var count = bits.readBits(mode.getCharacterCountBits(version));
            switch (mode) {
              case Mode.numeric:
                _decodeNumericSegment(bits, result, count);
                break;
              case Mode.alphanumeric:
                _decodeAlphanumericSegment(bits, result, count, fc1InEffect);
                break;
              case Mode.byte:
                _decodeByteSegment(bits, result, count, currentCharacterSetECI,
                    byteSegments, hints);
                break;
              case Mode.kanji:
                _decodeKanjiSegment(bits, result, count);
                break;
              default:
                throw FormatReaderException();
            }
            break;
        }
      } while (mode != Mode.terminator);
    } on ArgumentError catch (_) {
      // from readBits() calls
      throw FormatReaderException();
    }

    return DecoderResult(
        rawBytes: bytes,
        text: result.toString(),
        byteSegments: byteSegments.isEmpty ? null : byteSegments,
        ecLevel: ecLevel?.toString(),
        structuredAppendParity: symbolSequence,
        structuredAppendSequenceNumber: parityData);
  }

  /// See specification GBT 18284-2000
  static void _decodeHanziSegment(
      BitSource bits, StringBuffer result, int count) {
    // Don't crash trying to read more bits than we have available.
    if (count * 13 > bits.available()) {
      throw FormatReaderException();
    }

    // Each character will require 2 bytes. Read the characters as 2-byte pairs
    // and decode as GB2312 afterwards
    var buffer = Int8List(2 * count);
    var offset = 0;
    while (count > 0) {
      // Each 13 bits encodes a 2-byte character
      var twoBytes = bits.readBits(13);
      var assembledTwoBytes = ((twoBytes ~/ 0x060) << 8) | (twoBytes % 0x060);
      if (assembledTwoBytes < 0x00A00) {
        // In the 0xA1A1 to 0xAAFE range
        assembledTwoBytes += 0x0A1A1;
      } else {
        // In the 0xB0A1 to 0xFAFE range
        assembledTwoBytes += 0x0A6A1;
      }
      buffer[offset] = (assembledTwoBytes >> 8) & 0xFF;
      buffer[offset + 1] = assembledTwoBytes & 0xFF;
      offset += 2;
      count--;
    }

    result.write(CharacterSetECI.GB18030.encoding.decode(buffer));
  }

  static void _decodeKanjiSegment(
      BitSource bits, StringBuffer result, int count) {
    // Don't crash trying to read more bits than we have available.
    if (count * 13 > bits.available()) {
      throw FormatReaderException();
    }

    // Each character will require 2 bytes. Read the characters as 2-byte pairs
    // and decode as Shift_JIS afterwards
    var buffer = Int8List(2 * count);
    var offset = 0;
    while (count > 0) {
      // Each 13 bits encodes a 2-byte character
      var twoBytes = bits.readBits(13);
      var assembledTwoBytes = ((twoBytes ~/ 0x0C0) << 8) | (twoBytes % 0x0C0);
      if (assembledTwoBytes < 0x01F00) {
        // In the 0x8140 to 0x9FFC range
        assembledTwoBytes += 0x08140;
      } else {
        // In the 0xE040 to 0xEBBF range
        assembledTwoBytes += 0x0C140;
      }
      buffer[offset] = assembledTwoBytes >> 8;
      buffer[offset + 1] = assembledTwoBytes;
      offset += 2;
      count--;
    }
    result.write(CharacterSetECI.SJIS.encoding.decode(buffer));
  }

  static void _decodeByteSegment(
      BitSource bits,
      StringBuffer result,
      int count,
      CharacterSetECI? currentCharacterSetECI,
      List<Int8List> byteSegments,
      DecodeHints hints) {
    // Don't crash trying to read more bits than we have available.
    if (8 * count > bits.available()) {
      throw FormatReaderException();
    }

    var readBytes = Int8List(count);
    for (var i = 0; i < count; i++) {
      readBytes[i] = bits.readBits(8);
    }
    Encoding encoding;
    if (currentCharacterSetECI == null) {
      // The spec isn't clear on this mode; see
      // section 6.4.5: t does not say which encoding to assuming
      // upon decoding. I have seen ISO-8859-1 used as well as
      // Shift_JIS -- without anything like an ECI designator to
      // give a hint.
      encoding = StringUtils.guessCharset(readBytes, hints).encoding;
    } else {
      encoding = currentCharacterSetECI.encoding;
    }
    result.write(encoding.decode(readBytes));
    byteSegments.add(readBytes);
  }

  static String _toAlphaNumericChar(int value) {
    if (value >= _alphanumericChars.length) {
      throw FormatReaderException();
    }
    return _alphanumericChars[value];
  }

  static void _decodeAlphanumericSegment(
      BitSource bits, StringBuffer result, int count, bool fc1InEffect) {
    // Read two characters at a time
    //int start = result.length;
    while (count > 1) {
      if (bits.available() < 11) {
        throw FormatReaderException();
      }
      var nextTwoCharsBits = bits.readBits(11);
      result.write(_toAlphaNumericChar(nextTwoCharsBits ~/ 45));
      result.write(_toAlphaNumericChar(nextTwoCharsBits % 45));
      count -= 2;
    }
    if (count == 1) {
      // special case: one character left
      if (bits.available() < 6) {
        throw FormatReaderException();
      }
      result.write(_toAlphaNumericChar(bits.readBits(6)));
    }
    // See section 6.4.8.1, 6.4.8.2
    if (fc1InEffect) {
      assert(false);
      //TODO(xha): this need to use a custom implementation of StringBuffer to
      // support changing a previous character
      // We need to massage the result a bit if in an FNC1 mode:
      //for (int i = start; i < result.length; i++) {
      //  if (result.charAt(i) == '%') {
      //    if (i < result.length - 1 && result.charAt(i + 1) == '%') {
      //      // %% is rendered as %
      //      result.deleteCharAt(i + 1);
      //    } else {
      //      // In alpha mode, % should be converted to FNC1 separator 0x1D
      //      result.setCharAt(i, (char) 0x1D);
      //    }
      //  }
      //}
    }
  }

  static void _decodeNumericSegment(
      BitSource bits, StringBuffer result, int count) {
    // Read three digits at a time
    while (count >= 3) {
      // Each 10 bits encodes three digits
      if (bits.available() < 10) {
        throw FormatReaderException();
      }
      var threeDigitsBits = bits.readBits(10);
      if (threeDigitsBits >= 1000) {
        throw FormatReaderException();
      }
      result.write(_toAlphaNumericChar(threeDigitsBits ~/ 100));
      result.write(_toAlphaNumericChar((threeDigitsBits ~/ 10) % 10));
      result.write(_toAlphaNumericChar(threeDigitsBits % 10));
      count -= 3;
    }
    if (count == 2) {
      // Two digits left over to read, encoded in 7 bits
      if (bits.available() < 7) {
        throw FormatReaderException();
      }
      var twoDigitsBits = bits.readBits(7);
      if (twoDigitsBits >= 100) {
        throw FormatReaderException();
      }
      result.write(_toAlphaNumericChar(twoDigitsBits ~/ 10));
      result.write(_toAlphaNumericChar(twoDigitsBits % 10));
    } else if (count == 1) {
      // One digit left over to read
      if (bits.available() < 4) {
        throw FormatReaderException();
      }
      var digitBits = bits.readBits(4);
      if (digitBits >= 10) {
        throw FormatReaderException();
      }
      result.write(_toAlphaNumericChar(digitBits));
    }
  }

  static int _parseECIValue(BitSource bits) {
    var firstByte = bits.readBits(8);
    if ((firstByte & 0x80) == 0) {
      // just one byte
      return firstByte & 0x7F;
    }
    if ((firstByte & 0xC0) == 0x80) {
      // two bytes
      var secondByte = bits.readBits(8);
      return ((firstByte & 0x3F) << 8) | secondByte;
    }
    if ((firstByte & 0xE0) == 0xC0) {
      // three bytes
      var secondThirdBytes = bits.readBits(16);
      return ((firstByte & 0x1F) << 16) | secondThirdBytes;
    }
    throw FormatReaderException();
  }
}
