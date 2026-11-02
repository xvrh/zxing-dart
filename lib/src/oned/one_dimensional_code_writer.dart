import 'dart:math' as math;
import '../barcode_format.dart';
import '../common/bit_matrix.dart';
import '../encode_hint.dart';
import '../writer.dart';

/// <p>Encapsulates functionality and implementation that is common to one-dimensional barcodes.</p>
///
/// @author dsbnatut@gmail.com (Kazuki Nishiura)
abstract class OneDimensionalCodeWriter implements Writer {
  static final _numeric = RegExp(r'^[0-9]+$');

  /// Encode the contents to boolean array expression of one-dimensional barcode.
  /// Start code and end code should be included in result, and side margins should not be included.
  ///
  /// Can be overwritten if the encode requires to read the hints map.
  ///
  /// @param contents barcode contents to encode
  /// @param hints encoding hints
  /// @return a {@code boolean[]} of horizontal pixels (false = white, true = black)
  List<bool> encodeContents(String contents, {EncodeHints? hints});

  /// Encode the contents following specified format.
  /// `width` and `height` are required size. This method may return bigger size
  /// `BitMatrix` when specified size is too small. The user can set both `width` and
  /// `height` to zero to get minimum size barcode. If negative value is set to `width`
  /// or `height`, `ArgumentError` is thrown.
  @override
  BitMatrix encode(String contents, BarcodeFormat format, int width, int height,
      {EncodeHints? hints}) {
    if (contents.isEmpty) {
      throw ArgumentError('Found empty contents');
    }

    if (width < 0 || height < 0) {
      throw ArgumentError(
          'Negative size is not allowed. Input: ${width}x$height');
    }
    var supportedFormats = supportedWriteFormats;
    if (supportedFormats != null && !supportedFormats.contains(format)) {
      throw ArgumentError('Can only encode $supportedFormats, but got $format');
    }

    var sidesMargin = defaultMargin;
    if (hints != null && hints.contains(EncodeHintType.margin)) {
      sidesMargin = int.parse(hints.get(EncodeHintType.margin).toString());
    }

    var code = encodeContents(contents, hints: hints);
    return _renderResult(code, width, height, sidesMargin);
  }

  List<BarcodeFormat>? get supportedWriteFormats => null;

  /// @return a byte array of horizontal pixels (0 = white, 1 = black)
  static BitMatrix _renderResult(
      List<bool> code, int width, int height, int sidesMargin) {
    var inputWidth = code.length;
    // Add quiet zone on both sides.
    var fullWidth = inputWidth + sidesMargin;
    var outputWidth = math.max(width, fullWidth);
    var outputHeight = math.max(1, height);

    var multiple = outputWidth ~/ fullWidth;
    var leftPadding = (outputWidth - (inputWidth * multiple)) ~/ 2;

    var output = BitMatrix(outputWidth, outputHeight);
    for (var inputX = 0, outputX = leftPadding;
        inputX < inputWidth;
        inputX++, outputX += multiple) {
      if (code[inputX]) {
        output.setRegion(outputX, 0, multiple, outputHeight);
      }
    }
    return output;
  }

  /// @param contents string to check for numeric characters
  /// @throws IllegalArgumentException if input contains characters other than digits 0-9.
  static void checkNumeric(String contents) {
    if (!_numeric.hasMatch(contents)) {
      throw ArgumentError('Input should only contain digits 0-9');
    }
  }

  /// @param target encode black/white pattern into this array
  /// @param pos position to start encoding at in {@code target}
  /// @param pattern lengths of black/white runs to encode
  /// @param startColor starting color - false for white, true for black
  /// @return the number of elements added to target.
  static int appendPattern(
      List<bool> target, int pos, List<int> pattern, bool startColor) {
    var color = startColor;
    var numAdded = 0;
    for (var len in pattern) {
      for (var j = 0; j < len; j++) {
        target[pos++] = color;
      }
      numAdded += len;
      color = !color; // flip color after each segment
    }
    return numAdded;
  }

  int get defaultMargin {
    // CodaBar spec requires a side margin to be more than ten times wider than narrow space.
    // This seems like a decent idea for a default for all formats.
    return 10;
  }
}
