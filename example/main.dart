import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

void main() {
  // Encode some text to a QR code, rendered with its white margin
  var matrix =
      QRCodeWriter().encode('Hello zxing2 👋', BarcodeFormat.qrCode, 200, 200);
  var image = img.Image(width: matrix.width, height: matrix.height);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  for (var x = 0; x < matrix.width; x++) {
    for (var y = 0; y < matrix.height; y++) {
      if (matrix.get(x, y)) {
        image.setPixelRgb(x, y, 0, 0, 0);
      }
    }
  }

  // Decode it back. RGBLuminanceSource expects 0xAARRGGBB ints, which is the
  // BGRA byte order on little-endian platforms.
  var source = RGBLuminanceSource(
      image.width,
      image.height,
      image
          .convert(numChannels: 4)
          .getBytes(order: img.ChannelOrder.bgra)
          .buffer
          .asInt32List());
  var bitmap = BinaryBitmap(HybridBinarizer(source));

  // Tries all the supported formats: QR Code, Data Matrix and the 1D formats (EAN, UPC, Code 128...)
  var result = MultiFormatReader().decode(bitmap);
  print('${result.format}: ${result.text}');
}
