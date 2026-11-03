import 'dart:math' as math;
import 'dart:typed_data';
import '../../../decode_hint.dart';
import '../../../not_found_exception.dart';
import '../../../qrcode/detector/finder_pattern.dart';
import '../../../qrcode/detector/finder_pattern_finder.dart';
import '../../../qrcode/detector/finder_pattern_info.dart';
import '../../../result_point.dart';

/// <p>This class attempts to find finder patterns in a QR Code. Finder patterns are the square
/// markers at three corners of a QR Code.</p>
///
/// <p>This class is thread-safe but not reentrant. Each thread must allocate its own object.
///
/// <p>In contrast to [FinderPatternFinder], this class will return an array of all possible
/// QR code locations in the image.</p>
///
/// <p>Use the TRY_HARDER hint to ask for a more thorough detection.</p>
///
/// @author Sean Owen
/// @author Hannes Erven
class MultiFinderPatternFinder extends FinderPatternFinder {
  // max. legal count of modules per QR code edge (177)
  static const _maxModuleCountPerEdge = 180;
  // min. legal count per modules per QR code edge (11)
  static const _minModuleCountPerEdge = 9;

  /// More or less arbitrary cutoff point for determining if two finder patterns might belong
  /// to the same code if they differ less than DIFF_MODSIZE_CUTOFF_PERCENT percent in their
  /// estimated modules sizes.
  static const _diffModSizeCutoffPercent = 0.05;

  /// More or less arbitrary cutoff point for determining if two finder patterns might belong
  /// to the same code if they differ less than DIFF_MODSIZE_CUTOFF pixels/module in their
  /// estimated modules sizes.
  static const _diffModSizeCutoff = 0.5;

  MultiFinderPatternFinder(super.image, {super.resultPointCallback});

  /// @return the 3 best [FinderPattern]s from our list of candidates. The "best" are
  ///         those that have been detected at least 2 times, and whose module
  ///         size differs from the average among those patterns the least
  /// @throws NotFoundException if 3 such finder patterns do not exist
  List<List<FinderPattern>> _selectMultipleBestPatterns() {
    var possibleCenters = [
      for (var fp in this.possibleCenters)
        if (fp.count >= 2) fp
    ];
    var size = possibleCenters.length;

    if (size < 3) {
      // Couldn't find enough finder patterns
      throw NotFoundException();
    }

    // Begin HE modifications to safely detect multiple codes of equal size
    if (size == 3) {
      return [possibleCenters];
    }

    // Sort by estimated module size to speed up the upcoming checks
    possibleCenters
        .sort((a, b) => b.estimatedModuleSize.compareTo(a.estimatedModuleSize));

    // Now lets start: build a list of tuples of three finder locations that
    //  - feature similar module sizes
    //  - are placed in a distance so the estimated module count is within the QR specification
    //  - have similar distance between upper left/right and left top/bottom finder patterns
    //  - form a triangle with 90° angle (checked by comparing top right/bottom left distance
    //    with pythagoras)
    //
    // Note: we allow each point to be used for more than one code region: this might seem
    // counterintuitive at first, but the performance penalty is not that big. At this point,
    // we cannot make a good quality decision whether the three finders actually represent
    // a QR code, or are just by chance laid out so it looks like there might be a QR code there.
    // So, if the layout seems right, lets have the decoder try to decode.

    var results = <List<FinderPattern>>[]; // holder for the results

    for (var i1 = 0; i1 < (size - 2); i1++) {
      var p1 = possibleCenters[i1];

      for (var i2 = i1 + 1; i2 < (size - 1); i2++) {
        var p2 = possibleCenters[i2];

        // Compare the expected module sizes; if they are really off, skip
        var vModSize12 = (p1.estimatedModuleSize - p2.estimatedModuleSize) /
            math.min(p1.estimatedModuleSize, p2.estimatedModuleSize);
        var vModSize12A =
            (p1.estimatedModuleSize - p2.estimatedModuleSize).abs();
        if (vModSize12A > _diffModSizeCutoff &&
            vModSize12 >= _diffModSizeCutoffPercent) {
          // break, since elements are ordered by the module size deviation there cannot be
          // any more interesting elements for the given p1.
          break;
        }

        for (var i3 = i2 + 1; i3 < size; i3++) {
          var p3 = possibleCenters[i3];

          // Compare the expected module sizes; if they are really off, skip
          var vModSize23 = (p2.estimatedModuleSize - p3.estimatedModuleSize) /
              math.min(p2.estimatedModuleSize, p3.estimatedModuleSize);
          var vModSize23A =
              (p2.estimatedModuleSize - p3.estimatedModuleSize).abs();
          if (vModSize23A > _diffModSizeCutoff &&
              vModSize23 >= _diffModSizeCutoffPercent) {
            // break, since elements are ordered by the module size deviation there cannot be
            // any more interesting elements for the given p1.
            break;
          }

          var test = [p1, p2, p3];
          ResultPoint.orderBestPatterns(test);

          // Calculate the distances: a = topleft-bottomleft, b=topleft-topright, c = diagonal
          var info = FinderPatternInfo(test);
          var dA = ResultPoint.distance(info.topLeft, info.bottomLeft);
          var dC = ResultPoint.distance(info.topRight, info.bottomLeft);
          var dB = ResultPoint.distance(info.topLeft, info.topRight);

          // Check the sizes
          var estimatedModuleCount = (dA + dB) / (p1.estimatedModuleSize * 2.0);
          if (estimatedModuleCount > _maxModuleCountPerEdge ||
              estimatedModuleCount < _minModuleCountPerEdge) {
            continue;
          }

          // Calculate the difference of the edge lengths in percent
          var vABBC = ((dA - dB) / math.min(dA, dB)).abs();
          if (vABBC >= 0.1) {
            continue;
          }

          // Calculate the diagonal length by assuming a 90° angle at topleft
          var dCpy = math.sqrt(dA * dA + dB * dB);
          // Compare to the real distance in %
          var vPyC = ((dC - dCpy) / math.min(dC, dCpy)).abs();

          if (vPyC >= 0.1) {
            continue;
          }

          // All tests passed!
          results.add(test);
        }
      }
    }

    if (results.isNotEmpty) {
      return results;
    }

    // Nothing found!
    throw NotFoundException();
  }

  List<FinderPatternInfo> findMulti(DecodeHints hints) {
    var tryHarder = hints.contains(DecodeHintType.tryHarder);
    var maxI = image.height;
    var maxJ = image.width;
    // We are looking for black/white/black/white/black modules in
    // 1:1:3:1:1 ratio; this tracks the number of such modules seen so far

    // Let's assume that the maximum version QR Code we support takes up 1/4 the height of the
    // image, and then account for the center being 3 modules in size. This gives the smallest
    // number of pixels the center could be, so skip this often. When trying harder, look for all
    // QR versions regardless of how dense they are.
    var iSkip = (3 * maxI) ~/ (4 * FinderPatternFinder.kMaxModules);
    if (iSkip < FinderPatternFinder.kMinSkip || tryHarder) {
      iSkip = FinderPatternFinder.kMinSkip;
    }

    var stateCount = Int32List(5);
    for (var i = iSkip - 1; i < maxI; i += iSkip) {
      // Get a row of black/white values
      FinderPatternFinder.doClearCounts(stateCount);
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
              if (FinderPatternFinder.foundPatternCross(stateCount) &&
                  handlePossibleCenter(stateCount, i, j)) {
                // Yes
                // Clear state to start looking again
                currentState = 0;
                FinderPatternFinder.doClearCounts(stateCount);
              } else {
                // No, shift counts back by two
                FinderPatternFinder.doShiftCounts2(stateCount);
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
      } // for j=...

      if (FinderPatternFinder.foundPatternCross(stateCount)) {
        handlePossibleCenter(stateCount, i, maxJ);
      }
    } // for i=iSkip-1 ...
    var patternInfo = _selectMultipleBestPatterns();
    var result = <FinderPatternInfo>[];
    for (var pattern in patternInfo) {
      ResultPoint.orderBestPatterns(pattern);
      result.add(FinderPatternInfo(pattern));
    }
    return result;
  }
}
