/*
 * Copyright 2007 ZXing authors
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

import 'package:collection/collection.dart';
import 'package:fixnum/fixnum.dart';

import 'bit_array.dart';

/// <p>Represents a 2D matrix of bits. In function arguments below, and throughout the common
/// module, x is the column position, and y is the row position. The ordering is always x, y.
/// The origin is at the top-left.</p>
///
/// <p>Internally the bits are represented in a 1-D array of 32-bit ints. However, each row begins
/// with a new int. This is done intentionally so that we can copy out a row into a BitArray very
/// efficiently.</p>
///
/// <p>The ordering of bits is row-major. Within each int, the least significant bits are used first,
/// meaning they represent lower x values. This is compatible with BitArray's implementation.</p>
///
/// @author Sean Owen
/// @author dswitkin@google.com (Daniel Switkin)
class BitMatrix {
  int _width;
  int _height;
  int _rowSize;
  Int32List _bits;

  /// Creates an empty {@code BitMatrix}.
  ///
  /// @param width bit matrix width
  /// @param height bit matrix height
  factory BitMatrix(int width, [int? height]) {
    height ??= width;

    if (width < 1 || height < 1) {
      throw new ArgumentError("Both dimensions must be greater than 0");
    }

    var rowSize = (width + 31) ~/ 32;
    return BitMatrix._(width, height, rowSize, Int32List(rowSize * height));
  }

  BitMatrix._(this._width, this._height, this._rowSize, this._bits);

  /// Interprets a 2D array of booleans as a {@code BitMatrix}, where "true" means an "on" bit.
  ///
  /// @param image bits of the image, as a row-major 2D array. Elements are arrays representing rows
  /// @return {@code BitMatrix} representation of image
  static BitMatrix parse(List<List<bool>> image) {
    int height = image.length;
    int width = image[0].length;
    BitMatrix bits = BitMatrix(width, height);
    for (int i = 0; i < height; i++) {
      List<bool> imageI = image[i];
      for (int j = 0; j < width; j++) {
        if (imageI[j]) {
          bits.set(j, i);
        }
      }
    }
    return bits;
  }

  static BitMatrix parseString(
      String stringRepresentation, String setString, String unsetString) {
    List<bool> bits = List.filled(stringRepresentation.length, false);
    int bitsPos = 0;
    int rowStartPos = 0;
    int rowLength = -1;
    int nRows = 0;
    int pos = 0;
    while (pos < stringRepresentation.length) {
      if (stringRepresentation[pos] == '\n' ||
          stringRepresentation[pos] == '\r') {
        if (bitsPos > rowStartPos) {
          if (rowLength == -1) {
            rowLength = bitsPos - rowStartPos;
          } else if (bitsPos - rowStartPos != rowLength) {
            throw new ArgumentError("row lengths do not match");
          }
          rowStartPos = bitsPos;
          nRows++;
        }
        pos++;
      } else if (stringRepresentation.startsWith(setString, pos)) {
        pos += setString.length;
        bits[bitsPos] = true;
        bitsPos++;
      } else if (stringRepresentation.startsWith(unsetString, pos)) {
        pos += unsetString.length;
        bits[bitsPos] = false;
        bitsPos++;
      } else {
        throw new ArgumentError("illegal character encountered: " +
            stringRepresentation.substring(pos));
      }
    }

    // no EOL at end?
    if (bitsPos > rowStartPos) {
      if (rowLength == -1) {
        rowLength = bitsPos - rowStartPos;
      } else if (bitsPos - rowStartPos != rowLength) {
        throw new ArgumentError("row lengths do not match");
      }
      nRows++;
    }

    BitMatrix matrix = BitMatrix(rowLength, nRows);
    for (int i = 0; i < bitsPos; i++) {
      if (bits[i]) {
        matrix.set(i % rowLength, i ~/ rowLength);
      }
    }
    return matrix;
  }

/**
 * <p>Gets the requested bit, where true means black.</p>
 *
 * @param x The horizontal component (i.e. which column)
 * @param y The vertical component (i.e. which row)
 * @return value of given bit in matrix
 */
  bool get(int x, int y) {
    int offset = y * _rowSize + (x ~/ 32);
    return offset < _bits.length &&
        ((Int32(_bits[offset]).shiftRightUnsigned(x & 0x1f)) & 1) != 0;
  }

/**
 * <p>Sets the given bit to true.</p>
 *
 * @param x The horizontal component (i.e. which column)
 * @param y The vertical component (i.e. which row)
 */
  void set(int x, int y) {
    int offset = y * _rowSize + (x ~/ 32);
    if (offset < _bits.length) {
      _bits[offset] |= 1 << (x & 0x1f);
    }
  }

  void unset(int x, int y) {
    int offset = y * _rowSize + (x ~/ 32);
    if (offset < _bits.length) {
      _bits[offset] &= ~(1 << (x & 0x1f));
    }
  }

/**
 * <p>Flips the given bit.</p>
 *
 * @param x The horizontal component (i.e. which column)
 * @param y The vertical component (i.e. which row)
 */
  void flip(int x, int y) {
    int offset = y * _rowSize + (x ~/ 32);
    if (offset < _bits.length) {
      _bits[offset] ^= 1 << (x & 0x1f);
    }
  }

/**
 * Exclusive-or (XOR): Flip the bit in this {@code BitMatrix} if the corresponding
 * mask bit is set.
 *
 * @param mask XOR mask
 */
  void xor(BitMatrix mask) {
    if (_width != mask.width ||
        _height != mask.height ||
        _rowSize != mask.rowSize) {
      throw new ArgumentError("input matrix dimensions do not match");
    }
    var rowArray = BitArray(width);
    for (int y = 0; y < height; y++) {
      int offset = y * _rowSize;
      var row = mask.getRow(y, rowArray).bitArray;
      for (int x = 0; x < rowSize; x++) {
        _bits[offset + x] ^= row[x];
      }
    }
  }

/**
 * Clears all bits (sets to false).
 */
  void clear() {
    int max = _bits.length;
    for (int i = 0; i < max; i++) {
      _bits[i] = 0;
    }
  }

/**
 * <p>Sets a square region of the bit matrix to true.</p>
 *
 * @param left The horizontal position to begin at (inclusive)
 * @param top The vertical position to begin at (inclusive)
 * @param width The width of the region
 * @param height The height of the region
 */
  void setRegion(int left, int top, int width, int height) {
    if (top < 0 || left < 0) {
      throw new ArgumentError("Left and top must be nonnegative");
    }
    if (height < 1 || width < 1) {
      throw new ArgumentError("Height and width must be at least 1");
    }
    int right = left + width;
    int bottom = top + height;
    if (bottom > _height || right > _width) {
      throw new ArgumentError("The region must fit inside the matrix");
    }
    for (int y = top; y < bottom; y++) {
      int offset = y * _rowSize;
      for (int x = left; x < right; x++) {
        _bits[offset + (x ~/ 32)] |= 1 << (x & 0x1f);
      }
    }
  }

/**
 * A fast method to retrieve one row of data from the matrix as a BitArray.
 *
 * @param y The row to retrieve
 * @param row An optional caller-allocated BitArray, will be allocated if null or too small
 * @return The resulting BitArray - this reference should always be used even when passing
 *         your own row
 */
  BitArray getRow(int y, BitArray? row) {
    if (row == null || row.size < width) {
      row = BitArray(width);
    } else {
      row.clear();
    }
    int offset = y * rowSize;
    for (int x = 0; x < rowSize; x++) {
      row.setBulk(x * 32, _bits[offset + x]);
    }
    return row;
  }

/**
 * @param y row to set
 * @param row {@link BitArray} to copy from
 */
  void setRow(int y, BitArray row) {
    _bits.setRange(y * rowSize, y * rowSize + rowSize, row.bitArray);
  }

/**
 * Modifies this {@code BitMatrix} to represent the same but rotated 180 degrees
 */
  void rotate180() {
    var topRow = new BitArray(width);
    var bottomRow = new BitArray(width);
    int maxHeight = (height + 1) ~/ 2;
    for (int i = 0; i < maxHeight; i++) {
      topRow = getRow(i, topRow);
      int bottomRowIndex = height - 1 - i;
      bottomRow = getRow(bottomRowIndex, bottomRow);
      topRow.reverse();
      bottomRow.reverse();
      setRow(i, bottomRow);
      setRow(bottomRowIndex, topRow);
    }
  }

/**
 * Modifies this {@code BitMatrix} to represent the same but rotated 90 degrees counterclockwise
 */
  void rotate90() {
    int newWidth = height;
    int newHeight = width;
    int newRowSize = (newWidth + 31) ~/ 32;
    Int32List newBits = Int32List(newRowSize * newHeight);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int offset = y * rowSize + (x ~/ 32);
        if (((Int32(_bits[offset]).shiftRightUnsigned(x & 0x1f)) & 1) != 0) {
          int newOffset = (newHeight - 1 - x) * newRowSize + (y ~/ 32);
          newBits[newOffset] |= 1 << (y & 0x1f);
        }
      }
    }
    _width = newWidth;
    _height = newHeight;
    _rowSize = newRowSize;
    _bits = newBits;
  }

/**
 * This is useful in detecting the enclosing rectangle of a 'pure' barcode.
 *
 * @return {@code left,top,width,height} enclosing rectangle of all 1 bits, or null if it is all white
 */
  List<int>? getEnclosingRectangle() {
    int left = _width;
    int top = _height;
    int right = -1;
    int bottom = -1;

    for (int y = 0; y < _height; y++) {
      for (int x32 = 0; x32 < _rowSize; x32++) {
        var theBits = Int32(_bits[y * _rowSize + x32]);
        if (theBits != 0) {
          if (y < top) {
            top = y;
          }
          if (y > bottom) {
            bottom = y;
          }
          if (x32 * 32 < left) {
            int bit = 0;
            while ((theBits << (31 - bit)) == 0) {
              bit++;
            }
            if ((x32 * 32 + bit) < left) {
              left = x32 * 32 + bit;
            }
          }
          if (x32 * 32 + 31 > right) {
            int bit = 31;
            while ((theBits.shiftRightUnsigned(bit)) == 0) {
              bit--;
            }
            if ((x32 * 32 + bit) > right) {
              right = x32 * 32 + bit;
            }
          }
        }
      }
    }

    if (right < left || bottom < top) {
      return null;
    }

    return [left, top, right - left + 1, bottom - top + 1];
  }

  /// This is useful in detecting a corner of a 'pure' barcode.
  ///
  /// @return {@code x,y} coordinate of top-left-most 1 bit, or null if it is all white
  List<int>? getTopLeftOnBit() {
    int bitsOffset = 0;
    while (bitsOffset < _bits.length && _bits[bitsOffset] == 0) {
      bitsOffset++;
    }
    if (bitsOffset == _bits.length) {
      return null;
    }
    int y = bitsOffset ~/ rowSize;
    int x = (bitsOffset % rowSize) * 32;

    var theBits = Int32(_bits[bitsOffset]);
    int bit = 0;
    while ((theBits << (31 - bit)) == 0) {
      bit++;
    }
    x += bit;
    return [x, y];
  }

  List<int>? getBottomRightOnBit() {
    int bitsOffset = _bits.length - 1;
    while (bitsOffset >= 0 && _bits[bitsOffset] == 0) {
      bitsOffset--;
    }
    if (bitsOffset < 0) {
      return null;
    }

    int y = bitsOffset ~/ rowSize;
    int x = (bitsOffset % rowSize) * 32;

    var theBits = Int32(_bits[bitsOffset]);
    int bit = 31;
    while ((theBits.shiftRightUnsigned(bit)) == 0) {
      bit--;
    }
    x += bit;

    return [x, y];
  }

/**
 * @return The width of the matrix
 */
  int get width {
    return _width;
  }

  /// @return The height of the matrix
  int get height {
    return _height;
  }

  /// @return The row size of the matrix
  int get rowSize {
    return _rowSize;
  }

  @override
  bool operator ==(Object other) {
    if (other is! BitMatrix) {
      return false;
    }
    return width == other.width &&
        height == other.height &&
        rowSize == other.rowSize &&
        const ListEquality().equals(_bits, other._bits);
  }

  @override
  int get hashCode {
    int hash = width;
    hash = 31 * hash + width;
    hash = 31 * hash + height;
    hash = 31 * hash + rowSize;
    hash = 31 * hash + const ListEquality().hash(_bits);
    return hash;
  }

/**
 * @return string representation using "X" for set and " " for unset bits
 */
  @override
  String toString() {
    return toStringRepresentation("X ", "  ");
  }

/**
 * @param setString representation of a set bit
 * @param unsetString representation of an unset bit
 * @return string representation of entire matrix utilizing given strings
 */
  String toStringRepresentation(String setString, String unsetString) {
    return _buildToString(setString, unsetString, "\n");
  }

  String _buildToString(
      String setString, String unsetString, String lineSeparator) {
    var result = new StringBuffer();
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        result.write(get(x, y) ? setString : unsetString);
      }
      result.write(lineSeparator);
    }
    return result.toString();
  }

  BitMatrix clone() {
    return BitMatrix._(
        width, height, rowSize, Int32List(_bits.length)..setAll(0, _bits));
  }
}
