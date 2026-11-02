# zxing-dart

ZXing ("zebra crossing") is an open-source, multi-format 1D/2D barcode image processing library.  
This package is a pure Dart port of the original Java library.

Supported formats:

| Format                                       | Decoding | Encoding |
|----------------------------------------------|:--------:|:--------:|
| QR Code                                      |    ✓     |    ✓     |
| Data Matrix                                  |    ✓     |    ✓     |
| UPC-A, UPC-E, EAN-8, EAN-13                  |    ✓     |    ✓     |
| UPC/EAN 2 and 5 digits extensions            |    ✓     |          |
| Code 39, Code 93, Code 128                   |    ✓     |    ✓     |
| ITF (Interleaved 2 of 5)                     |    ✓     |    ✓     |
| Codabar                                      |    ✓     |    ✓     |

Aztec, PDF 417, MaxiCode and RSS-14 / RSS Expanded are not ported yet.

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

`QRCodeReader` decodes a `BinaryBitmap`, built from a `LuminanceSource` that wraps the image pixels.
`RGBLuminanceSource` takes one `0xAARRGGBB` int per pixel.
Flatten images with a transparent background onto white first: transparent pixels are read as black.

```dart
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

void main() {
  var image = img.decodeImage(File('tool/example.png').readAsBytesSync())!;

  // RGBLuminanceSource expects one 0xAARRGGBB int per pixel, which is the
  // BGRA byte order on little-endian platforms.
  LuminanceSource source = RGBLuminanceSource(
      image.width,
      image.height,
      image
          .convert(numChannels: 4)
          .getBytes(order: img.ChannelOrder.bgra)
          .buffer
          .asInt32List());
  var bitmap = BinaryBitmap(HybridBinarizer(source));

  var reader = QRCodeReader();
  var result = reader.decode(bitmap);
  print(result.text);
}
```

`decode` throws a `NotFoundException` when there is no QR code in the image.
`result.resultPoints` holds the position of the finder patterns (and of the alignment pattern, if found).

#### Encoding

`QRCodeWriter` returns a `BitMatrix` scaled to the requested size, with a white margin (the "quiet zone") around the code.
Use `EncodeHintType.margin` to change its size, in modules.

```dart
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
```

`Encoder.encode` gives the raw `QRCode` matrix, without margin or scaling.

#### Text encoding

Text that doesn't fit in ISO-8859-1 is encoded as UTF-8, with an ECI segment so readers know the character set.
Use `EncodeHintType.characterSet` to pick another one.

When decoding, the ECI segment of the QR code is used, or the character set is guessed (UTF-8, ISO-8859-1 or Shift_JIS).
Use `DecodeHintType.characterSet` to force one.
Codecs are bundled for UTF-8, UTF-16BE, ISO-8859-*, windows-125x, Cp437, Shift_JIS and GB2312.
For Big5 or EUC-KR, assign a codec, for example: `CharacterSetECI.Big5.encoding = myBig5Codec;`.

### Data Matrix

`DataMatrixReader` and `DataMatrixWriter` are in `package:zxing2/datamatrix.dart`.
The writer picks the smallest symbol that fits the text, square or rectangular: use `EncodeHintType.dataMatrixShape` to force one.
Unlike `QRCodeWriter`, it adds no quiet zone around the code.

```dart
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
```

With `EncodeHintType.dataMatrixCompact`, the writer uses the minimal encoder, which gives smaller symbols for mixed
content and encodes text outside ISO-8859-1 with an ECI.
Add `EncodeHintType.gs1Format` to it for GS1 data: an FNC1 is prepended, and the GS character (`\x1D`) in the text
marks the other FNC1 positions.

## Flutter

With the `camera` plugin, request YUV frames (`imageFormatGroup: ImageFormatGroup.yuv420`) and decode the first plane,
which holds the luminance:

```dart
Result? decodeCameraImage(CameraImage image) {
  var plane = image.planes.first;
  var source = PlanarYUVLuminanceSource(
      plane.bytes, plane.bytesPerRow, image.height,
      width: image.width);
  try {
    return QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)));
  } on NotFoundException {
    return null;
  }
}
```

Decoding is synchronous. For a live preview, run it outside the UI isolate, for example with `Isolate.run`.
