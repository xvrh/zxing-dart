import 'finder_pattern.dart';

/// <p>Encapsulates information about finder patterns in an image, including the location of
/// the three finder patterns, and their estimated module size.</p>
///
/// @author Sean Owen
class FinderPatternInfo {
  final FinderPattern bottomLeft;
  final FinderPattern topLeft;
  final FinderPattern topRight;

  FinderPatternInfo(List<FinderPattern> patternCenters)
      : this.bottomLeft = patternCenters[0],
        this.topLeft = patternCenters[1],
        this.topRight = patternCenters[2];
}
