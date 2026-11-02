import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zxing2/qrcode.dart';

void main() {
  const cols = 6;
  const rows = 4;
  final yuv = Int8List.fromList([
    0, 1, 1, 2, 3, 5, //
    8, 13, 21, 34, 55, 89,
    0, -1, -1, -2, -3, -5,
    -8, -13, -21, -34, -55, -89,
    127, 127, 127, 127, 127, 127,
    127, 127, 127, 127, 127, 127,
  ]);
  final y = yuv.sublist(0, cols * rows);

  Uint8List yuvBytes() => Uint8List.fromList(yuv.buffer.asUint8List());

  test('No crop', () {
    var source = PlanarYUVLuminanceSource(yuvBytes(), cols, rows);
    expect(source.getMatrix().sublist(0, y.length), y);
    for (var r = 0; r < rows; r++) {
      expect(source.getRow(r, null), y.sublist(r * cols, (r + 1) * cols));
    }
  });

  test('Crop', () {
    var source = PlanarYUVLuminanceSource(yuvBytes(), cols, rows,
        left: 1, top: 1, width: cols - 2, height: rows - 2);
    expect(source.isCropSupported, isTrue);
    var cropMatrix = source.getMatrix();
    for (var r = 0; r < rows - 2; r++) {
      var expected = y.sublist((r + 1) * cols + 1, (r + 1) * cols + cols - 1);
      expect(
          cropMatrix.sublist(r * (cols - 2), (r + 1) * (cols - 2)), expected);
      expect(source.getRow(r, null), expected);
    }
  });

  test('Thumbnail', () {
    var source = PlanarYUVLuminanceSource(yuvBytes(), cols, rows);
    expect(source.renderThumbnail(), [
      0xFF000000, 0xFF010101, 0xFF030303, //
      0xFF000000, 0xFFFFFFFF, 0xFFFDFDFD,
    ]);
  });

  test('Rejects a crop outside the image', () {
    expect(
        () => PlanarYUVLuminanceSource(yuvBytes(), cols, rows,
            left: 2, width: cols),
        throwsArgumentError);
  });

  test('Decodes a camera frame with padded rows', () {
    var matrix =
        QRCodeWriter().encode('camera', BarcodeFormat.qrCode, 120, 120);
    const rowStride = 128;
    // The last row of a camera plane is often not padded
    var plane = Uint8List(rowStride * (matrix.height - 1) + matrix.width);
    for (var row = 0; row < matrix.height; row++) {
      for (var x = 0; x < matrix.width; x++) {
        plane[row * rowStride + x] = matrix.get(x, row) ? 0 : 255;
      }
    }
    var source = PlanarYUVLuminanceSource(plane, rowStride, matrix.height,
        width: matrix.width);
    var result = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)));
    expect(result.text, 'camera');
  });
}
