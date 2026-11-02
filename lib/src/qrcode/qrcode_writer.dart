import 'dart:math' as math;
import '../barcode_format.dart';
import '../common/bit_matrix.dart';
import '../encode_hint.dart';
import '../writer.dart';
import 'decoder/error_correction_level.dart';
import 'encoder/encoder.dart';
import 'encoder/qr_code.dart';

/// This object renders a QR Code as a BitMatrix 2D array of greyscale values.
///
/// The output includes the quiet zone (4 modules by default, see
/// [EncodeHintType.margin]) and is scaled up to the requested size.
///
/// @author dswitkin@google.com (Daniel Switkin)
class QRCodeWriter implements Writer {
  static const _quietZoneSize = 4;

  @override
  BitMatrix encode(String contents, BarcodeFormat format, int width, int height,
      {EncodeHints? hints}) {
    if (contents.isEmpty) {
      throw ArgumentError('Found empty contents');
    }

    if (format != BarcodeFormat.qrCode) {
      throw ArgumentError('Can only encode QR_CODE, but got $format');
    }

    if (width < 0 || height < 0) {
      throw ArgumentError(
          'Requested dimensions are too small: ${width}x$height');
    }

    var errorCorrectionLevel = ErrorCorrectionLevel.l;
    var quietZone = _quietZoneSize;
    if (hints != null) {
      var requestedLevel = hints.get(EncodeHintType.errorCorrection);
      if (requestedLevel != null) {
        errorCorrectionLevel = _parseErrorCorrectionLevel(requestedLevel);
      }
      var margin = hints.get(EncodeHintType.margin);
      if (margin != null) {
        quietZone = int.parse(margin.toString());
      }
    }

    var code = Encoder.encode(contents, errorCorrectionLevel, hints: hints);
    return renderResult(code, width, height, quietZone);
  }

  static ErrorCorrectionLevel _parseErrorCorrectionLevel(Object value) {
    if (value is ErrorCorrectionLevel) {
      return value;
    }
    var name = value.toString().toUpperCase();
    for (var level in [
      ErrorCorrectionLevel.l,
      ErrorCorrectionLevel.m,
      ErrorCorrectionLevel.q,
      ErrorCorrectionLevel.h,
    ]) {
      if (level.name == name) {
        return level;
      }
    }
    throw ArgumentError.value(value, 'errorCorrection');
  }

  /// Renders the given [QRCode] as a [BitMatrix], scaling the same to be compliant with the
  /// provided dimensions.
  ///
  /// If no scaling is required, both [width] and [height] arguments should be non-positive
  /// numbers. [quietZone] is the size of the quiet zone, in modules.
  ///
  /// Throws a [StateError] if [code] does not have a matrix.
  // Note that the input matrix uses 0 == white, 1 == black, while the output matrix
  // uses true == black.
  static BitMatrix renderResult(
      QRCode code, int width, int height, int quietZone) {
    var input = code.matrix;
    if (input == null) {
      throw StateError('QR code has no matrix');
    }
    var inputWidth = input.width;
    var inputHeight = input.height;
    var qrWidth = inputWidth + (quietZone * 2);
    var qrHeight = inputHeight + (quietZone * 2);
    var outputWidth = math.max(width, qrWidth);
    var outputHeight = math.max(height, qrHeight);

    var multiple = math.min(outputWidth ~/ qrWidth, outputHeight ~/ qrHeight);
    // Padding includes both the quiet zone and the extra white pixels to accommodate the requested
    // dimensions. For example, if input is 25x25 the QR will be 33x33 including the quiet zone.
    // If the requested size is 200x160, the multiple will be 4, for a QR of 132x132. These will
    // handle all the padding from 100x100 (the actual QR) up to 200x160.
    var leftPadding = (outputWidth - (inputWidth * multiple)) ~/ 2;
    var topPadding = (outputHeight - (inputHeight * multiple)) ~/ 2;

    var output = BitMatrix(outputWidth, outputHeight);

    for (var inputY = 0, outputY = topPadding;
        inputY < inputHeight;
        inputY++, outputY += multiple) {
      // Write the contents of this row of the barcode
      for (var inputX = 0, outputX = leftPadding;
          inputX < inputWidth;
          inputX++, outputX += multiple) {
        if (input.get(inputX, inputY) == 1) {
          output.setRegion(outputX, outputY, multiple, multiple);
        }
      }
    }

    return output;
  }
}
