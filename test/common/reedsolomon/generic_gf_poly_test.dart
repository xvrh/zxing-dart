/*
 * Copyright 2018 ZXing authors
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
import 'package:zxing/src/common/reedsolomon/generic_gf.dart';
import 'package:zxing/src/common/reedsolomon/generic_gf_poly.dart';

final _field = GenericGF.QR_CODE_FIELD_256;

void main() {
  test('Polynomial string', () {
    expect(_field.zero.toString(), "0");
    expect(_field.buildMonomial(0, -1).toString(), "-1");
    GenericGFPoly p =
        GenericGFPoly(_field, Int32List.fromList([3, 0, -2, 1, 1]));
    expect(p.toString(), "a^25x^4 - ax^2 + x + 1");
    p = GenericGFPoly(_field, Int32List.fromList([3]));
    expect(p.toString(), "a^25");
  });

  test('Zero', () {
    expect(_field.buildMonomial(1, 0), _field.zero);
    expect(_field.buildMonomial(1, 2).multiplyScalar(0), _field.zero);
  });

  test('Evaluate', () {
    expect(_field.buildMonomial(0, 3).evaluateAt(0), 3);
  });
}
