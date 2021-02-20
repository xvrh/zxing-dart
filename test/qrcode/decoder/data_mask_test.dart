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

import 'package:test/test.dart';
import 'package:zxing/src/common/bit_matrix.dart';
import 'package:zxing/src/qrcode/decoder/data_mask.dart';

void main() {
  test('Mask0', () {
    testMaskAcrossDimensions(0, (i, j) => (i + j) % 2 == 0);
  });

  test('Mask1', () {
    testMaskAcrossDimensions(1, (i, j) => i % 2 == 0);
  });

  test('Mask2', () {
    testMaskAcrossDimensions(2, (i, j) => j % 3 == 0);
  });

  test('Mask3', () {
    testMaskAcrossDimensions(3, (i, j) => (i + j) % 3 == 0);
  });

  test('Mask4', () {
    testMaskAcrossDimensions(4, (i, j) {
      return (i ~/ 2 + j ~/ 3) % 2 == 0;
    });
  });

  test('Mask5', () {
    testMaskAcrossDimensions(5, (i, j) => (i * j) % 2 + (i * j) % 3 == 0);
  });

  test('Mask6', () {
    testMaskAcrossDimensions(6, (i, j) => ((i * j) % 2 + (i * j) % 3) % 2 == 0);
  });

  test('Mask7', () {
    testMaskAcrossDimensions(7, (i, j) => ((i + j) % 2 + (i * j) % 3) % 2 == 0);
  });
}

void testMaskAcrossDimensions(int reference, MaskCondition isMasked) {
  DataMask mask = DataMask.values[reference];
  for (int version = 1; version <= 40; version++) {
    int dimension = 17 + 4 * version;
    testMask(mask, dimension, isMasked);
  }
}

void testMask(DataMask mask, int dimension, MaskCondition isMasked) {
  BitMatrix bits = BitMatrix(dimension);
  mask.unmaskBitMatrix(bits, dimension);
  for (int i = 0; i < dimension; i++) {
    for (int j = 0; j < dimension; j++) {
      expect(bits.get(j, i), isMasked(i, j),
          reason: "($i,$j) Got ${bits.get(j, i)} expected ${isMasked(i, j)}");
    }
  }
}

typedef MaskCondition = bool Function(int i, int j);
