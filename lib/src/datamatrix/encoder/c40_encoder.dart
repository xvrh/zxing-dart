import 'package:charcode/charcode.dart';
import 'encoder.dart';
import 'encoder_context.dart';
import 'high_level_encoder.dart';

class C40Encoder implements Encoder {
  @override
  int get encodingMode {
    return HighLevelEncoder.c40Encodation;
  }

  void encodeMaximal(EncoderContext context) {
    var buffer = <int>[];
    var lastCharSize = 0;
    var backtrackStartPosition = context.pos;
    var backtrackBufferLength = 0;
    while (context.hasMoreCharacters) {
      var c = context.currentChar;
      context.pos++;
      lastCharSize = encodeChar(c, buffer);
      if (buffer.length % 3 == 0) {
        backtrackStartPosition = context.pos;
        backtrackBufferLength = buffer.length;
      }
    }
    if (backtrackBufferLength != buffer.length) {
      var unwritten = (buffer.length ~/ 3) * 2;

      var curCodewordCount =
          context.codewordCount + unwritten + 1; // +1 for the latch to C40
      context.updateSymbolInfo(curCodewordCount);
      var available = context.symbolInfo.dataCapacity - curCodewordCount;
      var rest = buffer.length % 3;
      if ((rest == 2 && available != 2) ||
          (rest == 1 && (lastCharSize > 3 || available != 1))) {
        buffer.length = backtrackBufferLength;
        context.pos = backtrackStartPosition;
      }
    }
    if (buffer.isNotEmpty) {
      context.writeCodeword(HighLevelEncoder.latchToC40);
    }

    handleEOD(context, buffer);
  }

  @override
  void encode(EncoderContext context) {
    //step C
    var buffer = <int>[];
    while (context.hasMoreCharacters) {
      var c = context.currentChar;
      context.pos++;

      var lastCharSize = encodeChar(c, buffer);

      var unwritten = (buffer.length ~/ 3) * 2;

      var curCodewordCount = context.codewordCount + unwritten;
      context.updateSymbolInfo(curCodewordCount);
      var available = context.symbolInfo.dataCapacity - curCodewordCount;

      if (!context.hasMoreCharacters) {
        //Avoid having a single C40 value in the last triplet
        var removed = <int>[];
        if ((buffer.length % 3) == 2 && available != 2) {
          lastCharSize =
              _backtrackOneCharacter(context, buffer, removed, lastCharSize);
        }
        while (
            (buffer.length % 3) == 1 && (lastCharSize > 3 || available != 1)) {
          lastCharSize =
              _backtrackOneCharacter(context, buffer, removed, lastCharSize);
        }
        break;
      }

      var count = buffer.length;
      if ((count % 3) == 0) {
        var newMode = HighLevelEncoder.lookAheadTest(
            context.message, context.pos, encodingMode);
        if (newMode != encodingMode) {
          // Return to ASCII encodation, which will actually handle latch to new mode
          context.signalEncoderChange(HighLevelEncoder.asciiEncodation);
          break;
        }
      }
    }
    handleEOD(context, buffer);
  }

  int _backtrackOneCharacter(EncoderContext context, List<int> buffer,
      List<int> removed, int lastCharSize) {
    var count = buffer.length;
    buffer.removeRange(count - lastCharSize, count);
    context.pos--;
    var c = context.currentChar;
    lastCharSize = encodeChar(c, removed);
    context.resetSymbolInfo(); //Deal with possible reduction in symbol size
    return lastCharSize;
  }

  static void writeNextTriplet(EncoderContext context, List<int> buffer) {
    context.writeCodewords(_encodeToCodewords(buffer));
    buffer.removeRange(0, 3);
  }

  /// Handle "end of data" situations
  ///
  /// @param context the encoder context
  /// @param buffer  the buffer with the remaining encoded characters
  void handleEOD(EncoderContext context, List<int> buffer) {
    var unwritten = (buffer.length ~/ 3) * 2;
    var rest = buffer.length % 3;

    var curCodewordCount = context.codewordCount + unwritten;
    context.updateSymbolInfo(curCodewordCount);
    var available = context.symbolInfo.dataCapacity - curCodewordCount;

    if (rest == 2) {
      buffer.add(0); //Shift 1
      while (buffer.length >= 3) {
        writeNextTriplet(context, buffer);
      }
      if (context.hasMoreCharacters) {
        context.writeCodeword(HighLevelEncoder.c40Unlatch);
      }
    } else if (available == 1 && rest == 1) {
      while (buffer.length >= 3) {
        writeNextTriplet(context, buffer);
      }
      if (context.hasMoreCharacters) {
        context.writeCodeword(HighLevelEncoder.c40Unlatch);
      }
      // else no unlatch
      context.pos--;
    } else if (rest == 0) {
      while (buffer.length >= 3) {
        writeNextTriplet(context, buffer);
      }
      if (available > 0 || context.hasMoreCharacters) {
        context.writeCodeword(HighLevelEncoder.c40Unlatch);
      }
    } else {
      throw StateError('Unexpected case. Please report!');
    }
    context.signalEncoderChange(HighLevelEncoder.asciiEncodation);
  }

  int encodeChar(int c, List<int> sb) {
    if (c == $space) {
      sb.add(3);
      return 1;
    }
    if (c >= $0 && c <= $9) {
      sb.add(c - 48 + 4);
      return 1;
    }
    if (c >= $A && c <= $Z) {
      sb.add(c - 65 + 14);
      return 1;
    }
    if (c < $space) {
      sb.add(0); //Shift 1 Set
      sb.add(c);
      return 2;
    }
    if (c <= $slash) {
      sb.add(1); //Shift 2 Set
      sb.add(c - 33);
      return 2;
    }
    if (c <= $at) {
      sb.add(1); //Shift 2 Set
      sb.add(c - 58 + 15);
      return 2;
    }
    if (c <= $underscore) {
      sb.add(1); //Shift 2 Set
      sb.add(c - 91 + 22);
      return 2;
    }
    if (c <= 127) {
      sb.add(2); //Shift 3 Set
      sb.add(c - 96);
      return 2;
    }
    sb.addAll([1, 0x1e]); //Shift 2, Upper Shift
    var len = 2;
    len += encodeChar(c - 128, sb);
    return len;
  }

  static String _encodeToCodewords(List<int> sb) {
    var v = (1600 * sb[0]) + (40 * sb[1]) + sb[2] + 1;
    var cw1 = v ~/ 256;
    var cw2 = v % 256;
    return String.fromCharCodes([cw1, cw2]);
  }
}
