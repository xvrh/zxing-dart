import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zxing/src/binary_bitmap.dart';
import 'package:zxing/src/common/hybrid_binarizer.dart';
import 'package:zxing/src/decode_hint.dart';
import 'package:zxing/src/luminance_source.dart';
import 'package:zxing/src/qrcode/qrcode_reader.dart';

import '../image_luminance_source.dart';
import 'package:image/image.dart' as img;

void main() {
  var qrReader = QRCodeReader();

  for (Directory directory in Directory('test/resources/blackbox')
      .listSync()
      .whereType<Directory>()
      .where((d) => p.basename(d.path).startsWith('qrcode-'))) {
    for (var pngFile in directory
        .listSync()
        .whereType<File>()
        .where((f) => p.extension(f.path) == '.png')) {
      test('${pngFile.path}', () {
        //TODO(xha): .bin and .metadata.txt
        var metadataFile = File(p.setExtension(pngFile.path, '.txt'));
        var expected = metadataFile.readAsStringSync();

        //TODO(xha): use int mustPassCount, int tryHarderCount, maxMisreads, maxTryHarderMisreads, float rotation

        //TODO(xha): loop: one normal and one with Hint tryHarder

        var image = img.decodePng(pngFile.readAsBytesSync())!;

        LuminanceSource source = new ImageLuminanceSource(image);
        BinaryBitmap bitmap = new BinaryBitmap(new HybridBinarizer(source));

        var result = qrReader.decode(bitmap, hints: Hints());

        expect(result.text, expected);
      });
    }
  }
}
