import 'encoder.dart';
import 'encoder_context.dart';
import 'high_level_encoder.dart';

class ASCIIEncoder implements Encoder {
  @override
  int get encodingMode {
    return HighLevelEncoder.asciiEncodation;
  }

  @override
  void encode(EncoderContext context) {
    //step B
    var n = HighLevelEncoder.determineConsecutiveDigitCount(
        context.message, context.pos);
    if (n >= 2) {
      context.writeCodeword(_encodeASCIIDigits(
          context.message.codeUnitAt(context.pos),
          context.message.codeUnitAt(context.pos + 1)));
      context.pos += 2;
    } else {
      var c = context.currentChar;
      var newMode = HighLevelEncoder.lookAheadTest(
          context.message, context.pos, encodingMode);
      if (newMode != encodingMode) {
        switch (newMode) {
          case HighLevelEncoder.base256Encodation:
            context.writeCodeword(HighLevelEncoder.latchToBase256);
            context.signalEncoderChange(HighLevelEncoder.base256Encodation);
            return;
          case HighLevelEncoder.c40Encodation:
            context.writeCodeword(HighLevelEncoder.latchToC40);
            context.signalEncoderChange(HighLevelEncoder.c40Encodation);
            return;
          case HighLevelEncoder.x12Encodation:
            context.writeCodeword(HighLevelEncoder.latchToAnsiX12);
            context.signalEncoderChange(HighLevelEncoder.x12Encodation);
          case HighLevelEncoder.textEncodation:
            context.writeCodeword(HighLevelEncoder.latchToText);
            context.signalEncoderChange(HighLevelEncoder.textEncodation);
          case HighLevelEncoder.edifactEncodation:
            context.writeCodeword(HighLevelEncoder.latchToEdifact);
            context.signalEncoderChange(HighLevelEncoder.edifactEncodation);
          default:
            throw StateError('Illegal mode: $newMode');
        }
      } else if (HighLevelEncoder.isExtendedASCII(c)) {
        context.writeCodeword(HighLevelEncoder.upperShift);
        context.writeCodeword(c - 128 + 1);
        context.pos++;
      } else {
        context.writeCodeword(c + 1);
        context.pos++;
      }
    }
  }

  static int _encodeASCIIDigits(int digit1, int digit2) {
    if (HighLevelEncoder.isDigit(digit1) && HighLevelEncoder.isDigit(digit2)) {
      var num = (digit1 - 48) * 10 + (digit2 - 48);
      return num + 130;
    }
    throw ArgumentError(
        'not digits: ${String.fromCharCode(digit1)}${String.fromCharCode(digit2)}');
  }
}
