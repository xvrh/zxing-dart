/*
 * Copyright 2014 ZXing authors
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
import 'package:zxing/src/rgb_luminance_source.dart';

/**
 * Tests {@link RGBLuminanceSource}.
 */
void main() {
  late RGBLuminanceSource source;

  setUp(() {
    source = RGBLuminanceSource(
      3,
      3,
      Int32List.fromList(<int>[
        0x000000, 0x7F7F7F, 0xFFFFFF,
        0xFF0000, 0x00FF00, 0x0000FF,
        0x0000FF, 0x00FF00, 0xFF0000, //
      ]),
    );
  });

  test('Crop', () {
    expect(source.isCropSupported, isTrue);
    var cropped = source.crop(1, 1, 1, 1);
    expect(cropped.height, 1);
    expect(cropped.width, 1);
    expect(cropped.getRow(0, null), [0x7F]);
  });

  test('Matrix', () {
    expect(source.getMatrix(),
        [0x00, 0x7F, 0xFF, 0x3F, 0x7F, 0x3F, 0x3F, 0x7F, 0x3F]);
    var croppedFullWidth = source.crop(0, 1, 3, 2);
    expect(croppedFullWidth.getMatrix(), [0x3F, 0x7F, 0x3F, 0x3F, 0x7F, 0x3F]);
    var croppedCorner = source.crop(1, 1, 2, 2);
    expect(croppedCorner.getMatrix(), [0x7F, 0x3F, 0x7F, 0x3F]);
  });

  test('Get row', () {
    expect(source.getRow(2, Uint8List(3)), [0x3F, 0x7F, 0x3F]);
  });

  test('ToString', () {
    expect(source.toString(), "#+ \n#+#\n#+#\n");
  });
}
