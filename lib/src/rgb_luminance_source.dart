import 'dart:typed_data';
import 'common/system.dart' as system;
import 'luminance_source.dart';

/// This class is used to help decode images from files which arrive as RGB data from
/// an ARGB pixel array. It does not support rotation.
///
/// @author dswitkin@google.com (Daniel Switkin)
/// @author Betaminos
class RGBLuminanceSource extends LuminanceSource {
  late final Int8List _luminances;
  final int _dataWidth;
  final int _dataHeight;
  final int _left;
  final int _top;

  RGBLuminanceSource(this._dataWidth, this._dataHeight, Int32List pixels)
      : _left = 0,
        _top = 0,
        super(_dataWidth, _dataHeight) {
    // In order to measure pure decoding speed, we convert the entire image to a greyscale array
    // up front, which is the same as the Y channel of the YUVLuminanceSource in the real app.
    //
    // Total number of pixels suffices, can ignore shape
    int size = _dataWidth * _dataHeight;
    _luminances = Int8List(size);
    for (int offset = 0; offset < size; offset++) {
      int pixel = pixels[offset];
      int r = (pixel >> 16) & 0xff; // red
      int g2 = (pixel >> 7) & 0x1fe; // 2 * green
      int b = pixel & 0xff; // blue
      // Calculate green-favouring average cheaply
      _luminances[offset] = ((r + g2 + b) ~/ 4).toInt();
    }
  }

  RGBLuminanceSource.crop(Int8List pixels, this._dataWidth, this._dataHeight,
      this._left, this._top, int width, int height)
      : _luminances = pixels,
        super(width, height) {
    if (_left + width > _dataWidth || _top + height > _dataHeight) {
      throw ArgumentError("Crop rectangle does not fit within image data.");
    }
  }

  @override
  Int8List getRow(int y, Int8List? row) {
    if (y < 0 || y >= height) {
      throw ArgumentError("Requested row is outside the image: $y");
    }
    int width = this.width;
    if (row == null || row.length < width) {
      row = Int8List(width);
    }
    int offset = (y + _top) * _dataWidth + _left;
    system.arraycopy(_luminances, offset, row, 0, width);
    return row;
  }

  @override
  Int8List getMatrix() {
    int width = this.width;
    int height = this.height;

    // If the caller asks for the entire underlying image, save the copy and give them the
    // original data. The docs specifically warn that result.length must be ignored.
    if (width == _dataWidth && height == _dataHeight) {
      return _luminances;
    }

    int area = width * height;
    Int8List matrix = Int8List(area);
    int inputOffset = _top * _dataWidth + _left;

    // If the width matches the full width of the underlying data, perform a single copy.
    if (width == _dataWidth) {
      system.arraycopy(_luminances, inputOffset, matrix, 0, area);
      return matrix;
    }

    // Otherwise copy one cropped row at a time.
    for (int y = 0; y < height; y++) {
      int outputOffset = y * width;
      system.arraycopy(_luminances, inputOffset, matrix, outputOffset, width);
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
    return RGBLuminanceSource.crop(_luminances, _dataWidth, _dataHeight,
        this._left + left, this._top + top, width, height);
  }
}
