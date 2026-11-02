import 'package:test/test.dart';
import 'package:zxing2/zxing2.dart';

/// Renders a one-row [BitMatrix] as a string of '1' and '0'.
String matrixToString(BitMatrix result) {
  expect(result.height, 1);
  var builder = StringBuffer();
  for (var i = 0; i < result.width; i++) {
    builder.write(result.get(i, 0) ? '1' : '0');
  }
  return builder.toString();
}
