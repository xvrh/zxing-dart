import 'dart:typed_data';
import 'package:camera/camera.dart' show CameraImage;
import 'package:zxing/zxing.dart';

Result? decode(CameraImage image) {
  var plane = image.planes.first;
  LuminanceSource source = RGBLuminanceSource(
      image.width, image.height, plane.bytes.buffer.asInt32List());
  var bitmap = BinaryBitmap(HybridBinarizer(source));

  var reader = QRCodeReader();
  try {
    return reader.decode(bitmap);
  } catch (_) {
    return null;
  }
}

class ImageLuminanceSource extends LuminanceSource {
  final Uint8List _bytes;
  final int left;
  final int top;

  ImageLuminanceSource.fromLTWH(
      this._bytes, this.left, this.top, int width, int height)
      : super(width, height);

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
