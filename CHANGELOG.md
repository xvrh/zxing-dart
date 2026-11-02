## [0.3.0]

* Add 1D barcode readers ported from ZXing 3.5.4 (`package:zxing2/oned.dart`): UPC-A, UPC-E, EAN-8, EAN-13
  (with 2 and 5 digits UPC/EAN extensions), Code 39, Code 93, Code 128, ITF and Codabar.
* Add the matching 1D writers (`EAN13Writer`, `Code128Writer`...) and the `Writer` interface.
* Add `MultiFormatReader` to decode any supported format (1D and QR Code).
* Export `BitMatrix`, `BitArray` and `WriterException`.
* Add `DecodeHintType.alsoInverted`, `EncodeHintType.forceCodeSet`, `EncodeHintType.code128Compact`,
  `ResultMetadataType.symbologyIdentifier`, `DecodeHints.remove`, `DecodeHints.clone` and `BitMatrix.flipAll`.

## [0.2.4]

* Fix named overlay
* Added version property to be visible as a part of decoding

## [0.2.3]

* Expose NotFoundException, FormatReaderException and ChecksumException

## [0.2.2]

* Fix some lints

## [0.2.1]

* Fix some lints
* Require Dart >=3.0.0

## [0.2.0]

* Update tests to use `package:image` v4.x

## [0.1.1]

* Export `EncodeHints` from `qrcode.dart`

## [0.1.0]

* initial release.
