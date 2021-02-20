import 'common/detector/math_utils.dart';

/// <p>Encapsulates a point of interest in an image containing a barcode. Typically, this
/// would be the location of a finder pattern or the corner of the barcode, for example.</p>
///
/// @author Sean Owen
class ResultPoint {
  final double x;
  final double y;

  ResultPoint(this.x, this.y);

  @override
  bool operator ==(Object other) {
    if (other is ResultPoint) {
      return x == other.x && y == other.y;
    }
    return false;
  }

  @override
  int get hashCode {
    return 31 * x.toInt() + y.toInt();
  }

  @override
  String toString() {
    return '($x,$y)';
  }

  /// Orders an array of three ResultPoints in an order [A,B,C] such that AB is less than AC
  /// and BC is less than AC, and the angle between BC and BA is less than 180 degrees.
  ///
  /// @param patterns array of three {@code ResultPoint} to order
  static void orderBestPatterns(List<ResultPoint> patterns) {
    // Find distances between pattern centers
    var zeroOneDistance = distance(patterns[0], patterns[1]);
    var oneTwoDistance = distance(patterns[1], patterns[2]);
    var zeroTwoDistance = distance(patterns[0], patterns[2]);

    ResultPoint pointA;
    ResultPoint pointB;
    ResultPoint pointC;
    // Assume one closest to other two is B; A and C will just be guesses at first
    if (oneTwoDistance >= zeroOneDistance &&
        oneTwoDistance >= zeroTwoDistance) {
      pointB = patterns[0];
      pointA = patterns[1];
      pointC = patterns[2];
    } else if (zeroTwoDistance >= oneTwoDistance &&
        zeroTwoDistance >= zeroOneDistance) {
      pointB = patterns[1];
      pointA = patterns[0];
      pointC = patterns[2];
    } else {
      pointB = patterns[2];
      pointA = patterns[0];
      pointC = patterns[1];
    }

    // Use cross product to figure out whether A and C are correct or flipped.
    // This asks whether BC x BA has a positive z component, which is the arrangement
    // we want for A, B, C. If it's negative, then we've got it flipped around and
    // should swap A and C.
    if (crossProductZ(pointA, pointB, pointC) < 0.0) {
      var temp = pointA;
      pointA = pointC;
      pointC = temp;
    }

    patterns[0] = pointA;
    patterns[1] = pointB;
    patterns[2] = pointC;
  }

  /// @param pattern1 first pattern
  /// @param pattern2 second pattern
  /// @return distance between two points
  static double distance(ResultPoint pattern1, ResultPoint pattern2) {
    return MathUtils.distance(pattern1.x, pattern1.y, pattern2.x, pattern2.y);
  }

  /// Returns the z component of the cross product between vectors BC and BA.
  static double crossProductZ(
      ResultPoint pointA, ResultPoint pointB, ResultPoint pointC) {
    var bX = pointB.x;
    var bY = pointB.y;
    return ((pointC.x - bX) * (pointA.y - bY)) -
        ((pointC.y - bY) * (pointA.x - bX));
  }
}
