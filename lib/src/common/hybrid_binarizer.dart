import 'dart:typed_data';
import 'dart:math' as math;
import '../binarizer.dart';
import '../luminance_source.dart';
import 'bit_matrix.dart';
import 'global_histogram_binarizer.dart';

/// This class implements a local thresholding algorithm, which while slower than the
/// GlobalHistogramBinarizer, is fairly efficient for what it does. It is designed for
/// high frequency images of barcodes with black data on white backgrounds. For this application,
/// it does a much better job than a global blackpoint with severe shadows and gradients.
/// However it tends to produce artifacts on lower frequency images and is therefore not
/// a good general purpose binarizer for uses outside ZXing.
///
/// This class extends GlobalHistogramBinarizer, using the older histogram approach for 1D readers,
/// and the newer local approach for 2D readers. 1D decoding using a per-row histogram is already
/// inherently local, and only fails for horizontal gradients. We can revisit that problem later,
/// but for now it was not a win to use local blocks for 1D.
///
/// This Binarizer is the default for the unit tests and the recommended class for library users.
///
/// @author dswitkin@google.com (Daniel Switkin)
class HybridBinarizer extends GlobalHistogramBinarizer {
  // This class uses 5x5 blocks to compute local luminance, where each block is 8x8 pixels.
  // So this is the smallest dimension in each axis we can accept.
  static final int _BLOCK_SIZE_POWER = 3;
  static final int _BLOCK_SIZE = 1 << _BLOCK_SIZE_POWER; // ...0100...00
  static final int _BLOCK_SIZE_MASK = _BLOCK_SIZE - 1; // ...0011...11
  static final int _MINIMUM_DIMENSION = _BLOCK_SIZE * 5;
  static final int _MIN_DYNAMIC_RANGE = 24;

  BitMatrix? _matrix;

  HybridBinarizer(LuminanceSource source) : super(source);

  /// Calculates the final BitMatrix once for all requests. This could be called once from the
  /// constructor instead, but there are some advantages to doing it lazily, such as making
  /// profiling easier, and not doing heavy lifting when callers don't expect it.
  @override
  BitMatrix getBlackMatrix() {
    if (_matrix != null) {
      return _matrix!;
    }
    LuminanceSource source = this.luminanceSource;
    int width = source.width;
    int height = source.height;
    if (width >= _MINIMUM_DIMENSION && height >= _MINIMUM_DIMENSION) {
      Int8List luminances = source.getMatrix();
      int subWidth = width >> _BLOCK_SIZE_POWER;
      if ((width & _BLOCK_SIZE_MASK) != 0) {
        subWidth++;
      }
      int subHeight = height >> _BLOCK_SIZE_POWER;
      if ((height & _BLOCK_SIZE_MASK) != 0) {
        subHeight++;
      }
      List<Int32List> blackPoints =
          _calculateBlackPoints(luminances, subWidth, subHeight, width, height);

      BitMatrix newMatrix = BitMatrix(width, height);
      _calculateThresholdForBlock(luminances, subWidth, subHeight, width,
          height, blackPoints, newMatrix);
      _matrix = newMatrix;
    } else {
      // If the image is too small, fall back to the global histogram approach.
      _matrix = super.getBlackMatrix();
    }
    return _matrix!;
  }

  @override
  Binarizer createBinarizer(LuminanceSource source) {
    return HybridBinarizer(source);
  }

  /// For each block in the image, calculate the average black point using a 5x5 grid
  /// of the blocks around it. Also handles the corner cases (fractional blocks are computed based
  /// on the last pixels in the row/column which are also used in the previous block).
  static void _calculateThresholdForBlock(
      Int8List luminances,
      int subWidth,
      int subHeight,
      int width,
      int height,
      List<Int32List> blackPoints,
      BitMatrix matrix) {
    int maxYOffset = height - _BLOCK_SIZE;
    int maxXOffset = width - _BLOCK_SIZE;
    for (int y = 0; y < subHeight; y++) {
      int yoffset = y << _BLOCK_SIZE_POWER;
      if (yoffset > maxYOffset) {
        yoffset = maxYOffset;
      }
      int top = _cap(y, subHeight - 3);
      for (int x = 0; x < subWidth; x++) {
        int xoffset = x << _BLOCK_SIZE_POWER;
        if (xoffset > maxXOffset) {
          xoffset = maxXOffset;
        }
        int left = _cap(x, subWidth - 3);
        int sum = 0;
        for (int z = -2; z <= 2; z++) {
          Int32List blackRow = blackPoints[top + z];
          sum += blackRow[left - 2] +
              blackRow[left - 1] +
              blackRow[left] +
              blackRow[left + 1] +
              blackRow[left + 2];
        }
        int average = sum ~/ 25;
        _thresholdBlock(luminances, xoffset, yoffset, average, width, matrix);
      }
    }
  }

  static int _cap(int value, int max) {
    return value < 2 ? 2 : math.min(value, max);
  }

  /// Applies a single threshold to a block of pixels.
  static void _thresholdBlock(Int8List luminances, int xoffset, int yoffset,
      int threshold, int stride, BitMatrix matrix) {
    for (int y = 0, offset = yoffset * stride + xoffset;
        y < _BLOCK_SIZE;
        y++, offset += stride) {
      for (int x = 0; x < _BLOCK_SIZE; x++) {
        // Comparison needs to be <= so that black == 0 pixels are black even if the threshold is 0.
        if ((luminances[offset + x] & 0xFF) <= threshold) {
          matrix.set(xoffset + x, yoffset + y);
        }
      }
    }
  }

  /// Calculates a single black point for each block of pixels and saves it away.
  /// See the following thread for a discussion of this algorithm:
  ///  http://groups.google.com/group/zxing/browse_thread/thread/d06efa2c35a7ddc0
  static List<Int32List> _calculateBlackPoints(
      Int8List luminances, int subWidth, int subHeight, int width, int height) {
    int maxYOffset = height - _BLOCK_SIZE;
    int maxXOffset = width - _BLOCK_SIZE;
    List<Int32List> blackPoints =
        List<Int32List>.generate(subHeight, (index) => Int32List(subWidth));
    for (int y = 0; y < subHeight; y++) {
      int yoffset = y << _BLOCK_SIZE_POWER;
      if (yoffset > maxYOffset) {
        yoffset = maxYOffset;
      }
      for (int x = 0; x < subWidth; x++) {
        int xoffset = x << _BLOCK_SIZE_POWER;
        if (xoffset > maxXOffset) {
          xoffset = maxXOffset;
        }
        int sum = 0;
        int min = 0xFF;
        int max = 0;
        for (int yy = 0, offset = yoffset * width + xoffset;
            yy < _BLOCK_SIZE;
            yy++, offset += width) {
          for (int xx = 0; xx < _BLOCK_SIZE; xx++) {
            int pixel = luminances[offset + xx] & 0xFF;
            sum += pixel;
            // still looking for good contrast
            if (pixel < min) {
              min = pixel;
            }
            if (pixel > max) {
              max = pixel;
            }
          }
          // short-circuit min/max tests once dynamic range is met
          if (max - min > _MIN_DYNAMIC_RANGE) {
            // finish the rest of the rows quickly
            yy++;
            for (offset += width; yy < _BLOCK_SIZE; yy++, offset += width) {
              for (int xx = 0; xx < _BLOCK_SIZE; xx++) {
                sum += luminances[offset + xx] & 0xFF;
              }
            }
          }
        }

        // The default estimate is the average of the values in the block.
        int average = sum >> (_BLOCK_SIZE_POWER * 2);
        if (max - min <= _MIN_DYNAMIC_RANGE) {
          // If variation within the block is low, assume this is a block with only light or only
          // dark pixels. In that case we do not want to use the average, as it would divide this
          // low contrast area into black and white pixels, essentially creating data out of noise.
          //
          // The default assumption is that the block is light/background. Since no estimate for
          // the level of dark pixels exists locally, use half the min for the block.
          average = min ~/ 2;

          if (y > 0 && x > 0) {
            // Correct the "white background" assumption for blocks that have neighbors by comparing
            // the pixels in this block to the previously calculated black points. This is based on
            // the fact that dark barcode symbology is always surrounded by some amount of light
            // background for which reasonable black point estimates were made. The bp estimated at
            // the boundaries is used for the interior.

            // The (min < bp) is arbitrary but works better than other heuristics that were tried.
            int averageNeighborBlackPoint = (blackPoints[y - 1][x] +
                    (2 * blackPoints[y][x - 1]) +
                    blackPoints[y - 1][x - 1]) ~/
                4;
            if (min < averageNeighborBlackPoint) {
              average = averageNeighborBlackPoint;
            }
          }
        }
        blackPoints[y][x] = average;
      }
    }
    return blackPoints;
  }
}
