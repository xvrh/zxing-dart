import '../../result_point.dart';

/// <p>Encapsulates a finder pattern, which are the three square patterns found in
/// the corners of QR Codes. It also encapsulates a count of similar finder patterns,
/// as a convenience to the finder's bookkeeping.</p>
///
/// @author Sean Owen
class FinderPattern extends ResultPoint {
  final double estimatedModuleSize;
  final int count;

  FinderPattern(double posX, double posY, this.estimatedModuleSize,
      {int? count})
      : count = count ?? 1,
        super(posX, posY);

  /// <p>Determines if this finder pattern "about equals" a finder pattern at the stated
  /// position and size -- meaning, it is at nearly the same center with nearly the same size.</p>
  bool aboutEquals(double moduleSize, double i, double j) {
    if ((i - y).abs() <= moduleSize && (j - x).abs() <= moduleSize) {
      double moduleSizeDiff = (moduleSize - estimatedModuleSize).abs();
      return moduleSizeDiff <= 1.0 || moduleSizeDiff <= estimatedModuleSize;
    }
    return false;
  }

  /// Combines this object's current estimate of a finder pattern position and module size
  /// with a new estimate. It returns a new {@code FinderPattern} containing a weighted average
  /// based on count.
  FinderPattern combineEstimate(double i, double j, double newModuleSize) {
    int combinedCount = count + 1;
    double combinedX = (count * x + j) / combinedCount;
    double combinedY = (count * y + i) / combinedCount;
    double combinedModuleSize =
        (count * estimatedModuleSize + newModuleSize) / combinedCount;
    return FinderPattern(combinedX, combinedY, combinedModuleSize,
        count: combinedCount);
  }
}
