import 'package:test/test.dart';
import 'package:zxing/src/qrcode/encoder/byte_matrix.dart';
import 'package:zxing/src/qrcode/encoder/mask_util.dart';

void main() {
  test('Apply mask penalty rule1', () {
    var matrix = ByteMatrix(4, 1);
    matrix.set(0, 0, 0);
    matrix.set(1, 0, 0);
    matrix.set(2, 0, 0);
    matrix.set(3, 0, 0);
    expect(MaskUtil.applyMaskPenaltyRule1(matrix), 0);
    // Horizontal.
    matrix = ByteMatrix(6, 1);
    matrix.set(0, 0, 0);
    matrix.set(1, 0, 0);
    matrix.set(2, 0, 0);
    matrix.set(3, 0, 0);
    matrix.set(4, 0, 0);
    matrix.set(5, 0, 1);
    expect(MaskUtil.applyMaskPenaltyRule1(matrix), 3);
    matrix.set(5, 0, 0);
    expect(4, MaskUtil.applyMaskPenaltyRule1(matrix));
    // Vertical.
    matrix = ByteMatrix(1, 6);
    matrix.set(0, 0, 0);
    matrix.set(0, 1, 0);
    matrix.set(0, 2, 0);
    matrix.set(0, 3, 0);
    matrix.set(0, 4, 0);
    matrix.set(0, 5, 1);
    expect(3, MaskUtil.applyMaskPenaltyRule1(matrix));
    matrix.set(0, 5, 0);
    expect(4, MaskUtil.applyMaskPenaltyRule1(matrix));
  });

  test('Apply mask penalty rule2', () {
    var matrix = ByteMatrix(1, 1);
    matrix.set(0, 0, 0);
    expect(0, MaskUtil.applyMaskPenaltyRule2(matrix));
    matrix = ByteMatrix(2, 2);
    matrix.set(0, 0, 0);
    matrix.set(1, 0, 0);
    matrix.set(0, 1, 0);
    matrix.set(1, 1, 1);
    expect(0, MaskUtil.applyMaskPenaltyRule2(matrix));
    matrix = ByteMatrix(2, 2);
    matrix.set(0, 0, 0);
    matrix.set(1, 0, 0);
    matrix.set(0, 1, 0);
    matrix.set(1, 1, 0);
    expect(3, MaskUtil.applyMaskPenaltyRule2(matrix));
    matrix = ByteMatrix(3, 3);
    matrix.set(0, 0, 0);
    matrix.set(1, 0, 0);
    matrix.set(2, 0, 0);
    matrix.set(0, 1, 0);
    matrix.set(1, 1, 0);
    matrix.set(2, 1, 0);
    matrix.set(0, 2, 0);
    matrix.set(1, 2, 0);
    matrix.set(2, 2, 0);
    // Four instances of 2x2 blocks.
    expect(3 * 4, MaskUtil.applyMaskPenaltyRule2(matrix));
  });

  test('Apply mask penalty rule 3', () {
    // Horizontal 00001011101.
    var matrix = ByteMatrix(11, 1);
    matrix.set(0, 0, 0);
    matrix.set(1, 0, 0);
    matrix.set(2, 0, 0);
    matrix.set(3, 0, 0);
    matrix.set(4, 0, 1);
    matrix.set(5, 0, 0);
    matrix.set(6, 0, 1);
    matrix.set(7, 0, 1);
    matrix.set(8, 0, 1);
    matrix.set(9, 0, 0);
    matrix.set(10, 0, 1);
    expect(40, MaskUtil.applyMaskPenaltyRule3(matrix));
    // Horizontal 10111010000.
    matrix = ByteMatrix(11, 1);
    matrix.set(0, 0, 1);
    matrix.set(1, 0, 0);
    matrix.set(2, 0, 1);
    matrix.set(3, 0, 1);
    matrix.set(4, 0, 1);
    matrix.set(5, 0, 0);
    matrix.set(6, 0, 1);
    matrix.set(7, 0, 0);
    matrix.set(8, 0, 0);
    matrix.set(9, 0, 0);
    matrix.set(10, 0, 0);
    expect(40, MaskUtil.applyMaskPenaltyRule3(matrix));
    // Vertical 00001011101.
    matrix = ByteMatrix(1, 11);
    matrix.set(0, 0, 0);
    matrix.set(0, 1, 0);
    matrix.set(0, 2, 0);
    matrix.set(0, 3, 0);
    matrix.set(0, 4, 1);
    matrix.set(0, 5, 0);
    matrix.set(0, 6, 1);
    matrix.set(0, 7, 1);
    matrix.set(0, 8, 1);
    matrix.set(0, 9, 0);
    matrix.set(0, 10, 1);
    expect(40, MaskUtil.applyMaskPenaltyRule3(matrix));
    // Vertical 10111010000.
    matrix = ByteMatrix(1, 11);
    matrix.set(0, 0, 1);
    matrix.set(0, 1, 0);
    matrix.set(0, 2, 1);
    matrix.set(0, 3, 1);
    matrix.set(0, 4, 1);
    matrix.set(0, 5, 0);
    matrix.set(0, 6, 1);
    matrix.set(0, 7, 0);
    matrix.set(0, 8, 0);
    matrix.set(0, 9, 0);
    matrix.set(0, 10, 0);
    expect(40, MaskUtil.applyMaskPenaltyRule3(matrix));
  });

  test('Apply mask penalty rule 4', () {
    // Dark cell ratio = 0%
    var matrix = ByteMatrix(1, 1);
    matrix.set(0, 0, 0);
    expect(100, MaskUtil.applyMaskPenaltyRule4(matrix));
    // Dark cell ratio = 5%
    matrix = ByteMatrix(2, 1);
    matrix.set(0, 0, 0);
    matrix.set(0, 0, 1);
    expect(0, MaskUtil.applyMaskPenaltyRule4(matrix));
    // Dark cell ratio = 66.67%
    matrix = ByteMatrix(6, 1);
    matrix.set(0, 0, 0);
    matrix.set(1, 0, 1);
    matrix.set(2, 0, 1);
    matrix.set(3, 0, 1);
    matrix.set(4, 0, 1);
    matrix.set(5, 0, 0);
    expect(30, MaskUtil.applyMaskPenaltyRule4(matrix));
  });

  test('Get data mask bit', () {
    var mask0 = [
      [1, 0, 1, 0, 1, 0],
      [0, 1, 0, 1, 0, 1],
      [1, 0, 1, 0, 1, 0],
      [0, 1, 0, 1, 0, 1],
      [1, 0, 1, 0, 1, 0],
      [0, 1, 0, 1, 0, 1],
    ];
    expect(_testGetDataMaskBitInternal(0, mask0), isTrue);
    var mask1 = [
      [1, 1, 1, 1, 1, 1],
      [0, 0, 0, 0, 0, 0],
      [1, 1, 1, 1, 1, 1],
      [0, 0, 0, 0, 0, 0],
      [1, 1, 1, 1, 1, 1],
      [0, 0, 0, 0, 0, 0],
    ];
    expect(_testGetDataMaskBitInternal(1, mask1), isTrue);
    var mask2 = [
      [1, 0, 0, 1, 0, 0],
      [1, 0, 0, 1, 0, 0],
      [1, 0, 0, 1, 0, 0],
      [1, 0, 0, 1, 0, 0],
      [1, 0, 0, 1, 0, 0],
      [1, 0, 0, 1, 0, 0],
    ];
    expect(_testGetDataMaskBitInternal(2, mask2), isTrue);
    var mask3 = [
      [1, 0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0, 1],
      [0, 1, 0, 0, 1, 0],
      [1, 0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0, 1],
      [0, 1, 0, 0, 1, 0],
    ];
    expect(_testGetDataMaskBitInternal(3, mask3), isTrue);
    var mask4 = [
      [1, 1, 1, 0, 0, 0],
      [1, 1, 1, 0, 0, 0],
      [0, 0, 0, 1, 1, 1],
      [0, 0, 0, 1, 1, 1],
      [1, 1, 1, 0, 0, 0],
      [1, 1, 1, 0, 0, 0],
    ];
    expect(_testGetDataMaskBitInternal(4, mask4), isTrue);
    var mask5 = [
      [1, 1, 1, 1, 1, 1],
      [1, 0, 0, 0, 0, 0],
      [1, 0, 0, 1, 0, 0],
      [1, 0, 1, 0, 1, 0],
      [1, 0, 0, 1, 0, 0],
      [1, 0, 0, 0, 0, 0],
    ];
    expect(_testGetDataMaskBitInternal(5, mask5), isTrue);
    var mask6 = [
      [1, 1, 1, 1, 1, 1],
      [1, 1, 1, 0, 0, 0],
      [1, 1, 0, 1, 1, 0],
      [1, 0, 1, 0, 1, 0],
      [1, 0, 1, 1, 0, 1],
      [1, 0, 0, 0, 1, 1],
    ];
    expect(_testGetDataMaskBitInternal(6, mask6), isTrue);
    var mask7 = [
      [1, 0, 1, 0, 1, 0],
      [0, 0, 0, 1, 1, 1],
      [1, 0, 0, 0, 1, 1],
      [0, 1, 0, 1, 0, 1],
      [1, 1, 1, 0, 0, 0],
      [0, 1, 1, 1, 0, 0],
    ];
    expect(_testGetDataMaskBitInternal(7, mask7), isTrue);
  });
}

bool _testGetDataMaskBitInternal(int maskPattern, List<List<int>> expected) {
  for (var x = 0; x < 6; ++x) {
    for (var y = 0; y < 6; ++y) {
      if ((expected[y][x] == 1) != MaskUtil.getDataMaskBit(maskPattern, x, y)) {
        return false;
      }
    }
  }
  return true;
}
