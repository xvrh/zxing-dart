import 'dart:typed_data';
import '../barcode_format.dart';
import '../checksum_exception.dart';
import '../common/bit_array.dart';
import '../decode_hint.dart';
import '../format_reader_exception.dart';
import '../not_found_exception.dart';
import '../result.dart';
import '../result_metadata_type.dart';
import '../result_point.dart';
import 'one_d_reader.dart';

/// <p>Decodes Code 93 barcodes.</p>
///
/// @author Sean Owen
/// @see Code39Reader
class Code93Reader extends OneDReader {
  // Note that 'abcd' are dummy characters in place of control characters.
  static const String alphabetString =
      r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%abcd*';

  /// These represent the encodings of characters, as patterns of wide and narrow bars.
  /// The 9 least-significant bits of each int correspond to the pattern of wide and narrow.
  static const List<int> characterEncodings = [
    0x114, 0x148, 0x144, 0x142, 0x128, 0x124, 0x122, 0x150, 0x112, 0x10A, // 0-9
    0x1A8, 0x1A4, 0x1A2, 0x194, 0x192, 0x18A, 0x168, 0x164, 0x162, 0x134, // A-J
    0x11A, 0x158, 0x14C, 0x146, 0x12C, 0x116, 0x1B4, 0x1B2, 0x1AC, 0x1A6, // K-T
    0x196, 0x19A, 0x16C, 0x166, 0x136, 0x13A, // U-Z
    0x12E, 0x1D4, 0x1D2, 0x1CA, 0x16E, 0x176, 0x1AE, // - - %
    0x126, 0x1DA, 0x1D6, 0x132, 0x15E, // Control chars? $-*
  ];
  static const int asteriskEncoding = 0x15E; // characterEncodings[47]

  final Int32List _counters = Int32List(6);

  @override
  Result decodeRow(int rowNumber, BitArray row, DecodeHints hints) {
    var start = _findAsteriskPattern(row);
    // Read off white space
    var nextStart = row.getNextSet(start[1]);
    var end = row.size;

    var theCounters = _counters;
    theCounters.fillRange(0, theCounters.length, 0);
    var result = StringBuffer();

    int decodedChar;
    int lastStart;
    do {
      OneDReader.recordPattern(row, nextStart, theCounters);
      var pattern = _toPattern(theCounters);
      if (pattern < 0) {
        throw NotFoundException();
      }
      decodedChar = _patternToChar(pattern);
      result.writeCharCode(decodedChar);
      lastStart = nextStart;
      for (var counter in theCounters) {
        nextStart += counter;
      }
      // Read off white space
      nextStart = row.getNextSet(nextStart);
    } while (decodedChar != 0x2A /* '*' */);
    var resultString = result.toString();
    resultString =
        resultString.substring(0, resultString.length - 1); // remove asterisk

    var lastPatternSize = 0;
    for (var counter in theCounters) {
      lastPatternSize += counter;
    }

    // Should be at least one more black module
    if (nextStart == end || !row.get(nextStart)) {
      throw NotFoundException();
    }

    if (resultString.length < 2) {
      // false positive -- need at least 2 checksum digits
      throw NotFoundException();
    }

    _checkChecksums(resultString);
    // Remove checksum digits
    resultString = resultString.substring(0, resultString.length - 2);

    resultString = _decodeExtended(resultString);

    var left = (start[1] + start[0]) / 2.0;
    var right = lastStart + lastPatternSize / 2.0;

    var resultObject =
        Result(resultString, null, BarcodeFormat.code93, points: [
      ResultPoint(left, rowNumber.toDouble()),
      ResultPoint(right, rowNumber.toDouble()),
    ]);
    resultObject.putMetadata(ResultMetadataType.symbologyIdentifier, ']G0');
    return resultObject;
  }

  List<int> _findAsteriskPattern(BitArray row) {
    var width = row.size;
    var rowOffset = row.getNextSet(0);

    _counters.fillRange(0, _counters.length, 0);
    var theCounters = _counters;
    var patternStart = rowOffset;
    var isWhite = false;
    var patternLength = theCounters.length;

    var counterPosition = 0;
    for (var i = rowOffset; i < width; i++) {
      if (row.get(i) != isWhite) {
        theCounters[counterPosition]++;
      } else {
        if (counterPosition == patternLength - 1) {
          if (_toPattern(theCounters) == asteriskEncoding) {
            return [patternStart, i];
          }
          patternStart += theCounters[0] + theCounters[1];
          theCounters.setRange(0, counterPosition - 1, theCounters, 2);
          theCounters[counterPosition - 1] = 0;
          theCounters[counterPosition] = 0;
          counterPosition--;
        } else {
          counterPosition++;
        }
        theCounters[counterPosition] = 1;
        isWhite = !isWhite;
      }
    }
    throw NotFoundException();
  }

  static int _toPattern(List<int> counters) {
    var sum = 0;
    for (var counter in counters) {
      sum += counter;
    }
    var pattern = 0;
    var max = counters.length;
    for (var i = 0; i < max; i++) {
      var scaled = (counters[i] * 9.0 / sum).round();
      if (scaled < 1 || scaled > 4) {
        return -1;
      }
      if ((i & 0x01) == 0) {
        for (var j = 0; j < scaled; j++) {
          pattern = (pattern << 1) | 0x01;
        }
      } else {
        pattern <<= scaled;
      }
    }
    return pattern;
  }

  static int _patternToChar(int pattern) {
    for (var i = 0; i < characterEncodings.length; i++) {
      if (characterEncodings[i] == pattern) {
        return alphabetString.codeUnitAt(i);
      }
    }
    throw NotFoundException();
  }

  static String _decodeExtended(String encoded) {
    var length = encoded.length;
    var decoded = StringBuffer();
    for (var i = 0; i < length; i++) {
      var c = encoded[i];
      if (c == 'a' || c == 'b' || c == 'c' || c == 'd') {
        if (i >= length - 1) {
          throw FormatReaderException();
        }
        var next = encoded.codeUnitAt(i + 1);
        var decodedChar = 0;
        switch (c) {
          case 'd':
            // +A to +Z map to a to z
            if (next >= 0x41 && next <= 0x5A) {
              decodedChar = next + 32;
            } else {
              throw FormatReaderException();
            }
          case 'a':
            // $A to $Z map to control codes SH to SB
            if (next >= 0x41 && next <= 0x5A) {
              decodedChar = next - 64;
            } else {
              throw FormatReaderException();
            }
          case 'b':
            if (next >= 0x41 && next <= 0x45) {
              // %A to %E map to control codes ESC to USep
              decodedChar = next - 38;
            } else if (next >= 0x46 && next <= 0x4A) {
              // %F to %J map to ; < = > ?
              decodedChar = next - 11;
            } else if (next >= 0x4B && next <= 0x4F) {
              // %K to %O map to [ \ ] ^ _
              decodedChar = next + 16;
            } else if (next >= 0x50 && next <= 0x54) {
              // %P to %T map to { | } ~ DEL
              decodedChar = next + 43;
            } else if (next == 0x55 /* U */) {
              // %U map to NUL
              decodedChar = 0;
            } else if (next == 0x56 /* V */) {
              // %V map to @
              decodedChar = 0x40;
            } else if (next == 0x57 /* W */) {
              // %W map to `
              decodedChar = 0x60;
            } else if (next >= 0x58 && next <= 0x5A) {
              // %X to %Z all map to DEL (127)
              decodedChar = 127;
            } else {
              throw FormatReaderException();
            }
          case 'c':
            // /A to /O map to ! to , and /Z maps to :
            if (next >= 0x41 && next <= 0x4F) {
              decodedChar = next - 32;
            } else if (next == 0x5A /* Z */) {
              decodedChar = 0x3A; // ':'
            } else {
              throw FormatReaderException();
            }
        }
        decoded.writeCharCode(decodedChar);
        // bump up i again since we read two characters
        i++;
      } else {
        decoded.write(c);
      }
    }
    return decoded.toString();
  }

  static void _checkChecksums(String result) {
    var length = result.length;
    _checkOneChecksum(result, length - 2, 20);
    _checkOneChecksum(result, length - 1, 15);
  }

  static void _checkOneChecksum(
      String result, int checkPosition, int weightMax) {
    var weight = 1;
    var total = 0;
    for (var i = checkPosition - 1; i >= 0; i--) {
      total += weight * alphabetString.indexOf(result[i]);
      if (++weight > weightMax) {
        weight = 1;
      }
    }
    if (result[checkPosition] != alphabetString[total % 47]) {
      throw ChecksumException('Code 93 checksum failed');
    }
  }
}
