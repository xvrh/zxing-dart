import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

void main() {
  var hints = EncodeHints()
    ..put(EncodeHintType.errorCorrection, ErrorCorrectionLevel.h);
  var matrix = QRCodeWriter()
      .encode('ABCDEF', BarcodeFormat.qrCode, 200, 200, hints: hints);

  // Paint a white background: readers need the light margin around the code.
  var image = img.Image(width: matrix.width, height: matrix.height);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  for (var x = 0; x < matrix.width; x++) {
    for (var y = 0; y < matrix.height; y++) {
      if (matrix.get(x, y)) {
        image.setPixelRgb(x, y, 0, 0, 0);
      }
    }
  }
  File('tool/examples/encoded.png').writeAsBytesSync(img.encodePng(image));
}
