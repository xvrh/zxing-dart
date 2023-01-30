import 'dart:typed_data';
import 'common/system.dart' as system;
import 'luminance_source.dart';

/// This object extends LuminanceSource around an array of YUV data returned from the camera driver,
/// with the option to crop to a rectangle within the full data. This can be used to exclude
/// superfluous pixels around the perimeter and speed up decoding.
///
/// It works for any pixel format where the Y channel is planar and appears first, including
/// YCbCr_420_SP and YCbCr_422_SP.
///
/// @author dswitkin@google.com (Daniel Switkin)
class PlanarYUVLuminanceSource extends LuminanceSource {
  final _thumbnailScaleFactor = 2;

  final Int8List _yuvData;
  final int _dataWidth;
  final int _dataHeight;
  final int _left;
  final int _top;

  PlanarYUVLuminanceSource(this._yuvData, this._dataWidth, this._dataHeight,
      this._left, this._top, int width, int height, bool reverseHorizontal)
      : super(width, height) {
    if (_left + width > _dataWidth || _top + height > _dataHeight) {
      throw ArgumentError('Crop rectangle does not fit within image data.');
    }

    if (reverseHorizontal) {
      _reverseHorizontal(width, height);
    }
  }

  @override
  Int8List getRow(int y, Int8List? row) {
    if (y < 0 || y >= height) {
      throw ArgumentError('Requested row is outside the image: $y');
    }
    var width = this.width;
    if (row == null || row.length < width) {
      row = Int8List(width);
    }
    var offset = (y + _top) * _dataWidth + _left;
    system.arraycopy(_yuvData, offset, row, 0, width);
    return row;
  }

  @override
  Int8List getMatrix() {
    var width = this.width;
    var height = this.height;

    // If the caller asks for the entire underlying image, save the copy and give them the
    // original data. The docs specifically warn that result.length must be ignored.
    if (width == _dataWidth && height == _dataHeight) {
      return _yuvData;
    }

    var area = width * height;
    var matrix = Int8List(area);
    var inputOffset = _top * _dataWidth + _left;

    // If the width matches the full width of the underlying data, perform a single copy.
    if (width == _dataWidth) {
      system.arraycopy(_yuvData, inputOffset, matrix, 0, area);
      return matrix;
    }

    // Otherwise copy one cropped row at a time.
    for (var y = 0; y < height; y++) {
      var outputOffset = y * width;
      system.arraycopy(_yuvData, inputOffset, matrix, outputOffset, width);
      inputOffset += _dataWidth;
    }
    return matrix;
  }

  @override
  bool get isCropSupported {
    return true;
  }

  @override
  LuminanceSource crop(int left, int top, int width, int height) {
    return PlanarYUVLuminanceSource(_yuvData, _dataWidth, _dataHeight,
        _left + left, _top + top, width, height, false);
  }

  List<int> renderThumbnail() {
    var width = this.width ~/ _thumbnailScaleFactor;
    var height = this.height ~/ _thumbnailScaleFactor;
    var pixels = List.filled(width * height, 0);
    var yuv = _yuvData;
    var inputOffset = _top * _dataWidth + _left;

    for (var y = 0; y < height; y++) {
      var outputOffset = y * width;
      for (var x = 0; x < width; x++) {
        var grey = yuv[inputOffset + x * _thumbnailScaleFactor] & 0xff;
        pixels[outputOffset + x] = 0xFF000000 | (grey * 0x00010101);
      }
      inputOffset += _dataWidth * _thumbnailScaleFactor;
    }
    return pixels;
  }

  /// @return width of image from {@link #renderThumbnail()}
  int getThumbnailWidth() {
    return width ~/ _thumbnailScaleFactor;
  }

  /// @return height of image from {@link #renderThumbnail()}
  int getThumbnailHeight() {
    return height ~/ _thumbnailScaleFactor;
  }

  void _reverseHorizontal(int width, int height) {
    var yuvData = _yuvData;
    for (var y = 0, rowStart = _top * _dataWidth + _left;
        y < height;
        y++, rowStart += _dataWidth) {
      var middle = rowStart + width ~/ 2;
      for (var x1 = rowStart, x2 = rowStart + width - 1;
          x1 < middle;
          x1++, x2--) {
        var temp = yuvData[x1];
        yuvData[x1] = yuvData[x2];
        yuvData[x2] = temp;
      }
    }
  }
}
