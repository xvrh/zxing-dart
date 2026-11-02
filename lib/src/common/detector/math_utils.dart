import 'dart:math' as math;

/// General math-related and numeric utility functions.
class MathUtils {
  /// Ends up being a bit faster than {@link Math#round(float)}. This merely rounds its
  /// argument to the nearest int, where x.5 rounds up to x+1. Semantics of this shortcut
  /// differ slightly from {@link Math#round(float)} in that half rounds down for negative
  /// values. -2.5 rounds to -3, not -2. For purposes here it makes no difference.
  ///
  /// @param d real value to round
  /// @return nearest {@code int}
  static int round(double d) {
    return toInt(d + (d < 0.0 ? -0.5 : 0.5));
  }

  /// Truncates like a Java `(int)` cast, where [double.toInt] would throw: NaN becomes 0 and
  /// the infinities are clamped to the 32-bit range.
  static int toInt(double d) {
    if (d.isNaN) {
      return 0;
    }
    if (d >= 0x7FFFFFFF) {
      return 0x7FFFFFFF;
    }
    if (d <= -0x80000000) {
      return -0x80000000;
    }
    return d.toInt();
  }

  /// @param aX point A x coordinate
  /// @param aY point A y coordinate
  /// @param bX point B x coordinate
  /// @param bY point B y coordinate
  /// @return Euclidean distance between points A and B
  static double distance(num aX, num aY, num bX, num bY) {
    var xDiff = aX - bX;
    var yDiff = aY - bY;
    return math.sqrt(xDiff * xDiff + yDiff * yDiff);
  }

  /// @param array values to sum
  /// @return sum of values in array
  static int sum(List<int> array) {
    var count = 0;
    for (var a in array) {
      count += a;
    }
    return count;
  }
}
