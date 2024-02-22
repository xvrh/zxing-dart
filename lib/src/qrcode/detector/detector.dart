import 'dart:math' as math;
import '../../common/bit_matrix.dart';
import '../../common/detector/math_utils.dart';
import '../../common/detector_result.dart';
import '../../common/grid_sampler.dart';
import '../../common/perspective_transform.dart';
import '../../decode_hint.dart';
import '../../not_found_exception.dart';
import '../../result_point.dart';
import '../../result_point_callback.dart';
import '../decoder/version.dart';
import 'alignment_pattern.dart';
import 'alignment_pattern_finder.dart';
import 'finder_pattern_finder.dart';
import 'finder_pattern_info.dart';

/// <p>Encapsulates logic that can detect a QR Code in an image, even if the QR Code
/// is rotated or skewed, or partially obscured.</p>
///
/// @author Sean Owen
class Detector {
  final BitMatrix image;
  ResultPointCallback? _resultPointCallback;

  Detector(this.image);

  ResultPointCallback? get resultPointCallback {
    return _resultPointCallback;
  }

  /// <p>Detects a QR Code in an image.</p>
  ///
  /// @param hints optional hints to detector
  /// @return {@link DetectorResult} encapsulating results of detecting a QR Code
  /// @throws NotFoundException if QR Code cannot be found
  /// @throws FormatReaderException if a QR Code cannot be decoded
  DetectorResult detect({required DecodeHints hints}) {
    _resultPointCallback = hints.get(DecodeHintType.needResultPointCallback);

    var finder =
        FinderPatternFinder(image, resultPointCallback: _resultPointCallback);
    var info = finder.find(hints);

    return processFinderPatternInfo(info);
  }

  DetectorResult processFinderPatternInfo(FinderPatternInfo info) {
    var topLeft = info.topLeft;
    var topRight = info.topRight;
    var bottomLeft = info.bottomLeft;

    var moduleSize = calculateModuleSize(topLeft, topRight, bottomLeft);
    if (moduleSize < 1.0) {
      throw NotFoundException();
    }
    var dimension =
        _computeDimension(topLeft, topRight, bottomLeft, moduleSize);
    var provisionalVersion =
        Version.getProvisionalVersionForDimension(dimension);
    var modulesBetweenFPCenters = provisionalVersion.dimensionForVersion - 7;

    AlignmentPattern? alignmentPattern;
    // Anything above version 1 has an alignment pattern
    if (provisionalVersion.alignmentPatternCenters.isNotEmpty) {
      // Guess where a "bottom right" finder pattern would have been
      var bottomRightX = topRight.x - topLeft.x + bottomLeft.x;
      var bottomRightY = topRight.y - topLeft.y + bottomLeft.y;

      // Estimate that alignment pattern is closer by 3 modules
      // from "bottom right" to known top left location
      var correctionToTopLeft = 1.0 - 3.0 / modulesBetweenFPCenters;
      var estAlignmentX =
          (topLeft.x + correctionToTopLeft * (bottomRightX - topLeft.x))
              .toInt();
      var estAlignmentY =
          (topLeft.y + correctionToTopLeft * (bottomRightY - topLeft.y))
              .toInt();

      // Kind of arbitrary -- expand search radius before giving up
      for (var i = 4; i <= 16; i <<= 1) {
        try {
          alignmentPattern = findAlignmentInRegion(
              moduleSize, estAlignmentX, estAlignmentY, i.toDouble());
          break;
        } on NotFoundException catch (_) {
          // try next round
        }
      }
      // If we didn't find alignment pattern... well try anyway without it
    }

    var transform = _createTransform(
        topLeft, topRight, bottomLeft, alignmentPattern, dimension);

    var bits = _sampleGrid(image, transform, dimension);

    List<ResultPoint> points;
    if (alignmentPattern == null) {
      points = [bottomLeft, topLeft, topRight];
    } else {
      points = [bottomLeft, topLeft, topRight, alignmentPattern];
    }
    return DetectorResult(bits, points);
  }

  static PerspectiveTransform _createTransform(
      ResultPoint topLeft,
      ResultPoint topRight,
      ResultPoint bottomLeft,
      ResultPoint? alignmentPattern,
      int dimension) {
    var dimMinusThree = dimension - 3.5;
    double bottomRightX;
    double bottomRightY;
    double sourceBottomRightX;
    double sourceBottomRightY;
    if (alignmentPattern != null) {
      bottomRightX = alignmentPattern.x;
      bottomRightY = alignmentPattern.y;
      sourceBottomRightX = dimMinusThree - 3.0;
      sourceBottomRightY = sourceBottomRightX;
    } else {
      // Don't have an alignment pattern, just make up the bottom-right point
      bottomRightX = (topRight.x - topLeft.x) + bottomLeft.x;
      bottomRightY = (topRight.y - topLeft.y) + bottomLeft.y;
      sourceBottomRightX = dimMinusThree;
      sourceBottomRightY = dimMinusThree;
    }

    return PerspectiveTransform.quadrilateralToQuadrilateral(
        3.5,
        3.5,
        dimMinusThree,
        3.5,
        sourceBottomRightX,
        sourceBottomRightY,
        3.5,
        dimMinusThree,
        topLeft.x,
        topLeft.y,
        topRight.x,
        topRight.y,
        bottomRightX,
        bottomRightY,
        bottomLeft.x,
        bottomLeft.y);
  }

  static BitMatrix _sampleGrid(
      BitMatrix image, PerspectiveTransform transform, int dimension) {
    var sampler = GridSampler.gridSampler;
    return sampler.sampleGridTransform(image, dimension, dimension, transform);
  }

  /// <p>Computes the dimension (number of modules on a size) of the QR Code based on the position
  /// of the finder patterns and estimated module size.</p>
  static int _computeDimension(ResultPoint topLeft, ResultPoint topRight,
      ResultPoint bottomLeft, double moduleSize) {
    var tltrCentersDimension =
        MathUtils.round(ResultPoint.distance(topLeft, topRight) / moduleSize);
    var tlblCentersDimension =
        MathUtils.round(ResultPoint.distance(topLeft, bottomLeft) / moduleSize);
    var dimension = ((tltrCentersDimension + tlblCentersDimension) ~/ 2) + 7;
    switch (dimension & 0x03) {
      // mod 4
      case 0:
        dimension++;
        break;
      // 1? do nothing
      case 2:
        dimension--;
        break;
      case 3:
        throw NotFoundException();
    }
    return dimension;
  }

  /// <p>Computes an average estimated module size based on estimated derived from the positions
  /// of the three finder patterns.</p>
  ///
  /// @param topLeft detected top-left finder pattern center
  /// @param topRight detected top-right finder pattern center
  /// @param bottomLeft detected bottom-left finder pattern center
  /// @return estimated module size
  double calculateModuleSize(
      ResultPoint topLeft, ResultPoint topRight, ResultPoint bottomLeft) {
    // Take the average
    return (_calculateModuleSizeOneWay(topLeft, topRight) +
            _calculateModuleSizeOneWay(topLeft, bottomLeft)) /
        2.0;
  }

  /// <p>Estimates module size based on two finder patterns -- it uses
  /// {#sizeOfBlackWhiteBlackRunBothWays(int, int, int, int)} to figure the
  /// width of each, measuring along the axis between their centers.</p>
  double _calculateModuleSizeOneWay(
      ResultPoint pattern, ResultPoint otherPattern) {
    var moduleSizeEst1 = _sizeOfBlackWhiteBlackRunBothWays(pattern.x.toInt(),
        pattern.y.toInt(), otherPattern.x.toInt(), otherPattern.y.toInt());
    var moduleSizeEst2 = _sizeOfBlackWhiteBlackRunBothWays(
        otherPattern.x.toInt(),
        otherPattern.y.toInt(),
        pattern.x.toInt(),
        pattern.y.toInt());
    if (moduleSizeEst1.isNaN) {
      return moduleSizeEst2 / 7.0;
    }
    if (moduleSizeEst2.isNaN) {
      return moduleSizeEst1 / 7.0;
    }
    // Average them, and divide by 7 since we've counted the width of 3 black modules,
    // and 1 white and 1 black module on either side. Ergo, divide sum by 14.
    return (moduleSizeEst1 + moduleSizeEst2) / 14.0;
  }

  /// See {@link #sizeOfBlackWhiteBlackRun(int, int, int, int)}; computes the total width of
  /// a finder pattern by looking for a black-white-black run from the center in the direction
  /// of another point (another finder pattern center), and in the opposite direction too.
  double _sizeOfBlackWhiteBlackRunBothWays(
      int fromX, int fromY, int toX, int toY) {
    var result = _sizeOfBlackWhiteBlackRun(fromX, fromY, toX, toY);

    // Now count other way -- don't run off image though of course
    var scale = 1.0;
    var otherToX = fromX - (toX - fromX);
    if (otherToX < 0) {
      scale = fromX / (fromX - otherToX);
      otherToX = 0;
    } else if (otherToX >= image.width) {
      scale = (image.width - 1 - fromX) / (otherToX - fromX);
      otherToX = image.width - 1;
    }
    var otherToY = (fromY - (toY - fromY) * scale).toInt();

    scale = 1.0;
    if (otherToY < 0) {
      scale = fromY / (fromY - otherToY);
      otherToY = 0;
    } else if (otherToY >= image.height) {
      scale = (image.height - 1 - fromY) / (otherToY - fromY);
      otherToY = image.height - 1;
    }
    otherToX = (fromX + (otherToX - fromX) * scale).toInt();

    result += _sizeOfBlackWhiteBlackRun(fromX, fromY, otherToX, otherToY);

    // Middle pixel is double-counted this way; subtract 1
    return result - 1.0;
  }

  /// <p>This method traces a line from a point in the image, in the direction towards another point.
  /// It begins in a black region, and keeps going until it finds white, then black, then white again.
  /// It reports the distance from the start to this point.</p>
  ///
  /// <p>This is used when figuring out how wide a finder pattern is, when the finder pattern
  /// may be skewed or rotated.</p>
  double _sizeOfBlackWhiteBlackRun(int fromX, int fromY, int toX, int toY) {
    // Mild variant of Bresenham's algorithm;
    // see http://en.wikipedia.org/wiki/Bresenham's_line_algorithm
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
    var xstep = fromX < toX ? 1 : -1;
    var ystep = fromY < toY ? 1 : -1;

    // In black pixels, looking for white, first or second time.
    var state = 0;
    // Loop up until x == toX, but not beyond
    var xLimit = toX + xstep;
    for (var x = fromX, y = fromY; x != xLimit; x += xstep) {
      var realX = steep ? y : x;
      var realY = steep ? x : y;

      // Does current pixel mean we have moved white to black or vice versa?
      // Scanning black in state 0,2 and white in state 1, so if we find the wrong
      // color, advance to next state or end if we are in state 2 already
      if ((state == 1) == image.get(realX, realY)) {
        if (state == 2) {
          return MathUtils.distance(x, y, fromX, fromY);
        }
        state++;
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
    // Found black-white-black; give the benefit of the doubt that the next pixel outside the image
    // is "white" so this last point at (toX+xStep,toY) is the right ending. This is really a
    // small approximation; (toX+xStep,toY+yStep) might be really correct. Ignore this.
    if (state == 2) {
      return MathUtils.distance(toX + xstep, toY, fromX, fromY);
    }
    // else we didn't find even black-white-black; no estimate is really possible
    return double.nan;
  }

  /// <p>Attempts to locate an alignment pattern in a limited region of the image, which is
  /// guessed to contain it. This method uses {@link AlignmentPattern}.</p>
  ///
  /// @param overallEstModuleSize estimated module size so far
  /// @param estAlignmentX x coordinate of center of area probably containing alignment pattern
  /// @param estAlignmentY y coordinate of above
  /// @param allowanceFactor number of pixels in all directions to search from the center
  /// @return {@link AlignmentPattern} if found, or null otherwise
  /// @throws NotFoundException if an unexpected error occurs during detection
  AlignmentPattern findAlignmentInRegion(double overallEstModuleSize,
      int estAlignmentX, int estAlignmentY, double allowanceFactor) {
    // Look for an alignment pattern (3 modules in size) around where it
    // should be
    var allowance = (allowanceFactor * overallEstModuleSize).toInt();
    var alignmentAreaLeftX = math.max(0, estAlignmentX - allowance);
    var alignmentAreaRightX =
        math.min(image.width - 1, estAlignmentX + allowance);
    if (alignmentAreaRightX - alignmentAreaLeftX < overallEstModuleSize * 3) {
      throw NotFoundException();
    }

    var alignmentAreaTopY = math.max(0, estAlignmentY - allowance);
    var alignmentAreaBottomY =
        math.min(image.height - 1, estAlignmentY + allowance);
    if (alignmentAreaBottomY - alignmentAreaTopY < overallEstModuleSize * 3) {
      throw NotFoundException();
    }

    var alignmentFinder = AlignmentPatternFinder(
        image,
        alignmentAreaLeftX,
        alignmentAreaTopY,
        alignmentAreaRightX - alignmentAreaLeftX,
        alignmentAreaBottomY - alignmentAreaTopY,
        overallEstModuleSize,
        resultPointCallback: resultPointCallback);
    return alignmentFinder.find();
  }
}
