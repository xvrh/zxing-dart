import 'encoder.dart';
import 'encoder_context.dart';
import 'high_level_encoder.dart';

class Base256Encoder implements Encoder {
  @override
  int get encodingMode {
    return HighLevelEncoder.base256Encodation;
  }

  @override
  void encode(EncoderContext context) {
    var buffer = <int>[];
    buffer.add(0); //Initialize length field
    while (context.hasMoreCharacters) {
      var c = context.currentChar;
      buffer.add(c);

      context.pos++;

      var newMode = HighLevelEncoder.lookAheadTest(
          context.message, context.pos, encodingMode);
      if (newMode != encodingMode) {
        // Return to ASCII encodation, which will actually handle latch to new mode
        context.signalEncoderChange(HighLevelEncoder.asciiEncodation);
        break;
      }
    }
    var dataCount = buffer.length - 1;
    var lengthFieldSize = 1;
    var currentSize = context.codewordCount + dataCount + lengthFieldSize;
    context.updateSymbolInfo(currentSize);
    var mustPad = (context.symbolInfo.dataCapacity - currentSize) > 0;
    if (context.hasMoreCharacters || mustPad) {
      if (dataCount <= 249) {
        buffer[0] = dataCount;
      } else if (dataCount <= 1555) {
        buffer[0] = (dataCount ~/ 250) + 249;
        buffer.insert(1, dataCount % 250);
      } else {
        throw StateError('Message length not in valid ranges: $dataCount');
      }
    }
    for (var i = 0, c = buffer.length; i < c; i++) {
      context.writeCodeword(
          _randomize255State(buffer[i], context.codewordCount + 1));
    }
  }

  static int _randomize255State(int ch, int codewordPosition) {
    var pseudoRandom = ((149 * codewordPosition) % 255) + 1;
    var tempVariable = ch + pseudoRandom;
    if (tempVariable <= 255) {
      return tempVariable;
    } else {
      return tempVariable - 256;
    }
  }
}
