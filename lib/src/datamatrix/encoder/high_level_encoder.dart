import 'dart:math' as math;
import 'dart:typed_data';
import 'package:charcode/charcode.dart';
import '../../dimension.dart';
import 'ascii_encoder.dart';
import 'base256_encoder.dart';
import 'c40_encoder.dart';
import 'edifact_encoder.dart';
import 'encoder.dart';
import 'encoder_context.dart';
import 'symbol_shape_hint.dart';
import 'text_encoder.dart';
import 'x12_encoder.dart';

/// DataMatrix ECC 200 data encoder following the algorithm described in ISO/IEC 16022:200(E) in
/// annex S.
class HighLevelEncoder {
  /// Padding character
  static const _pad = 129;

  /// mode latch to C40 encodation mode
  static const latchToC40 = 230;

  /// mode latch to Base 256 encodation mode
  static const latchToBase256 = 231;

  // FNC1 Codeword
  //static const _fnc1 = 232;

  // Structured Append Codeword
  //static const _structuredAppend = 233;

  // Reader Programming
  //static const _readerProgramming = 234;

  /// Upper Shift
  static const upperShift = 235;

  /// 05 Macro
  static const _macro05 = 236;

  /// 06 Macro
  static const _macro06 = 237;

  /// mode latch to ANSI X.12 encodation mode
  static const latchToAnsiX12 = 238;

  /// mode latch to Text encodation mode
  static const latchToText = 239;

  /// mode latch to EDIFACT encodation mode
  static const latchToEdifact = 240;

  // ECI character (Extended Channel Interpretation)
  //static const _eci = 241;

  /// Unlatch from C40 encodation
  static const c40Unlatch = 254;

  /// Unlatch from X12 encodation
  static const x12Unlatch = 254;

  /// 05 Macro header
  static const macro05Header = '[)>\u001E05\u001D';

  /// 06 Macro header
  static const macro06Header = '[)>\u001E06\u001D';

  /// Macro trailer
  static const macroTrailer = '\u001E\u0004';

  static const asciiEncodation = 0;
  static const c40Encodation = 1;
  static const textEncodation = 2;
  static const x12Encodation = 3;
  static const edifactEncodation = 4;
  static const base256Encodation = 5;

  static const _maxInt = 0x7fffffff;

  static final _float32 = Float32List(1);

  HighLevelEncoder._();

  static int _randomize253State(int codewordPosition) {
    var pseudoRandom = ((149 * codewordPosition) % 253) + 1;
    var tempVariable = _pad + pseudoRandom;
    return tempVariable <= 254 ? tempVariable : tempVariable - 254;
  }

  /// Performs message encoding of a DataMatrix message using the algorithm described in annex P
  /// of ISO/IEC 16022:2000(E).
  ///
  /// @param msg     the message
  /// @param shape   requested shape. May be {@code SymbolShapeHint.FORCE_NONE},
  ///                {SymbolShapeHint.FORCE_SQUARE} or {@code SymbolShapeHint.FORCE_RECTANGLE}.
  /// @param minSize the minimum symbol size constraint or null for no constraint
  /// @param maxSize the maximum symbol size constraint or null for no constraint
  /// @param forceC40 enforce C40 encoding
  /// @return the encoded message (the char values range from 0 to 255)
  static String encodeHighLevel(String msg,
      {SymbolShapeHint shape = SymbolShapeHint.forceNone,
      Dimension? minSize,
      Dimension? maxSize,
      bool forceC40 = false}) {
    //the codewords 0..255 are encoded as Unicode characters
    var c40Encoder = C40Encoder();
    var encoders = <Encoder>[
      ASCIIEncoder(),
      c40Encoder,
      TextEncoder(),
      X12Encoder(),
      EdifactEncoder(),
      Base256Encoder()
    ];

    var context = EncoderContext(msg);
    context.symbolShape = shape;
    context.setSizeConstraints(minSize, maxSize);

    if (msg.startsWith(macro05Header) && msg.endsWith(macroTrailer)) {
      context.writeCodeword(_macro05);
      context.skipAtEnd = 2;
      context.pos += macro05Header.length;
    } else if (msg.startsWith(macro06Header) && msg.endsWith(macroTrailer)) {
      context.writeCodeword(_macro06);
      context.skipAtEnd = 2;
      context.pos += macro06Header.length;
    }

    var encodingMode = asciiEncodation; //Default mode

    if (forceC40) {
      c40Encoder.encodeMaximal(context);
      encodingMode = context.newEncoding;
      context.resetEncoderSignal();
    }

    while (context.hasMoreCharacters) {
      encoders[encodingMode].encode(context);
      if (context.newEncoding >= 0) {
        encodingMode = context.newEncoding;
        context.resetEncoderSignal();
      }
    }
    var len = context.codewordCount;
    context.updateSymbolInfo();
    var capacity = context.symbolInfo.dataCapacity;
    if (len < capacity &&
        encodingMode != asciiEncodation &&
        encodingMode != base256Encodation &&
        encodingMode != edifactEncodation) {
      context.writeCodeword(0xfe); //Unlatch (254)
    }
    //Padding
    var codewords = context.codewords;
    if (codewords.length < capacity) {
      codewords.writeCharCode(_pad);
    }
    while (codewords.length < capacity) {
      codewords.writeCharCode(_randomize253State(codewords.length + 1));
    }

    return context.codewords.toString();
  }

  static int lookAheadTest(String msg, int startpos, int currentMode) {
    var newMode = lookAheadTestIntern(msg, startpos, currentMode);
    if (currentMode == x12Encodation && newMode == x12Encodation) {
      var endpos = math.min(startpos + 3, msg.length);
      for (var i = startpos; i < endpos; i++) {
        if (!isNativeX12(msg.codeUnitAt(i))) {
          return asciiEncodation;
        }
      }
    } else if (currentMode == edifactEncodation &&
        newMode == edifactEncodation) {
      var endpos = math.min(startpos + 4, msg.length);
      for (var i = startpos; i < endpos; i++) {
        if (!isNativeEDIFACT(msg.codeUnitAt(i))) {
          return asciiEncodation;
        }
      }
    }
    return newMode;
  }

  static int lookAheadTestIntern(String msg, int startpos, int currentMode) {
    if (startpos >= msg.length) {
      return currentMode;
    }
    Float32List charCounts;
    //step J
    if (currentMode == asciiEncodation) {
      charCounts = Float32List.fromList([0, 1, 1, 1, 1, 1.25]);
    } else {
      charCounts = Float32List.fromList([1, 2, 2, 2, 2, 2.25]);
      charCounts[currentMode] = 0;
    }

    var charsProcessed = 0;
    var mins = Int8List(6);
    var intCharCounts = Int32List(6);
    while (true) {
      //step K
      if ((startpos + charsProcessed) == msg.length) {
        mins.fillRange(0, mins.length, 0);
        intCharCounts.fillRange(0, intCharCounts.length, 0);
        var min = _findMinimums(charCounts, intCharCounts, _maxInt, mins);
        var minCount = _getMinimumCount(mins);

        if (intCharCounts[asciiEncodation] == min) {
          return asciiEncodation;
        }
        if (minCount == 1) {
          if (mins[base256Encodation] > 0) {
            return base256Encodation;
          }
          if (mins[edifactEncodation] > 0) {
            return edifactEncodation;
          }
          if (mins[textEncodation] > 0) {
            return textEncodation;
          }
          if (mins[x12Encodation] > 0) {
            return x12Encodation;
          }
        }
        return c40Encodation;
      }

      var c = msg.codeUnitAt(startpos + charsProcessed);
      charsProcessed++;

      //step L
      if (isDigit(c)) {
        charCounts[asciiEncodation] += 0.5;
      } else if (isExtendedASCII(c)) {
        charCounts[asciiEncodation] =
            charCounts[asciiEncodation].ceilToDouble();
        charCounts[asciiEncodation] += 2.0;
      } else {
        charCounts[asciiEncodation] =
            charCounts[asciiEncodation].ceilToDouble();
        charCounts[asciiEncodation]++;
      }

      //step M
      if (isNativeC40(c)) {
        charCounts[c40Encodation] += _float(2.0 / 3.0);
      } else if (isExtendedASCII(c)) {
        charCounts[c40Encodation] += _float(8.0 / 3.0);
      } else {
        charCounts[c40Encodation] += _float(4.0 / 3.0);
      }

      //step N
      if (isNativeText(c)) {
        charCounts[textEncodation] += _float(2.0 / 3.0);
      } else if (isExtendedASCII(c)) {
        charCounts[textEncodation] += _float(8.0 / 3.0);
      } else {
        charCounts[textEncodation] += _float(4.0 / 3.0);
      }

      //step O
      if (isNativeX12(c)) {
        charCounts[x12Encodation] += _float(2.0 / 3.0);
      } else if (isExtendedASCII(c)) {
        charCounts[x12Encodation] += _float(13.0 / 3.0);
      } else {
        charCounts[x12Encodation] += _float(10.0 / 3.0);
      }

      //step P
      if (isNativeEDIFACT(c)) {
        charCounts[edifactEncodation] += _float(3.0 / 4.0);
      } else if (isExtendedASCII(c)) {
        charCounts[edifactEncodation] += _float(17.0 / 4.0);
      } else {
        charCounts[edifactEncodation] += _float(13.0 / 4.0);
      }

      // step Q
      if (_isSpecialB256(c)) {
        charCounts[base256Encodation] += 4.0;
      } else {
        charCounts[base256Encodation]++;
      }

      //step R
      if (charsProcessed >= 4) {
        mins.fillRange(0, mins.length, 0);
        intCharCounts.fillRange(0, intCharCounts.length, 0);
        _findMinimums(charCounts, intCharCounts, _maxInt, mins);

        if (intCharCounts[asciiEncodation] <
            _min5(
                intCharCounts[base256Encodation],
                intCharCounts[c40Encodation],
                intCharCounts[textEncodation],
                intCharCounts[x12Encodation],
                intCharCounts[edifactEncodation])) {
          return asciiEncodation;
        }
        if (intCharCounts[base256Encodation] < intCharCounts[asciiEncodation] ||
            intCharCounts[base256Encodation] + 1 <
                _min4(
                    intCharCounts[c40Encodation],
                    intCharCounts[textEncodation],
                    intCharCounts[x12Encodation],
                    intCharCounts[edifactEncodation])) {
          return base256Encodation;
        }
        if (intCharCounts[edifactEncodation] + 1 <
            _min5(
                intCharCounts[base256Encodation],
                intCharCounts[c40Encodation],
                intCharCounts[textEncodation],
                intCharCounts[x12Encodation],
                intCharCounts[asciiEncodation])) {
          return edifactEncodation;
        }
        if (intCharCounts[textEncodation] + 1 <
            _min5(
                intCharCounts[base256Encodation],
                intCharCounts[c40Encodation],
                intCharCounts[edifactEncodation],
                intCharCounts[x12Encodation],
                intCharCounts[asciiEncodation])) {
          return textEncodation;
        }
        if (intCharCounts[x12Encodation] + 1 <
            _min5(
                intCharCounts[base256Encodation],
                intCharCounts[c40Encodation],
                intCharCounts[edifactEncodation],
                intCharCounts[textEncodation],
                intCharCounts[asciiEncodation])) {
          return x12Encodation;
        }
        if (intCharCounts[c40Encodation] + 1 <
            _min4(
                intCharCounts[asciiEncodation],
                intCharCounts[base256Encodation],
                intCharCounts[edifactEncodation],
                intCharCounts[textEncodation])) {
          if (intCharCounts[c40Encodation] < intCharCounts[x12Encodation]) {
            return c40Encodation;
          }
          if (intCharCounts[c40Encodation] == intCharCounts[x12Encodation]) {
            var p = startpos + charsProcessed + 1;
            while (p < msg.length) {
              var tc = msg.codeUnitAt(p);
              if (_isX12TermSep(tc)) {
                return x12Encodation;
              }
              if (!isNativeX12(tc)) {
                break;
              }
              p++;
            }
            return c40Encodation;
          }
        }
      }
    }
  }

  static double _float(double value) {
    _float32[0] = value;
    return _float32[0];
  }

  static int _min5(int f1, int f2, int f3, int f4, int f5) {
    return math.min(_min4(f1, f2, f3, f4), f5);
  }

  static int _min4(int f1, int f2, int f3, int f4) {
    return math.min(f1, math.min(f2, math.min(f3, f4)));
  }

  static int _findMinimums(
      Float32List charCounts, Int32List intCharCounts, int min, Int8List mins) {
    for (var i = 0; i < 6; i++) {
      var current = intCharCounts[i] = charCounts[i].ceil();
      if (min > current) {
        min = current;
        mins.fillRange(0, mins.length, 0);
      }
      if (min == current) {
        mins[i]++;
      }
    }
    return min;
  }

  static int _getMinimumCount(Int8List mins) {
    var minCount = 0;
    for (var i = 0; i < 6; i++) {
      minCount += mins[i];
    }
    return minCount;
  }

  static bool isDigit(int ch) {
    return ch >= $0 && ch <= $9;
  }

  static bool isExtendedASCII(int ch) {
    return ch >= 128 && ch <= 255;
  }

  static bool isNativeC40(int ch) {
    return (ch == $space) || (ch >= $0 && ch <= $9) || (ch >= $A && ch <= $Z);
  }

  static bool isNativeText(int ch) {
    return (ch == $space) || (ch >= $0 && ch <= $9) || (ch >= $a && ch <= $z);
  }

  static bool isNativeX12(int ch) {
    return _isX12TermSep(ch) ||
        (ch == $space) ||
        (ch >= $0 && ch <= $9) ||
        (ch >= $A && ch <= $Z);
  }

  static bool _isX12TermSep(int ch) {
    return (ch == $cr) //CR
        ||
        (ch == $asterisk) ||
        (ch == $gt);
  }

  static bool isNativeEDIFACT(int ch) {
    return ch >= $space && ch <= $caret;
  }

  static bool _isSpecialB256(int ch) {
    return false; //TODO NOT IMPLEMENTED YET!!!
  }

  /// Determines the number of consecutive characters that are encodable using numeric compaction.
  ///
  /// @param msg      the message
  /// @param startpos the start position within the message
  /// @return the requested character count
  static int determineConsecutiveDigitCount(String msg, int startpos) {
    var len = msg.length;
    var idx = startpos;
    while (idx < len && isDigit(msg.codeUnitAt(idx))) {
      idx++;
    }
    return idx - startpos;
  }

  static void illegalCharacter(int c) {
    var hex = c.toRadixString(16).padLeft(4, '0');
    throw ArgumentError(
        'Illegal character: ${String.fromCharCode(c)} (0x$hex)');
  }
}
