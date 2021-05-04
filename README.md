# zxing-dart

ZXing ("zebra crossing") is an open-source, multi-format 1D/2D barcode image processing library.  
This package is a pure Dart port of the original Java library.

For now, it only supports **QR-Code** (encoding and decoding). New format can be added if this port proves useful.

## Getting started

### QR Code

#### Decoding

The `QRCodeReader` class takes a list of bytes and returns the decoded barcode.
```dart
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

void main() {
  var image = img.decodePng(File('tool/example.png').readAsBytesSync())!;

  LuminanceSource source = RGBLuminanceSource(image.width, image.height,
      image.getBytes(format: img.Format.abgr).buffer.asInt32List());
  var bitmap = BinaryBitmap(HybridBinarizer(source));

  var reader = QRCodeReader();
  var result = reader.decode(bitmap);
  print(result.text);
}
```

#### Encoding

The `QRCodeReader` class takes a list of bytes and returns the decoded barcode.
```dart
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
```

## Flutter
The `example` folder contains a full example that uses the official camera plugin connected to this
package to decode barcode from the bytes stream.
