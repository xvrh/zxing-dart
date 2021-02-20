import 'dart:typed_data';
import '../../common/bit_matrix.dart';
import '../../not_found_exception.dart';
import '../../result_point_callback.dart';
import 'alignment_pattern.dart';

/// <p>This class attempts to find alignment patterns in a QR Code. Alignment patterns look like finder
/// patterns but are smaller and appear at regular intervals throughout the image.</p>
///
/// <p>At the moment this only looks for the bottom-right alignment pattern.</p>
///
/// <p>This is mostly a simplified copy of {@link FinderPatternFinder}. It is copied,
/// pasted and stripped down here for maximum performance but does unfortunately duplicate
/// some code.</p>
///
/// <p>This class is thread-safe but not reentrant. Each thread must allocate its own object.</p>
///
/// @author Sean Owen
class AlignmentPatternFinder {
  final BitMatrix image;
  final List<AlignmentPattern> possibleCenters = <AlignmentPattern>[];
  final int startX;
  final int startY;
  final int width;
  final int height;
  final double moduleSize;
  final crossCheckStateCount = Int32List(3);
  final ResultPointCallback? resultPointCallback;

  /// <p>Creates a finder that will look in a portion of the whole image.</p>
  ///
  /// @param image image to search
  /// @param startX left column from which to start searching
  /// @param startY top row from which to start searching
  /// @param width width of region to search
  /// @param height height of region to search
  /// @param moduleSize estimated module size so far
  AlignmentPatternFinder(this.image, this.startX, this.startY, this.width,
      this.height, this.moduleSize,
      {this.resultPointCallback});

  /// <p>This method attempts to find the bottom-right alignment pattern in the image. It is a bit messy since
  /// it's pretty performance-critical and so is written to be fast foremost.</p>
  ///
  /// @return {@link AlignmentPattern} if found
  /// @throws NotFoundException if not found
  AlignmentPattern find() {
    var startX = this.startX;
    var height = this.height;
    var maxJ = startX + width;
    var middleI = startY + (height ~/ 2);
    // We are looking for black/white/black modules in 1:1:1 ratio;
    // this tracks the number of black/white/black modules seen so far
    var stateCount = Int32List(3);
    for (var iGen = 0; iGen < height; iGen++) {
      // Search from middle outwards
      var i =
          middleI + ((iGen & 0x01) == 0 ? (iGen + 1) ~/ 2 : -((iGen + 1) ~/ 2));
      stateCount[0] = 0;
      stateCount[1] = 0;
      stateCount[2] = 0;
      var j = startX;
      // Burn off leading white pixels before anything else; if we start in the middle of
      // a white run, it doesn't make sense to count its length, since we don't know if the
      // white run continued to the left of the start point
      while (j < maxJ && !image.get(j, i)) {
        j++;
      }
      var currentState = 0;
      while (j < maxJ) {
        if (image.get(j, i)) {
          // Black pixel
          if (currentState == 1) {
            // Counting black pixels
            stateCount[1]++;
          } else {
            // Counting white pixels
            if (currentState == 2) {
              // A winner?
              if (_foundPatternCross(stateCount)) {
                // Yes
                var confirmed = _handlePossibleCenter(stateCount, i, j);
                if (confirmed != null) {
                  return confirmed;
                }
              }
              stateCount[0] = stateCount[2];
              stateCount[1] = 1;
              stateCount[2] = 0;
              currentState = 1;
            } else {
              stateCount[++currentState]++;
            }
          }
        } else {
          // White pixel
          if (currentState == 1) {
            // Counting black pixels
            currentState++;
          }
          stateCount[currentState]++;
        }
        j++;
      }
      if (_foundPatternCross(stateCount)) {
        var confirmed = _handlePossibleCenter(stateCount, i, maxJ);
        if (confirmed != null) {
          return confirmed;
        }
      }
    }

    // Hmm, nothing we saw was observed and confirmed twice. If we had
    // any guess at all, return it.
    if (possibleCenters.isNotEmpty) {
      return possibleCenters[0];
    }

    throw NotFoundException();
  }

  /// Given a count of black/white/black pixels just seen and an end position,
  /// figures the location of the center of this black/white/black run.
  static double _centerFromEnd(Int32List stateCount, int end) {
    return (end - stateCount[2]) - stateCount[1] / 2.0;
  }

  /// @param stateCount count of black/white/black pixels just read
  /// @return true iff the proportions of the counts is close enough to the 1/1/1 ratios
  ///         used by alignment patterns to be considered a match
  bool _foundPatternCross(Int32List stateCount) {
    var moduleSize = this.moduleSize;
    var maxVariance = moduleSize / 2.0;
    for (var i = 0; i < 3; i++) {
      if ((moduleSize - stateCount[i]).abs() >= maxVariance) {
        return false;
      }
    }
    return true;
  }

  /// <p>After a horizontal scan finds a potential alignment pattern, this method
  /// "cross-checks" by scanning down vertically through the center of the possible
  /// alignment pattern to see if the same proportion is detected.</p>
  ///
  /// @param startI row where an alignment pattern was detected
  /// @param centerJ center of the section that appears to cross an alignment pattern
  /// @param maxCount maximum reasonable number of modules that should be
  /// observed in any reading state, based on the results of the horizontal scan
  /// @return vertical center of alignment pattern, or {@link double#NaN} if not found
  double _crossCheckVertical(
      int startI, int centerJ, int maxCount, int originalStateCountTotal) {
    var image = this.image;

    var maxI = image.height;
    var stateCount = crossCheckStateCount;
    stateCount[0] = 0;
    stateCount[1] = 0;
    stateCount[2] = 0;

    // Start counting up from center
    var i = startI;
    while (i >= 0 && image.get(centerJ, i) && stateCount[1] <= maxCount) {
      stateCount[1]++;
      i--;
    }
    // If already too many modules in this state or ran off the edge:
    if (i < 0 || stateCount[1] > maxCount) {
      return double.nan;
    }
    while (i >= 0 && !image.get(centerJ, i) && stateCount[0] <= maxCount) {
      stateCount[0]++;
      i--;
    }
    if (stateCount[0] > maxCount) {
      return double.nan;
    }

    // Now also count down from center
    i = startI + 1;
    while (i < maxI && image.get(centerJ, i) && stateCount[1] <= maxCount) {
      stateCount[1]++;
      i++;
    }
    if (i == maxI || stateCount[1] > maxCount) {
      return double.nan;
    }
    while (i < maxI && !image.get(centerJ, i) && stateCount[2] <= maxCount) {
      stateCount[2]++;
      i++;
    }
    if (stateCount[2] > maxCount) {
      return double.nan;
    }

    var stateCountTotal = stateCount[0] + stateCount[1] + stateCount[2];
    if (5 * (stateCountTotal - originalStateCountTotal).abs() >=
        2 * originalStateCountTotal) {
      return double.nan;
    }

    return _foundPatternCross(stateCount)
        ? _centerFromEnd(stateCount, i)
        : double.nan;
  }

  /// <p>This is called when a horizontal scan finds a possible alignment pattern. It will
  /// cross check with a vertical scan, and if successful, will see if this pattern had been
  /// found on a previous horizontal scan. If so, we consider it confirmed and conclude we have
  /// found the alignment pattern.</p>
  ///
  /// @param stateCount reading state module counts from horizontal scan
  /// @param i row where alignment pattern may be found
  /// @param j end of possible alignment pattern in row
  /// @return {@link AlignmentPattern} if we have found the same pattern twice, or null if not
  AlignmentPattern? _handlePossibleCenter(Int32List stateCount, int i, int j) {
    var stateCountTotal = stateCount[0] + stateCount[1] + stateCount[2];
    var centerJ = _centerFromEnd(stateCount, j);
    var centerI = _crossCheckVertical(
        i, centerJ.toInt(), 2 * stateCount[1], stateCountTotal);
    if (!centerI.isNaN) {
      var estimatedModuleSize =
          (stateCount[0] + stateCount[1] + stateCount[2]) / 3.0;
      for (var center in possibleCenters) {
        // Look for about the same center and module size:
        if (center.aboutEquals(estimatedModuleSize, centerI, centerJ)) {
          return center.combineEstimate(centerI, centerJ, estimatedModuleSize);
        }
      }
      // Hadn't found this before; save it
      var point = AlignmentPattern(centerJ, centerI, estimatedModuleSize);
      possibleCenters.add(point);
      if (resultPointCallback != null) {
        resultPointCallback!(point);
      }
    }
    return null;
  }
}
