## [0.2.5]

* Fix decoding of non-ASCII text: UTF-8 and other byte-mode content was returned as `�` (#21)
* Decode Shift_JIS (byte and Kanji mode) and GB2312 (Hanzi mode) with bundled codecs, which were decoded as ASCII
* Add codecs for ISO-8859-2 to 16, windows-125x, Cp437 and UTF-16BE, which were decoded as Latin-1, ASCII or UTF-8
* Handle FNC1 (GS1) in alphanumeric mode, which failed an assertion
* Fix structured append sequence number and parity, which were swapped
* `Encoder.encode` uses UTF-8 (with an ECI segment) for text that doesn't fit in ISO-8859-1, instead of throwing
* Throw `WriterException` when the text can't be encoded in the requested character set
* Add `QRCodeWriter`, which renders a `BitMatrix` with a quiet zone and supports the `margin` and `errorCorrection` hints (#23)
* Export `PlanarYUVLuminanceSource`, to decode camera frames without converting them to RGB, and give it named crop parameters
* Export `BitMatrix`, `ByteMatrix`, `Writer` and `WriterException`
* Fix the README examples: use the BGRA byte order for `RGBLuminanceSource`, and render encoded codes on a white background

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
