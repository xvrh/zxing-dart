import 'dart:typed_data';

class BlockPair {
  final Int8List dataBytes;
  final Int8List errorCorrectionBytes;

  BlockPair(this.dataBytes, this.errorCorrectionBytes);
}
