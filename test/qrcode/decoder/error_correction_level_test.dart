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

import 'package:test/test.dart';
import 'package:zxing/src/qrcode/decoder/error_correction_level.dart';

void main() {
  test('For bits', () {
    expect(ErrorCorrectionLevel.forBits(0), ErrorCorrectionLevel.M);
    expect(ErrorCorrectionLevel.forBits(1), ErrorCorrectionLevel.L);
    expect(ErrorCorrectionLevel.forBits(2), ErrorCorrectionLevel.H);
    expect(ErrorCorrectionLevel.forBits(3), ErrorCorrectionLevel.Q);
  });

  test('Bad ECC level', () {
    expect(
        () => ErrorCorrectionLevel.forBits(4), throwsA(isA<ArgumentError>()));
  });
}
