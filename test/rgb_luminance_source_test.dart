import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zxing/src/rgb_luminance_source.dart';

/// Tests {@link RGBLuminanceSource}.
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
    expect(
        source.getMatrix(),
        Int8List.fromList(
            [0x00, 0x7F, 0xFF, 0x3F, 0x7F, 0x3F, 0x3F, 0x7F, 0x3F]));
    var croppedFullWidth = source.crop(0, 1, 3, 2);
    expect(croppedFullWidth.getMatrix(),
        Int8List.fromList([0x3F, 0x7F, 0x3F, 0x3F, 0x7F, 0x3F]));
    var croppedCorner = source.crop(1, 1, 2, 2);
    expect(
        croppedCorner.getMatrix(), Int8List.fromList([0x7F, 0x3F, 0x7F, 0x3F]));
  });

  test('Get row', () {
    expect(source.getRow(2, Int8List(3)), [0x3F, 0x7F, 0x3F]);
  });

  test('ToString', () {
    expect(source.toString(), "#+ \n#+#\n#+#\n");
  });
}
