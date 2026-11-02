import 'dart:math' as math;
import 'dart:typed_data';
import '../barcode_format.dart';
import '../common/bit_array.dart';
import '../decode_hint.dart';
import '../format_reader_exception.dart';
import '../not_found_exception.dart';
import '../result.dart';
import '../result_metadata_type.dart';
import '../result_point.dart';
import 'one_d_reader.dart';

/// <p>Implements decoding of the ITF format, or Interleaved Two of Five.</p>
///
/// <p>This Reader will scan ITF barcodes of certain lengths only.
/// At the moment it reads length 6, 8, 10, 12, 14, 16, 18, 20, 24, and 44 as these have appeared "in the wild". Not all
/// lengths are scanned, especially shorter ones, to avoid false positives. This in turn is due to a lack of
/// required checksum function.</p>
///
/// <p>The checksum is optional and is not applied by this Reader. The consumer of the decoded
/// value will have to apply a checksum if required.</p>
///
/// <p><a href="http://en.wikipedia.org/wiki/Interleaved_2_of_5">http://en.wikipedia.org/wiki/Interleaved_2_of_5</a>
/// is a great reference for Interleaved 2 of 5 information.</p>
///
/// @author kevin.osullivan@sita.aero, SITA Lab.
class ITFReader extends OneDReader {
  static const double _maxAvgVariance = 0.38;
  static const double _maxIndividualVariance2X =
      0.5; // 2x wide lines -> stricter
  static const double _maxIndividualVariance3X =
      0.75; // 3x wide lines -> less strict

  static const int _wide3 = 3; // Pixel width of a 3x wide line
  static const int _wide2 = 2; // Pixel width of a 2x wide line
  static const int _narrow = 1; // Pixel width of a narrow line

  /// Valid ITF lengths. Anything longer than the largest value is also allowed.
  static const List<int> _defaultAllowedLengths = [6, 8, 10, 12, 14];

  // Stores the actual narrow line width of the image being decoded.
  int _narrowLineWidth = -1;

  /// Start/end guard pattern.
  ///
  /// Note: The end pattern is reversed because the row is reversed before
  /// searching for the END_PATTERN
  static const List<int> _startPattern = [_narrow, _narrow, _narrow, _narrow];
  static const List<List<int>> _endPatternReversed = [
    [_narrow, _narrow, _wide2], // 2x
    [_narrow, _narrow, _wide3], // 3x
  ];

  // See ITFWriter.PATTERNS

  /// Patterns of Wide / Narrow lines to indicate each digit
  static const List<List<int>> _patterns = [
    [_narrow, _narrow, _wide2, _wide2, _narrow], // 0
    [_wide2, _narrow, _narrow, _narrow, _wide2], // 1
    [_narrow, _wide2, _narrow, _narrow, _wide2], // 2
    [_wide2, _wide2, _narrow, _narrow, _narrow], // 3
    [_narrow, _narrow, _wide2, _narrow, _wide2], // 4
    [_wide2, _narrow, _wide2, _narrow, _narrow], // 5
    [_narrow, _wide2, _wide2, _narrow, _narrow], // 6
    [_narrow, _narrow, _narrow, _wide2, _wide2], // 7
    [_wide2, _narrow, _narrow, _wide2, _narrow], // 8
    [_narrow, _wide2, _narrow, _wide2, _narrow], // 9
    [_narrow, _narrow, _wide3, _wide3, _narrow], // 0
    [_wide3, _narrow, _narrow, _narrow, _wide3], // 1
    [_narrow, _wide3, _narrow, _narrow, _wide3], // 2
    [_wide3, _wide3, _narrow, _narrow, _narrow], // 3
    [_narrow, _narrow, _wide3, _narrow, _wide3], // 4
    [_wide3, _narrow, _wide3, _narrow, _narrow], // 5
    [_narrow, _wide3, _wide3, _narrow, _narrow], // 6
    [_narrow, _narrow, _narrow, _wide3, _wide3], // 7
    [_wide3, _narrow, _narrow, _wide3, _narrow], // 8
    [_narrow, _wide3, _narrow, _wide3, _narrow], // 9
  ];

  @override
  Result decodeRow(int rowNumber, BitArray row, DecodeHints hints) {
    // Find out where the Middle section (payload) starts & ends
    var startRange = _decodeStart(row);
    var endRange = _decodeEnd(row);

    var result = StringBuffer();
    _decodeMiddle(row, startRange[1], endRange[0], result);
    var resultString = result.toString();

    var allowedLengths =
        hints.get(DecodeHintType.allowedLengths) ?? _defaultAllowedLengths;

    // To avoid false positives with 2D barcodes (and other patterns), make
    // an assumption that the decoded string must be a 'standard' length if it's short
    var length = resultString.length;
    var lengthOK = false;
    var maxAllowedLength = 0;
    for (var allowedLength in allowedLengths) {
      if (length == allowedLength) {
        lengthOK = true;
        break;
      }
      if (allowedLength > maxAllowedLength) {
        maxAllowedLength = allowedLength;
      }
    }
    if (!lengthOK && length > maxAllowedLength) {
      lengthOK = true;
    }
    if (!lengthOK) {
      throw FormatReaderException();
    }

    var resultObject = Result(
        resultString,
        null, // no natural byte representation for these barcodes
        BarcodeFormat.itf,
        points: [
          ResultPoint(startRange[1].toDouble(), rowNumber.toDouble()),
          ResultPoint(endRange[0].toDouble(), rowNumber.toDouble()),
        ]);
    resultObject.putMetadata(ResultMetadataType.symbologyIdentifier, ']I0');
    return resultObject;
  }

  /// @param row          row of black/white values to search
  /// @param payloadStart offset of start pattern
  /// @param resultString {@link StringBuilder} to append decoded chars to
  /// @throws NotFoundException if decoding could not complete successfully
  static void _decodeMiddle(BitArray row, int payloadStart, int payloadEnd,
      StringBuffer resultString) {
    // Digits are interleaved in pairs - 5 black lines for one digit, and the
    // 5
    // interleaved white lines for the second digit.
    // Therefore, need to scan 10 lines and then
    // split these into two arrays
    var counterDigitPair = Int32List(10);
    var counterBlack = Int32List(5);
    var counterWhite = Int32List(5);

    while (payloadStart < payloadEnd) {
      // Get 10 runs of black/white.
      OneDReader.recordPattern(row, payloadStart, counterDigitPair);
      // Split them into each array
      for (var k = 0; k < 5; k++) {
        var twoK = 2 * k;
        counterBlack[k] = counterDigitPair[twoK];
        counterWhite[k] = counterDigitPair[twoK + 1];
      }

      var bestMatch = _decodeDigit(counterBlack);
      resultString.writeCharCode(0x30 + bestMatch);
      bestMatch = _decodeDigit(counterWhite);
      resultString.writeCharCode(0x30 + bestMatch);

      for (var counterDigit in counterDigitPair) {
        payloadStart += counterDigit;
      }
    }
  }

  /// Identify where the start of the middle / payload section starts.
  ///
  /// @param row row of black/white values to search
  /// @return Array, containing index of start of 'start block' and end of
  ///         'start block'
  List<int> _decodeStart(BitArray row) {
    var endStart = _skipWhiteSpace(row);
    var startPattern = _findGuardPattern(row, endStart, _startPattern);

    // Determine the width of a narrow line in pixels. We can do this by
    // getting the width of the start pattern and dividing by 4 because its
    // made up of 4 narrow lines.
    _narrowLineWidth = (startPattern[1] - startPattern[0]) ~/ 4;

    _validateQuietZone(row, startPattern[0]);

    return startPattern;
  }

  /// The start & end patterns must be pre/post fixed by a quiet zone. This
  /// zone must be at least 10 times the width of a narrow line.  Scan back until
  /// we either get to the start of the barcode or match the necessary number of
  /// quiet zone pixels.
  ///
  /// Note: Its assumed the row is reversed when using this method to find
  /// quiet zone after the end pattern.
  ///
  /// ref: http://www.barcode-1.net/i25code.html
  ///
  /// @param row bit array representing the scanned barcode.
  /// @param startPattern index into row of the start or end pattern.
  /// @throws NotFoundException if the quiet zone cannot be found
  void _validateQuietZone(BitArray row, int startPattern) {
    var quietCount =
        _narrowLineWidth * 10; // expect to find this many pixels of quiet zone

    // if there are not so many pixel at all let's try as many as possible
    quietCount = math.min(quietCount, startPattern);

    for (var i = startPattern - 1; quietCount > 0 && i >= 0; i--) {
      if (row.get(i)) {
        break;
      }
      quietCount--;
    }
    if (quietCount != 0) {
      // Unable to find the necessary number of quiet zone pixels.
      throw NotFoundException();
    }
  }

  /// Skip all whitespace until we get to the first black line.
  ///
  /// @param row row of black/white values to search
  /// @return index of the first black line.
  /// @throws NotFoundException Throws exception if no black lines are found in the row
  static int _skipWhiteSpace(BitArray row) {
    var width = row.size;
    var endStart = row.getNextSet(0);
    if (endStart == width) {
      throw NotFoundException();
    }

    return endStart;
  }

  /// Identify where the end of the middle / payload section ends.
  ///
  /// @param row row of black/white values to search
  /// @return Array, containing index of start of 'end block' and end of 'end
  ///         block'
  List<int> _decodeEnd(BitArray row) {
    // For convenience, reverse the row and then
    // search from 'the start' for the end block
    row.reverse();
    try {
      var endStart = _skipWhiteSpace(row);
      List<int> endPattern;
      try {
        endPattern = _findGuardPattern(row, endStart, _endPatternReversed[0]);
      } on NotFoundException catch (_) {
        endPattern = _findGuardPattern(row, endStart, _endPatternReversed[1]);
      }

      // The start & end patterns must be pre/post fixed by a quiet zone. This
      // zone must be at least 10 times the width of a narrow line.
      // ref: http://www.barcode-1.net/i25code.html
      _validateQuietZone(row, endPattern[0]);

      // Now recalculate the indices of where the 'endblock' starts & stops to
      // accommodate
      // the reversed nature of the search
      var temp = endPattern[0];
      endPattern[0] = row.size - endPattern[1];
      endPattern[1] = row.size - temp;

      return endPattern;
    } finally {
      // Put the row back the right way.
      row.reverse();
    }
  }

  /// @param row       row of black/white values to search
  /// @param rowOffset position to start search
  /// @param pattern   pattern of counts of number of black and white pixels that are
  ///                  being searched for as a pattern
  /// @return start/end horizontal offset of guard pattern, as an array of two
  ///         ints
  /// @throws NotFoundException if pattern is not found
  static List<int> _findGuardPattern(
      BitArray row, int rowOffset, List<int> pattern) {
    var patternLength = pattern.length;
    var counters = Int32List(patternLength);
    var width = row.size;
    var isWhite = false;

    var counterPosition = 0;
    var patternStart = rowOffset;
    for (var x = rowOffset; x < width; x++) {
      if (row.get(x) != isWhite) {
        counters[counterPosition]++;
      } else {
        if (counterPosition == patternLength - 1) {
          if (OneDReader.patternMatchVariance(
                  counters, pattern, _maxIndividualVariance2X) <
              _maxAvgVariance) {
            return [patternStart, x];
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

  /// Attempts to decode a sequence of ITF black/white lines into single
  /// digit.
  ///
  /// @param counters the counts of runs of observed black/white/black/... values
  /// @return The decoded digit
  /// @throws NotFoundException if digit cannot be decoded
  static int _decodeDigit(List<int> counters) {
    var bestVariance = _maxAvgVariance; // worst variance we'll accept
    var bestMatch = -1;
    var max = _patterns.length;
    for (var i = 0; i < max; i++) {
      var pattern = _patterns[i];
      var maxVariance =
          (i <= 9 ? _maxIndividualVariance2X : _maxIndividualVariance3X);
      var variance =
          OneDReader.patternMatchVariance(counters, pattern, maxVariance);
      if (variance < bestVariance) {
        bestVariance = variance;
        bestMatch = i;
      } else if (variance == bestVariance) {
        // if we find a second 'best match' with the same variance, we can not reliably report to have a suitable match
        bestMatch = -1;
      }
    }
    if (bestMatch >= 0) {
      return bestMatch % 10;
    } else {
      throw NotFoundException();
    }
  }
}
