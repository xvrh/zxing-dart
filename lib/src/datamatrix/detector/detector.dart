import 'dart:math' as math;
import '../../common/bit_matrix.dart';
import '../../common/detector/white_rectangle_detector.dart';
import '../../common/detector_result.dart';
import '../../common/grid_sampler.dart';
import '../../not_found_exception.dart';
import '../../result_point.dart';

/// <p>Encapsulates logic that can detect a Data Matrix Code in an image, even if the Data Matrix Code
/// is rotated or skewed, or partially obscured.</p>
///
/// @author Sean Owen
class Detector {
  final BitMatrix _image;
  final WhiteRectangleDetector _rectangleDetector;

  Detector(this._image) : _rectangleDetector = WhiteRectangleDetector(_image);

  /// <p>Detects a Data Matrix Code in an image.</p>
  ///
  /// @return {@link DetectorResult} encapsulating results of detecting a Data Matrix Code
  /// @throws NotFoundException if no Data Matrix Code can be found
  DetectorResult detect() {
    var cornerPoints = _rectangleDetector.detect();

    var points = _detectSolid1(cornerPoints);
    points = _detectSolid2(points);
    var correctedTopRight = _correctTopRight(points);
    if (correctedTopRight == null) {
      throw NotFoundException();
    }
    points[3] = correctedTopRight;
    points = _shiftToModuleCenter(points);

    var topLeft = points[0];
    var bottomLeft = points[1];
    var bottomRight = points[2];
    var topRight = points[3];

    var dimensionTop = _transitionsBetween(topLeft, topRight) + 1;
    var dimensionRight = _transitionsBetween(bottomRight, topRight) + 1;
    if ((dimensionTop & 0x01) == 1) {
      dimensionTop += 1;
    }
    if ((dimensionRight & 0x01) == 1) {
      dimensionRight += 1;
    }

    if (4 * dimensionTop < 6 * dimensionRight &&
        4 * dimensionRight < 6 * dimensionTop) {
      // The matrix is square
      dimensionTop = dimensionRight = math.max(dimensionTop, dimensionRight);
    }

    var bits = _sampleGrid(_image, topLeft, bottomLeft, bottomRight, topRight,
        dimensionTop, dimensionRight);

    return DetectorResult(bits, [topLeft, bottomLeft, bottomRight, topRight]);
  }

  static ResultPoint _shiftPoint(ResultPoint point, ResultPoint to, int div) {
    var x = (to.x - point.x) / (div + 1);
    var y = (to.y - point.y) / (div + 1);
    return ResultPoint(point.x + x, point.y + y);
  }

  static ResultPoint _moveAway(ResultPoint point, double fromX, double fromY) {
    var x = point.x;
    var y = point.y;

    if (x < fromX) {
      x -= 1;
    } else {
      x += 1;
    }

    if (y < fromY) {
      y -= 1;
    } else {
      y += 1;
    }

    return ResultPoint(x, y);
  }

  /// Detect a solid side which has minimum transition.
  List<ResultPoint> _detectSolid1(List<ResultPoint> cornerPoints) {
    // 0  2
    // 1  3
    var pointA = cornerPoints[0];
    var pointB = cornerPoints[1];
    var pointC = cornerPoints[3];
    var pointD = cornerPoints[2];

    var trAB = _transitionsBetween(pointA, pointB);
    var trBC = _transitionsBetween(pointB, pointC);
    var trCD = _transitionsBetween(pointC, pointD);
    var trDA = _transitionsBetween(pointD, pointA);

    // 0..3
    // :  :
    // 1--2
    var min = trAB;
    var points = [pointD, pointA, pointB, pointC];
    if (min > trBC) {
      min = trBC;
      points[0] = pointA;
      points[1] = pointB;
      points[2] = pointC;
      points[3] = pointD;
    }
    if (min > trCD) {
      min = trCD;
      points[0] = pointB;
      points[1] = pointC;
      points[2] = pointD;
      points[3] = pointA;
    }
    if (min > trDA) {
      points[0] = pointC;
      points[1] = pointD;
      points[2] = pointA;
      points[3] = pointB;
    }

    return points;
  }

  /// Detect a second solid side next to first solid side.
  List<ResultPoint> _detectSolid2(List<ResultPoint> points) {
    // A..D
    // :  :
    // B--C
    var pointA = points[0];
    var pointB = points[1];
    var pointC = points[2];
    var pointD = points[3];

    // Transition detection on the edge is not stable.
    // To safely detect, shift the points to the module center.
    var tr = _transitionsBetween(pointA, pointD);
    var pointBs = _shiftPoint(pointB, pointC, (tr + 1) * 4);
    var pointCs = _shiftPoint(pointC, pointB, (tr + 1) * 4);
    var trBA = _transitionsBetween(pointBs, pointA);
    var trCD = _transitionsBetween(pointCs, pointD);

    // 0..3
    // |  :
    // 1--2
    if (trBA < trCD) {
      // solid sides: A-B-C
      points[0] = pointA;
      points[1] = pointB;
      points[2] = pointC;
      points[3] = pointD;
    } else {
      // solid sides: B-C-D
      points[0] = pointB;
      points[1] = pointC;
      points[2] = pointD;
      points[3] = pointA;
    }

    return points;
  }

  /// Calculates the corner position of the white top right module.
  ResultPoint? _correctTopRight(List<ResultPoint> points) {
    // A..D
    // |  :
    // B--C
    var pointA = points[0];
    var pointB = points[1];
    var pointC = points[2];
    var pointD = points[3];

    // shift points for safe transition detection.
    var trTop = _transitionsBetween(pointA, pointD);
    var trRight = _transitionsBetween(pointB, pointD);
    var pointAs = _shiftPoint(pointA, pointB, (trRight + 1) * 4);
    var pointCs = _shiftPoint(pointC, pointB, (trTop + 1) * 4);

    trTop = _transitionsBetween(pointAs, pointD);
    trRight = _transitionsBetween(pointCs, pointD);

    var candidate1 = ResultPoint(pointD.x + (pointC.x - pointB.x) / (trTop + 1),
        pointD.y + (pointC.y - pointB.y) / (trTop + 1));
    var candidate2 = ResultPoint(
        pointD.x + (pointA.x - pointB.x) / (trRight + 1),
        pointD.y + (pointA.y - pointB.y) / (trRight + 1));

    if (!_isValid(candidate1)) {
      if (_isValid(candidate2)) {
        return candidate2;
      }
      return null;
    }
    if (!_isValid(candidate2)) {
      return candidate1;
    }

    var sumc1 = _transitionsBetween(pointAs, candidate1) +
        _transitionsBetween(pointCs, candidate1);
    var sumc2 = _transitionsBetween(pointAs, candidate2) +
        _transitionsBetween(pointCs, candidate2);

    if (sumc1 > sumc2) {
      return candidate1;
    } else {
      return candidate2;
    }
  }

  /// Shift the edge points to the module center.
  List<ResultPoint> _shiftToModuleCenter(List<ResultPoint> points) {
    // A..D
    // |  :
    // B--C
    var pointA = points[0];
    var pointB = points[1];
    var pointC = points[2];
    var pointD = points[3];

    // calculate pseudo dimensions
    var dimH = _transitionsBetween(pointA, pointD) + 1;
    var dimV = _transitionsBetween(pointC, pointD) + 1;

    // shift points for safe dimension detection
    var pointAs = _shiftPoint(pointA, pointB, dimV * 4);
    var pointCs = _shiftPoint(pointC, pointB, dimH * 4);

    //  calculate more precise dimensions
    dimH = _transitionsBetween(pointAs, pointD) + 1;
    dimV = _transitionsBetween(pointCs, pointD) + 1;
    if ((dimH & 0x01) == 1) {
      dimH += 1;
    }
    if ((dimV & 0x01) == 1) {
      dimV += 1;
    }

    // WhiteRectangleDetector returns points inside of the rectangle.
    // I want points on the edges.
    var centerX = (pointA.x + pointB.x + pointC.x + pointD.x) / 4;
    var centerY = (pointA.y + pointB.y + pointC.y + pointD.y) / 4;
    pointA = _moveAway(pointA, centerX, centerY);
    pointB = _moveAway(pointB, centerX, centerY);
    pointC = _moveAway(pointC, centerX, centerY);
    pointD = _moveAway(pointD, centerX, centerY);

    ResultPoint pointBs;
    ResultPoint pointDs;

    // shift points to the center of each modules
    pointAs = _shiftPoint(pointA, pointB, dimV * 4);
    pointAs = _shiftPoint(pointAs, pointD, dimH * 4);
    pointBs = _shiftPoint(pointB, pointA, dimV * 4);
    pointBs = _shiftPoint(pointBs, pointC, dimH * 4);
    pointCs = _shiftPoint(pointC, pointD, dimV * 4);
    pointCs = _shiftPoint(pointCs, pointB, dimH * 4);
    pointDs = _shiftPoint(pointD, pointC, dimV * 4);
    pointDs = _shiftPoint(pointDs, pointA, dimH * 4);

    return [pointAs, pointBs, pointCs, pointDs];
  }

  bool _isValid(ResultPoint p) {
    return p.x >= 0 &&
        p.x <= _image.width - 1 &&
        p.y > 0 &&
        p.y <= _image.height - 1;
  }

  static BitMatrix _sampleGrid(
      BitMatrix image,
      ResultPoint topLeft,
      ResultPoint bottomLeft,
      ResultPoint bottomRight,
      ResultPoint topRight,
      int dimensionX,
      int dimensionY) {
    var sampler = GridSampler.gridSampler;

    return sampler.sampleGrid(
        image,
        dimensionX,
        dimensionY,
        0.5,
        0.5,
        dimensionX - 0.5,
        0.5,
        dimensionX - 0.5,
        dimensionY - 0.5,
        0.5,
        dimensionY - 0.5,
        topLeft.x,
        topLeft.y,
        topRight.x,
        topRight.y,
        bottomRight.x,
        bottomRight.y,
        bottomLeft.x,
        bottomLeft.y);
  }

  /// Counts the number of black/white transitions between two points, using something like Bresenham's algorithm.
  int _transitionsBetween(ResultPoint from, ResultPoint to) {
    // See QR Code Detector, sizeOfBlackWhiteBlackRun()
    var fromX = from.x.toInt();
    var fromY = from.y.toInt();
    var toX = to.x.toInt();
    var toY = math.min(_image.height - 1, to.y.toInt());

    var steep = (toY - fromY).abs() > (toX - fromX).abs();
    if (steep) {
      var temp = fromX;
      fromX = fromY;
      fromY = temp;
      temp = toX;
      toX = toY;
      toY = temp;
    }

    var dx = (toX - fromX).abs();
    var dy = (toY - fromY).abs();
    var error = -dx ~/ 2;
    var ystep = fromY < toY ? 1 : -1;
    var xstep = fromX < toX ? 1 : -1;
    var transitions = 0;
    var inBlack = _image.get(steep ? fromY : fromX, steep ? fromX : fromY);
    for (var x = fromX, y = fromY; x != toX; x += xstep) {
      var isBlack = _image.get(steep ? y : x, steep ? x : y);
      if (isBlack != inBlack) {
        transitions++;
        inBlack = isBlack;
      }
      error += dy;
      if (error > 0) {
        if (y == toY) {
          break;
        }
        y += ystep;
        error -= dx;
      }
    }
    return transitions;
  }
}
