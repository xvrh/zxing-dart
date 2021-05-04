import 'package:test/test.dart';
import 'package:zxing2/src/common/perspective_transform.dart';

final _epsilon = 1.0E-4;
void main() {
  test('Square to quadrilateral', () {
    var pt = PerspectiveTransform.squareToQuadrilateral(
        2.0, 3.0, 10.0, 4.0, 16.0, 15.0, 4.0, 9.0);
    assertPointEquals(2.0, 3.0, 0.0, 0.0, pt);
    assertPointEquals(10.0, 4.0, 1.0, 0.0, pt);
    assertPointEquals(4.0, 9.0, 0.0, 1.0, pt);
    assertPointEquals(16.0, 15.0, 1.0, 1.0, pt);
    assertPointEquals(6.535211, 6.8873234, 0.5, 0.5, pt);
    assertPointEquals(48.0, 42.42857, 1.5, 1.5, pt);
  });

  test('Quadrilateral to quadrilateral', () {
    var pt = PerspectiveTransform.quadrilateralToQuadrilateral(
      2.0, 3.0, 10.0, 4.0, 16.0, 15.0, 4.0, 9.0, //
      103.0, 110.0, 300.0, 120.0, 290.0, 270.0, 150.0, 280.0,
    );
    assertPointEquals(103.0, 110.0, 2.0, 3.0, pt);
    assertPointEquals(300.0, 120.0, 10.0, 4.0, pt);
    assertPointEquals(290.0, 270.0, 16.0, 15.0, pt);
    assertPointEquals(150.0, 280.0, 4.0, 9.0, pt);
    assertPointEquals(7.1516876, -64.60185, 0.5, 0.5, pt);
    assertPointEquals(328.09116, 334.16385, 50.0, 50.0, pt);
  });
}

void assertPointEquals(double expectedX, double expectedY, double sourceX,
    double sourceY, PerspectiveTransform pt) {
  var points = <double>[sourceX, sourceY];
  pt.transformPoints(points);
  expect(points[0], closeTo(expectedX, _epsilon));
  expect(points[1], closeTo(expectedY, _epsilon));
}
