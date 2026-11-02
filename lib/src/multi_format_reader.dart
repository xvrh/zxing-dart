import 'barcode_format.dart';
import 'binary_bitmap.dart';
import 'datamatrix/data_matrix_reader.dart';
import 'decode_hint.dart';
import 'not_found_exception.dart';
import 'oned/multi_format_one_d_reader.dart';
import 'qrcode/qrcode_reader.dart';
import 'reader.dart';
import 'reader_exception.dart';
import 'result.dart';

/// MultiFormatReader is a convenience class and the main entry point into the library for most uses.
/// By default it attempts to decode all barcode formats that the library supports. Optionally, you
/// can provide a hints object to request different behavior, for example only decoding QR codes.
///
/// The supported formats are QR Code, Data Matrix and the 1D formats (UPC-A, UPC-E, EAN-8, EAN-13,
/// Code 39, Code 93, Code 128, ITF and Codabar).
///
/// @author Sean Owen
/// @author dswitkin@google.com (Daniel Switkin)
class MultiFormatReader implements Reader {
  DecodeHints? _hints;
  List<Reader>? _readers;

  /// Decode an image using the hints provided. Does not honor existing state.
  ///
  /// @param image The pixel data to decode
  /// @param hints The hints to use, clearing the previous state.
  /// @return The contents of the image
  /// @throws NotFoundException Any errors which occurred
  @override
  Result decode(BinaryBitmap image, {DecodeHints? hints}) {
    setHints(hints);
    return _decodeInternal(image);
  }

  /// Decode an image using the state set up by calling setHints() previously. Continuous scan
  /// clients will get a <b>large</b> speed increase by using this instead of decode().
  ///
  /// @param image The pixel data to decode
  /// @return The contents of the image
  /// @throws NotFoundException Any errors which occurred
  Result decodeWithState(BinaryBitmap image) {
    // Make sure to set up the default state so we don't crash
    if (_readers == null) {
      setHints(null);
    }
    return _decodeInternal(image);
  }

  /// This method adds state to the MultiFormatReader. By setting the hints once, subsequent calls
  /// to decodeWithState(image) can reuse the same set of readers without reallocating memory. This
  /// is important for performance in continuous scan clients.
  ///
  /// @param hints The set of hints to use for subsequent calls to decode(image)
  void setHints(DecodeHints? hints) {
    _hints = hints;

    var tryHarder = hints?.contains(DecodeHintType.tryHarder) ?? false;
    var formats = hints?.get(DecodeHintType.possibleFormats);
    var readers = <Reader>[];
    if (formats != null) {
      var addOneDReader = formats.contains(BarcodeFormat.upcA) ||
          formats.contains(BarcodeFormat.upcE) ||
          formats.contains(BarcodeFormat.ean13) ||
          formats.contains(BarcodeFormat.ean8) ||
          formats.contains(BarcodeFormat.codabar) ||
          formats.contains(BarcodeFormat.code39) ||
          formats.contains(BarcodeFormat.code93) ||
          formats.contains(BarcodeFormat.code128) ||
          formats.contains(BarcodeFormat.itf);
      // Put 1D readers upfront in "normal" mode
      if (addOneDReader && !tryHarder) {
        readers.add(MultiFormatOneDReader(hints));
      }
      if (formats.contains(BarcodeFormat.qrCode)) {
        readers.add(QRCodeReader());
      }
      if (formats.contains(BarcodeFormat.dataMatrix)) {
        readers.add(DataMatrixReader());
      }
      // At end in "try harder" mode
      if (addOneDReader && tryHarder) {
        readers.add(MultiFormatOneDReader(hints));
      }
    }
    if (readers.isEmpty) {
      if (!tryHarder) {
        readers.add(MultiFormatOneDReader(hints));
      }

      readers.add(QRCodeReader());
      readers.add(DataMatrixReader());

      if (tryHarder) {
        readers.add(MultiFormatOneDReader(hints));
      }
    }
    _readers = readers;
  }

  @override
  void reset() {
    var readers = _readers;
    if (readers != null) {
      for (var reader in readers) {
        reader.reset();
      }
    }
  }

  Result _decodeInternal(BinaryBitmap image) {
    var readers = _readers;
    if (readers != null) {
      for (var reader in readers) {
        try {
          return reader.decode(image, hints: _hints);
        } on ReaderException catch (_) {
          // continue
        }
      }
      var hints = _hints;
      if (hints != null && hints.contains(DecodeHintType.alsoInverted)) {
        // Calling all readers again with inverted image
        image.getBlackMatrix().flipAll();
        for (var reader in readers) {
          try {
            return reader.decode(image, hints: hints);
          } on ReaderException catch (_) {
            // continue
          }
        }
      }
    }
    throw NotFoundException();
  }
}
