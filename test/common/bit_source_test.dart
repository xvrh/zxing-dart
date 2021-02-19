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

import 'package:test/test.dart';
import 'package:zxing/src/common/bit_source.dart';

void main() {
  test('Source', () {
    var bytes = Int8List.fromList([1, 2, 3, 4, 5]);
    BitSource source = new BitSource(bytes);
    expect(source.available(), 40);
    expect(source.readBits(1), 0);
    expect(source.available(), 39);
    expect(source.readBits(6), 0);
    expect(source.available(), 33);
    expect(source.readBits(1), 1);
    expect(source.available(), 32);
    expect(source.readBits(8), 2);
    expect(source.available(), 24);
    expect(source.readBits(10), 12);
    expect(source.available(), 14);
    expect(source.readBits(8), 16);
    expect(source.available(), 6);
    expect(source.readBits(6), 5);
    expect(source.available(), 0);
  });
}
