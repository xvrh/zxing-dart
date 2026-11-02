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
import 'tool/examples/oned_decoding.dart';
```

### 1D barcodes

The readers and writers for each 1D format (`EAN13Reader`, `Code128Writer`...) are in `package:zxing2/oned.dart`.
```dart
import 'tool/examples/oned_encoding.dart';
```

### QR Code

#### Decoding

The `QRCodeReader` class takes a list of bytes and returns the decoded barcode.
```dart
import 'tool/examples/png_decoding.dart';
```

#### Encoding

The `QRCodeReader` class takes a list of bytes and returns the decoded barcode.
```dart
import 'tool/examples/png_encoding.dart';
```

## Flutter
The `example` folder contains a full example that uses the official camera plugin connected to this
package to decode barcode from the bytes stream.
