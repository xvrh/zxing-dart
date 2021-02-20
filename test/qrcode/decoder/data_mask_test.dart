import 'package:test/test.dart';
import 'package:zxing/src/common/bit_matrix.dart';
import 'package:zxing/src/qrcode/decoder/data_mask.dart';

void main() {
  test('Mask0', () {
    testMaskAcrossDimensions(0, (i, j) => (i + j) % 2 == 0);
  });

  test('Mask1', () {
    testMaskAcrossDimensions(1, (i, j) => i % 2 == 0);
  });

  test('Mask2', () {
    testMaskAcrossDimensions(2, (i, j) => j % 3 == 0);
  });

  test('Mask3', () {
    testMaskAcrossDimensions(3, (i, j) => (i + j) % 3 == 0);
  });

  test('Mask4', () {
    testMaskAcrossDimensions(4, (i, j) {
      return (i ~/ 2 + j ~/ 3) % 2 == 0;
    });
  });

  test('Mask5', () {
    testMaskAcrossDimensions(5, (i, j) => (i * j) % 2 + (i * j) % 3 == 0);
  });

  test('Mask6', () {
    testMaskAcrossDimensions(6, (i, j) => ((i * j) % 2 + (i * j) % 3) % 2 == 0);
  });

  test('Mask7', () {
    testMaskAcrossDimensions(7, (i, j) => ((i + j) % 2 + (i * j) % 3) % 2 == 0);
  });
}

void testMaskAcrossDimensions(int reference, MaskCondition isMasked) {
  var mask = DataMask.values[reference];
  for (var version = 1; version <= 40; version++) {
    var dimension = 17 + 4 * version;
    testMask(mask, dimension, isMasked);
  }
}

void testMask(DataMask mask, int dimension, MaskCondition isMasked) {
  var bits = BitMatrix(dimension);
  mask.unmaskBitMatrix(bits, dimension);
  for (var i = 0; i < dimension; i++) {
    for (var j = 0; j < dimension; j++) {
      expect(bits.get(j, i), isMasked(i, j),
          reason: '($i,$j) Got ${bits.get(j, i)} expected ${isMasked(i, j)}');
    }
  }
}

typedef MaskCondition = bool Function(int i, int j);
