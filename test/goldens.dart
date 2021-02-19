import 'dart:io';

import 'package:test/test.dart';
import 'package:zxing/zxing.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

import 'image_luminance_source.dart';

void testGolden(
  String folder,
  Reader reader, {
  required int mustPassCount,
  int rotation = 0,
}) {
  test('Golden $folder', () {
    var passCount = 0;
    for (var pngFile in Directory(p.join('test/resources/blackbox', folder))
        .listSync()
        .whereType<File>()
        .where((f) => p.extension(f.path) == '.png')) {
      var image = img.decodePng(pngFile.readAsBytesSync())!;
      if (rotation != 0) {
        image = img.copyRotate(image, rotation);
      }

      LuminanceSource source = new ImageLuminanceSource(image);
      BinaryBitmap bitmap = new BinaryBitmap(new HybridBinarizer(source));

      try {
        var result = reader.decode(bitmap);

        var textFile = File(p.setExtension(pngFile.path, '.txt'));
        if (textFile.existsSync()) {
          var expected = textFile.readAsStringSync();
          expect(result.text, expected);
        } else {
          var binFile = File(p.setExtension(pngFile.path, '.bin'));
          var expected = binFile.readAsBytesSync();
          expect(result.rawBytes, expected.buffer.asInt8List());
        }
        ++passCount;
      } on ReaderException catch (e) {
        //print('Failed to decode $folder/${pngFile.path} ($e)');
      }
    }

    expect(passCount, greaterThanOrEqualTo(mustPassCount));
  });
}