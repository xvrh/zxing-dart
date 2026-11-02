import 'package:test/test.dart';
import 'package:zxing2/src/common/bit_matrix.dart';
import 'package:zxing2/src/common/detector/math_utils.dart';
import 'package:zxing2/src/common/grid_sampler.dart';
import 'package:zxing2/src/common/perspective_transform.dart';
import 'package:zxing2/src/not_found_exception.dart';

void main() {
  test('toInt truncates like a Java cast', () {
    expect(MathUtils.toInt(2.7), 2);
    expect(MathUtils.toInt(-2.7), -2);
    expect(MathUtils.toInt(double.nan), 0);
    expect(MathUtils.toInt(double.infinity), 0x7FFFFFFF);
    expect(MathUtils.toInt(double.negativeInfinity), -0x80000000);
    expect(MathUtils.round(double.nan), 0);
  });

  test('Degenerate transforms do not crash', () {
    var image = BitMatrix(50);
    // All the source points collapse to one: the transform yields NaN
    var transform = PerspectiveTransform.quadrilateralToQuadrilateral(
        0, 0, 0, 0, 0, 0, 0, 0, 10, 10, 10, 10, 10, 10, 10, 10);
    try {
      GridSampler.gridSampler.sampleGridTransform(image, 21, 21, transform);
    } on NotFoundException catch (_) {
      // Fine: what matters is that no other error is thrown
    }
  });
}
