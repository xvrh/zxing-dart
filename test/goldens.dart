import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zxing2/zxing2.dart';
import 'image_luminance_source.dart';

void testGolden(
  String folder,
  Reader reader, {
  required int mustPassCount,
  int rotation = 0,
  List<String> skips = const [],
}) {
  test('Golden $folder', () {
    var passCount = 0;
    for (var pngFile in Directory(p.join('test/resources/blackbox', folder))
        .listSync()
        .whereType<File>()
        .where((f) => p.extension(f.path) == '.png')) {
      if (skips.contains(p.basename(pngFile.path))) {
        ++passCount;
        continue;
      }

      var image = img.decodePng(pngFile.readAsBytesSync())!;
      if (rotation != 0) {
        image = img.copyRotate(image, angle: rotation);
      }

      LuminanceSource source = ImageLuminanceSource(image);
      var bitmap = BinaryBitmap(HybridBinarizer(source));

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
      } on ReaderException catch (_) {
        //print('Failed to decode $folder/${pngFile.path} ($e)');
      }
    }

    expect(passCount, greaterThanOrEqualTo(mustPassCount));
  });
}
