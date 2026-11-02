import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:zxing2/oned.dart';

void main() {
  var matrix =
      EAN13Writer().encode('5901234123457', BarcodeFormat.ean13, 300, 100);

  var image = img.Image(width: matrix.width, height: matrix.height);
  img.fill(image, color: img.ColorRgb8(0xFF, 0xFF, 0xFF));
  for (var x = 0; x < matrix.width; x++) {
    for (var y = 0; y < matrix.height; y++) {
      if (matrix.get(x, y)) {
        image.setPixelRgb(x, y, 0, 0, 0);
      }
    }
  }
  File('tool/examples/ean13.png').writeAsBytesSync(img.encodePng(image));
}
