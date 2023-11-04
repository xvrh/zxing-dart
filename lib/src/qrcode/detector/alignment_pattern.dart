import '../../result_point.dart';

/// <p>Encapsulates an alignment pattern, which are the smaller square patterns found in
/// all but the simplest QR Codes.</p>
///
/// @author Sean Owen
class AlignmentPattern extends ResultPoint {
  final double _estimatedModuleSize;

  AlignmentPattern(super.posX, super.posY, this._estimatedModuleSize);

  /// <p>Determines if this alignment pattern "about equals" an alignment pattern at the stated
  /// position and size -- meaning, it is at nearly the same center with nearly the same size.</p>
  bool aboutEquals(double moduleSize, double i, double j) {
    if ((i - y).abs() <= moduleSize && (j - x).abs() <= moduleSize) {
      var moduleSizeDiff = (moduleSize - _estimatedModuleSize).abs();
      return moduleSizeDiff <= 1.0 || moduleSizeDiff <= _estimatedModuleSize;
    }
    return false;
  }

  /// Combines this object's current estimate of a finder pattern position and module size
  /// with a new estimate. It returns a new {@code FinderPattern} containing an average of the two.
  AlignmentPattern combineEstimate(double i, double j, double newModuleSize) {
    var combinedX = (x + j) / 2.0;
    var combinedY = (y + i) / 2.0;
    var combinedModuleSize = (_estimatedModuleSize + newModuleSize) / 2.0;
    return AlignmentPattern(combinedX, combinedY, combinedModuleSize);
  }
}
