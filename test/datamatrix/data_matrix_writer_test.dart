import 'package:test/test.dart';
import 'package:zxing2/datamatrix.dart';

/// @author satorux@google.com (Satoru Takabayashi) - creator
/// @author dswitkin@google.com (Daniel Switkin) - ported and expanded from C++
void main() {
  test('Data matrix image writer', () {
    var hints = EncodeHints()
      ..put(EncodeHintType.dataMatrixShape, SymbolShapeHint.forceSquare);

    var bigEnough = 64;
    var writer = DataMatrixWriter();
    var matrix = writer.encode(
        'Hello Google', BarcodeFormat.dataMatrix, bigEnough, bigEnough,
        hints: hints);
    expect(matrix.width, lessThanOrEqualTo(bigEnough));
    expect(matrix.height, lessThanOrEqualTo(bigEnough));
  });

  test('Data matrix writer', () {
    var hints = EncodeHints()
      ..put(EncodeHintType.dataMatrixShape, SymbolShapeHint.forceSquare);

    var bigEnough = 14;
    var writer = DataMatrixWriter();
    var matrix = writer.encode(
        'Hello Me', BarcodeFormat.dataMatrix, bigEnough, bigEnough,
        hints: hints);
    expect(matrix.width, bigEnough);
    expect(matrix.height, bigEnough);
  });

  test('Data matrix too small', () {
    // The DataMatrix will not fit in this size, so the matrix should come back bigger
    var tooSmall = 8;
    var writer = DataMatrixWriter();
    var matrix = writer.encode(
        'http://www.google.com/', BarcodeFormat.dataMatrix, tooSmall, tooSmall);
    expect(matrix.width, greaterThan(tooSmall));
    expect(matrix.height, greaterThan(tooSmall));
  });
}
