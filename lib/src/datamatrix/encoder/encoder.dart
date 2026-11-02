import 'encoder_context.dart';

abstract class Encoder {
  int get encodingMode;

  void encode(EncoderContext context);
}
