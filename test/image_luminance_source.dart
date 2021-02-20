import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:zxing/src/luminance_source.dart';

/// This LuminanceSource implementation is meant for J2SE clients and our blackbox unit tests.
///
/// @author dswitkin@google.com (Daniel Switkin)
/// @author Sean Owen
/// @author code@elektrowolle.de (Wolfgang Jung)
class ImageLuminanceSource extends LuminanceSource {
  final Uint8List _bytes;
  final int left;
  final int top;

  ImageLuminanceSource._(
      this._bytes, this.left, this.top, int width, int height)
      : super(width, height);

  factory ImageLuminanceSource(img.Image image) {
    return ImageLuminanceSource.fromLTWH(
        image, 0, 0, image.width, image.height);
  }

  factory ImageLuminanceSource.fromLTWH(
      img.Image image, int left, int top, int width, int height) {
    var bytes = image.getBytes(format: img.Format.luminance);
    return ImageLuminanceSource._(bytes, left, top, width, height);
  }

  @override
  Int8List getRow(int y, Int8List? row) {
    if (y < 0 || y >= height) {
      throw ArgumentError('Requested row is outside the image: $y');
    }
    var width = height;
    if (row == null || row.length < width) {
      row = Int8List(width);
    }

    row.setRange(0, row.length, _bytes, width * (y + top) + left);

    return row;
  }

  @override
  Int8List getMatrix() {
    var width = this.width;
    var height = this.height;
    var area = width * height;
    var matrix = Int8List(area);
    matrix.setRange(0, matrix.length, _bytes, top * width);
    return matrix;
  }

  @override
  bool get isCropSupported {
    return false;
  }

  @override
  LuminanceSource crop(int left, int top, int width, int height) {
    throw UnimplementedError();
  }

  /// This is always true, since the image is a gray-scale image.
  ///
  /// @return true
  @override
  bool get isRotateSupported {
    return false;
  }

  @override
  LuminanceSource rotateCounterClockwise() {
    throw UnimplementedError();
  }

  @override
  LuminanceSource rotateCounterClockwise45() {
    throw UnimplementedError();
  }
}
