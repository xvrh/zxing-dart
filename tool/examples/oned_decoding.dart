import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:zxing2/zxing2.dart';

void main() {
  var image = img.decodePng(File('tool/examples/ean13.png').readAsBytesSync())!;

  LuminanceSource source = RGBLuminanceSource(
      image.width,
      image.height,
      image
          .convert(numChannels: 4)
          .getBytes(order: img.ChannelOrder.bgra)
          .buffer
          .asInt32List());
  var bitmap = BinaryBitmap(HybridBinarizer(source));

  // Restrict the formats to speed up decoding, or omit the hints to try all formats.
  var hints = DecodeHints()
    ..put(DecodeHintType.possibleFormats,
        [BarcodeFormat.ean13, BarcodeFormat.code128, BarcodeFormat.qrCode]);
  var result = MultiFormatReader().decode(bitmap, hints: hints);
  print('${result.format}: ${result.text}');
}
