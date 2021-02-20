import 'dart:typed_data';
import 'package:fixnum/fixnum.dart';

/// Class that lets one easily build an array of bytes by appending bits at a time.
///
/// @author Sean Owen
class BitSourceBuilder {
  final BytesBuilder output = BytesBuilder();
  int _nextByte = 0;
  int _bitsLeftInNextByte = 8;

  void write(int value, int numBits) {
    if (numBits <= _bitsLeftInNextByte) {
      _nextByte <<= numBits;
      _nextByte |= value;
      _bitsLeftInNextByte -= numBits;
      if (_bitsLeftInNextByte == 0) {
        output.addByte(_nextByte);
        _nextByte = 0;
        _bitsLeftInNextByte = 8;
      }
    } else {
      var bitsToWriteNow = _bitsLeftInNextByte;
      var numRestOfBits = numBits - bitsToWriteNow;
      var mask = 0xFF >> (8 - bitsToWriteNow);
      var valueToWriteNow =
          (Int32(value).shiftRightUnsigned(numRestOfBits)) & mask;
      write(valueToWriteNow.toInt(), bitsToWriteNow);
      write(value, numRestOfBits);
    }
  }

  Int8List toByteArray() {
    if (_bitsLeftInNextByte < 8) {
      write(0, _bitsLeftInNextByte);
    }
    return output.toBytes().buffer.asInt8List();
  }
}
