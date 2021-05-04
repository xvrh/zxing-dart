# zxing-dart

ZXing ("zebra crossing") is an open-source, multi-format 1D/2D barcode image processing library.  
This package is a pure Dart port of the original Java library.

For now, it only supports **QR-Code** (encoding and decoding). New format can easily be added if this port proves useful.

## Getting started

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
