import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:zxing2/multi.dart';

void main() {
  var image = img.decodePng(File('tool/examples/multi.png').readAsBytesSync())!;

  LuminanceSource source = RGBLuminanceSource(
      image.width,
      image.height,
      image
          .convert(numChannels: 4)
          .getBytes(order: img.ChannelOrder.bgra)
          .buffer
          .asInt32List());
  var bitmap = BinaryBitmap(HybridBinarizer(source));

  for (var result in QRCodeMultiReader().decodeMultiple(bitmap)) {
    print(result.text);
  }

  // Works with any reader, for example to find barcodes of different formats
  for (var result in GenericMultipleBarcodeReader(MultiFormatReader())
      .decodeMultiple(bitmap)) {
    print('${result.format}: ${result.text}');
  }
}
