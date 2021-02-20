/*
 * Copyright 2007 ZXing authors
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
import 'dart:math' as math;
import 'package:fixnum/fixnum.dart';
import 'package:meta/meta.dart';
import 'package:collection/collection.dart';
import 'package:zxing/src/common/bits.dart';

/// <p>A simple, fast array of bits, represented compactly by an array of ints internally.</p>
///
/// @author Sean Owen
class BitArray {
  Int32List _bits;
  int _size;

  factory BitArray([int? size]) {
    if (size == null) {
      return BitArray.fromBits(Int32List(1), 0);
    } else {
      return BitArray.fromBits(makeArray(size), size);
    }
  }

  // For testing only
  @visibleForTesting
  BitArray.fromBits(this._bits, this._size);

  int get size => _size;

  int get sizeInBytes {
    return (size + 7) ~/ 8;
  }

  void ensureCapacity(int size) {
    if (size > _bits.length * 32) {
      var newBits = makeArray(size);
      newBits.setRange(0, _bits.length, _bits);
      _bits = newBits;
    }
  }

  /// @param i bit to get
  /// @return true iff bit i is set
  bool get(int i) {
    return (_bits[i ~/ 32] & (1 << (i & 0x1F))) != 0;
  }

  /// Sets bit i.
  ///
  /// @param i bit to set
  void set(int i) {
    _bits[i ~/ 32] |= 1 << (i & 0x1F);
  }

  /// Flips bit i.
  ///
  /// @param i bit to set
  void flip(int i) {
    _bits[i ~/ 32] ^= 1 << (i & 0x1F);
  }

  /// @param from first bit to check
  /// @return index of first bit that is set, starting from the given index, or size if none are set
  ///  at or beyond this given index
  /// @see #getNextUnset(int)
  int getNextSet(int from) {
    if (from >= size) {
      return size;
    }
    int bitsOffset = from ~/ 32;
    int currentBits = _bits[bitsOffset];
    // mask off lesser bits first
    currentBits &= -(1 << (from & 0x1F));
    while (currentBits == 0) {
      if (++bitsOffset == _bits.length) {
        return size;
      }
      currentBits = _bits[bitsOffset];
    }

    int result = (bitsOffset * 32) + numberOfTrailingZerosInt32(currentBits);
    return math.min(result, size);
  }

  /// @param from index to start looking for unset bit
  /// @return index of next unset bit, or {@code size} if none are unset until the end
  /// @see #getNextSet(int)
  int getNextUnset(int from) {
    if (from >= size) {
      return size;
    }
    int bitsOffset = from ~/ 32;
    int currentBits = ~_bits[bitsOffset];
    // mask off lesser bits first
    currentBits &= -(1 << (from & 0x1F));
    while (currentBits == 0) {
      if (++bitsOffset == _bits.length) {
        return size;
      }
      currentBits = ~_bits[bitsOffset];
    }
    int result = (bitsOffset * 32) + numberOfTrailingZerosInt32(currentBits);
    return math.min(result, size);
  }

/// Sets a block of 32 bits, starting at bit i.
  ///
  /// @param i first bit to set
  /// @param newBits the new value of the next 32 bits. Note again that the least-significant bit
  /// corresponds to bit i, the next-least-significant to i+1, and so on.
  void setBulk(int i, int newBits) {
    _bits[i ~/ 32] = newBits;
  }

/// Sets a range of bits.
  ///
  /// @param start start of range, inclusive.
  /// @param end end of range, exclusive
  void setRange(int start, int end) {
    if (end < start || start < 0 || end > size) {
      throw ArgumentError();
    }
    if (end == start) {
      return;
    }
    end--; // will be easier to treat this as the last actually set bit -- inclusive
    int firstInt = start ~/ 32;
    int lastInt = end ~/ 32;
    for (int i = firstInt; i <= lastInt; i++) {
      int firstBit = i > firstInt ? 0 : start & 0x1F;
      int lastBit = i < lastInt ? 31 : end & 0x1F;
      // Ones from firstBit to lastBit, inclusive
      int mask = (2 << lastBit) - (1 << firstBit);
      _bits[i] |= mask;
    }
  }

/// Clears all bits (sets to false).
  void clear() {
    int max = _bits.length;
    for (int i = 0; i < max; i++) {
      _bits[i] = 0;
    }
  }

/// Efficient method to check if a range of bits is set, or not set.
  ///
  /// @param start start of range, inclusive.
  /// @param end end of range, exclusive
  /// @param value if true, checks that bits in range are set, otherwise checks that they are not set
  /// @return true iff all bits are set or not set in range, according to value argument
  /// @throws IllegalArgumentException if end is less than start or the range is not contained in the array
  bool isRange(int start, int end, bool value) {
    if (end < start || start < 0 || end > size) {
      throw ArgumentError();
    }
    if (end == start) {
      return true; // empty range matches
    }
    end--; // will be easier to treat this as the last actually set bit -- inclusive
    int firstInt = start ~/ 32;
    int lastInt = end ~/ 32;
    for (int i = firstInt; i <= lastInt; i++) {
      int firstBit = i > firstInt ? 0 : start & 0x1F;
      int lastBit = i < lastInt ? 31 : end & 0x1F;
      // Ones from firstBit to lastBit, inclusive
      int mask = (2 << lastBit) - (1 << firstBit);

      // Return false if we're looking for 1s and the masked bits[i] isn't all 1s (that is,
      // equals the mask, or we're looking for 0s and the masked portion is not all 0s
      if ((_bits[i] & mask) != (value ? mask : 0)) {
        return false;
      }
    }
    return true;
  }

  void appendBit(bool bit) {
    ensureCapacity(size + 1);
    if (bit) {
      _bits[size ~/ 32] |= 1 << (size & 0x1F);
    }
    _size++;
  }

/// Appends the least-significant bits, from value, in order from most-significant to
  /// least-significant. For example, appending 6 bits from 0x000001E will append the bits
  /// 0, 1, 1, 1, 1, 0 in that order.
  ///
  /// @param value {@code int} containing bits to append
  /// @param numBits bits from value to append
  void appendBits(int value, int numBits) {
    if (numBits < 0 || numBits > 32) {
      throw ArgumentError("Num bits must be between 0 and 32");
    }
    ensureCapacity(size + numBits);
    for (int numBitsLeft = numBits; numBitsLeft > 0; numBitsLeft--) {
      appendBit(((value >> (numBitsLeft - 1)) & 0x01) == 1);
    }
  }

  void appendBitArray(BitArray other) {
    int otherSize = other.size;
    ensureCapacity(size + otherSize);
    for (int i = 0; i < otherSize; i++) {
      appendBit(other.get(i));
    }
  }

  void xor(BitArray other) {
    if (size != other.size) {
      throw ArgumentError("Sizes don't match");
    }
    for (int i = 0; i < _bits.length; i++) {
      // The last int could be incomplete (i.e. not have 32 bits in
      // it) but there is no problem since 0 XOR 0 == 0.
      _bits[i] ^= other._bits[i];
    }
  }

///
  /// @param bitOffset first bit to start writing
  /// @param array array to write into. Bytes are written most-significant byte first. This is the opposite
  ///  of the internal representation, which is exposed by {@link #getBitArray()}
  /// @param offset position in array to start writing
  /// @param numBytes how many bytes to write
  void toBytes(int bitOffset, Int8List array, int offset, int numBytes) {
    for (int i = 0; i < numBytes; i++) {
      int theByte = 0;
      for (int j = 0; j < 8; j++) {
        if (get(bitOffset)) {
          theByte |= 1 << (7 - j);
        }
        bitOffset++;
      }
      array[offset + i] = theByte;
    }
  }

  /// @return underlying array of ints. The first element holds the first 32 bits, and the least
  ///         significant bit is bit 0.
  Int32List get bitArray {
    return _bits;
  }

  /// Reverses all bits in the array.
  void reverse() {
    Int32List newBits = Int32List(_bits.length);
    // reverse all int's first
    int len = (size - 1) ~/ 32;
    int oldBitsLen = len + 1;
    for (int i = 0; i < oldBitsLen; i++) {
      var x = Int32(_bits[i]);
      x = ((x >> 1) & 0x55555555) | ((x & 0x55555555) << 1);
      x = ((x >> 2) & 0x33333333) | ((x & 0x33333333) << 2);
      x = ((x >> 4) & 0x0f0f0f0f) | ((x & 0x0f0f0f0f) << 4);
      x = ((x >> 8) & 0x00ff00ff) | ((x & 0x00ff00ff) << 8);
      x = ((x >> 16) & 0x0000ffff) | ((x & 0x0000ffff) << 16);
      newBits[len - i] = x.toInt();
    }
    // now correct the int's if the bit size isn't a multiple of 32
    if (size != oldBitsLen * 32) {
      int leftOffset = oldBitsLen * 32 - size;
      var currentInt = Int32(newBits[0]).shiftRightUnsigned(leftOffset);
      for (int i = 1; i < oldBitsLen; i++) {
        var nextInt = Int32(newBits[i]);
        currentInt |= nextInt << (32 - leftOffset);
        newBits[i - 1] = currentInt.toInt();
        currentInt = nextInt.shiftRightUnsigned(leftOffset);
      }
      newBits[oldBitsLen - 1] = currentInt.toInt();
    }
    _bits = newBits;
  }

  static Int32List makeArray(int size) {
    return Int32List((size + 31) ~/ 32);
  }

  @override
  bool operator ==(Object other) {
    if (other is! BitArray) {
      return false;
    }
    return size == other.size &&
        const ListEquality().equals(_bits, other._bits);
  }

  @override
  int get hashCode {
    return 31 * size + const ListEquality().hash(_bits);
  }

  @override
  String toString() {
    var result = StringBuffer(size + (size / 8) + 1);
    for (int i = 0; i < size; i++) {
      if ((i & 0x07) == 0) {
        result.write(' ');
      }
      result.write(get(i) ? 'X' : '.');
    }
    return result.toString();
  }

  BitArray clone() {
    return BitArray.fromBits(Int32List(_bits.length)..setAll(0, _bits), size);
  }
}
