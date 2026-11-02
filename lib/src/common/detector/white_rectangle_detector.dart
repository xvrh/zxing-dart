import '../../not_found_exception.dart';
import '../../result_point.dart';
import '../bit_matrix.dart';
import 'math_utils.dart';

/// <p>
/// Detects a candidate barcode-like rectangular region within an image. It
/// starts around the center of the image, increases the size of the candidate
/// region until it finds a white rectangular region. By keeping track of the
/// last black points it encountered, it determines the corners of the barcode.
/// </p>
///
/// @author David Olivier
class WhiteRectangleDetector {
  static const _initSize = 10;
  static const _corr = 1;

  final BitMatrix _image;
  final int _height;
  final int _width;
  late final int _leftInit;
  late final int _rightInit;
  late final int _downInit;
  late final int _upInit;

  /// @param image barcode image to find a rectangle in
  /// @param initSize initial size of search area around center
  /// @param x x position of search center
  /// @param y y position of search center
  /// @throws NotFoundException if image is too small to accommodate {@code initSize}
  WhiteRectangleDetector(this._image,
      {int initSize = _initSize, int? x, int? y})
      : _height = _image.height,
        _width = _image.width {
    x ??= _width ~/ 2;
    y ??= _height ~/ 2;
    var halfsize = initSize ~/ 2;
    _leftInit = x - halfsize;
    _rightInit = x + halfsize;
    _upInit = y - halfsize;
    _downInit = y + halfsize;
    if (_upInit < 0 ||
        _leftInit < 0 ||
        _downInit >= _height ||
        _rightInit >= _width) {
      throw NotFoundException();
    }
  }

  /// <p>
  /// Detects a candidate barcode-like rectangular region within an image. It
  /// starts around the center of the image, increases the size of the candidate
  /// region until it finds a white rectangular region.
  /// </p>
  ///
  /// @return {@link ResultPoint}[] describing the corners of the rectangular
  ///         region. The first and last points are opposed on the diagonal, as
  ///         are the second and third. The first point will be the topmost
  ///         point and the last, the bottommost. The second point will be
  ///         leftmost and the third, the rightmost
  /// @throws NotFoundException if no Data Matrix Code can be found
  List<ResultPoint> detect() {
    var left = _leftInit;
    var right = _rightInit;
    var up = _upInit;
    var down = _downInit;
    var sizeExceeded = false;
    var aBlackPointFoundOnBorder = true;

    var atLeastOneBlackPointFoundOnRight = false;
    var atLeastOneBlackPointFoundOnBottom = false;
    var atLeastOneBlackPointFoundOnLeft = false;
    var atLeastOneBlackPointFoundOnTop = false;

    while (aBlackPointFoundOnBorder) {
      aBlackPointFoundOnBorder = false;

      // .....
      // .   |
      // .....
      var rightBorderNotWhite = true;
      while ((rightBorderNotWhite || !atLeastOneBlackPointFoundOnRight) &&
          right < _width) {
        rightBorderNotWhite = _containsBlackPoint(up, down, right, false);
        if (rightBorderNotWhite) {
          right++;
          aBlackPointFoundOnBorder = true;
          atLeastOneBlackPointFoundOnRight = true;
        } else if (!atLeastOneBlackPointFoundOnRight) {
          right++;
        }
      }

      if (right >= _width) {
        sizeExceeded = true;
        break;
      }

      // .....
      // .   .
      // .___.
      var bottomBorderNotWhite = true;
      while ((bottomBorderNotWhite || !atLeastOneBlackPointFoundOnBottom) &&
          down < _height) {
        bottomBorderNotWhite = _containsBlackPoint(left, right, down, true);
        if (bottomBorderNotWhite) {
          down++;
          aBlackPointFoundOnBorder = true;
          atLeastOneBlackPointFoundOnBottom = true;
        } else if (!atLeastOneBlackPointFoundOnBottom) {
          down++;
        }
      }

      if (down >= _height) {
        sizeExceeded = true;
        break;
      }

      // .....
      // |   .
      // .....
      var leftBorderNotWhite = true;
      while ((leftBorderNotWhite || !atLeastOneBlackPointFoundOnLeft) &&
          left >= 0) {
        leftBorderNotWhite = _containsBlackPoint(up, down, left, false);
        if (leftBorderNotWhite) {
          left--;
          aBlackPointFoundOnBorder = true;
          atLeastOneBlackPointFoundOnLeft = true;
        } else if (!atLeastOneBlackPointFoundOnLeft) {
          left--;
        }
      }

      if (left < 0) {
        sizeExceeded = true;
        break;
      }

      // .___.
      // .   .
      // .....
      var topBorderNotWhite = true;
      while (
          (topBorderNotWhite || !atLeastOneBlackPointFoundOnTop) && up >= 0) {
        topBorderNotWhite = _containsBlackPoint(left, right, up, true);
        if (topBorderNotWhite) {
          up--;
          aBlackPointFoundOnBorder = true;
          atLeastOneBlackPointFoundOnTop = true;
        } else if (!atLeastOneBlackPointFoundOnTop) {
          up--;
        }
      }

      if (up < 0) {
        sizeExceeded = true;
        break;
      }
    }

    if (!sizeExceeded) {
      var maxSize = right - left;

      ResultPoint? z;
      for (var i = 1; z == null && i < maxSize; i++) {
        z = _getBlackPointOnSegment(left, down - i, left + i, down);
      }

      if (z == null) {
        throw NotFoundException();
      }

      ResultPoint? t;
      //go down right
      for (var i = 1; t == null && i < maxSize; i++) {
        t = _getBlackPointOnSegment(left, up + i, left + i, up);
      }

      if (t == null) {
        throw NotFoundException();
      }

      ResultPoint? x;
      //go down left
      for (var i = 1; x == null && i < maxSize; i++) {
        x = _getBlackPointOnSegment(right, up + i, right - i, up);
      }

      if (x == null) {
        throw NotFoundException();
      }

      ResultPoint? y;
      //go up left
      for (var i = 1; y == null && i < maxSize; i++) {
        y = _getBlackPointOnSegment(right, down - i, right - i, down);
      }

      if (y == null) {
        throw NotFoundException();
      }

      return _centerEdges(y, z, x, t);
    } else {
      throw NotFoundException();
    }
  }

  ResultPoint? _getBlackPointOnSegment(num aX, num aY, num bX, num bY) {
    var dist = MathUtils.round(MathUtils.distance(aX, aY, bX, bY));
    var xStep = (bX - aX) / dist;
    var yStep = (bY - aY) / dist;

    for (var i = 0; i < dist; i++) {
      var x = MathUtils.round(aX + i * xStep);
      var y = MathUtils.round(aY + i * yStep);
      if (_image.get(x, y)) {
        return ResultPoint(x.toDouble(), y.toDouble());
      }
    }
    return null;
  }

  /// recenters the points of a constant distance towards the center
  ///
  /// @param y bottom most point
  /// @param z left most point
  /// @param x right most point
  /// @param t top most point
  /// @return {@link ResultPoint}[] describing the corners of the rectangular
  ///         region. The first and last points are opposed on the diagonal, as
  ///         are the second and third. The first point will be the topmost
  ///         point and the last, the bottommost. The second point will be
  ///         leftmost and the third, the rightmost
  List<ResultPoint> _centerEdges(
      ResultPoint y, ResultPoint z, ResultPoint x, ResultPoint t) {
    //
    //       t            t
    //  z                      x
    //        x    OR    z
    //   y                    y
    //

    var yi = y.x;
    var yj = y.y;
    var zi = z.x;
    var zj = z.y;
    var xi = x.x;
    var xj = x.y;
    var ti = t.x;
    var tj = t.y;

    if (yi < _width / 2.0) {
      return [
        ResultPoint(ti - _corr, tj + _corr),
        ResultPoint(zi + _corr, zj + _corr),
        ResultPoint(xi - _corr, xj - _corr),
        ResultPoint(yi + _corr, yj - _corr)
      ];
    } else {
      return [
        ResultPoint(ti + _corr, tj + _corr),
        ResultPoint(zi + _corr, zj - _corr),
        ResultPoint(xi - _corr, xj + _corr),
        ResultPoint(yi - _corr, yj - _corr)
      ];
    }
  }

  /// Determines whether a segment contains a black point
  ///
  /// @param a          min value of the scanned coordinate
  /// @param b          max value of the scanned coordinate
  /// @param fixed      value of fixed coordinate
  /// @param horizontal set to true if scan must be horizontal, false if vertical
  /// @return true if a black point has been found, else false.
  bool _containsBlackPoint(int a, int b, int fixed, bool horizontal) {
    if (horizontal) {
      for (var x = a; x <= b; x++) {
        if (_image.get(x, fixed)) {
          return true;
        }
      }
    } else {
      for (var y = a; y <= b; y++) {
        if (_image.get(fixed, y)) {
          return true;
        }
      }
    }

    return false;
  }
}
