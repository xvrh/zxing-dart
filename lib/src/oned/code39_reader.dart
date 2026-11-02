import 'dart:math' as math;
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

/// <p>Decodes Code 39 barcodes. Supports "Full ASCII Code 39" if USE_CODE_39_EXTENDED_MODE is set.</p>
///
/// @author Sean Owen
/// @see Code93Reader
class Code39Reader extends OneDReader {
  static const String alphabetString =
      r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%';

  /// These represent the encodings of characters, as patterns of wide and narrow bars.
  /// The 9 least-significant bits of each int correspond to the pattern of wide and narrow,
  /// with 1s representing "wide" and 0s representing narrow.
  static const List<int> characterEncodings = [
    0x034, 0x121, 0x061, 0x160, 0x031, 0x130, 0x070, 0x025, 0x124, 0x064, // 0-9
    0x109, 0x049, 0x148, 0x019, 0x118, 0x058, 0x00D, 0x10C, 0x04C, 0x01C, // A-J
    0x103, 0x043, 0x142, 0x013, 0x112, 0x052, 0x007, 0x106, 0x046, 0x016, // K-T
    0x181, 0x0C1, 0x1C0, 0x091, 0x190, 0x0D0, 0x085, 0x184, 0x0C4, 0x0A8, // U-$
    0x0A2, 0x08A, 0x02A // /-%
  ];

  static const int asteriskEncoding = 0x094;

  final bool _usingCheckDigit;
  final bool _extendedMode;
  final Int32List _counters = Int32List(9);

  /// Creates a reader that can be configured to check the last character as a check digit,
  /// or optionally attempt to decode "extended Code 39" sequences that are used to encode
  /// the full ASCII character set.
  ///
  /// @param usingCheckDigit if true, treat the last data character as a check digit, not
  /// data, and verify that the checksum passes.
  /// @param extendedMode if true, will attempt to decode extended Code 39 sequences in the
  /// text.
  Code39Reader([bool usingCheckDigit = false, bool extendedMode = false])
      : _usingCheckDigit = usingCheckDigit,
        _extendedMode = extendedMode;

  @override
  Result decodeRow(int rowNumber, BitArray row, DecodeHints hints) {
    var theCounters = _counters;
    theCounters.fillRange(0, theCounters.length, 0);
    var result = StringBuffer();

    var start = _findAsteriskPattern(row, theCounters);
    // Read off white space
    var nextStart = row.getNextSet(start[1]);
    var end = row.size;

    int decodedChar;
    int lastStart;
    do {
      OneDReader.recordPattern(row, nextStart, theCounters);
      var pattern = _toNarrowWidePattern(theCounters);
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

    // Look for whitespace after pattern:
    var lastPatternSize = 0;
    for (var counter in theCounters) {
      lastPatternSize += counter;
    }
    var whiteSpaceAfterEnd = nextStart - lastStart - lastPatternSize;
    // If 50% of last pattern size, following last pattern, is not whitespace, fail
    // (but if it's whitespace to the very end of the image, that's OK)
    if (nextStart != end && (whiteSpaceAfterEnd * 2) < lastPatternSize) {
      throw NotFoundException();
    }

    if (_usingCheckDigit) {
      var max = resultString.length - 1;
      var total = 0;
      for (var i = 0; i < max; i++) {
        total += alphabetString.indexOf(resultString[i]);
      }
      if (resultString[max] != alphabetString[total % 43]) {
        throw ChecksumException('Code 39 check digit mismatch');
      }
      resultString = resultString.substring(0, max);
    }

    if (resultString.isEmpty) {
      // false positive
      throw NotFoundException();
    }

    if (_extendedMode) {
      resultString = _decodeExtended(resultString);
    }

    var left = (start[1] + start[0]) / 2.0;
    var right = lastStart + lastPatternSize / 2.0;

    var resultObject =
        Result(resultString, null, BarcodeFormat.code39, points: [
      ResultPoint(left, rowNumber.toDouble()),
      ResultPoint(right, rowNumber.toDouble()),
    ]);
    resultObject.putMetadata(ResultMetadataType.symbologyIdentifier, ']A0');
    return resultObject;
  }

  static List<int> _findAsteriskPattern(BitArray row, List<int> counters) {
    var width = row.size;
    var rowOffset = row.getNextSet(0);

    var counterPosition = 0;
    var patternStart = rowOffset;
    var isWhite = false;
    var patternLength = counters.length;

    for (var i = rowOffset; i < width; i++) {
      if (row.get(i) != isWhite) {
        counters[counterPosition]++;
      } else {
        if (counterPosition == patternLength - 1) {
          // Look for whitespace before start pattern, >= 50% of width of start pattern
          if (_toNarrowWidePattern(counters) == asteriskEncoding &&
              row.isRange(math.max(0, patternStart - ((i - patternStart) ~/ 2)),
                  patternStart, false)) {
            return [patternStart, i];
          }
          patternStart += counters[0] + counters[1];
          counters.setRange(0, counterPosition - 1, counters, 2);
          counters[counterPosition - 1] = 0;
          counters[counterPosition] = 0;
          counterPosition--;
        } else {
          counterPosition++;
        }
        counters[counterPosition] = 1;
        isWhite = !isWhite;
      }
    }
    throw NotFoundException();
  }

  // For efficiency, returns -1 on failure. Not throwing here saved as many as 700 exceptions
  // per image when using some of our blackbox images.
  static int _toNarrowWidePattern(List<int> counters) {
    var numCounters = counters.length;
    var maxNarrowCounter = 0;
    int wideCounters;
    do {
      var minCounter = 0x7fffffff;
      for (var counter in counters) {
        if (counter < minCounter && counter > maxNarrowCounter) {
          minCounter = counter;
        }
      }
      maxNarrowCounter = minCounter;
      wideCounters = 0;
      var totalWideCountersWidth = 0;
      var pattern = 0;
      for (var i = 0; i < numCounters; i++) {
        var counter = counters[i];
        if (counter > maxNarrowCounter) {
          pattern |= 1 << (numCounters - 1 - i);
          wideCounters++;
          totalWideCountersWidth += counter;
        }
      }
      if (wideCounters == 3) {
        // Found 3 wide counters, but are they close enough in width?
        // We can perform a cheap, conservative check to see if any individual
        // counter is more than 1.5 times the average:
        for (var i = 0; i < numCounters && wideCounters > 0; i++) {
          var counter = counters[i];
          if (counter > maxNarrowCounter) {
            wideCounters--;
            // totalWideCountersWidth = 3 * average, so this checks if counter >= 3/2 * average
            if ((counter * 2) >= totalWideCountersWidth) {
              return -1;
            }
          }
        }
        return pattern;
      }
    } while (wideCounters > 3);
    return -1;
  }

  static int _patternToChar(int pattern) {
    for (var i = 0; i < characterEncodings.length; i++) {
      if (characterEncodings[i] == pattern) {
        return alphabetString.codeUnitAt(i);
      }
    }
    if (pattern == asteriskEncoding) {
      return 0x2A; // '*'
    }
    throw NotFoundException();
  }

  static String _decodeExtended(String encoded) {
    var length = encoded.length;
    var decoded = StringBuffer();
    for (var i = 0; i < length; i++) {
      var c = encoded[i];
      if (c == '+' || c == r'$' || c == '%' || c == '/') {
        if (i + 1 >= length) {
          throw FormatReaderException();
        }
        var next = encoded.codeUnitAt(i + 1);
        var decodedChar = 0;
        switch (c) {
          case '+':
            // +A to +Z map to a to z
            if (next >= 0x41 && next <= 0x5A) {
              decodedChar = next + 32;
            } else {
              throw FormatReaderException();
            }
          case r'$':
            // $A to $Z map to control codes SH to SB
            if (next >= 0x41 && next <= 0x5A) {
              decodedChar = next - 64;
            } else {
              throw FormatReaderException();
            }
          case '%':
            // %A to %E map to control codes ESC to US
            if (next >= 0x41 && next <= 0x45) {
              decodedChar = next - 38;
            } else if (next >= 0x46 && next <= 0x4A) {
              decodedChar = next - 11;
            } else if (next >= 0x4B && next <= 0x4F) {
              decodedChar = next + 16;
            } else if (next >= 0x50 && next <= 0x54) {
              decodedChar = next + 43;
            } else if (next == 0x55 /* U */) {
              decodedChar = 0;
            } else if (next == 0x56 /* V */) {
              decodedChar = 0x40; // '@'
            } else if (next == 0x57 /* W */) {
              decodedChar = 0x60; // '`'
            } else if (next == 0x58 || next == 0x59 || next == 0x5A) {
              decodedChar = 127;
            } else {
              throw FormatReaderException();
            }
          case '/':
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
}
