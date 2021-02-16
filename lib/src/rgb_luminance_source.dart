/*
 * Copyright 2009 ZXing authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:typed_data';
import 'common/system.dart' as system;
import 'luminance_source.dart';

/**
 * This class is used to help decode images from files which arrive as RGB data from
 * an ARGB pixel array. It does not support rotation.
 *
 * @author dswitkin@google.com (Daniel Switkin)
 * @author Betaminos
 */
class RGBLuminanceSource extends LuminanceSource {
  late final Uint8List _luminances;
  final int _dataWidth;
  final int _dataHeight;
  final int _left;
  final int _top;

  RGBLuminanceSource(this._dataWidth, this._dataHeight, Uint32List pixels)
      : _left = 0,
        _top = 0,
        super(_dataWidth, _dataHeight) {
    // In order to measure pure decoding speed, we convert the entire image to a greyscale array
    // up front, which is the same as the Y channel of the YUVLuminanceSource in the real app.
    //
    // Total number of pixels suffices, can ignore shape
    int size = _dataWidth * _dataHeight;
    _luminances = Uint8List(size);
    for (int offset = 0; offset < size; offset++) {
      int pixel = pixels[offset];
      int r = (pixel >> 16) & 0xff; // red
      int g2 = (pixel >> 7) & 0x1fe; // 2 * green
      int b = pixel & 0xff; // blue
      // Calculate green-favouring average cheaply
      _luminances[offset] = ((r + g2 + b) ~/ 4);
    }
  }

  RGBLuminanceSource.crop(Uint8List pixels, this._dataWidth, this._dataHeight,
      this._left, this._top, int width, int height)
      : _luminances = pixels,
        super(width, height) {
    if (_left + width > _dataWidth || _top + height > _dataHeight) {
      throw new ArgumentError("Crop rectangle does not fit within image data.");
    }
  }

  @override
  Uint8List getRow(int y, Uint8List? row) {
    if (y < 0 || y >= height) {
      throw new ArgumentError("Requested row is outside the image: $y");
    }
    int width = this.width;
    if (row == null || row.length < width) {
      row = Uint8List(width);
    }
    int offset = (y + _top) * _dataWidth + _left;
    system.arraycopy(_luminances, offset, row, 0, width);
    return row;
  }

  @override
  Uint8List getMatrix() {
    int width = this.width;
    int height = this.height;

    // If the caller asks for the entire underlying image, save the copy and give them the
    // original data. The docs specifically warn that result.length must be ignored.
    if (width == _dataWidth && height == _dataHeight) {
      return _luminances;
    }

    int area = width * height;
    Uint8List matrix = Uint8List(area);
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
    return new RGBLuminanceSource.crop(_luminances, _dataWidth, _dataHeight,
        this._left + left, this._top + top, width, height);
  }
}
