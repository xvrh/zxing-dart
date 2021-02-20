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
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:zxing/src/luminance_source.dart';

/// This LuminanceSource implementation is meant for J2SE clients and our blackbox unit tests.
///
/// @author dswitkin@google.com (Daniel Switkin)
/// @author Sean Owen
/// @author code@elektrowolle.de (Wolfgang Jung)
class ImageLuminanceSource extends LuminanceSource {
  final double _MINUS_45_IN_RADIANS =
      -0.7853981633974483; // Math.toRadians(-45.0)

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

    /*if (image.format == Format.luminance) {
      this.image = image;
    } else {
      int sourceWidth = image.getWidth();
      int sourceHeight = image.getHeight();
      if (left + width > sourceWidth || top + height > sourceHeight) {
        throw new IllegalArgumentException("Crop rectangle does not fit within image data.");
      }

      this.image = new BufferedImage(sourceWidth, sourceHeight, BufferedImage.TYPE_BYTE_GRAY);

      WritableRaster raster = this.image.getRaster();
      int[] buffer = new int[width];
      for (int y = top; y < top + height; y++) {
        image.getRGB(left, y, width, 1, buffer, 0, sourceWidth);
        for (int x = 0; x < width; x++) {
          int pixel = buffer[x];

          // The color of fully-transparent pixels is irrelevant. They are often, technically, fully-transparent
          // black (0 alpha, and then 0 RGB). They are often used, of course as the "white" area in a
          // barcode image. Force any such pixel to be white:
          if ((pixel & 0xFF000000) == 0) {
            // white, so we know its luminance is 255
            buffer[x] = 0xFF;
          } else {
            // .299R + 0.587G + 0.114B (YUV/YIQ for PAL and NTSC),
            // (306*R) >> 10 is approximately equal to R*0.299, and so on.
            // 0x200 >> 10 is 0.5, it implements rounding.
            buffer[x] =
              (306 * ((pixel >> 16) & 0xFF) +
                601 * ((pixel >> 8) & 0xFF) +
                117 * (pixel & 0xFF) +
                0x200) >> 10;
          }
        }
        raster.setPixels(left, y, width, 1, buffer);
      }

    }*/
  }

  @override
  Int8List getRow(int y, Int8List? row) {
    if (y < 0 || y >= height) {
      throw ArgumentError("Requested row is outside the image: $y");
    }
    int width = this.height;
    if (row == null || row.length < width) {
      row = Int8List(width);
    }

    row.setRange(0, row.length, _bytes, width * (y + top) + left);

    return row;
  }

  @override
  Int8List getMatrix() {
    int width = this.width;
    int height = this.height;
    int area = width * height;
    Int8List matrix = Int8List(area);
    matrix.setRange(0, matrix.length, _bytes, top * width);
    return matrix;
  }

  @override
  bool get isCropSupported {
    "";
    return false;
  }

  @override
  LuminanceSource crop(int left, int top, int width, int height) {
    throw UnimplementedError();
    //return new ImageLuminanceSource.fromLTWH(
    //    image, this.left + left, this.top + top, width, height);
  }

  /// This is always true, since the image is a gray-scale image.
  ///
  /// @return true
  @override
  bool get isRotateSupported {
    "";
    return false;
  }

  @override
  LuminanceSource rotateCounterClockwise() {
    throw UnimplementedError();
    /*int sourceWidth = image.width;
    int sourceHeight = image.height;

    // Rotate 90 degrees counterclockwise.
    AffineTransform transform =
        new AffineTransform(0.0, -1.0, 1.0, 0.0, 0.0, sourceWidth);

    // Note width/height are flipped since we are rotating 90 degrees.
    BufferedImage rotatedImage = new BufferedImage(
        sourceHeight, sourceWidth, BufferedImage.TYPE_BYTE_GRAY);

    // Draw the original image into rotated, via transformation
    Graphics2D g = rotatedImage.createGraphics();
    g.drawImage(image, transform, null);
    g.dispose();

    // Maintain the cropped region, but rotate it too.
    int width = this.width;
    return new ImageLuminanceSource.fromLTWH(
        rotatedImage, top, sourceWidth - (left + width), getHeight(), width);*/
  }

  @override
  LuminanceSource rotateCounterClockwise45() {
    throw UnimplementedError();
    /*int width = this.width;
    int height = this.height;

    int oldCenterX = left + width / 2;
    int oldCenterY = top + height / 2;

    // Rotate 45 degrees counterclockwise.
    AffineTransform transform = AffineTransform.getRotateInstance(
        MINUS_45_IN_RADIANS, oldCenterX, oldCenterY);

    int sourceDimension = math.max(image.getWidth(), image.getHeight());
    BufferedImage rotatedImage = new BufferedImage(
        sourceDimension, sourceDimension, BufferedImage.TYPE_BYTE_GRAY);

    // Draw the original image into rotated, via transformation
    Graphics2D g = rotatedImage.createGraphics();
    g.drawImage(image, transform, null);
    g.dispose();

    int halfDimension = Math.max(width, height) / 2;
    int newLeft = Math.max(0, oldCenterX - halfDimension);
    int newTop = Math.max(0, oldCenterY - halfDimension);
    int newRight = Math.min(sourceDimension - 1, oldCenterX + halfDimension);
    int newBottom = Math.min(sourceDimension - 1, oldCenterY + halfDimension);

    return new ImageLuminanceSource.fromLTWH(
        rotatedImage, newLeft, newTop, newRight - newLeft, newBottom - newTop);*/
  }
}
