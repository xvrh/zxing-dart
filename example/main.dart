import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:zxing2/zxing2.dart';

void main() {
  var image = img.decodePng(File('tool/example.png').readAsBytesSync())!;

  LuminanceSource source = RGBLuminanceSource(
      image.width,
      image.height,
      image
          .convert(numChannels: 4)
          .getBytes(order: img.ChannelOrder.bgra)
          .buffer
          .asInt32List());
  var bitmap = BinaryBitmap(HybridBinarizer(source));

  // Tries all the supported formats: QR Code and the 1D formats (EAN, UPC, Code 128...)
  var reader = MultiFormatReader();
  var result = reader.decode(bitmap);
  print('${result.format}: ${result.text}');
}
