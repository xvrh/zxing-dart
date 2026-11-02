import 'package:image/image.dart' as img;
import 'package:zxing2/datamatrix.dart';

void main() {
  var hints = EncodeHints()
    ..put(EncodeHintType.dataMatrixShape, SymbolShapeHint.forceSquare);
  var matrix = DataMatrixWriter()
      .encode('Hello zxing2', BarcodeFormat.dataMatrix, 160, 160, hints: hints);

  // Draw the code on a white margin: DataMatrixWriter doesn't add one.
  const margin = 20;
  var image = img.Image(
      width: matrix.width + 2 * margin, height: matrix.height + 2 * margin);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  for (var x = 0; x < matrix.width; x++) {
    for (var y = 0; y < matrix.height; y++) {
      if (matrix.get(x, y)) {
        image.setPixelRgb(x + margin, y + margin, 0, 0, 0);
      }
    }
  }

  var source = RGBLuminanceSource(
      image.width,
      image.height,
      image
          .convert(numChannels: 4)
          .getBytes(order: img.ChannelOrder.bgra)
          .buffer
          .asInt32List());
  var result = DataMatrixReader().decode(BinaryBitmap(HybridBinarizer(source)));
  print(result.text);
}
