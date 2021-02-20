import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zxing/src/common/bit_source.dart';

void main() {
  test('Source', () {
    var bytes = Int8List.fromList([1, 2, 3, 4, 5]);
    BitSource source = BitSource(bytes);
    expect(source.available(), 40);
    expect(source.readBits(1), 0);
    expect(source.available(), 39);
    expect(source.readBits(6), 0);
    expect(source.available(), 33);
    expect(source.readBits(1), 1);
    expect(source.available(), 32);
    expect(source.readBits(8), 2);
    expect(source.available(), 24);
    expect(source.readBits(10), 12);
    expect(source.available(), 14);
    expect(source.readBits(8), 16);
    expect(source.available(), 6);
    expect(source.readBits(6), 5);
    expect(source.available(), 0);
  });
}
