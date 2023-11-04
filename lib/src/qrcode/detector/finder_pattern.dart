import '../../result_point.dart';

/// <p>Encapsulates a finder pattern, which are the three square patterns found in
/// the corners of QR Codes. It also encapsulates a count of similar finder patterns,
/// as a convenience to the finder's bookkeeping.</p>
///
/// @author Sean Owen
class FinderPattern extends ResultPoint {
  final double estimatedModuleSize;
  final int count;

  FinderPattern(super.posX, super.posY, this.estimatedModuleSize, {int? count})
      : count = count ?? 1;

  /// <p>Determines if this finder pattern "about equals" a finder pattern at the stated
  /// position and size -- meaning, it is at nearly the same center with nearly the same size.</p>
  bool aboutEquals(double moduleSize, double i, double j) {
    if ((i - y).abs() <= moduleSize && (j - x).abs() <= moduleSize) {
      var moduleSizeDiff = (moduleSize - estimatedModuleSize).abs();
      return moduleSizeDiff <= 1.0 || moduleSizeDiff <= estimatedModuleSize;
    }
    return false;
  }

  /// Combines this object's current estimate of a finder pattern position and module size
  /// with a new estimate. It returns a new {@code FinderPattern} containing a weighted average
  /// based on count.
  FinderPattern combineEstimate(double i, double j, double newModuleSize) {
    var combinedCount = count + 1;
    var combinedX = (count * x + j) / combinedCount;
    var combinedY = (count * y + i) / combinedCount;
    var combinedModuleSize =
        (count * estimatedModuleSize + newModuleSize) / combinedCount;
    return FinderPattern(combinedX, combinedY, combinedModuleSize,
        count: combinedCount);
  }
}
