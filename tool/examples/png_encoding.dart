import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

void main() {
  var qrcode = Encoder.encode('ABCDEF', ErrorCorrectionLevel.h);
  var matrix = qrcode.matrix!;
  var scale = 4;

  var image = img.Image(
      width: matrix.width * scale,
      height: matrix.height * scale,
      numChannels: 4);
  for (var x = 0; x < matrix.width; x++) {
    for (var y = 0; y < matrix.height; y++) {
      if (matrix.get(x, y) == 1) {
        img.fillRect(image,
            x1: x * scale,
            y1: y * scale,
            x2: x * scale + scale,
            y2: y * scale + scale,
            color: img.ColorRgba8(0, 0, 0, 0xFF));
      }
    }
  }
  var pngBytes = img.encodePng(image);
  File('tool/examples/encoded.png').writeAsBytes(pngBytes);
}
