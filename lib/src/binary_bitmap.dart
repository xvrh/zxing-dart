import 'common/bit_matrix.dart';
import 'common/bit_array.dart';
import 'binarizer.dart';
import 'not_found_exception.dart';

/// This class is the core bitmap class used by ZXing to represent 1 bit data. Reader objects
/// accept a BinaryBitmap and attempt to decode it.
class BinaryBitmap {
  final Binarizer _binarizer;
  BitMatrix? _matrix;

  BinaryBitmap(this._binarizer);

  /// @return The width of the bitmap.
  int get width {
    return _binarizer.width;
  }

  /// @return The height of the bitmap.
  int get height {
    return _binarizer.height;
  }

  /// Converts one row of luminance data to 1 bit data. May actually do the conversion, or return
  /// cached data. Callers should assume this method is expensive and call it as seldom as possible.
  /// This method is intended for decoding 1D barcodes and may choose to apply sharpening.
  ///
  /// @param y The row to fetch, which must be in [0, bitmap height)
  /// @param row An optional preallocated array. If null or too small, it will be ignored.
  ///            If used, the Binarizer will call BitArray.clear(). Always use the returned object.
  /// @return The array of bits for this row (true means black).
  /// @throws NotFoundException if row can't be binarized
  BitArray getBlackRow(int y, BitArray row) {
    return _binarizer.getBlackRow(y, row);
  }

  /// Converts a 2D array of luminance data to 1 bit. As above, assume this method is expensive
  /// and do not call it repeatedly. This method is intended for decoding 2D barcodes and may or
  /// may not apply sharpening. Therefore, a row from this matrix may not be identical to one
  /// fetched using getBlackRow(), so don't mix and match between them.
  ///
  /// @return The 2D array of bits for the image (true means black).
  /// @throws NotFoundException if image can't be binarized to make a matrix
  BitMatrix getBlackMatrix() {
    // The matrix is created on demand the first time it is requested, then cached. There are two
    // reasons for this:
    // 1. This work will never be done if the caller only installs 1D Reader objects, or if a
    //    1D Reader finds a barcode before the 2D Readers run.
    // 2. This work will only be done once even if the caller installs multiple 2D Readers.
    if (_matrix == null) {
      _matrix = _binarizer.getBlackMatrix();
    }
    return _matrix!;
  }

  /// @return Whether this bitmap can be cropped.
  bool get isCropSupported {
    return _binarizer.luminanceSource.isCropSupported;
  }

  /// Returns a new object with cropped image data. Implementations may keep a reference to the
  /// original data rather than a copy. Only callable if isCropSupported() is true.
  ///
  /// @param left The left coordinate, which must be in [0,getWidth())
  /// @param top The top coordinate, which must be in [0,getHeight())
  /// @param width The width of the rectangle to crop.
  /// @param height The height of the rectangle to crop.
  /// @return A cropped version of this object.
  BinaryBitmap crop(int left, int top, int width, int height) {
    var newSource = _binarizer.luminanceSource.crop(left, top, width, height);
    return BinaryBitmap(_binarizer.createBinarizer(newSource));
  }

  /// @return Whether this bitmap supports counter-clockwise rotation.
  bool isRotateSupported() {
    return _binarizer.luminanceSource.isRotateSupported;
  }

  /// Returns a new object with rotated image data by 90 degrees counterclockwise.
  /// Only callable if {@link #isRotateSupported()} is true.
  ///
  /// @return A rotated version of this object.
  BinaryBitmap rotateCounterClockwise() {
    var newSource = _binarizer.luminanceSource.rotateCounterClockwise();
    return BinaryBitmap(_binarizer.createBinarizer(newSource));
  }

  /// Returns a new object with rotated image data by 45 degrees counterclockwise.
  /// Only callable if {@link #isRotateSupported()} is true.
  ///
  /// @return A rotated version of this object.
  BinaryBitmap rotateCounterClockwise45() {
    var newSource = _binarizer.luminanceSource.rotateCounterClockwise45();
    return BinaryBitmap(_binarizer.createBinarizer(newSource));
  }

  @override
  String toString() {
    try {
      return getBlackMatrix().toString();
    } on NotFoundException catch (_) {
      return "";
    }
  }
}
