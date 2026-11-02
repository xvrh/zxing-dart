import 'package:charcode/charcode.dart';
import 'encoder.dart';
import 'encoder_context.dart';
import 'high_level_encoder.dart';

class EdifactEncoder implements Encoder {
  @override
  int get encodingMode {
    return HighLevelEncoder.edifactEncodation;
  }

  @override
  void encode(EncoderContext context) {
    //step F
    var buffer = <int>[];
    while (context.hasMoreCharacters) {
      var c = context.currentChar;
      _encodeChar(c, buffer);
      context.pos++;

      var count = buffer.length;
      if (count >= 4) {
        context.writeCodewords(_encodeToCodewords(buffer));
        buffer.removeRange(0, 4);

        var newMode = HighLevelEncoder.lookAheadTest(
            context.message, context.pos, encodingMode);
        if (newMode != encodingMode) {
          // Return to ASCII encodation, which will actually handle latch to new mode
          context.signalEncoderChange(HighLevelEncoder.asciiEncodation);
          break;
        }
      }
    }
    buffer.add(31); //Unlatch
    _handleEOD(context, buffer);
  }

  /// Handle "end of data" situations
  ///
  /// @param context the encoder context
  /// @param buffer  the buffer with the remaining encoded characters
  static void _handleEOD(EncoderContext context, List<int> buffer) {
    try {
      var count = buffer.length;
      if (count == 0) {
        return; //Already finished
      }
      if (count == 1) {
        //Only an unlatch at the end
        context.updateSymbolInfo();
        var available = context.symbolInfo.dataCapacity - context.codewordCount;
        var remaining = context.remainingCharacters;
        // The following two lines are a hack inspired by the 'fix' from https://sourceforge.net/p/barcode4j/svn/221/
        if (remaining > available) {
          context.updateSymbolInfo(context.codewordCount + 1);
          available = context.symbolInfo.dataCapacity - context.codewordCount;
        }
        if (remaining <= available && available <= 2) {
          return; //No unlatch
        }
      }

      if (count > 4) {
        throw StateError('Count must not exceed 4');
      }
      var restChars = count - 1;
      var encoded = _encodeToCodewords(buffer);
      var endOfSymbolReached = !context.hasMoreCharacters;
      var restInAscii = endOfSymbolReached && restChars <= 2;

      if (restChars <= 2) {
        context.updateSymbolInfo(context.codewordCount + restChars);
        var available = context.symbolInfo.dataCapacity - context.codewordCount;
        if (available >= 3) {
          restInAscii = false;
          context.updateSymbolInfo(context.codewordCount + encoded.length);
          //available = context.symbolInfo.dataCapacity - context.getCodewordCount();
        }
      }

      if (restInAscii) {
        context.resetSymbolInfo();
        context.pos -= restChars;
      } else {
        context.writeCodewords(encoded);
      }
    } finally {
      context.signalEncoderChange(HighLevelEncoder.asciiEncodation);
    }
  }

  static void _encodeChar(int c, List<int> sb) {
    if (c >= $space && c <= $question) {
      sb.add(c);
    } else if (c >= $at && c <= $caret) {
      sb.add(c - 64);
    } else {
      HighLevelEncoder.illegalCharacter(c);
    }
  }

  static String _encodeToCodewords(List<int> sb) {
    var len = sb.length;
    if (len == 0) {
      throw StateError('StringBuilder must not be empty');
    }
    var c1 = sb[0];
    var c2 = len >= 2 ? sb[1] : 0;
    var c3 = len >= 3 ? sb[2] : 0;
    var c4 = len >= 4 ? sb[3] : 0;

    var v = (c1 << 18) + (c2 << 12) + (c3 << 6) + c4;
    var cw1 = (v >> 16) & 255;
    var cw2 = (v >> 8) & 255;
    var cw3 = v & 255;
    var res = StringBuffer();
    res.writeCharCode(cw1);
    if (len >= 2) {
      res.writeCharCode(cw2);
    }
    if (len >= 3) {
      res.writeCharCode(cw3);
    }
    return res.toString();
  }
}
