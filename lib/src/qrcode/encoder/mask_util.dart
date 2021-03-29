import 'dart:math' as math;
import 'dart:typed_data';
import 'byte_matrix.dart';

/// @author Satoru Takabayashi
/// @author Daniel Switkin
/// @author Sean Owen
class MaskUtil {
  // Penalty weights from section 6.8.2.1
  static final int _n1 = 3;
  static final int _n2 = 3;
  static final int _n3 = 40;
  static final int _n4 = 10;

  MaskUtil._() {
    // do nothing
  }

  /// Apply mask penalty rule 1 and return the penalty. Find repetitive cells with the same color and
  /// give penalty to them. Example: 00000 or 11111.
  static int applyMaskPenaltyRule1(ByteMatrix matrix) {
    return _applyMaskPenaltyRule1Internal(matrix, true) +
        _applyMaskPenaltyRule1Internal(matrix, false);
  }

  /// Apply mask penalty rule 2 and return the penalty. Find 2x2 blocks with the same color and give
  /// penalty to them. This is actually equivalent to the spec's rule, which is to find MxN blocks and give a
  /// penalty proportional to (M-1)x(N-1), because this is the number of 2x2 blocks inside such a block.
  static int applyMaskPenaltyRule2(ByteMatrix matrix) {
    var penalty = 0;
    var array = matrix.bytes;
    var width = matrix.width;
    var height = matrix.height;
    for (var y = 0; y < height - 1; y++) {
      var arrayY = array[y];
      for (var x = 0; x < width - 1; x++) {
        var value = arrayY[x];
        if (value == arrayY[x + 1] &&
            value == array[y + 1][x] &&
            value == array[y + 1][x + 1]) {
          penalty++;
        }
      }
    }
    return _n2 * penalty;
  }

  /// Apply mask penalty rule 3 and return the penalty. Find consecutive runs of 1:1:3:1:1:4
  /// starting with black, or 4:1:1:3:1:1 starting with white, and give penalty to them.  If we
  /// find patterns like 000010111010000, we give penalty once.
  static int applyMaskPenaltyRule3(ByteMatrix matrix) {
    var numPenalties = 0;
    var array = matrix.bytes;
    var width = matrix.width;
    var height = matrix.height;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var arrayY = array[y]; // We can at least optimize this access
        if (x + 6 < width &&
            arrayY[x] == 1 &&
            arrayY[x + 1] == 0 &&
            arrayY[x + 2] == 1 &&
            arrayY[x + 3] == 1 &&
            arrayY[x + 4] == 1 &&
            arrayY[x + 5] == 0 &&
            arrayY[x + 6] == 1 &&
            (_isWhiteHorizontal(arrayY, x - 4, x) ||
                _isWhiteHorizontal(arrayY, x + 7, x + 11))) {
          numPenalties++;
        }
        if (y + 6 < height &&
            array[y][x] == 1 &&
            array[y + 1][x] == 0 &&
            array[y + 2][x] == 1 &&
            array[y + 3][x] == 1 &&
            array[y + 4][x] == 1 &&
            array[y + 5][x] == 0 &&
            array[y + 6][x] == 1 &&
            (_isWhiteVertical(array, x, y - 4, y) ||
                _isWhiteVertical(array, x, y + 7, y + 11))) {
          numPenalties++;
        }
      }
    }
    return numPenalties * _n3;
  }

  static bool _isWhiteHorizontal(Int8List rowArray, int from, int to) {
    from = math.max(from, 0);
    to = math.min(to, rowArray.length);
    for (var i = from; i < to; i++) {
      if (rowArray[i] == 1) {
        return false;
      }
    }
    return true;
  }

  static bool _isWhiteVertical(
      List<Int8List> array, int col, int from, int to) {
    from = math.max(from, 0);
    to = math.min(to, array.length);
    for (var i = from; i < to; i++) {
      if (array[i][col] == 1) {
        return false;
      }
    }
    return true;
  }

  /// Apply mask penalty rule 4 and return the penalty. Calculate the ratio of dark cells and give
  /// penalty if the ratio is far from 50%. It gives 10 penalty for 5% distance.
  static int applyMaskPenaltyRule4(ByteMatrix matrix) {
    var numDarkCells = 0;
    var array = matrix.bytes;
    var width = matrix.width;
    var height = matrix.height;
    for (var y = 0; y < height; y++) {
      var arrayY = array[y];
      for (var x = 0; x < width; x++) {
        if (arrayY[x] == 1) {
          numDarkCells++;
        }
      }
    }
    var numTotalCells = matrix.height * matrix.width;
    var fivePercentVariances =
        (numDarkCells * 2 - numTotalCells).abs() * 10 ~/ numTotalCells;
    return fivePercentVariances * _n4;
  }

  /// Return the mask bit for "getMaskPattern" at "x" and "y". See 8.8 of JISX0510:2004 for mask
  /// pattern conditions.
  static bool getDataMaskBit(int maskPattern, int x, int y) {
    int intermediate;
    int temp;
    switch (maskPattern) {
      case 0:
        intermediate = (y + x) & 0x1;
        break;
      case 1:
        intermediate = y & 0x1;
        break;
      case 2:
        intermediate = x % 3;
        break;
      case 3:
        intermediate = (y + x) % 3;
        break;
      case 4:
        intermediate = ((y ~/ 2) + (x ~/ 3)) & 0x1;
        break;
      case 5:
        temp = y * x;
        intermediate = (temp & 0x1) + (temp % 3);
        break;
      case 6:
        temp = y * x;
        intermediate = ((temp & 0x1) + (temp % 3)) & 0x1;
        break;
      case 7:
        temp = y * x;
        intermediate = ((temp % 3) + ((y + x) & 0x1)) & 0x1;
        break;
      default:
        throw ArgumentError('Invalid mask pattern: $maskPattern');
    }
    return intermediate == 0;
  }

  /// Helper function for applyMaskPenaltyRule1. We need this for doing this calculation in both
  /// vertical and horizontal orders respectively.
  static int _applyMaskPenaltyRule1Internal(
      ByteMatrix matrix, bool isHorizontal) {
    var penalty = 0;
    var iLimit = isHorizontal ? matrix.height : matrix.width;
    var jLimit = isHorizontal ? matrix.width : matrix.height;
    var array = matrix.bytes;
    for (var i = 0; i < iLimit; i++) {
      var numSameBitCells = 0;
      var prevBit = -1;
      for (var j = 0; j < jLimit; j++) {
        var bit = isHorizontal ? array[i][j] : array[j][i];
        if (bit == prevBit) {
          numSameBitCells++;
        } else {
          if (numSameBitCells >= 5) {
            penalty += _n1 + (numSameBitCells - 5);
          }
          numSameBitCells = 1; // Include the cell itself.
          prevBit = bit;
        }
      }
      if (numSameBitCells >= 5) {
        penalty += _n1 + (numSameBitCells - 5);
      }
    }
    return penalty;
  }
}
