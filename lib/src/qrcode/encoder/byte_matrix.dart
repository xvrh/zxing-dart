import 'dart:typed_data';

/// JAVAPORT: The original code was a 2D array of ints, but since it only ever gets assigned
/// -1, 0, and 1, I'm going to use less memory and go with bytes.
///
/// @author dswitkin@google.com (Daniel Switkin)
class ByteMatrix {
  /// @return an internal representation as bytes, in row-major order. array[y][x] represents point (x,y)
  final List<Int8List> bytes;
  final int width;
  final int height;

  ByteMatrix(this.width, this.height)
      : bytes = List.generate(height, (index) => Int8List(width));

  int get(int x, int y) {
    return bytes[y][x];
  }

  void set(int x, int y, int value) {
    bytes[y][x] = value;
  }

  void setBool(int x, int y, bool value) {
    bytes[y][x] = (value ? 1 : 0);
  }

  void clear(int value) {
    for (var aByte in bytes) {
      for (var i = 0; i < aByte.length; i++) {
        aByte[i] = value;
      }
    }
  }

  @override
  String toString() {
    var result = StringBuffer();
    for (var y = 0; y < height; ++y) {
      var bytesY = bytes[y];
      for (var x = 0; x < width; ++x) {
        switch (bytesY[x]) {
          case 0:
            result.write(' 0');
            break;
          case 1:
            result.write(' 1');
            break;
          default:
            result.write('  ');
            break;
        }
      }
      result.write('\n');
    }
    return result.toString();
  }
}
