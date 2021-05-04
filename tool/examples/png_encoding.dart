import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

void main() {
  var qrcode = Encoder.encode('ABCDEF', ErrorCorrectionLevel.h);
  var matrix = qrcode.matrix!;
  var scale = 4;

  var image = img.Image(matrix.width * scale, matrix.height * scale);
  for (var x = 0; x < matrix.width; x++) {
    for (var y = 0; y < matrix.height; y++) {
      if (matrix.get(x, y) == 1) {
        img.fillRect(image, x * scale, y * scale, x * scale + scale,
            y * scale + scale, 0xFF000000);
      }
    }
  }
  var pngBytes = img.encodePng(image);
  File('tool/examples/encoded.png').writeAsBytes(pngBytes);
}
