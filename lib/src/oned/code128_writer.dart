import '../barcode_format.dart';
import '../encode_hint.dart';
import 'code128_reader.dart';
import 'one_dimensional_code_writer.dart';

// Results of minimal lookahead for code C
enum _CType { uncodable, oneDigit, twoDigits, fnc1 }

/// This object renders a CODE128 code as a {@link BitMatrix}.
///
/// @author erik.barbara@gmail.com (Erik Barbara)
class Code128Writer extends OneDimensionalCodeWriter {
  static const int _codeStartA = 103;
  static const int _codeStartB = 104;
  static const int _codeStartC = 105;
  static const int _codeCodeA = 101;
  static const int _codeCodeB = 100;
  static const int _codeCodeC = 99;
  static const int _codeStop = 106;

  // Dummy characters used to specify control characters in input
  static const int _escapeFnc1 = 0xf1;
  static const int _escapeFnc2 = 0xf2;
  static const int _escapeFnc3 = 0xf3;
  static const int _escapeFnc4 = 0xf4;

  static const int _codeFnc1 = 102; // Code A, Code B, Code C
  static const int _codeFnc2 = 97; // Code A, Code B
  static const int _codeFnc3 = 96; // Code A, Code B
  static const int _codeFnc4A = 101; // Code A
  static const int _codeFnc4B = 100; // Code B

  @override
  List<BarcodeFormat> get supportedWriteFormats =>
      const [BarcodeFormat.code128];

  @override
  List<bool> encodeContents(String contents, {EncodeHints? hints}) {
    var forcedCodeSet = _check(contents, hints);

    var hasCompactionHint = hints != null &&
        hints.contains(EncodeHintType.code128Compact) &&
        hints.get(EncodeHintType.code128Compact) == true;

    return hasCompactionHint
        ? _MinimalEncoder().encode(contents)
        : _encodeFast(contents, forcedCodeSet);
  }

  static int _check(String contents, EncodeHints? hints) {
    // Check for forced code set hint.
    var forcedCodeSet = -1;
    if (hints != null && hints.contains(EncodeHintType.forceCodeSet)) {
      var codeSetHint = hints.get(EncodeHintType.forceCodeSet).toString();
      switch (codeSetHint) {
        case 'A':
          forcedCodeSet = _codeCodeA;
        case 'B':
          forcedCodeSet = _codeCodeB;
        case 'C':
          forcedCodeSet = _codeCodeC;
        default:
          throw ArgumentError('Unsupported code set hint: $codeSetHint');
      }
    }

    // Check content
    var length = contents.length;
    for (var i = 0; i < length; i++) {
      var c = contents.codeUnitAt(i);
      // check for non ascii characters that are not special GS1 characters
      switch (c) {
        // special function characters
        case _escapeFnc1:
        case _escapeFnc2:
        case _escapeFnc3:
        case _escapeFnc4:
          break;
        // non ascii characters
        default:
          if (c > 127) {
            // no full Latin-1 character set available at the moment
            // shift and manual code change are not supported
            throw ArgumentError('Bad character in input: ASCII value=$c');
          }
      }
      // check characters for compatibility with forced code set
      switch (forcedCodeSet) {
        case _codeCodeA:
          // allows no ascii above 95 (no lower caps, no special symbols)
          if (c > 95 && c <= 127) {
            throw ArgumentError(
                'Bad character in input for forced code set A: ASCII value=$c');
          }
        case _codeCodeB:
          // allows no ascii below 32 (terminal symbols)
          if (c < 32) {
            throw ArgumentError(
                'Bad character in input for forced code set B: ASCII value=$c');
          }
        case _codeCodeC:
          // allows only numbers and no FNC 2/3/4
          if (c < 48 ||
              (c > 57 && c <= 127) ||
              c == _escapeFnc2 ||
              c == _escapeFnc3 ||
              c == _escapeFnc4) {
            throw ArgumentError(
                'Bad character in input for forced code set C: ASCII value=$c');
          }
      }
    }
    return forcedCodeSet;
  }

  static List<bool> _encodeFast(String contents, int forcedCodeSet) {
    var length = contents.length;

    var patterns = <List<int>>[]; // temporary storage for patterns
    var checkSum = 0;
    var checkWeight = 1;
    var codeSet = 0; // selected code (CODE_CODE_B or CODE_CODE_C)
    var position = 0; // position in contents

    while (position < length) {
      //Select code to use
      int newCodeSet;
      if (forcedCodeSet == -1) {
        newCodeSet = _chooseCode(contents, position, codeSet);
      } else {
        newCodeSet = forcedCodeSet;
      }

      //Get the pattern index
      int patternIndex;
      if (newCodeSet == codeSet) {
        // Encode the current character
        // First handle escapes
        switch (contents.codeUnitAt(position)) {
          case _escapeFnc1:
            patternIndex = _codeFnc1;
          case _escapeFnc2:
            patternIndex = _codeFnc2;
          case _escapeFnc3:
            patternIndex = _codeFnc3;
          case _escapeFnc4:
            if (codeSet == _codeCodeA) {
              patternIndex = _codeFnc4A;
            } else {
              patternIndex = _codeFnc4B;
            }
          default:
            // Then handle normal characters otherwise
            switch (codeSet) {
              case _codeCodeA:
                patternIndex = contents.codeUnitAt(position) - 0x20;
                if (patternIndex < 0) {
                  // everything below a space character comes behind the underscore in the code patterns table
                  patternIndex += 0x60;
                }
              case _codeCodeB:
                patternIndex = contents.codeUnitAt(position) - 0x20;
              default:
                // CODE_CODE_C
                if (position + 1 == length) {
                  // this is the last character, but the encoding is C, which always encodes two characers
                  throw ArgumentError(
                      'Bad number of characters for digit only encoding.');
                }
                patternIndex =
                    int.parse(contents.substring(position, position + 2));
                position++; // Also incremented below
            }
        }
        position++;
      } else {
        // Should we change the current code?
        // Do we have a code set?
        if (codeSet == 0) {
          // No, we don't have a code set
          switch (newCodeSet) {
            case _codeCodeA:
              patternIndex = _codeStartA;
            case _codeCodeB:
              patternIndex = _codeStartB;
            default:
              patternIndex = _codeStartC;
          }
        } else {
          // Yes, we have a code set
          patternIndex = newCodeSet;
        }
        codeSet = newCodeSet;
      }

      // Get the pattern
      patterns.add(Code128Reader.codePatterns[patternIndex]);

      // Compute checksum
      checkSum += patternIndex * checkWeight;
      if (position != 0) {
        checkWeight++;
      }
    }
    return _produceResult(patterns, checkSum);
  }

  static List<bool> _produceResult(List<List<int>> patterns, int checkSum) {
    // Compute and append checksum
    checkSum %= 103;
    if (checkSum < 0) {
      throw ArgumentError('Unable to compute a valid input checksum');
    }
    patterns.add(Code128Reader.codePatterns[checkSum]);

    // Append stop code
    patterns.add(Code128Reader.codePatterns[_codeStop]);

    // Compute code width
    var codeWidth = 0;
    for (var pattern in patterns) {
      for (var width in pattern) {
        codeWidth += width;
      }
    }

    // Compute result
    var result = List<bool>.filled(codeWidth, false);
    var pos = 0;
    for (var pattern in patterns) {
      pos += OneDimensionalCodeWriter.appendPattern(result, pos, pattern, true);
    }

    return result;
  }

  static _CType _findCType(String value, int start) {
    var last = value.length;
    if (start >= last) {
      return _CType.uncodable;
    }
    var c = value.codeUnitAt(start);
    if (c == _escapeFnc1) {
      return _CType.fnc1;
    }
    if (c < 0x30 || c > 0x39) {
      return _CType.uncodable;
    }
    if (start + 1 >= last) {
      return _CType.oneDigit;
    }
    c = value.codeUnitAt(start + 1);
    if (c < 0x30 || c > 0x39) {
      return _CType.oneDigit;
    }
    return _CType.twoDigits;
  }

  static int _chooseCode(String value, int start, int oldCode) {
    var lookahead = _findCType(value, start);
    if (lookahead == _CType.oneDigit) {
      if (oldCode == _codeCodeA) {
        return _codeCodeA;
      }
      return _codeCodeB;
    }
    if (lookahead == _CType.uncodable) {
      if (start < value.length) {
        var c = value.codeUnitAt(start);
        if (c < 0x20 ||
            (oldCode == _codeCodeA &&
                (c < 0x60 || (c >= _escapeFnc1 && c <= _escapeFnc4)))) {
          // can continue in code A, encodes ASCII 0 to 95 or FNC1 to FNC4
          return _codeCodeA;
        }
      }
      return _codeCodeB; // no choice
    }
    if (oldCode == _codeCodeA && lookahead == _CType.fnc1) {
      return _codeCodeA;
    }
    if (oldCode == _codeCodeC) {
      // can continue in code C
      return _codeCodeC;
    }
    if (oldCode == _codeCodeB) {
      if (lookahead == _CType.fnc1) {
        return _codeCodeB; // can continue in code B
      }
      // Seen two consecutive digits, see what follows
      lookahead = _findCType(value, start + 2);
      if (lookahead == _CType.uncodable || lookahead == _CType.oneDigit) {
        return _codeCodeB; // not worth switching now
      }
      if (lookahead == _CType.fnc1) {
        // two digits, then FNC_1...
        lookahead = _findCType(value, start + 3);
        if (lookahead == _CType.twoDigits) {
          // then two more digits, switch
          return _codeCodeC;
        } else {
          return _codeCodeB; // otherwise not worth switching
        }
      }
      // At this point, there are at least 4 consecutive digits.
      // Look ahead to choose whether to switch now or on the next round.
      var index = start + 4;
      while ((lookahead = _findCType(value, index)) == _CType.twoDigits) {
        index += 2;
      }
      if (lookahead == _CType.oneDigit) {
        // odd number of digits, switch later
        return _codeCodeB;
      }
      return _codeCodeC; // even number of digits, switch now
    }
    // Here oldCode == 0, which means we are choosing the initial code
    if (lookahead == _CType.fnc1) {
      // ignore FNC_1
      lookahead = _findCType(value, start + 1);
    }
    if (lookahead == _CType.twoDigits) {
      // at least two digits, start in code C
      return _codeCodeC;
    }
    return _codeCodeB;
  }
}

enum _Charset { a, b, c, none }

enum _Latch { a, b, c, shift, none }

/// Encodes minimally using Divide-And-Conquer with Memoization
class _MinimalEncoder {
  static final String _a = String.fromCharCodes([
    for (var c = 0x20; c < 0x60; c++) c,
    for (var c = 0x00; c < 0x20; c++) c,
    0xFF,
  ]);
  static final String _b = String.fromCharCodes([
    for (var c = 0x20; c < 0x80; c++) c,
    0xFF,
  ]);

  static const int _codeShift = 98;

  late List<List<int>> _memoizedCost;
  late List<List<_Latch>> _minPath;

  List<bool> encode(String contents) {
    _memoizedCost = List.generate(
        _Charset.values.length, (_) => List.filled(contents.length, 0));
    _minPath = List.generate(_Charset.values.length,
        (_) => List.filled(contents.length, _Latch.none));

    _encode(contents, _Charset.none, 0);

    var patterns = <List<int>>[];
    var checkSum = [0];
    var checkWeight = [1];
    var length = contents.length;
    var charset = _Charset.none;
    for (var i = 0; i < length; i++) {
      var latch = _minPath[charset.index][i];
      switch (latch) {
        case _Latch.a:
          charset = _Charset.a;
          _addPattern(
              patterns,
              i == 0 ? Code128Writer._codeStartA : Code128Writer._codeCodeA,
              checkSum,
              checkWeight,
              i);
        case _Latch.b:
          charset = _Charset.b;
          _addPattern(
              patterns,
              i == 0 ? Code128Writer._codeStartB : Code128Writer._codeCodeB,
              checkSum,
              checkWeight,
              i);
        case _Latch.c:
          charset = _Charset.c;
          _addPattern(
              patterns,
              i == 0 ? Code128Writer._codeStartC : Code128Writer._codeCodeC,
              checkSum,
              checkWeight,
              i);
        case _Latch.shift:
          _addPattern(patterns, _codeShift, checkSum, checkWeight, i);
        case _Latch.none:
          break;
      }
      if (charset == _Charset.c) {
        if (contents.codeUnitAt(i) == Code128Writer._escapeFnc1) {
          _addPattern(
              patterns, Code128Writer._codeFnc1, checkSum, checkWeight, i);
        } else {
          _addPattern(patterns, int.parse(contents.substring(i, i + 2)),
              checkSum, checkWeight, i);
          assert(i + 1 <
              length); //the algorithm never leads to a single trailing digit in character set C
          if (i + 1 < length) {
            i++;
          }
        }
      } else {
        // charset A or B
        int patternIndex;
        switch (contents.codeUnitAt(i)) {
          case Code128Writer._escapeFnc1:
            patternIndex = Code128Writer._codeFnc1;
          case Code128Writer._escapeFnc2:
            patternIndex = Code128Writer._codeFnc2;
          case Code128Writer._escapeFnc3:
            patternIndex = Code128Writer._codeFnc3;
          case Code128Writer._escapeFnc4:
            if (charset == _Charset.a && latch != _Latch.shift ||
                charset == _Charset.b && latch == _Latch.shift) {
              patternIndex = Code128Writer._codeFnc4A;
            } else {
              patternIndex = Code128Writer._codeFnc4B;
            }
          default:
            patternIndex = contents.codeUnitAt(i) - 0x20;
        }
        if ((charset == _Charset.a && latch != _Latch.shift ||
                charset == _Charset.b && latch == _Latch.shift) &&
            patternIndex < 0) {
          patternIndex += 0x60;
        }
        _addPattern(patterns, patternIndex, checkSum, checkWeight, i);
      }
    }
    _memoizedCost = const [];
    _minPath = const [];
    return Code128Writer._produceResult(patterns, checkSum[0]);
  }

  static void _addPattern(List<List<int>> patterns, int patternIndex,
      List<int> checkSum, List<int> checkWeight, int position) {
    patterns.add(Code128Reader.codePatterns[patternIndex]);
    if (position != 0) {
      checkWeight[0]++;
    }
    checkSum[0] += patternIndex * checkWeight[0];
  }

  static bool _isDigit(int c) {
    return c >= 0x30 && c <= 0x39;
  }

  bool _canEncode(String contents, _Charset charset, int position) {
    var c = contents.codeUnitAt(position);
    switch (charset) {
      case _Charset.a:
        return c == Code128Writer._escapeFnc1 ||
            c == Code128Writer._escapeFnc2 ||
            c == Code128Writer._escapeFnc3 ||
            c == Code128Writer._escapeFnc4 ||
            _a.contains(String.fromCharCode(c));
      case _Charset.b:
        return c == Code128Writer._escapeFnc1 ||
            c == Code128Writer._escapeFnc2 ||
            c == Code128Writer._escapeFnc3 ||
            c == Code128Writer._escapeFnc4 ||
            _b.contains(String.fromCharCode(c));
      case _Charset.c:
        return c == Code128Writer._escapeFnc1 ||
            (position + 1 < contents.length &&
                _isDigit(c) &&
                _isDigit(contents.codeUnitAt(position + 1)));
      case _Charset.none:
        return false;
    }
  }

  /// Encode the string starting at position position starting with the character set charset
  int _encode(String contents, _Charset charset, int position) {
    assert(position < contents.length);
    var mCost = _memoizedCost[charset.index][position];
    if (mCost > 0) {
      return mCost;
    }

    var minCost = _maxInt;
    var minLatch = _Latch.none;
    var atEnd = position + 1 >= contents.length;

    var sets = [_Charset.a, _Charset.b];
    for (var i = 0; i <= 1; i++) {
      if (_canEncode(contents, sets[i], position)) {
        var cost = 1;
        var latch = _Latch.none;
        if (charset != sets[i]) {
          cost++;
          latch = _Latch.values[sets[i].index];
        }
        if (!atEnd) {
          cost += _encode(contents, sets[i], position + 1);
        }
        if (cost < minCost) {
          minCost = cost;
          minLatch = latch;
        }
        cost = 1;
        if (charset == sets[(i + 1) % 2]) {
          cost++;
          latch = _Latch.shift;
          if (!atEnd) {
            cost += _encode(contents, charset, position + 1);
          }
          if (cost < minCost) {
            minCost = cost;
            minLatch = latch;
          }
        }
      }
    }
    if (_canEncode(contents, _Charset.c, position)) {
      var cost = 1;
      var latch = _Latch.none;
      if (charset != _Charset.c) {
        cost++;
        latch = _Latch.c;
      }
      var advance =
          contents.codeUnitAt(position) == Code128Writer._escapeFnc1 ? 1 : 2;
      if (position + advance < contents.length) {
        cost += _encode(contents, _Charset.c, position + advance);
      }
      if (cost < minCost) {
        minCost = cost;
        minLatch = latch;
      }
    }
    if (minCost == _maxInt) {
      throw ArgumentError(
          'Bad character in input: ASCII value=${contents.codeUnitAt(position)}');
    }
    _memoizedCost[charset.index][position] = minCost;
    _minPath[charset.index][position] = minLatch;
    return minCost;
  }

  static const int _maxInt = 0x7fffffff;
}
