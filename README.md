# zxing-dart

ZXing ("zebra crossing") is an open-source, multi-format 1D/2D barcode image processing library.  
This package is a pure Dart port of the original Java library.

Supported formats:

| Format                                       | Decoding | Encoding |
|----------------------------------------------|:--------:|:--------:|
| QR Code                                      |    ✓     |    ✓     |
| UPC-A, UPC-E, EAN-8, EAN-13                  |    ✓     |    ✓     |
| UPC/EAN 2 and 5 digits extensions            |    ✓     |          |
| Code 39, Code 93, Code 128                   |    ✓     |    ✓     |
| ITF (Interleaved 2 of 5)                     |    ✓     |    ✓     |
| Codabar                                      |    ✓     |    ✓     |

Data Matrix, Aztec, PDF 417, MaxiCode and RSS-14 / RSS Expanded are not ported yet.

[![pub package](https://img.shields.io/pub/v/zxing2.svg)](https://pub.dartlang.org/packages/zxing2)
[![Build Status](https://github.com/xvrh/zxing-dart/workflows/Build/badge.svg?branch=master)](https://github.com/xvrh/zxing-dart)
[![codecov](https://codecov.io/gh/xvrh/zxing-dart/graph/badge.svg?token=UGGAJMNLBC)](https://codecov.io/gh/xvrh/zxing-dart)

<a href="https://www.buymeacoffee.com/xvrh" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="60" width="217"></a>

## Getting started

### Any format

`MultiFormatReader` tries all the supported formats (or only the ones listed in
`DecodeHintType.possibleFormats`) and returns the first barcode found.
```dart
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
```

### 1D barcodes

The readers and writers for each 1D format (`EAN13Reader`, `Code128Writer`...) are in `package:zxing2/oned.dart`.
```dart
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
```

### QR Code

#### Decoding

The `QRCodeReader` class takes a list of bytes and returns the decoded barcode.
```dart
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

void main() {
  var image = img.decodePng(File('tool/example.png').readAsBytesSync())!;

  LuminanceSource source = RGBLuminanceSource(
      image.width,
      image.height,
      image
          .convert(numChannels: 4)
          .getBytes(order: img.ChannelOrder.abgr)
          .buffer
          .asInt32List());
  var bitmap = BinaryBitmap(GlobalHistogramBinarizer(source));

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
```

## Flutter
The `example` folder contains a full example that uses the official camera plugin connected to this
package to decode barcode from the bytes stream.
