import '../binary_bitmap.dart';
import '../decode_hint.dart';
import '../not_found_exception.dart';
import '../reader.dart';
import '../result.dart';
import '../result_point.dart';

/// This class attempts to decode a barcode from an image, not by scanning the whole image,
/// but by scanning subsets of the image. This is important when there may be multiple barcodes in
/// an image, and detecting a barcode may find parts of multiple barcode and fail to decode
/// (e.g. QR Codes). Instead this scans the four quadrants of the image -- and also the center
/// 'quadrant' to cover the case where a barcode is found in the center.
///
/// @see GenericMultipleBarcodeReader
class ByQuadrantReader implements Reader {
  final Reader _delegate;

  ByQuadrantReader(this._delegate);

  @override
  Result decode(BinaryBitmap image, {DecodeHints? hints}) {
    var width = image.width;
    var height = image.height;
    var halfWidth = width ~/ 2;
    var halfHeight = height ~/ 2;

    try {
      // No need to call makeAbsolute as results will be relative to original top left here
      return _delegate.decode(image.crop(0, 0, halfWidth, halfHeight),
          hints: hints);
    } on NotFoundException catch (_) {
      // continue
    }

    try {
      var result = _delegate.decode(
          image.crop(halfWidth, 0, halfWidth, halfHeight),
          hints: hints);
      _makeAbsolute(result.resultPoints, halfWidth, 0);
      return result;
    } on NotFoundException catch (_) {
      // continue
    }

    try {
      var result = _delegate.decode(
          image.crop(0, halfHeight, halfWidth, halfHeight),
          hints: hints);
      _makeAbsolute(result.resultPoints, 0, halfHeight);
      return result;
    } on NotFoundException catch (_) {
      // continue
    }

    try {
      var result = _delegate.decode(
          image.crop(halfWidth, halfHeight, halfWidth, halfHeight),
          hints: hints);
      _makeAbsolute(result.resultPoints, halfWidth, halfHeight);
      return result;
    } on NotFoundException catch (_) {
      // continue
    }

    var quarterWidth = halfWidth ~/ 2;
    var quarterHeight = halfHeight ~/ 2;
    var center = image.crop(quarterWidth, quarterHeight, halfWidth, halfHeight);
    var result = _delegate.decode(center, hints: hints);
    _makeAbsolute(result.resultPoints, quarterWidth, quarterHeight);
    return result;
  }

  @override
  void reset() {
    _delegate.reset();
  }

  static void _makeAbsolute(
      List<ResultPoint> points, int leftOffset, int topOffset) {
    for (var i = 0; i < points.length; i++) {
      var relative = points[i];
      points[i] = ResultPoint(relative.x + leftOffset, relative.y + topOffset);
    }
  }
}
