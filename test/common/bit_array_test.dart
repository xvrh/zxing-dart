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

import 'dart:math';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';
import 'package:zxing/src/common/bit_array.dart';

void main() {
  test('GetSet', () {
    BitArray array = new BitArray(33);
    for (int i = 0; i < 33; i++) {
      expect(array.get(i), isFalse);
      array.set(i);
      expect(array.get(i), isTrue);
    }
  });

  test('GetNextSet1', () {
    BitArray array = new BitArray(32);
    for (int i = 0; i < array.size; i++) {
      expect(array.getNextSet(i), 32, reason: '$i');
    }
    array = new BitArray(33);
    for (int i = 0; i < array.size; i++) {
      expect(array.getNextSet(i), 33, reason: '$i');
    }
  });

  test('GetNextSet2', () {
    BitArray array = new BitArray(33);
    array.set(31);
    for (int i = 0; i < array.size; i++) {
      expect(array.getNextSet(i), i <= 31 ? 31 : 33);
    }
    array = new BitArray(33);
    array.set(32);
    for (int i = 0; i < array.size; i++) {
      expect(array.getNextSet(i), 32);
    }
  });

  test('GetNextSet3', () {
    BitArray array = new BitArray(63);
    array.set(31);
    array.set(32);
    for (int i = 0; i < array.size; i++) {
      int expected;
      if (i <= 31) {
        expected = 31;
      } else if (i == 32) {
        expected = 32;
      } else {
        expected = 63;
      }
      expect(array.getNextSet(i), expected);
    }
  });

  test('GetNextSet4', () {
    BitArray array = new BitArray(63);
    array.set(33);
    array.set(40);
    for (int i = 0; i < array.size; i++) {
      int expected;
      if (i <= 33) {
        expected = 33;
      } else if (i <= 40) {
        expected = 40;
      } else {
        expected = 63;
      }
      expect(array.getNextSet(i), expected);
    }
  });

  test('GetNextSet5', () {
    Random r = new Random(0xDEADBEEF);
    for (int i = 0; i < 10; i++) {
      BitArray array = new BitArray(1 + r.nextInt(100));
      int numSet = r.nextInt(20);
      for (int j = 0; j < numSet; j++) {
        array.set(r.nextInt(array.size));
      }
      int numQueries = r.nextInt(20);
      for (int j = 0; j < numQueries; j++) {
        int query = r.nextInt(array.size);
        int expected = query;
        while (expected < array.size && !array.get(expected)) {
          expected++;
        }
        int actual = array.getNextSet(query);
        expect(actual, expected);
      }
    }
  });

  test('Set bulk', () {
    BitArray array = new BitArray(64);
    array.setBulk(32, 0xFFFF0000);
    for (int i = 0; i < 48; i++) {
      expect(array.get(i), isFalse);
    }
    for (int i = 48; i < 64; i++) {
      expect(array.get(i), isTrue);
    }
  });

  test('Set range', () {
    BitArray array = new BitArray(64);
    array.setRange(28, 36);
    expect(array.get(27), isFalse);
    for (int i = 28; i < 36; i++) {
      expect(array.get(i), isTrue);
    }
    expect(array.get(36), isFalse);
  });

  test('Clear', () {
    BitArray array = new BitArray(32);
    for (int i = 0; i < 32; i++) {
      array.set(i);
    }
    array.clear();
    for (int i = 0; i < 32; i++) {
      expect(array.get(i), isFalse);
    }
  });

  test('Flip', () {
    BitArray array = new BitArray(32);
    expect(array.get(5), isFalse);
    array.flip(5);
    expect(array.get(5), isTrue);
    array.flip(5);
    expect(array.get(5), isFalse);
  });

  test('Get array', () {
    BitArray array = new BitArray(64);
    array.set(0);
    array.set(63);
    var ints = array.bitArray;
    expect(ints[0], 1);
    expect(ints[1], Int32.MIN_VALUE);
  });

  test('Is range', () {
    BitArray array = new BitArray(64);
    expect(array.isRange(0, 64, false), isTrue);
    expect(array.isRange(0, 64, true), isFalse);
    array.set(32);
    expect(array.isRange(32, 33, true), isTrue);
    array.set(31);
    expect(array.isRange(31, 33, true), isTrue);
    array.set(34);
    expect(array.isRange(31, 35, true), isFalse);
    for (int i = 0; i < 31; i++) {
      array.set(i);
    }
    expect(array.isRange(0, 33, true), isTrue);
    for (int i = 33; i < 64; i++) {
      array.set(i);
    }
    expect(array.isRange(0, 64, true), isTrue);
    expect(array.isRange(0, 64, false), isFalse);
  });

  test('Reverse algorithm', () {
    var oldBits = <int>[128, 256, 512, 6453324, 50934953];
    for (int size = 1; size < 160; size++) {
      var newBitsOriginal = _reverseOriginal(Int32List.fromList(oldBits), size);
      BitArray newBitArray =
          new BitArray.fromBits(Int32List.fromList(oldBits), size);
      newBitArray.reverse();
      var newBitsNew = newBitArray.bitArray;
      expect(
          _arraysAreEqual(newBitsOriginal, newBitsNew, size ~/ 32 + 1), isTrue);
    }
  });

  test('Clone', () {
    BitArray array = new BitArray(32);
    array.clone().set(0);
    expect(array.get(0), isFalse);
  });

  test('Equals', () {
    BitArray a = new BitArray(32);
    BitArray b = new BitArray(32);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(new BitArray(31)));
    a.set(16);
    expect(a, isNot(b));
    expect(a.hashCode, isNot(b.hashCode));
    b.set(16);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}

bool _arraysAreEqual(Int32List left, Int32List right, int size) {
  for (int i = 0; i < size; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}

bool _bitSet(List<int> bits, int i) {
  return (bits[i ~/ 32] & (1 << (i & 0x1F))) != 0;
}

Int32List _reverseOriginal(List<int> oldBits, int size) {
  Int32List newBits = Int32List(oldBits.length);
  for (int i = 0; i < size; i++) {
    if (_bitSet(oldBits, size - i - 1)) {
      newBits[i ~/ 32] |= 1 << (i & 0x1F);
    }
  }
  return newBits;
}
