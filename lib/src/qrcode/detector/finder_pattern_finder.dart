import 'dart:typed_data';
import '../../common/bit_matrix.dart';
import '../../decode_hint.dart';
import '../../not_found_exception.dart';
import '../../result_point.dart';
import '../../result_point_callback.dart';
import 'finder_pattern.dart';
import 'finder_pattern_info.dart';

/// <p>This class attempts to find finder patterns in a QR Code. Finder patterns are the square
/// markers at three corners of a QR Code.</p>
///
/// <p>This class is thread-safe but not reentrant. Each thread must allocate its own object.
///
/// @author Sean Owen
class FinderPatternFinder {
  static final int kCenterQuorum = 2;
  static final int kMinSkip = 3; // 1 pixel/module times 3 modules/center
  static final int kMaxModules =
      97; // support up to version 20 for mobile clients

  final BitMatrix image;
  final possibleCenters = <FinderPattern>[];
  bool _hasSkipped = false;
  final Int32List _crossCheckStateCount = Int32List(5);
  final ResultPointCallback? resultPointCallback;

  /// <p>Creates a finder that will search the image for three finder patterns.</p>
  ///
  /// @param image image to search
  FinderPatternFinder(this.image, {this.resultPointCallback});

  FinderPatternInfo find(DecodeHints hints) {
    var tryHarder = hints.contains(DecodeHintType.tryHarder);
    var maxI = image.height;
    var maxJ = image.width;
    // We are looking for black/white/black/white/black modules in
    // 1:1:3:1:1 ratio; this tracks the number of such modules seen so far

    // Let's assume that the maximum version QR Code we support takes up 1/4 the height of the
    // image, and then account for the center being 3 modules in size. This gives the smallest
    // number of pixels the center could be, so skip this often. When trying harder, look for all
    // QR versions regardless of how dense they are.
    var iSkip = (3 * maxI) ~/ (4 * kMaxModules);
    if (iSkip < kMinSkip || tryHarder) {
      iSkip = kMinSkip;
    }

    var done = false;
    var stateCount = Int32List(5);
    for (var i = iSkip - 1; i < maxI && !done; i += iSkip) {
      // Get a row of black/white values
      doClearCounts(stateCount);
      var currentState = 0;
      for (var j = 0; j < maxJ; j++) {
        if (image.get(j, i)) {
          // Black pixel
          if ((currentState & 1) == 1) {
            // Counting white pixels
            currentState++;
          }
          stateCount[currentState]++;
        } else {
          // White pixel
          if ((currentState & 1) == 0) {
            // Counting black pixels
            if (currentState == 4) {
              // A winner?
              if (foundPatternCross(stateCount)) {
                // Yes
                var confirmed = _handlePossibleCenter(stateCount, i, j);
                if (confirmed) {
                  // Start examining every other line. Checking each line turned out to be too
                  // expensive and didn't improve performance.
                  iSkip = 2;
                  if (_hasSkipped) {
                    done = _haveMultiplyConfirmedCenters();
                  } else {
                    var rowSkip = _findRowSkip();
                    if (rowSkip > stateCount[2]) {
                      // Skip rows between row of lower confirmed center
                      // and top of presumed third confirmed center
                      // but back up a bit to get a full chance of detecting
                      // it, entire width of center of finder pattern

                      // Skip by rowSkip, but back off by stateCount[2] (size of last center
                      // of pattern we saw) to be conservative, and also back off by iSkip which
                      // is about to be re-added
                      i += rowSkip - stateCount[2] - iSkip;
                      j = maxJ - 1;
                    }
                  }
                } else {
                  doShiftCounts2(stateCount);
                  currentState = 3;
                  continue;
                }
                // Clear state to start looking again
                currentState = 0;
                doClearCounts(stateCount);
              } else {
                // No, shift counts back by two
                doShiftCounts2(stateCount);
                currentState = 3;
              }
            } else {
              stateCount[++currentState]++;
            }
          } else {
            // Counting white pixels
            stateCount[currentState]++;
          }
        }
      }
      if (foundPatternCross(stateCount)) {
        var confirmed = _handlePossibleCenter(stateCount, i, maxJ);
        if (confirmed) {
          iSkip = stateCount[0];
          if (_hasSkipped) {
            // Found a third one
            done = _haveMultiplyConfirmedCenters();
          }
        }
      }
    }

    var patternInfo = _selectBestPatterns();
    ResultPoint.orderBestPatterns(patternInfo);

    return FinderPatternInfo(patternInfo);
  }

  /// Given a count of black/white/black/white/black pixels just seen and an end position,
  /// figures the location of the center of this run.
  static double _centerFromEnd(Int32List stateCount, int end) {
    return (end - stateCount[4] - stateCount[3]) - stateCount[2] / 2.0;
  }

  /// @param stateCount count of black/white/black/white/black pixels just read
  /// @return true iff the proportions of the counts is close enough to the 1/1/3/1/1 ratios
  ///         used by finder patterns to be considered a match
  static bool foundPatternCross(Int32List stateCount) {
    var totalModuleSize = 0;
    for (var i = 0; i < 5; i++) {
      var count = stateCount[i];
      if (count == 0) {
        return false;
      }
      totalModuleSize += count;
    }
    if (totalModuleSize < 7) {
      return false;
    }
    var moduleSize = totalModuleSize / 7.0;
    var maxVariance = moduleSize / 2.0;
    // Allow less than 50% variance from 1-1-3-1-1 proportions
    return (moduleSize - stateCount[0]).abs() < maxVariance &&
        (moduleSize - stateCount[1]).abs() < maxVariance &&
        (3.0 * moduleSize - stateCount[2]).abs() < 3 * maxVariance &&
        (moduleSize - stateCount[3]).abs() < maxVariance &&
        (moduleSize - stateCount[4]).abs() < maxVariance;
  }

  /// @param stateCount count of black/white/black/white/black pixels just read
  /// @return true iff the proportions of the counts is close enough to the 1/1/3/1/1 ratios
  ///         used by finder patterns to be considered a match
  static bool foundPatternDiagonal(Int32List stateCount) {
    var totalModuleSize = 0;
    for (var i = 0; i < 5; i++) {
      var count = stateCount[i];
      if (count == 0) {
        return false;
      }
      totalModuleSize += count;
    }
    if (totalModuleSize < 7) {
      return false;
    }
    var moduleSize = totalModuleSize / 7.0;
    var maxVariance = moduleSize / 1.333;
    // Allow less than 75% variance from 1-1-3-1-1 proportions
    return (moduleSize - stateCount[0]).abs() < maxVariance &&
        (moduleSize - stateCount[1]).abs() < maxVariance &&
        (3.0 * moduleSize - stateCount[2]).abs() < 3 * maxVariance &&
        (moduleSize - stateCount[3]).abs() < maxVariance &&
        (moduleSize - stateCount[4]).abs() < maxVariance;
  }

  Int32List _getCrossCheckStateCount() {
    doClearCounts(_crossCheckStateCount);
    return _crossCheckStateCount;
  }

  static void doClearCounts(Int32List counts) {
    for (var i = 0; i < counts.length; i++) {
      counts[i] = 0;
    }
  }

  static void doShiftCounts2(Int32List stateCount) {
    stateCount[0] = stateCount[2];
    stateCount[1] = stateCount[3];
    stateCount[2] = stateCount[4];
    stateCount[3] = 1;
    stateCount[4] = 0;
  }

  /// After a vertical and horizontal scan finds a potential finder pattern, this method
  /// "cross-cross-cross-checks" by scanning down diagonally through the center of the possible
  /// finder pattern to see if the same proportion is detected.
  ///
  /// @param centerI row where a finder pattern was detected
  /// @param centerJ center of the section that appears to cross a finder pattern
  /// @return true if proportions are withing expected limits
  bool _crossCheckDiagonal(int centerI, int centerJ) {
    var stateCount = _getCrossCheckStateCount();

    // Start counting up, left from center finding black center mass
    var i = 0;
    while (
        centerI >= i && centerJ >= i && image.get(centerJ - i, centerI - i)) {
      stateCount[2]++;
      i++;
    }
    if (stateCount[2] == 0) {
      return false;
    }

    // Continue up, left finding white space
    while (
        centerI >= i && centerJ >= i && !image.get(centerJ - i, centerI - i)) {
      stateCount[1]++;
      i++;
    }
    if (stateCount[1] == 0) {
      return false;
    }

    // Continue up, left finding black border
    while (
        centerI >= i && centerJ >= i && image.get(centerJ - i, centerI - i)) {
      stateCount[0]++;
      i++;
    }
    if (stateCount[0] == 0) {
      return false;
    }

    var maxI = image.height;
    var maxJ = image.width;

    // Now also count down, right from center
    i = 1;
    while (centerI + i < maxI &&
        centerJ + i < maxJ &&
        image.get(centerJ + i, centerI + i)) {
      stateCount[2]++;
      i++;
    }

    while (centerI + i < maxI &&
        centerJ + i < maxJ &&
        !image.get(centerJ + i, centerI + i)) {
      stateCount[3]++;
      i++;
    }
    if (stateCount[3] == 0) {
      return false;
    }

    while (centerI + i < maxI &&
        centerJ + i < maxJ &&
        image.get(centerJ + i, centerI + i)) {
      stateCount[4]++;
      i++;
    }
    if (stateCount[4] == 0) {
      return false;
    }

    return foundPatternDiagonal(stateCount);
  }

  /// <p>After a horizontal scan finds a potential finder pattern, this method
  /// "cross-checks" by scanning down vertically through the center of the possible
  /// finder pattern to see if the same proportion is detected.</p>
  ///
  /// @param startI row where a finder pattern was detected
  /// @param centerJ center of the section that appears to cross a finder pattern
  /// @param maxCount maximum reasonable number of modules that should be
  /// observed in any reading state, based on the results of the horizontal scan
  /// @return vertical center of finder pattern, or {@link Float#NaN} if not found
  double _crossCheckVertical(
      int startI, int centerJ, int maxCount, int originalStateCountTotal) {
    var image = this.image;

    var maxI = image.height;
    var stateCount = _getCrossCheckStateCount();

    // Start counting up from center
    var i = startI;
    while (i >= 0 && image.get(centerJ, i)) {
      stateCount[2]++;
      i--;
    }
    if (i < 0) {
      return double.nan;
    }
    while (i >= 0 && !image.get(centerJ, i) && stateCount[1] <= maxCount) {
      stateCount[1]++;
      i--;
    }
    // If already too many modules in this state or ran off the edge:
    if (i < 0 || stateCount[1] > maxCount) {
      return double.nan;
    }
    while (i >= 0 && image.get(centerJ, i) && stateCount[0] <= maxCount) {
      stateCount[0]++;
      i--;
    }
    if (stateCount[0] > maxCount) {
      return double.nan;
    }

    // Now also count down from center
    i = startI + 1;
    while (i < maxI && image.get(centerJ, i)) {
      stateCount[2]++;
      i++;
    }
    if (i == maxI) {
      return double.nan;
    }
    while (i < maxI && !image.get(centerJ, i) && stateCount[3] < maxCount) {
      stateCount[3]++;
      i++;
    }
    if (i == maxI || stateCount[3] >= maxCount) {
      return double.nan;
    }
    while (i < maxI && image.get(centerJ, i) && stateCount[4] < maxCount) {
      stateCount[4]++;
      i++;
    }
    if (stateCount[4] >= maxCount) {
      return double.nan;
    }

    // If we found a finder-pattern-like section, but its size is more than 40% different than
    // the original, assume it's a false positive
    var stateCountTotal = stateCount[0] +
        stateCount[1] +
        stateCount[2] +
        stateCount[3] +
        stateCount[4];
    if (5 * (stateCountTotal - originalStateCountTotal).abs() >=
        2 * originalStateCountTotal) {
      return double.nan;
    }

    return foundPatternCross(stateCount)
        ? _centerFromEnd(stateCount, i)
        : double.nan;
  }

  /// <p>Like {@link #crossCheckVertical(int, int, int, int)}, and in fact is basically identical,
  /// except it reads horizontally instead of vertically. This is used to cross-cross
  /// check a vertical cross check and locate the real center of the alignment pattern.</p>
  double _crossCheckHorizontal(
      int startJ, int centerI, int maxCount, int originalStateCountTotal) {
    var image = this.image;

    var maxJ = image.width;
    var stateCount = _getCrossCheckStateCount();

    var j = startJ;
    while (j >= 0 && image.get(j, centerI)) {
      stateCount[2]++;
      j--;
    }
    if (j < 0) {
      return double.nan;
    }
    while (j >= 0 && !image.get(j, centerI) && stateCount[1] <= maxCount) {
      stateCount[1]++;
      j--;
    }
    if (j < 0 || stateCount[1] > maxCount) {
      return double.nan;
    }
    while (j >= 0 && image.get(j, centerI) && stateCount[0] <= maxCount) {
      stateCount[0]++;
      j--;
    }
    if (stateCount[0] > maxCount) {
      return double.nan;
    }

    j = startJ + 1;
    while (j < maxJ && image.get(j, centerI)) {
      stateCount[2]++;
      j++;
    }
    if (j == maxJ) {
      return double.nan;
    }
    while (j < maxJ && !image.get(j, centerI) && stateCount[3] < maxCount) {
      stateCount[3]++;
      j++;
    }
    if (j == maxJ || stateCount[3] >= maxCount) {
      return double.nan;
    }
    while (j < maxJ && image.get(j, centerI) && stateCount[4] < maxCount) {
      stateCount[4]++;
      j++;
    }
    if (stateCount[4] >= maxCount) {
      return double.nan;
    }

    // If we found a finder-pattern-like section, but its size is significantly different than
    // the original, assume it's a false positive
    var stateCountTotal = stateCount[0] +
        stateCount[1] +
        stateCount[2] +
        stateCount[3] +
        stateCount[4];
    if (5 * (stateCountTotal - originalStateCountTotal).abs() >=
        originalStateCountTotal) {
      return double.nan;
    }

    return foundPatternCross(stateCount)
        ? _centerFromEnd(stateCount, j)
        : double.nan;
  }

  /// <p>This is called when a horizontal scan finds a possible alignment pattern. It will
  /// cross check with a vertical scan, and if successful, will, ah, cross-cross-check
  /// with another horizontal scan. This is needed primarily to locate the real horizontal
  /// center of the pattern in cases of extreme skew.
  /// And then we cross-cross-cross check with another diagonal scan.</p>
  ///
  /// <p>If that succeeds the finder pattern location is added to a list that tracks
  /// the number of times each location has been nearly-matched as a finder pattern.
  /// Each additional find is more evidence that the location is in fact a finder
  /// pattern center
  ///
  /// @param stateCount reading state module counts from horizontal scan
  /// @param i row where finder pattern may be found
  /// @param j end of possible finder pattern in row
  /// @return true if a finder pattern candidate was found this time
  bool _handlePossibleCenter(Int32List stateCount, int i, int j) {
    var stateCountTotal = stateCount[0] +
        stateCount[1] +
        stateCount[2] +
        stateCount[3] +
        stateCount[4];
    var centerJ = _centerFromEnd(stateCount, j);
    var centerI =
        _crossCheckVertical(i, centerJ.toInt(), stateCount[2], stateCountTotal);
    if (!centerI.isNaN) {
      // Re-cross check
      centerJ = _crossCheckHorizontal(
          centerJ.toInt(), centerI.toInt(), stateCount[2], stateCountTotal);
      if (!centerJ.isNaN &&
          _crossCheckDiagonal(centerI.toInt(), centerJ.toInt())) {
        var estimatedModuleSize = stateCountTotal / 7.0;
        var found = false;
        for (var index = 0; index < possibleCenters.length; index++) {
          var center = possibleCenters[index];
          // Look for about the same center and module size:
          if (center.aboutEquals(estimatedModuleSize, centerI, centerJ)) {
            possibleCenters[index] =
                center.combineEstimate(centerI, centerJ, estimatedModuleSize);
            found = true;
            break;
          }
        }
        if (!found) {
          var point = FinderPattern(centerJ, centerI, estimatedModuleSize);
          possibleCenters.add(point);
          if (resultPointCallback != null) {
            resultPointCallback!(point);
          }
        }
        return true;
      }
    }
    return false;
  }

  /// @return number of rows we could safely skip during scanning, based on the first
  ///         two finder patterns that have been located. In some cases their position will
  ///         allow us to infer that the third pattern must lie below a certain point farther
  ///         down in the image.
  int _findRowSkip() {
    var max = possibleCenters.length;
    if (max <= 1) {
      return 0;
    }
    ResultPoint? firstConfirmedCenter;
    for (var center in possibleCenters) {
      if (center.count >= kCenterQuorum) {
        if (firstConfirmedCenter == null) {
          firstConfirmedCenter = center;
        } else {
          // We have two confirmed centers
          // How far down can we skip before resuming looking for the next
          // pattern? In the worst case, only the difference between the
          // difference in the x / y coordinates of the two centers.
          // This is the case where you find top left last.
          _hasSkipped = true;
          return ((firstConfirmedCenter.x - center.x).abs() -
                  (firstConfirmedCenter.y - center.y).abs()) ~/
              2;
        }
      }
    }
    return 0;
  }

  /// @return true iff we have found at least 3 finder patterns that have been detected
  ///         at least {@link #CENTER_QUORUM} times each, and, the estimated module size of the
  ///         candidates is "pretty similar"
  bool _haveMultiplyConfirmedCenters() {
    var confirmedCount = 0;
    var totalModuleSize = 0.0;
    var max = possibleCenters.length;
    for (var pattern in possibleCenters) {
      if (pattern.count >= kCenterQuorum) {
        confirmedCount++;
        totalModuleSize += pattern.estimatedModuleSize;
      }
    }
    if (confirmedCount < 3) {
      return false;
    }
    // OK, we have at least 3 confirmed centers, but, it's possible that one is a "false positive"
    // and that we need to keep looking. We detect this by asking if the estimated module sizes
    // vary too much. We arbitrarily say that when the total deviation from average exceeds
    // 5% of the total module size estimates, it's too much.
    var average = totalModuleSize / max;
    var totalDeviation = 0.0;
    for (var pattern in possibleCenters) {
      totalDeviation += (pattern.estimatedModuleSize - average).abs();
    }
    return totalDeviation <= 0.05 * totalModuleSize;
  }

  /// Get square of distance between a and b.
  static double squaredDistance(FinderPattern a, FinderPattern b) {
    var x = a.x - b.x;
    var y = a.y - b.y;
    return x * x + y * y;
  }

  /// @return the 3 best {@link FinderPattern}s from our list of candidates. The "best" are
  ///         those have similar module size and form a shape closer to a isosceles right triangle.
  /// @throws NotFoundException if 3 such finder patterns do not exist
  List<FinderPattern> _selectBestPatterns() {
    var startSize = possibleCenters.length;
    if (startSize < 3) {
      // Couldn't find enough finder patterns
      throw NotFoundException();
    }

    possibleCenters.sort(_comparePattern);

    var distortion = double.maxFinite;
    var bestPatterns = List<FinderPattern?>.filled(3, null);

    for (var i = 0; i < possibleCenters.length - 2; i++) {
      var fpi = possibleCenters[i];
      var minModuleSize = fpi.estimatedModuleSize;

      for (var j = i + 1; j < possibleCenters.length - 1; j++) {
        var fpj = possibleCenters[j];
        var squares0 = squaredDistance(fpi, fpj);

        for (var k = j + 1; k < possibleCenters.length; k++) {
          var fpk = possibleCenters[k];
          var maxModuleSize = fpk.estimatedModuleSize;
          if (maxModuleSize > minModuleSize * 1.4) {
            // module size is not similar
            continue;
          }

          var a = squares0;
          var b = squaredDistance(fpj, fpk);
          var c = squaredDistance(fpi, fpk);

          // sorts ascending - inlined
          if (a < b) {
            if (b > c) {
              if (a < c) {
                var temp = b;
                b = c;
                c = temp;
              } else {
                var temp = a;
                a = c;
                c = b;
                b = temp;
              }
            }
          } else {
            if (b < c) {
              if (a < c) {
                var temp = a;
                a = b;
                b = temp;
              } else {
                var temp = a;
                a = b;
                b = c;
                c = temp;
              }
            } else {
              var temp = a;
              a = c;
              c = temp;
            }
          }

          // a^2 + b^2 = c^2 (Pythagorean theorem), and a = b (isosceles triangle).
          // Since any right triangle satisfies the formula c^2 - b^2 - a^2 = 0,
          // we need to check both two equal sides separately.
          // The value of |c^2 - 2 * b^2| + |c^2 - 2 * a^2| increases as dissimilarity
          // from isosceles right triangle.
          var d = (c - 2 * b).abs() + (c - 2 * a).abs();
          if (d < distortion) {
            distortion = d;
            bestPatterns[0] = fpi;
            bestPatterns[1] = fpj;
            bestPatterns[2] = fpk;
          }
        }
      }
    }

    if (distortion == double.maxFinite) {
      throw NotFoundException();
    }

    return bestPatterns.cast();
  }

  int _comparePattern(FinderPattern center1, FinderPattern center2) {
    return center1.estimatedModuleSize.compareTo(center2.estimatedModuleSize);
  }
}
