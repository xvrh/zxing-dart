import 'package:charcode/charcode.dart';
import 'c40_encoder.dart';
import 'encoder_context.dart';
import 'high_level_encoder.dart';

class X12Encoder extends C40Encoder {
  @override
  int get encodingMode {
    return HighLevelEncoder.x12Encodation;
  }

  @override
  void encode(EncoderContext context) {
    //step C
    var buffer = <int>[];
    while (context.hasMoreCharacters) {
      var c = context.currentChar;
      context.pos++;

      encodeChar(c, buffer);

      var count = buffer.length;
      if ((count % 3) == 0) {
        C40Encoder.writeNextTriplet(context, buffer);

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

  @override
  int encodeChar(int c, List<int> sb) {
    switch (c) {
      case $cr:
        sb.add(0);
      case $asterisk:
        sb.add(1);
      case $gt:
        sb.add(2);
      case $space:
        sb.add(3);
      default:
        if (c >= $0 && c <= $9) {
          sb.add(c - 48 + 4);
        } else if (c >= $A && c <= $Z) {
          sb.add(c - 65 + 14);
        } else {
          HighLevelEncoder.illegalCharacter(c);
        }
    }
    return 1;
  }

  @override
  void handleEOD(EncoderContext context, List<int> buffer) {
    context.updateSymbolInfo();
    var available = context.symbolInfo.dataCapacity - context.codewordCount;
    var count = buffer.length;
    context.pos -= count;
    if (context.remainingCharacters > 1 ||
        available > 1 ||
        context.remainingCharacters != available) {
      context.writeCodeword(HighLevelEncoder.x12Unlatch);
    }
    if (context.newEncoding < 0) {
      context.signalEncoderChange(HighLevelEncoder.asciiEncodation);
    }
  }
}
