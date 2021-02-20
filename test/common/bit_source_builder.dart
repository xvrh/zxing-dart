/*
 * Copyright 2008 ZXing authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

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
      int bitsToWriteNow = _bitsLeftInNextByte;
      int numRestOfBits = numBits - bitsToWriteNow;
      int mask = 0xFF >> (8 - bitsToWriteNow);
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
