# zxing-dart

ZXing ("zebra crossing") is an open-source, multi-format 1D/2D barcode image processing library.  
This package is a pure Dart port of the original Java library.

For now, it only supports **QR-Code** (encoding and decoding). New format can easily be added if this port proves useful.

## Getting started

### QR Code

#### Encoding
The `QRCodeReader` class takes a list of bytes and returns the decoded barcode.
```dart
// Example decode a png with the image package
```

For a Flutter example that uses a camera plugin, look at the `example/` folder.

#### Decoding
```dart
// Example encode a text to a qr code
```

For a Flutter widget that can draw this QR Code, look at the `example/` folder.


## Flutter
The `example` folder contains a full example that uses the official camera plugin connected to this
package to decode barcode from the bytes stream.

```dart
// Show camera plugin and callback to the library with compute()
```