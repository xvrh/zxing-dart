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

/// <p>Decodes Code 128 barcodes.</p>
///
/// @author Sean Owen
class Code128Reader extends OneDReader {
  static const List<List<int>> codePatterns = [
    [2, 1, 2, 2, 2, 2], // 0
    [2, 2, 2, 1, 2, 2],
    [2, 2, 2, 2, 2, 1],
    [1, 2, 1, 2, 2, 3],
    [1, 2, 1, 3, 2, 2],
    [1, 3, 1, 2, 2, 2], // 5
    [1, 2, 2, 2, 1, 3],
    [1, 2, 2, 3, 1, 2],
    [1, 3, 2, 2, 1, 2],
    [2, 2, 1, 2, 1, 3],
    [2, 2, 1, 3, 1, 2], // 10
    [2, 3, 1, 2, 1, 2],
    [1, 1, 2, 2, 3, 2],
    [1, 2, 2, 1, 3, 2],
    [1, 2, 2, 2, 3, 1],
    [1, 1, 3, 2, 2, 2], // 15
    [1, 2, 3, 1, 2, 2],
    [1, 2, 3, 2, 2, 1],
    [2, 2, 3, 2, 1, 1],
    [2, 2, 1, 1, 3, 2],
    [2, 2, 1, 2, 3, 1], // 20
    [2, 1, 3, 2, 1, 2],
    [2, 2, 3, 1, 1, 2],
    [3, 1, 2, 1, 3, 1],
    [3, 1, 1, 2, 2, 2],
    [3, 2, 1, 1, 2, 2], // 25
    [3, 2, 1, 2, 2, 1],
    [3, 1, 2, 2, 1, 2],
    [3, 2, 2, 1, 1, 2],
    [3, 2, 2, 2, 1, 1],
    [2, 1, 2, 1, 2, 3], // 30
    [2, 1, 2, 3, 2, 1],
    [2, 3, 2, 1, 2, 1],
    [1, 1, 1, 3, 2, 3],
    [1, 3, 1, 1, 2, 3],
    [1, 3, 1, 3, 2, 1], // 35
    [1, 1, 2, 3, 1, 3],
    [1, 3, 2, 1, 1, 3],
    [1, 3, 2, 3, 1, 1],
    [2, 1, 1, 3, 1, 3],
    [2, 3, 1, 1, 1, 3], // 40
    [2, 3, 1, 3, 1, 1],
    [1, 1, 2, 1, 3, 3],
    [1, 1, 2, 3, 3, 1],
    [1, 3, 2, 1, 3, 1],
    [1, 1, 3, 1, 2, 3], // 45
    [1, 1, 3, 3, 2, 1],
    [1, 3, 3, 1, 2, 1],
    [3, 1, 3, 1, 2, 1],
    [2, 1, 1, 3, 3, 1],
    [2, 3, 1, 1, 3, 1], // 50
    [2, 1, 3, 1, 1, 3],
    [2, 1, 3, 3, 1, 1],
    [2, 1, 3, 1, 3, 1],
    [3, 1, 1, 1, 2, 3],
    [3, 1, 1, 3, 2, 1], // 55
    [3, 3, 1, 1, 2, 1],
    [3, 1, 2, 1, 1, 3],
    [3, 1, 2, 3, 1, 1],
    [3, 3, 2, 1, 1, 1],
    [3, 1, 4, 1, 1, 1], // 60
    [2, 2, 1, 4, 1, 1],
    [4, 3, 1, 1, 1, 1],
    [1, 1, 1, 2, 2, 4],
    [1, 1, 1, 4, 2, 2],
    [1, 2, 1, 1, 2, 4], // 65
    [1, 2, 1, 4, 2, 1],
    [1, 4, 1, 1, 2, 2],
    [1, 4, 1, 2, 2, 1],
    [1, 1, 2, 2, 1, 4],
    [1, 1, 2, 4, 1, 2], // 70
    [1, 2, 2, 1, 1, 4],
    [1, 2, 2, 4, 1, 1],
    [1, 4, 2, 1, 1, 2],
    [1, 4, 2, 2, 1, 1],
    [2, 4, 1, 2, 1, 1], // 75
    [2, 2, 1, 1, 1, 4],
    [4, 1, 3, 1, 1, 1],
    [2, 4, 1, 1, 1, 2],
    [1, 3, 4, 1, 1, 1],
    [1, 1, 1, 2, 4, 2], // 80
    [1, 2, 1, 1, 4, 2],
    [1, 2, 1, 2, 4, 1],
    [1, 1, 4, 2, 1, 2],
    [1, 2, 4, 1, 1, 2],
    [1, 2, 4, 2, 1, 1], // 85
    [4, 1, 1, 2, 1, 2],
    [4, 2, 1, 1, 1, 2],
    [4, 2, 1, 2, 1, 1],
    [2, 1, 2, 1, 4, 1],
    [2, 1, 4, 1, 2, 1], // 90
    [4, 1, 2, 1, 2, 1],
    [1, 1, 1, 1, 4, 3],
    [1, 1, 1, 3, 4, 1],
    [1, 3, 1, 1, 4, 1],
    [1, 1, 4, 1, 1, 3], // 95
    [1, 1, 4, 3, 1, 1],
    [4, 1, 1, 1, 1, 3],
    [4, 1, 1, 3, 1, 1],
    [1, 1, 3, 1, 4, 1],
    [1, 1, 4, 1, 3, 1], // 100
    [3, 1, 1, 1, 4, 1],
    [4, 1, 1, 1, 3, 1],
    [2, 1, 1, 4, 1, 2],
    [2, 1, 1, 2, 1, 4],
    [2, 1, 1, 2, 3, 2], // 105
    [2, 3, 3, 1, 1, 1, 2],
  ];

  static const double _maxAvgVariance = 0.25;
  static const double _maxIndividualVariance = 0.7;

  static const int _codeShift = 98;

  static const int _codeCodeC = 99;
  static const int _codeCodeB = 100;
  static const int _codeCodeA = 101;

  static const int _codeFnc1 = 102;
  static const int _codeFnc2 = 97;
  static const int _codeFnc3 = 96;
  static const int _codeFnc4A = 101;
  static const int _codeFnc4B = 100;

  static const int _codeStartA = 103;
  static const int _codeStartB = 104;
  static const int _codeStartC = 105;
  static const int _codeStop = 106;

  static List<int> _findStartPattern(BitArray row) {
    var width = row.size;
    var rowOffset = row.getNextSet(0);

    var counterPosition = 0;
    var counters = Int32List(6);
    var patternStart = rowOffset;
    var isWhite = false;
    var patternLength = counters.length;

    for (var i = rowOffset; i < width; i++) {
      if (row.get(i) != isWhite) {
        counters[counterPosition]++;
      } else {
        if (counterPosition == patternLength - 1) {
          var bestVariance = _maxAvgVariance;
          var bestMatch = -1;
          for (var startCode = _codeStartA;
              startCode <= _codeStartC;
              startCode++) {
            var variance = OneDReader.patternMatchVariance(
                counters, codePatterns[startCode], _maxIndividualVariance);
            if (variance < bestVariance) {
              bestVariance = variance;
              bestMatch = startCode;
            }
          }
          // Look for whitespace before start pattern, >= 50% of width of start pattern
          if (bestMatch >= 0 &&
              row.isRange(math.max(0, patternStart - (i - patternStart) ~/ 2),
                  patternStart, false)) {
            return [patternStart, i, bestMatch];
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

  static int _decodeCode(BitArray row, List<int> counters, int rowOffset) {
    OneDReader.recordPattern(row, rowOffset, counters);
    var bestVariance = _maxAvgVariance; // worst variance we'll accept
    var bestMatch = -1;
    for (var d = 0; d < codePatterns.length; d++) {
      var pattern = codePatterns[d];
      var variance = OneDReader.patternMatchVariance(
          counters, pattern, _maxIndividualVariance);
      if (variance < bestVariance) {
        bestVariance = variance;
        bestMatch = d;
      }
    }
    // TODO We're overlooking the fact that the STOP pattern has 7 values, not 6.
    if (bestMatch >= 0) {
      return bestMatch;
    } else {
      throw NotFoundException();
    }
  }

  @override
  Result decodeRow(int rowNumber, BitArray row, DecodeHints hints) {
    var convertFNC1 = hints.contains(DecodeHintType.assumeGs1);

    var symbologyModifier = 0;

    var startPatternInfo = _findStartPattern(row);
    var startCode = startPatternInfo[2];

    var rawCodes = <int>[startCode];

    int codeSet;
    switch (startCode) {
      case _codeStartA:
        codeSet = _codeCodeA;
      case _codeStartB:
        codeSet = _codeCodeB;
      case _codeStartC:
        codeSet = _codeCodeC;
      default:
        throw FormatReaderException();
    }

    var done = false;
    var isNextShifted = false;

    var result = StringBuffer();

    var lastStart = startPatternInfo[0];
    var nextStart = startPatternInfo[1];
    var counters = Int32List(6);

    var lastCode = 0;
    var code = 0;
    var checksumTotal = startCode;
    var multiplier = 0;
    var lastCharacterWasPrintable = true;
    var upperMode = false;
    var shiftUpperMode = false;

    while (!done) {
      var unshift = isNextShifted;
      isNextShifted = false;

      // Save off last code
      lastCode = code;

      // Decode another code from image
      code = _decodeCode(row, counters, nextStart);

      rawCodes.add(code);

      // Remember whether the last code was printable or not (excluding CODE_STOP)
      if (code != _codeStop) {
        lastCharacterWasPrintable = true;
      }

      // Add to checksum computation (if not CODE_STOP of course)
      if (code != _codeStop) {
        multiplier++;
        checksumTotal += multiplier * code;
      }

      // Advance to where the next code will to start
      lastStart = nextStart;
      for (var counter in counters) {
        nextStart += counter;
      }

      // Take care of illegal start codes
      switch (code) {
        case _codeStartA:
        case _codeStartB:
        case _codeStartC:
          throw FormatReaderException();
      }

      switch (codeSet) {
        case _codeCodeA:
          if (code < 64) {
            if (shiftUpperMode == upperMode) {
              result.writeCharCode(0x20 + code);
            } else {
              result.writeCharCode(0x20 + code + 128);
            }
            shiftUpperMode = false;
          } else if (code < 96) {
            if (shiftUpperMode == upperMode) {
              result.writeCharCode(code - 64);
            } else {
              result.writeCharCode(code + 64);
            }
            shiftUpperMode = false;
          } else {
            // Don't let CODE_STOP, which always appears, affect whether whether we think the last
            // code was printable or not.
            if (code != _codeStop) {
              lastCharacterWasPrintable = false;
            }
            switch (code) {
              case _codeFnc1:
                if (result.length == 0) {
                  // FNC1 at first or second character determines the symbology
                  symbologyModifier = 1;
                } else if (result.length == 1) {
                  symbologyModifier = 2;
                }
                if (convertFNC1) {
                  if (result.length == 0) {
                    // GS1 specification 5.4.3.7. and 5.4.6.4. If the first char after the start code
                    // is FNC1 then this is GS1-128. We add the symbology identifier.
                    result.write(']C1');
                  } else {
                    // GS1 specification 5.4.7.5. Every subsequent FNC1 is returned as ASCII 29 (GS)
                    result.writeCharCode(29);
                  }
                }
              case _codeFnc2:
                symbologyModifier = 4;
              case _codeFnc3:
                // do nothing?
                break;
              case _codeFnc4A:
                if (!upperMode && shiftUpperMode) {
                  upperMode = true;
                  shiftUpperMode = false;
                } else if (upperMode && shiftUpperMode) {
                  upperMode = false;
                  shiftUpperMode = false;
                } else {
                  shiftUpperMode = true;
                }
              case _codeShift:
                isNextShifted = true;
                codeSet = _codeCodeB;
              case _codeCodeB:
                codeSet = _codeCodeB;
              case _codeCodeC:
                codeSet = _codeCodeC;
              case _codeStop:
                done = true;
            }
          }
        case _codeCodeB:
          if (code < 96) {
            if (shiftUpperMode == upperMode) {
              result.writeCharCode(0x20 + code);
            } else {
              result.writeCharCode(0x20 + code + 128);
            }
            shiftUpperMode = false;
          } else {
            if (code != _codeStop) {
              lastCharacterWasPrintable = false;
            }
            switch (code) {
              case _codeFnc1:
                if (result.length == 0) {
                  // FNC1 at first or second character determines the symbology
                  symbologyModifier = 1;
                } else if (result.length == 1) {
                  symbologyModifier = 2;
                }
                if (convertFNC1) {
                  if (result.length == 0) {
                    // GS1 specification 5.4.3.7. and 5.4.6.4. If the first char after the start code
                    // is FNC1 then this is GS1-128. We add the symbology identifier.
                    result.write(']C1');
                  } else {
                    // GS1 specification 5.4.7.5. Every subsequent FNC1 is returned as ASCII 29 (GS)
                    result.writeCharCode(29);
                  }
                }
              case _codeFnc2:
                symbologyModifier = 4;
              case _codeFnc3:
                // do nothing?
                break;
              case _codeFnc4B:
                if (!upperMode && shiftUpperMode) {
                  upperMode = true;
                  shiftUpperMode = false;
                } else if (upperMode && shiftUpperMode) {
                  upperMode = false;
                  shiftUpperMode = false;
                } else {
                  shiftUpperMode = true;
                }
              case _codeShift:
                isNextShifted = true;
                codeSet = _codeCodeA;
              case _codeCodeA:
                codeSet = _codeCodeA;
              case _codeCodeC:
                codeSet = _codeCodeC;
              case _codeStop:
                done = true;
            }
          }
        case _codeCodeC:
          if (code < 100) {
            if (code < 10) {
              result.write('0');
            }
            result.write(code);
          } else {
            if (code != _codeStop) {
              lastCharacterWasPrintable = false;
            }
            switch (code) {
              case _codeFnc1:
                if (result.length == 0) {
                  // FNC1 at first or second character determines the symbology
                  symbologyModifier = 1;
                } else if (result.length == 1) {
                  symbologyModifier = 2;
                }
                if (convertFNC1) {
                  if (result.length == 0) {
                    // GS1 specification 5.4.3.7. and 5.4.6.4. If the first char after the start code
                    // is FNC1 then this is GS1-128. We add the symbology identifier.
                    result.write(']C1');
                  } else {
                    // GS1 specification 5.4.7.5. Every subsequent FNC1 is returned as ASCII 29 (GS)
                    result.writeCharCode(29);
                  }
                }
              case _codeCodeA:
                codeSet = _codeCodeA;
              case _codeCodeB:
                codeSet = _codeCodeB;
              case _codeStop:
                done = true;
            }
          }
      }

      // Unshift back to another code set if we were shifted
      if (unshift) {
        codeSet = codeSet == _codeCodeA ? _codeCodeB : _codeCodeA;
      }
    }

    var lastPatternSize = nextStart - lastStart;

    // Check for ample whitespace following pattern, but, to do this we first need to remember that
    // we fudged decoding CODE_STOP since it actually has 7 bars, not 6. There is a black bar left
    // to read off. Would be slightly better to properly read. Here we just skip it:
    nextStart = row.getNextUnset(nextStart);
    if (!row.isRange(nextStart,
        math.min(row.size, nextStart + (nextStart - lastStart) ~/ 2), false)) {
      throw NotFoundException();
    }

    // Pull out from sum the value of the penultimate check code
    checksumTotal -= multiplier * lastCode;
    // lastCode is the checksum then:
    if (checksumTotal % 103 != lastCode) {
      throw ChecksumException('Code 128 checksum failed');
    }

    // Need to pull out the check digits from string
    var resultString = result.toString();
    var resultLength = resultString.length;
    if (resultLength == 0) {
      // false positive
      throw NotFoundException();
    }

    // Only bother if the result had at least one character, and if the checksum digit happened to
    // be a printable character. If it was just interpreted as a control code, nothing to remove.
    if (resultLength > 0 && lastCharacterWasPrintable) {
      if (codeSet == _codeCodeC) {
        resultString = resultString.substring(0, resultLength - 2);
      } else {
        resultString = resultString.substring(0, resultLength - 1);
      }
    }

    var left = (startPatternInfo[1] + startPatternInfo[0]) / 2.0;
    var right = lastStart + lastPatternSize / 2.0;

    var rawBytes = Int8List.fromList(rawCodes);
    var resultObject =
        Result(resultString, rawBytes, BarcodeFormat.code128, points: [
      ResultPoint(left, rowNumber.toDouble()),
      ResultPoint(right, rowNumber.toDouble()),
    ]);
    resultObject.putMetadata(
        ResultMetadataType.symbologyIdentifier, ']C$symbologyModifier');
    return resultObject;
  }
}
