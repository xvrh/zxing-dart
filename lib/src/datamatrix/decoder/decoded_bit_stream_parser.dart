import 'dart:typed_data';
import '../../common/bit_source.dart';
import '../../common/decoder_result.dart';
import '../../common/eci_string_builder.dart';
import '../../format_reader_exception.dart';

enum _Mode {
  padEncode, // Not really a mode
  asciiEncode,
  c40Encode,
  textEncode,
  ansix12Encode,
  edifactEncode,
  base256Encode,
  eciEncode,
}

/// <p>Data Matrix Codes can encode text as bits in one of several modes, and can use multiple modes
/// in one Data Matrix Code. This class decodes the bits back into text.</p>
///
/// <p>See ISO 16022:2006, 5.2.1 - 5.2.9.2</p>
///
/// @author bbrown@google.com (Brian Brown)
/// @author Sean Owen
class DecodedBitStreamParser {
  /// See ISO 16022:2006, Annex C Table C.1
  /// The C40 Basic Character Set (*'s used for placeholders for the shift values)
  static const _c40BasicSetChars = '*** 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  static const _c40Shift2SetChars = r'''!"#$%&'()*+,-./:;<=>?@[\]^_''';

  /// See ISO 16022:2006, Annex C Table C.2
  /// The Text Basic Character Set (*'s used for placeholders for the shift values)
  static const _textBasicSetChars = '*** 0123456789abcdefghijklmnopqrstuvwxyz';

  // Shift 2 for Text is the same encoding as C40
  static const _textShift2SetChars = _c40Shift2SetChars;

  static const _textShift3SetChars = '`ABCDEFGHIJKLMNOPQRSTUVWXYZ{|}~\x7F';

  DecodedBitStreamParser._();

  static DecoderResult decode(Int8List bytes) {
    var bits = BitSource(bytes);
    var result = ECIStringBuilder();
    var resultTrailer = StringBuffer();
    var byteSegments = <Int8List>[];
    var mode = _Mode.asciiEncode;
    // Could look directly at 'bytes', if we're sure of not having to account for multi byte values
    var fnc1Positions = <int>{};
    int symbologyModifier;
    var isECIencoded = false;
    do {
      if (mode == _Mode.asciiEncode) {
        mode = _decodeAsciiSegment(bits, result, resultTrailer, fnc1Positions);
      } else {
        switch (mode) {
          case _Mode.c40Encode:
            _decodeC40Segment(bits, result, fnc1Positions);
            break;
          case _Mode.textEncode:
            _decodeTextSegment(bits, result, fnc1Positions);
            break;
          case _Mode.ansix12Encode:
            _decodeAnsiX12Segment(bits, result);
            break;
          case _Mode.edifactEncode:
            _decodeEdifactSegment(bits, result);
            break;
          case _Mode.base256Encode:
            _decodeBase256Segment(bits, result, byteSegments);
            break;
          case _Mode.eciEncode:
            _decodeECISegment(bits, result);
            isECIencoded =
                true; // ECI detection only, atm continue decoding as ASCII
            break;
          case _Mode.padEncode:
          case _Mode.asciiEncode:
            throw FormatReaderException();
        }
        mode = _Mode.asciiEncode;
      }
    } while (mode != _Mode.padEncode && bits.available() > 0);
    if (resultTrailer.isNotEmpty) {
      result.appendCharacters(resultTrailer.toString());
    }
    if (isECIencoded) {
      // Examples for this numbers can be found in this documentation of a hardware barcode scanner:
      // https://honeywellaidc.force.com/supportppr/s/article/List-of-barcode-symbology-AIM-Identifiers
      if (fnc1Positions.contains(0) || fnc1Positions.contains(4)) {
        symbologyModifier = 5;
      } else if (fnc1Positions.contains(1) || fnc1Positions.contains(5)) {
        symbologyModifier = 6;
      } else {
        symbologyModifier = 4;
      }
    } else {
      if (fnc1Positions.contains(0) || fnc1Positions.contains(4)) {
        symbologyModifier = 2;
      } else if (fnc1Positions.contains(1) || fnc1Positions.contains(5)) {
        symbologyModifier = 3;
      } else {
        symbologyModifier = 1;
      }
    }

    return DecoderResult(
        rawBytes: bytes,
        text: result.toString(),
        byteSegments: byteSegments.isEmpty ? null : byteSegments,
        ecLevel: null,
        symbologyModifier: symbologyModifier);
  }

  /// See ISO 16022:2006, 5.2.3 and Annex C, Table C.2
  static _Mode _decodeAsciiSegment(BitSource bits, ECIStringBuilder result,
      StringBuffer resultTrailer, Set<int> fnc1positions) {
    var upperShift = false;
    do {
      var oneByte = bits.readBits(8);
      if (oneByte == 0) {
        throw FormatReaderException();
      } else if (oneByte <= 128) {
        // ASCII data (ASCII value + 1)
        if (upperShift) {
          oneByte += 128;
          //upperShift = false;
        }
        result.appendCharCode(oneByte - 1);
        return _Mode.asciiEncode;
      } else if (oneByte == 129) {
        // Pad
        return _Mode.padEncode;
      } else if (oneByte <= 229) {
        // 2-digit data 00-99 (Numeric Value + 130)
        var value = oneByte - 130;
        if (value < 10) {
          // pad with '0' for single digit values
          result.append('0');
        }
        result.append('$value');
      } else {
        switch (oneByte) {
          case 230: // Latch to C40 encodation
            return _Mode.c40Encode;
          case 231: // Latch to Base 256 encodation
            return _Mode.base256Encode;
          case 232: // FNC1
            fnc1positions.add(result.length);
            result.appendCharCode(29); // translate as ASCII 29
            break;
          case 233: // Structured Append
          case 234: // Reader Programming
            // Ignore these symbols for now
            //throw ReaderException.getInstance();
            break;
          case 235: // Upper Shift (shift to Extended ASCII)
            upperShift = true;
            break;
          case 236: // 05 Macro
            result.append('[)>\u001E05\u001D');
            _insertAtStart(resultTrailer, '\u001E\u0004');
            break;
          case 237: // 06 Macro
            result.append('[)>\u001E06\u001D');
            _insertAtStart(resultTrailer, '\u001E\u0004');
            break;
          case 238: // Latch to ANSI X12 encodation
            return _Mode.ansix12Encode;
          case 239: // Latch to Text encodation
            return _Mode.textEncode;
          case 240: // Latch to EDIFACT encodation
            return _Mode.edifactEncode;
          case 241: // ECI Character
            return _Mode.eciEncode;
          default:
            // Not to be used in ASCII encodation
            // but work around encoders that end with 254, latch back to ASCII
            if (oneByte != 254 || bits.available() != 0) {
              throw FormatReaderException();
            }
            break;
        }
      }
    } while (bits.available() > 0);
    return _Mode.asciiEncode;
  }

  static void _insertAtStart(StringBuffer buffer, String value) {
    var current = buffer.toString();
    buffer
      ..clear()
      ..write(value)
      ..write(current);
  }

  /// See ISO 16022:2006, 5.2.5 and Annex C, Table C.1
  static void _decodeC40Segment(
      BitSource bits, ECIStringBuilder result, Set<int> fnc1positions) {
    // Three C40 values are encoded in a 16-bit value as
    // (1600 * C1) + (40 * C2) + C3 + 1
    // TODO(bbrown): The Upper Shift with C40 doesn't work in the 4 value scenario all the time
    var upperShift = false;

    var cValues = Int32List(3);
    var shift = 0;

    do {
      // If there is only one byte left then it will be encoded as ASCII
      if (bits.available() == 8) {
        return;
      }
      var firstByte = bits.readBits(8);
      if (firstByte == 254) {
        // Unlatch codeword
        return;
      }

      _parseTwoBytes(firstByte, bits.readBits(8), cValues);

      for (var i = 0; i < 3; i++) {
        var cValue = cValues[i];
        switch (shift) {
          case 0:
            if (cValue < 3) {
              shift = cValue + 1;
            } else if (cValue < _c40BasicSetChars.length) {
              var c40char = _c40BasicSetChars.codeUnitAt(cValue);
              if (upperShift) {
                result.appendCharCode(c40char + 128);
                upperShift = false;
              } else {
                result.appendCharCode(c40char);
              }
            } else {
              throw FormatReaderException();
            }
            break;
          case 1:
            if (upperShift) {
              result.appendCharCode(cValue + 128);
              upperShift = false;
            } else {
              result.appendCharCode(cValue);
            }
            shift = 0;
            break;
          case 2:
            if (cValue < _c40Shift2SetChars.length) {
              var c40char = _c40Shift2SetChars.codeUnitAt(cValue);
              if (upperShift) {
                result.appendCharCode(c40char + 128);
                upperShift = false;
              } else {
                result.appendCharCode(c40char);
              }
            } else {
              switch (cValue) {
                case 27: // FNC1
                  fnc1positions.add(result.length);
                  result.appendCharCode(29); // translate as ASCII 29
                  break;
                case 30: // Upper Shift
                  upperShift = true;
                  break;
                default:
                  throw FormatReaderException();
              }
            }
            shift = 0;
            break;
          case 3:
            if (upperShift) {
              result.appendCharCode(cValue + 224);
              upperShift = false;
            } else {
              result.appendCharCode(cValue + 96);
            }
            shift = 0;
            break;
          default:
            throw FormatReaderException();
        }
      }
    } while (bits.available() > 0);
  }

  /// See ISO 16022:2006, 5.2.6 and Annex C, Table C.2
  static void _decodeTextSegment(
      BitSource bits, ECIStringBuilder result, Set<int> fnc1positions) {
    // Three Text values are encoded in a 16-bit value as
    // (1600 * C1) + (40 * C2) + C3 + 1
    // TODO(bbrown): The Upper Shift with Text doesn't work in the 4 value scenario all the time
    var upperShift = false;

    var cValues = Int32List(3);
    var shift = 0;
    do {
      // If there is only one byte left then it will be encoded as ASCII
      if (bits.available() == 8) {
        return;
      }
      var firstByte = bits.readBits(8);
      if (firstByte == 254) {
        // Unlatch codeword
        return;
      }

      _parseTwoBytes(firstByte, bits.readBits(8), cValues);

      for (var i = 0; i < 3; i++) {
        var cValue = cValues[i];
        switch (shift) {
          case 0:
            if (cValue < 3) {
              shift = cValue + 1;
            } else if (cValue < _textBasicSetChars.length) {
              var textChar = _textBasicSetChars.codeUnitAt(cValue);
              if (upperShift) {
                result.appendCharCode(textChar + 128);
                upperShift = false;
              } else {
                result.appendCharCode(textChar);
              }
            } else {
              throw FormatReaderException();
            }
            break;
          case 1:
            if (upperShift) {
              result.appendCharCode(cValue + 128);
              upperShift = false;
            } else {
              result.appendCharCode(cValue);
            }
            shift = 0;
            break;
          case 2:
            // Shift 2 for Text is the same encoding as C40
            if (cValue < _textShift2SetChars.length) {
              var textChar = _textShift2SetChars.codeUnitAt(cValue);
              if (upperShift) {
                result.appendCharCode(textChar + 128);
                upperShift = false;
              } else {
                result.appendCharCode(textChar);
              }
            } else {
              switch (cValue) {
                case 27: // FNC1
                  fnc1positions.add(result.length);
                  result.appendCharCode(29); // translate as ASCII 29
                  break;
                case 30: // Upper Shift
                  upperShift = true;
                  break;
                default:
                  throw FormatReaderException();
              }
            }
            shift = 0;
            break;
          case 3:
            if (cValue < _textShift3SetChars.length) {
              var textChar = _textShift3SetChars.codeUnitAt(cValue);
              if (upperShift) {
                result.appendCharCode(textChar + 128);
                upperShift = false;
              } else {
                result.appendCharCode(textChar);
              }
              shift = 0;
            } else {
              throw FormatReaderException();
            }
            break;
          default:
            throw FormatReaderException();
        }
      }
    } while (bits.available() > 0);
  }

  /// See ISO 16022:2006, 5.2.7
  static void _decodeAnsiX12Segment(BitSource bits, ECIStringBuilder result) {
    // Three ANSI X12 values are encoded in a 16-bit value as
    // (1600 * C1) + (40 * C2) + C3 + 1

    var cValues = Int32List(3);
    do {
      // If there is only one byte left then it will be encoded as ASCII
      if (bits.available() == 8) {
        return;
      }
      var firstByte = bits.readBits(8);
      if (firstByte == 254) {
        // Unlatch codeword
        return;
      }

      _parseTwoBytes(firstByte, bits.readBits(8), cValues);

      for (var i = 0; i < 3; i++) {
        var cValue = cValues[i];
        switch (cValue) {
          case 0: // X12 segment terminator <CR>
            result.append('\r');
            break;
          case 1: // X12 segment separator *
            result.append('*');
            break;
          case 2: // X12 sub-element separator >
            result.append('>');
            break;
          case 3: // space
            result.append(' ');
            break;
          default:
            if (cValue < 14) {
              // 0 - 9
              result.appendCharCode(cValue + 44);
            } else if (cValue < 40) {
              // A - Z
              result.appendCharCode(cValue + 51);
            } else {
              throw FormatReaderException();
            }
            break;
        }
      }
    } while (bits.available() > 0);
  }

  static void _parseTwoBytes(int firstByte, int secondByte, Int32List result) {
    var fullBitValue = (firstByte << 8) + secondByte - 1;
    var temp = fullBitValue ~/ 1600;
    result[0] = temp;
    fullBitValue -= temp * 1600;
    temp = fullBitValue ~/ 40;
    result[1] = temp;
    result[2] = fullBitValue - temp * 40;
  }

  /// See ISO 16022:2006, 5.2.8 and Annex C Table C.3
  static void _decodeEdifactSegment(BitSource bits, ECIStringBuilder result) {
    do {
      // If there is only two or less bytes left then it will be encoded as ASCII
      if (bits.available() <= 16) {
        return;
      }

      for (var i = 0; i < 4; i++) {
        var edifactValue = bits.readBits(6);

        // Check for the unlatch character
        if (edifactValue == 0x1F) {
          // 011111
          // Read rest of byte, which should be 0, and stop
          var bitsLeft = 8 - bits.bitOffset;
          if (bitsLeft != 8) {
            bits.readBits(bitsLeft);
          }
          return;
        }

        if ((edifactValue & 0x20) == 0) {
          // no 1 in the leading (6th) bit
          edifactValue |= 0x40; // Add a leading 01 to the 6 bit binary value
        }
        result.appendCharCode(edifactValue);
      }
    } while (bits.available() > 0);
  }

  /// See ISO 16022:2006, 5.2.9 and Annex B, B.2
  static void _decodeBase256Segment(
      BitSource bits, ECIStringBuilder result, List<Int8List> byteSegments) {
    // Figure out how long the Base 256 Segment is.
    var codewordPosition = 1 + bits.byteOffset; // position is 1-indexed
    var d1 = _unrandomize255State(bits.readBits(8), codewordPosition++);
    int count;
    if (d1 == 0) {
      // Read the remainder of the symbol
      count = bits.available() ~/ 8;
    } else if (d1 < 250) {
      count = d1;
    } else {
      count = 250 * (d1 - 249) +
          _unrandomize255State(bits.readBits(8), codewordPosition++);
    }

    // We're seeing NegativeArraySizeException errors from users.
    if (count < 0) {
      throw FormatReaderException();
    }

    var bytes = Uint8List(count);
    for (var i = 0; i < count; i++) {
      // Have seen this particular error in the wild, such as at
      // http://www.bcgen.com/demo/IDAutomationStreamingDataMatrix.aspx?MODE=3&D=Fred&PFMT=3&PT=F&X=0.3&O=0&LM=0.2
      if (bits.available() < 8) {
        throw FormatReaderException();
      }
      bytes[i] = _unrandomize255State(bits.readBits(8), codewordPosition++);
    }
    byteSegments.add(Int8List.sublistView(bytes));
    result.append(String.fromCharCodes(bytes));
  }

  /// See ISO 16022:2007, 5.4.1
  static void _decodeECISegment(BitSource bits, ECIStringBuilder result) {
    if (bits.available() < 8) {
      throw FormatReaderException();
    }
    var c1 = bits.readBits(8);
    if (c1 <= 127) {
      result.appendECI(c1 - 1);
    }
    //currently we only support character set ECIs
    /*} else {
      if (bits.available() < 8) {
        throw FormatReaderException();
      }
      int c2 = bits.readBits(8);
      if (c1 >= 128 && c1 <= 191) {
      } else {
        if (bits.available() < 8) {
          throw FormatReaderException();
        }
        int c3 = bits.readBits(8);
      }
    }*/
  }

  /// See ISO 16022:2006, Annex B, B.2
  static int _unrandomize255State(
      int randomizedBase256Codeword, int base256CodewordPosition) {
    var pseudoRandomNumber = ((149 * base256CodewordPosition) % 255) + 1;
    var tempVariable = randomizedBase256Codeword - pseudoRandomNumber;
    return tempVariable >= 0 ? tempVariable : tempVariable + 256;
  }
}
