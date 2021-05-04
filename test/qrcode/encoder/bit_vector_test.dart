import 'package:test/test.dart';
import 'package:zxing2/src/common/bit_array.dart';

void main() {
  test('Append bit', () {
    var v = BitArray();
    expect(v.sizeInBytes, 0);
    // 1
    v.appendBit(true);
    expect(v.size, 1);
    expect(_getUnsignedInt(v), 0x80000000);
    // 10
    v.appendBit(false);
    expect(v.size, 2);
    expect(_getUnsignedInt(v), 0x80000000);
    // 101
    v.appendBit(true);
    expect(v.size, 3);
    expect(_getUnsignedInt(v), 0xa0000000);
    // 1010
    v.appendBit(false);
    expect(v.size, 4);
    expect(_getUnsignedInt(v), 0xa0000000);
    // 10101
    v.appendBit(true);
    expect(v.size, 5);
    expect(_getUnsignedInt(v), 0xa8000000);
    // 101010
    v.appendBit(false);
    expect(v.size, 6);
    expect(_getUnsignedInt(v), 0xa8000000);
    // 1010101
    v.appendBit(true);
    expect(v.size, 7);
    expect(_getUnsignedInt(v), 0xaa000000);
    // 10101010
    v.appendBit(false);
    expect(v.size, 8);
    expect(_getUnsignedInt(v), 0xaa000000);
    // 10101010 1
    v.appendBit(true);
    expect(v.size, 9);
    expect(_getUnsignedInt(v), 0xaa800000);
    // 10101010 10
    v.appendBit(false);
    expect(v.size, 10);
    expect(_getUnsignedInt(v), 0xaa800000);
  });

  test('Append bits', () {
    var v = BitArray();
    v.appendBits(0x1, 1);
    expect(v.size, 1);
    expect(_getUnsignedInt(v), 0x80000000);
    v = BitArray();
    v.appendBits(0xff, 8);
    expect(v.size, 8);
    expect(_getUnsignedInt(v), 0xff000000);
    v = BitArray();
    v.appendBits(0xff7, 12);
    expect(v.size, 12);
    expect(_getUnsignedInt(v), 0xff700000);
  });

  test('Num bytes', () {
    var v = BitArray();
    expect(v.sizeInBytes, 0);
    v.appendBit(false);
    // 1 bit was added in the vector, so 1 byte should be consumed.
    expect(v.sizeInBytes, 1);
    v.appendBits(0, 7);
    expect(v.sizeInBytes, 1);
    v.appendBits(0, 8);
    expect(v.sizeInBytes, 2);
    v.appendBits(0, 1);
    // We now have 17 bits, so 3 bytes should be consumed.
    expect(v.sizeInBytes, 3);
  });

  test('Append bit vector', () {
    var v1 = BitArray();
    v1.appendBits(0xbe, 8);
    var v2 = BitArray();
    v2.appendBits(0xef, 8);
    v1.appendBitArray(v2);
    // beef = 1011 1110 1110 1111
    expect(v1.toString(), ' X.XXXXX. XXX.XXXX');
  });

  test('XOR', () {
    var v1 = BitArray();
    v1.appendBits(0x5555aaaa, 32);
    var v2 = BitArray();
    v2.appendBits(0xaaaa5555, 32);
    v1.xor(v2);
    expect(_getUnsignedInt(v1), 0xffffffff);
  });

  test('XOR 2', () {
    var v1 = BitArray();
    v1.appendBits(0x2a, 7); // 010 1010
    var v2 = BitArray();
    v2.appendBits(0x55, 7); // 101 0101
    v1.xor(v2);
    expect(_getUnsignedInt(v1), 0xfe000000); // 1111 1110
  });

  test('At', () {
    var v = BitArray();
    v.appendBits(0xdead, 16); // 1101 1110 1010 1101
    expect(v.get(0), isTrue);
    expect(v.get(1), isTrue);
    expect(v.get(2), isFalse);
    expect(v.get(3), isTrue);

    expect(v.get(4), isTrue);
    expect(v.get(5), isTrue);
    expect(v.get(6), isTrue);
    expect(v.get(7), isFalse);

    expect(v.get(8), isTrue);
    expect(v.get(9), isFalse);
    expect(v.get(10), isTrue);
    expect(v.get(11), isFalse);

    expect(v.get(12), isTrue);
    expect(v.get(13), isTrue);
    expect(v.get(14), isFalse);
    expect(v.get(15), isTrue);
  });

  test('toString', () {
    var v = BitArray();
    v.appendBits(0xdead, 16); // 1101 1110 1010 1101
    expect(' XX.XXXX. X.X.XX.X', v.toString());
  });
}

int _getUnsignedInt(BitArray v) {
  var result = 0;
  for (var i = 0, offset = 0; i < 32; i++) {
    if (v.get(offset + i)) {
      result |= 1 << (31 - i);
    }
  }
  return result;
}
