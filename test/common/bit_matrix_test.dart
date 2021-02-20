import 'package:test/test.dart';
import 'package:zxing/src/common/bit_array.dart';
import 'package:zxing/src/common/bit_matrix.dart';

final bitMatrixPoints = <int>[1, 2, 2, 0, 3, 1];

void main() {
  test('Get set', () {
    var matrix = BitMatrix(33);
    expect(matrix.height, 33);
    for (var y = 0; y < 33; y++) {
      for (var x = 0; x < 33; x++) {
        if (y * x % 3 == 0) {
          matrix.set(x, y);
        }
      }
    }
    for (var y = 0; y < 33; y++) {
      for (var x = 0; x < 33; x++) {
        expect(matrix.get(x, y), y * x % 3 == 0);
      }
    }
  });

  test('Set region', () {
    var matrix = BitMatrix(5);
    matrix.setRegion(1, 1, 3, 3);
    for (var y = 0; y < 5; y++) {
      for (var x = 0; x < 5; x++) {
        expect(matrix.get(x, y), y >= 1 && y <= 3 && x >= 1 && x <= 3);
      }
    }
  });

  test('Enclosing', () {
    var matrix = BitMatrix(5);
    expect(matrix.getEnclosingRectangle(), isNull);
    matrix.setRegion(1, 1, 1, 1);
    expect(matrix.getEnclosingRectangle(), [1, 1, 1, 1]);
    matrix.setRegion(1, 1, 3, 2);
    expect(matrix.getEnclosingRectangle(), [1, 1, 3, 2]);
    matrix.setRegion(0, 0, 5, 5);
    expect(matrix.getEnclosingRectangle(), [0, 0, 5, 5]);
  });

  test('On bit', () {
    var matrix = BitMatrix(5);
    expect(matrix.getTopLeftOnBit(), isNull);
    expect(matrix.getBottomRightOnBit(), isNull);
    matrix.setRegion(1, 1, 1, 1);
    expect(matrix.getTopLeftOnBit(), [1, 1]);
    expect(matrix.getBottomRightOnBit(), [1, 1]);
    matrix.setRegion(1, 1, 3, 2);
    expect(matrix.getTopLeftOnBit(), [1, 1]);
    expect(matrix.getBottomRightOnBit(), [3, 2]);
    matrix.setRegion(0, 0, 5, 5);
    expect(matrix.getTopLeftOnBit(), [0, 0]);
    expect(matrix.getBottomRightOnBit(), [4, 4]);
  });

  test('Rectangular matrix', () {
    var matrix = BitMatrix(75, 20);
    expect(matrix.width, 75);
    expect(matrix.height, 20);
    matrix.set(10, 0);
    matrix.set(11, 1);
    matrix.set(50, 2);
    matrix.set(51, 3);
    matrix.flip(74, 4);
    matrix.flip(0, 5);

    // Should all be on
    expect(matrix.get(10, 0), isTrue);
    expect(matrix.get(11, 1), isTrue);
    expect(matrix.get(50, 2), isTrue);
    expect(matrix.get(51, 3), isTrue);
    expect(matrix.get(74, 4), isTrue);
    expect(matrix.get(0, 5), isTrue);

    // Flip a couple back off
    matrix.flip(50, 2);
    matrix.flip(51, 3);
    expect(matrix.get(50, 2), isFalse);
    expect(matrix.get(51, 3), isFalse);
  });

  test('Rectangular set region', () {
    var matrix = BitMatrix(320, 240);
    expect(matrix.width, 320);
    expect(matrix.height, 240);
    matrix.setRegion(105, 22, 80, 12);

    // Only bits in the region should be on
    for (var y = 0; y < 240; y++) {
      for (var x = 0; x < 320; x++) {
        expect(y >= 22 && y < 34 && x >= 105 && x < 185, matrix.get(x, y));
      }
    }
  });

  test('Get row', () {
    var matrix = BitMatrix(102, 5);
    for (var x = 0; x < 102; x++) {
      if ((x & 0x03) == 0) {
        matrix.set(x, 2);
      }
    }

    // Should allocate
    var array = matrix.getRow(2, null);
    expect(array.size, 102);

    // Should reallocate
    var array2 = BitArray(60);
    array2 = matrix.getRow(2, array2);
    expect(array2.size, 102);

    // Should use provided object, with original BitArray size
    var array3 = BitArray(200);
    array3 = matrix.getRow(2, array3);
    expect(array3.size, 200);

    for (var x = 0; x < 102; x++) {
      var on = (x & 0x03) == 0;
      expect(array.get(x), on);
      expect(array2.get(x), on);
      expect(array3.get(x), on);
    }
  });

  test('Rotate 90 simple', () {
    var matrix = BitMatrix(3, 3);
    matrix.set(0, 0);
    matrix.set(0, 1);
    matrix.set(1, 2);
    matrix.set(2, 1);

    matrix.rotate90();

    expect(matrix.get(0, 2), isTrue);
    expect(matrix.get(1, 2), isTrue);
    expect(matrix.get(2, 1), isTrue);
    expect(matrix.get(1, 0), isTrue);
  });

  test('Rotate 180', () {
    var matrix = BitMatrix(3, 3);
    matrix.set(0, 0);
    matrix.set(0, 1);
    matrix.set(1, 2);
    matrix.set(2, 1);

    matrix.rotate180();

    expect(matrix.get(2, 2), isTrue);
    expect(matrix.get(2, 1), isTrue);
    expect(matrix.get(1, 0), isTrue);
    expect(matrix.get(0, 1), isTrue);
  });

  test('Rotate 180', () {
    _testRotate180(7, 4);
    _testRotate180(7, 5);
    _testRotate180(8, 4);
    _testRotate180(8, 5);
  });

  test('Parse', () {
    var emptyMatrix = BitMatrix(3, 3);
    var fullMatrix = BitMatrix(3, 3);
    fullMatrix.setRegion(0, 0, 3, 3);
    var centerMatrix = BitMatrix(3, 3);
    centerMatrix.setRegion(1, 1, 1, 1);
    var emptyMatrix24 = BitMatrix(2, 4);

    expect(BitMatrix.parseString('   \n   \n   \n', 'x', ' '), emptyMatrix);
    expect(
        BitMatrix.parseString('   \n   \r\r\n   \n\r', 'x', ' '), emptyMatrix);
    expect(BitMatrix.parseString('   \n   \n   ', 'x', ' '), emptyMatrix);

    expect(BitMatrix.parseString('xxx\nxxx\nxxx\n', 'x', ' '), fullMatrix);

    expect(BitMatrix.parseString('   \n x \n   \n', 'x', ' '), centerMatrix);
    expect(BitMatrix.parseString('      \n  x   \n      \n', 'x ', '  '),
        centerMatrix);
    try {
      expect(BitMatrix.parseString('   \n xy\n   \n', 'x', ' '), centerMatrix);
      fail('Should have thrown');
    } on ArgumentError catch (_) {
      // good
    }

    expect(BitMatrix.parseString('  \n  \n  \n  \n', 'x', ' '), emptyMatrix24);

    expect(
        BitMatrix.parseString(
            centerMatrix.toStringRepresentation('x', '.'), 'x', '.'),
        centerMatrix);
  });

  test('Parse boolean', () {
    var emptyMatrix = BitMatrix(3, 3);
    var fullMatrix = BitMatrix(3, 3);
    fullMatrix.setRegion(0, 0, 3, 3);
    var centerMatrix = BitMatrix(3, 3);
    centerMatrix.setRegion(1, 1, 1, 1);

    var matrix =
        List<List<bool>>.generate(3, (index) => List.generate(3, (index) => false));
    expect(BitMatrix.parse(matrix), emptyMatrix);
    matrix[1][1] = true;
    expect(BitMatrix.parse(matrix), centerMatrix);
    for (var arr in matrix) {
      for (var i = 0; i < arr.length; i++) {
        arr[i] = true;
      }
    }
    expect(fullMatrix, BitMatrix.parse(matrix));
  });

  test('Unset', () {
    var emptyMatrix = BitMatrix(3, 3);
    var matrix = emptyMatrix.clone();
    matrix.set(1, 1);
    expect(matrix, isNot(emptyMatrix));
    matrix.unset(1, 1);
    expect(matrix, emptyMatrix);
    matrix.unset(1, 1);
    expect(matrix, emptyMatrix);
  });

  test('XOR', () {
    var emptyMatrix = BitMatrix(3, 3);
    var fullMatrix = BitMatrix(3, 3);
    fullMatrix.setRegion(0, 0, 3, 3);
    var centerMatrix = BitMatrix(3, 3);
    centerMatrix.setRegion(1, 1, 1, 1);
    var invertedCenterMatrix = fullMatrix.clone();
    invertedCenterMatrix.unset(1, 1);
    var badMatrix = BitMatrix(4, 4);

    _testXOR(emptyMatrix, emptyMatrix, emptyMatrix);
    _testXOR(emptyMatrix, centerMatrix, centerMatrix);
    _testXOR(emptyMatrix, fullMatrix, fullMatrix);

    _testXOR(centerMatrix, emptyMatrix, centerMatrix);
    _testXOR(centerMatrix, centerMatrix, emptyMatrix);
    _testXOR(centerMatrix, fullMatrix, invertedCenterMatrix);

    _testXOR(invertedCenterMatrix, emptyMatrix, invertedCenterMatrix);
    _testXOR(invertedCenterMatrix, centerMatrix, fullMatrix);
    _testXOR(invertedCenterMatrix, fullMatrix, centerMatrix);

    _testXOR(fullMatrix, emptyMatrix, fullMatrix);
    _testXOR(fullMatrix, centerMatrix, invertedCenterMatrix);
    _testXOR(fullMatrix, fullMatrix, emptyMatrix);

    try {
      emptyMatrix.clone().xor(badMatrix);
      fail('Should have throw');
    } on ArgumentError catch (_) {
      // good
    }

    try {
      badMatrix.clone().xor(emptyMatrix);
      fail('Should have thrown');
    } on ArgumentError catch (_) {
      // good
    }
  });
}

String matrixToString(BitMatrix result) {
  expect(result.height, 1);
  var builder = StringBuffer();
  for (var i = 0; i < result.width; i++) {
    builder.write(result.get(i, 0) ? '1' : '0');
  }
  return builder.toString();
}

void _testXOR(
    BitMatrix dataMatrix, BitMatrix flipMatrix, BitMatrix expectedMatrix) {
  var matrix = dataMatrix.clone();
  matrix.xor(flipMatrix);
  expect(matrix, expectedMatrix);
}

void _testRotate180(int width, int height) {
  var input = _getInput(width, height);
  input.rotate180();
  var expected = _getExpected(width, height);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      expect(input.get(x, y), expected.get(x, y), reason: '($x,$y)');
    }
  }
}

BitMatrix _getExpected(int width, int height) {
  var result = BitMatrix(width, height);
  for (var i = 0; i < bitMatrixPoints.length; i += 2) {
    result.set(
        width - 1 - bitMatrixPoints[i], height - 1 - bitMatrixPoints[i + 1]);
  }
  return result;
}

BitMatrix _getInput(int width, int height) {
  var result = BitMatrix(width, height);
  for (var i = 0; i < bitMatrixPoints.length; i += 2) {
    result.set(bitMatrixPoints[i], bitMatrixPoints[i + 1]);
  }
  return result;
}
