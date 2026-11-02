import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:zxing2/src/luminance_source.dart';

/// This LuminanceSource implementation is meant for J2SE clients and our blackbox unit tests.
///
/// @author dswitkin@google.com (Daniel Switkin)
/// @author Sean Owen
/// @author code@elektrowolle.de (Wolfgang Jung)
class ImageLuminanceSource extends LuminanceSource {
  final Int8List _luminances;
  final int _dataWidth;
  final int _dataHeight;
  final int _left;
  final int _top;

  ImageLuminanceSource._(this._luminances, this._dataWidth, this._dataHeight,
      this._left, this._top, int width, int height)
      : super(width, height);

  factory ImageLuminanceSource(img.Image image) {
    return ImageLuminanceSource.fromLTWH(
        image, 0, 0, image.width, image.height);
  }

  factory ImageLuminanceSource.fromLTWH(
      img.Image image, int left, int top, int width, int height) {
    if (left + width > image.width || top + height > image.height) {
      throw ArgumentError('Crop rectangle does not fit within image data.');
    }
    var isGray = !image.hasPalette && image.numChannels <= 2;
    // Palette pixels report an alpha of 0 when the palette has no alpha channel
    var hasAlpha = image.hasAlpha;
    var luminances = Uint8List(image.width * image.height);
    var i = 0;
    for (var pixel in image) {
      luminances[i++] = _luminance(pixel, isGray: isGray, hasAlpha: hasAlpha);
    }
    return ImageLuminanceSource._(luminances.buffer.asInt8List(), image.width,
        image.height, left, top, width, height);
  }

  static int _luminance(img.Pixel pixel,
      {required bool isGray, required bool hasAlpha}) {
    // The color of fully-transparent pixels is irrelevant. They are often, technically, fully-transparent
    // black (0 alpha, and then 0 RGB). They are often used, of course as the "white" area in a
    // barcode image. Force any such pixel to be white:
    if (hasAlpha && pixel.aNormalized == 0) {
      return 0xFF;
    }
    if (isGray) {
      return (pixel.rNormalized * 255).round();
    }
    var r = (pixel.rNormalized * 255).round();
    var g = (pixel.gNormalized * 255).round();
    var b = (pixel.bNormalized * 255).round();
    // .299R + 0.587G + 0.114B (YUV/YIQ for PAL and NTSC),
    // (306*R) >> 10 is approximately equal to R*0.299, and so on.
    // 0x200 >> 10 is 0.5, it implements rounding.
    return (306 * r + 601 * g + 117 * b + 0x200) >> 10;
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
    row.setRange(0, width, _luminances, offset);
    return row;
  }

  @override
  Int8List getMatrix() {
    var width = this.width;
    var height = this.height;
    var matrix = Int8List(width * height);
    for (var y = 0; y < height; y++) {
      var offset = (y + _top) * _dataWidth + _left;
      matrix.setRange(y * width, (y + 1) * width, _luminances, offset);
    }
    return matrix;
  }

  @override
  bool get isCropSupported {
    return true;
  }

  @override
  LuminanceSource crop(int left, int top, int width, int height) {
    return ImageLuminanceSource._(_luminances, _dataWidth, _dataHeight,
        _left + left, _top + top, width, height);
  }

  @override
  bool get isRotateSupported {
    return true;
  }

  @override
  LuminanceSource rotateCounterClockwise() {
    var rotated = Int8List(_luminances.length);
    var newDataWidth = _dataHeight;
    for (var y = 0; y < _dataWidth; y++) {
      for (var x = 0; x < newDataWidth; x++) {
        rotated[y * newDataWidth + x] =
            _luminances[x * _dataWidth + (_dataWidth - 1 - y)];
      }
    }
    return ImageLuminanceSource._(rotated, newDataWidth, _dataWidth, _top,
        _dataWidth - (_left + width), height, width);
  }

  @override
  LuminanceSource rotateCounterClockwise45() {
    throw UnsupportedError(
        'This luminance source does not support rotation by 45 degrees.');
  }
}
