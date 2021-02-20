import 'dart:typed_data';

import 'luminance_source.dart';

/// A wrapper implementation of {@link LuminanceSource} which inverts the luminances it returns -- black becomes
/// white and vice versa, and each value becomes (255-value).
///
/// @author Sean Owen
class InvertedLuminanceSource extends LuminanceSource {
  final LuminanceSource _delegate;

  InvertedLuminanceSource(this._delegate)
      : super(_delegate.width, _delegate.height);

  @override
  Int8List getRow(int y, Int8List? row) {
    row = _delegate.getRow(y, row);
    int width = this.width;
    for (int i = 0; i < width; i++) {
      row[i] = (255 - (row[i] & 0xFF));
    }
    return row;
  }

  @override
  Int8List getMatrix() {
    Int8List matrix = _delegate.getMatrix();
    int length = width * height;
    Int8List invertedMatrix = Int8List(length);
    for (int i = 0; i < length; i++) {
      invertedMatrix[i] = (255 - (matrix[i] & 0xFF));
    }
    return invertedMatrix;
  }

  @override
  bool get isCropSupported {
    return _delegate.isCropSupported;
  }

  @override
  LuminanceSource crop(int left, int top, int width, int height) {
    return InvertedLuminanceSource(_delegate.crop(left, top, width, height));
  }

  @override
  bool get isRotateSupported {
    return _delegate.isRotateSupported;
  }

  /// @return original delegate {@link LuminanceSource} since invert undoes itself
  @override
  LuminanceSource invert() {
    return _delegate;
  }

  @override
  LuminanceSource rotateCounterClockwise() {
    return InvertedLuminanceSource(_delegate.rotateCounterClockwise());
  }

  @override
  LuminanceSource rotateCounterClockwise45() {
    return InvertedLuminanceSource(_delegate.rotateCounterClockwise45());
  }
}
