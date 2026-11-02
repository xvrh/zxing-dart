import 'dart:typed_data';
import '../barcode_format.dart';
import '../common/bit_array.dart';
import '../decode_hint.dart';
import '../not_found_exception.dart';
import '../result.dart';
import '../result_metadata_type.dart';
import '../result_point.dart';
import 'one_d_reader.dart';

/// <p>Decodes Codabar barcodes.</p>
///
/// @author Bas Vijfwinkel
/// @author David Walker
class CodaBarReader extends OneDReader {
  // These values are critical for determining how permissive the decoding
  // will be. All stripe sizes must be within the window these define, as
  // compared to the average stripe size.
  static const double _maxAcceptable = 2.0;
  static const double _padding = 1.5;

  static const String alphabetString = r'0123456789-$:/.+ABCD';

  /// These represent the encodings of characters, as patterns of wide and narrow bars. The 7 least-significant bits of
  /// each int correspond to the pattern of wide and narrow, with 1s representing "wide" and 0s representing narrow.
  static const List<int> characterEncodings = [
    0x003, 0x006, 0x009, 0x060, 0x012, 0x042, 0x021, 0x024, 0x030, 0x048, // 0-9
    0x00c, 0x018, 0x045, 0x051, 0x054, 0x015, 0x01A, 0x029, 0x00B,
    0x00E, // -$:/.+ABCD
  ];

  // minimal number of characters that should be present (including start and stop characters)
  // under normal circumstances this should be set to 3, but can be set higher
  // as a last-ditch attempt to reduce false positives.
  static const int _minCharacterLength = 3;

  // official start and end patterns
  static const String _startEndEncoding = 'ABCD';
  // some Codabar generator allow the Codabar string to be closed by every
  // character. This will cause lots of false positives!

  // some industries use a checksum standard but this is not part of the original Codabar standard
  // for more information see : http://www.mecsw.com/specs/codabar.html

  // Keep some instance variables to avoid reallocations
  final List<int> _decodeRowResult = [];
  Int32List _counters = Int32List(80);
  int _counterLength = 0;

  @override
  Result decodeRow(int rowNumber, BitArray row, DecodeHints hints) {
    _counters.fillRange(0, _counters.length, 0);
    _setCounters(row);
    var startOffset = _findStartPattern();
    var nextStart = startOffset;

    _decodeRowResult.clear();
    do {
      var charOffset = _toNarrowWidePattern(nextStart);
      if (charOffset == -1) {
        throw NotFoundException();
      }
      // Hack: We store the position in the alphabet table into a
      // StringBuilder, so that we can access the decoded patterns in
      // validatePattern. We'll translate to the actual characters later.
      _decodeRowResult.add(charOffset);
      nextStart += 8;
      // Stop as soon as we see the end character.
      if (_decodeRowResult.length > 1 &&
          _startEndEncoding.contains(alphabetString[charOffset])) {
        break;
      }
    } while (nextStart <
        _counterLength); // no fixed end pattern so keep on reading while data is available

    // Look for whitespace after pattern:
    var trailingWhitespace = _counters[nextStart - 1];
    var lastPatternSize = 0;
    for (var i = -8; i < -1; i++) {
      lastPatternSize += _counters[nextStart + i];
    }

    // We need to see whitespace equal to 50% of the last pattern size,
    // otherwise this is probably a false positive. The exception is if we are
    // at the end of the row. (I.e. the barcode barely fits.)
    if (nextStart < _counterLength &&
        trailingWhitespace < lastPatternSize ~/ 2) {
      throw NotFoundException();
    }

    _validatePattern(startOffset);

    // Translate character table offsets to actual characters.
    var decoded = _decodeRowResult.map((i) => alphabetString[i]).join();
    // Ensure a valid start and end character
    var startchar = decoded[0];
    if (!_startEndEncoding.contains(startchar)) {
      throw NotFoundException();
    }
    var endchar = decoded[decoded.length - 1];
    if (!_startEndEncoding.contains(endchar)) {
      throw NotFoundException();
    }

    // remove stop/start characters character and check if a long enough string is contained
    if (decoded.length <= _minCharacterLength) {
      // Almost surely a false positive ( start + stop + at least 1 character)
      throw NotFoundException();
    }

    if (!hints.contains(DecodeHintType.returnCodabarStartEnd)) {
      decoded = decoded.substring(1, decoded.length - 1);
    }

    var runningCount = 0;
    for (var i = 0; i < startOffset; i++) {
      runningCount += _counters[i];
    }
    var left = runningCount.toDouble();
    for (var i = startOffset; i < nextStart - 1; i++) {
      runningCount += _counters[i];
    }
    var right = runningCount.toDouble();

    var result = Result(decoded, null, BarcodeFormat.codabar, points: [
      ResultPoint(left, rowNumber.toDouble()),
      ResultPoint(right, rowNumber.toDouble()),
    ]);
    result.putMetadata(ResultMetadataType.symbologyIdentifier, ']F0');
    return result;
  }

  void _validatePattern(int start) {
    // First, sum up the total size of our four categories of stripe sizes;
    var sizes = [0, 0, 0, 0];
    var counts = [0, 0, 0, 0];
    var end = _decodeRowResult.length - 1;

    // We break out of this loop in the middle, in order to handle
    // inter-character spaces properly.
    var pos = start;
    for (var i = 0; i <= end; i++) {
      var pattern = characterEncodings[_decodeRowResult[i]];
      for (var j = 6; j >= 0; j--) {
        // Even j = bars, while odd j = spaces. Categories 2 and 3 are for
        // long stripes, while 0 and 1 are for short stripes.
        var category = (j & 1) + (pattern & 1) * 2;
        sizes[category] += _counters[pos + j];
        counts[category]++;
        pattern >>= 1;
      }
      // We ignore the inter-character space - it could be of any size.
      pos += 8;
    }

    // Calculate our allowable size thresholds using fixed-point math.
    var maxes = Float64List(4);
    var mins = Float64List(4);
    // Define the threshold of acceptability to be the midpoint between the
    // average small stripe and the average large stripe. No stripe lengths
    // should be on the "wrong" side of that line.
    for (var i = 0; i < 2; i++) {
      mins[i] = 0.0; // Accept arbitrarily small "short" stripes.
      mins[i + 2] = (sizes[i] / counts[i] + sizes[i + 2] / counts[i + 2]) / 2.0;
      maxes[i] = mins[i + 2];
      maxes[i + 2] = (sizes[i + 2] * _maxAcceptable + _padding) / counts[i + 2];
    }

    // Now verify that all of the stripes are within the thresholds.
    pos = start;
    for (var i = 0; i <= end; i++) {
      var pattern = characterEncodings[_decodeRowResult[i]];
      for (var j = 6; j >= 0; j--) {
        // Even j = bars, while odd j = spaces. Categories 2 and 3 are for
        // long stripes, while 0 and 1 are for short stripes.
        var category = (j & 1) + (pattern & 1) * 2;
        var size = _counters[pos + j];
        if (size < mins[category] || size > maxes[category]) {
          throw NotFoundException();
        }
        pattern >>= 1;
      }
      pos += 8;
    }
  }

  /// Records the size of all runs of white and black pixels, starting with white.
  /// This is just like recordPattern, except it records all the counters, and
  /// uses our builtin "counters" member for storage.
  /// @param row row to count from
  void _setCounters(BitArray row) {
    _counterLength = 0;
    // Start from the first white bit.
    var i = row.getNextUnset(0);
    var end = row.size;
    if (i >= end) {
      throw NotFoundException();
    }
    var isWhite = true;
    var count = 0;
    while (i < end) {
      if (row.get(i) != isWhite) {
        count++;
      } else {
        _counterAppend(count);
        count = 1;
        isWhite = !isWhite;
      }
      i++;
    }
    _counterAppend(count);
  }

  void _counterAppend(int e) {
    _counters[_counterLength] = e;
    _counterLength++;
    if (_counterLength >= _counters.length) {
      var temp = Int32List(_counterLength * 2);
      temp.setRange(0, _counterLength, _counters);
      _counters = temp;
    }
  }

  int _findStartPattern() {
    for (var i = 1; i < _counterLength; i += 2) {
      var charOffset = _toNarrowWidePattern(i);
      if (charOffset != -1 &&
          _startEndEncoding.contains(alphabetString[charOffset])) {
        // Look for whitespace before start pattern, >= 50% of width of start pattern
        // We make an exception if the whitespace is the first element.
        var patternSize = 0;
        for (var j = i; j < i + 7; j++) {
          patternSize += _counters[j];
        }
        if (i == 1 || _counters[i - 1] >= patternSize ~/ 2) {
          return i;
        }
      }
    }
    throw NotFoundException();
  }

  // Assumes that counters[position] is a bar.
  int _toNarrowWidePattern(int position) {
    var end = position + 7;
    if (end >= _counterLength) {
      return -1;
    }

    var theCounters = _counters;

    var maxBar = 0;
    var minBar = 0x7fffffff;
    for (var j = position; j < end; j += 2) {
      var currentCounter = theCounters[j];
      if (currentCounter < minBar) {
        minBar = currentCounter;
      }
      if (currentCounter > maxBar) {
        maxBar = currentCounter;
      }
    }
    var thresholdBar = (minBar + maxBar) ~/ 2;

    var maxSpace = 0;
    var minSpace = 0x7fffffff;
    for (var j = position + 1; j < end; j += 2) {
      var currentCounter = theCounters[j];
      if (currentCounter < minSpace) {
        minSpace = currentCounter;
      }
      if (currentCounter > maxSpace) {
        maxSpace = currentCounter;
      }
    }
    var thresholdSpace = (minSpace + maxSpace) ~/ 2;

    var bitmask = 1 << 7;
    var pattern = 0;
    for (var i = 0; i < 7; i++) {
      var threshold = (i & 1) == 0 ? thresholdBar : thresholdSpace;
      bitmask >>= 1;
      if (theCounters[position + i] > threshold) {
        pattern |= bitmask;
      }
    }

    for (var i = 0; i < characterEncodings.length; i++) {
      if (characterEncodings[i] == pattern) {
        return i;
      }
    }
    return -1;
  }
}
