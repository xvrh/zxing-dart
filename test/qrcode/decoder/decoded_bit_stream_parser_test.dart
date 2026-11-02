import 'dart:convert';
import 'package:test/test.dart';
import 'package:zxing2/src/decode_hint.dart';
import 'package:zxing2/src/qrcode/decoder/decoded_bit_stream_parser.dart';
import 'package:zxing2/src/qrcode/decoder/version.dart';
import '../../common/bit_source_builder.dart';

void main() {
  String decode(BitSourceBuilder builder, {DecodeHints? hints}) {
    return DecodedBitStreamParser.decode(builder.toByteArray(),
            Version.getVersionForNumber(1), null, hints ?? DecodeHints())
        .text;
  }

  test('Simple Byte mode', () {
    var builder = BitSourceBuilder();
    builder.write(0x04, 4); // Byte mode
    builder.write(0x03, 8); // 3 bytes
    builder.write(0xF1, 8);
    builder.write(0xF2, 8);
    builder.write(0xF3, 8);
    expect(decode(builder), '\u00f1\u00f2\u00f3');
  });

  test('Simple SJIS', () {
    var builder = BitSourceBuilder();
    builder.write(0x04, 4); // Byte mode
    builder.write(0x04, 8); // 4 bytes
    builder.write(0xA1, 8);
    builder.write(0xA2, 8);
    builder.write(0xA3, 8);
    builder.write(0xD0, 8);
    expect(decode(builder), '\uff61\uff62\uff63\uff90');
  });

  test('ECI', () {
    var builder = BitSourceBuilder();
    builder.write(0x07, 4); // ECI mode
    builder.write(0x02, 8); // ECI 2 = CP437 encoding
    builder.write(0x04, 4); // Byte mode
    builder.write(0x03, 8); // 3 bytes
    builder.write(0xA1, 8);
    builder.write(0xA2, 8);
    builder.write(0xA3, 8);
    expect(decode(builder), '\u00ed\u00f3\u00fa');
  });

  test('Hanzi', () {
    var builder = BitSourceBuilder();
    builder.write(0x0D, 4); // Hanzi mode
    builder.write(0x01, 4); // Subset 1 = GB2312 encoding
    builder.write(0x01, 8); // 1 characters
    builder.write(0x03C1, 13);
    expect(decode(builder), '\u963f');
  });

  test('Hanzi level 1', () {
    var builder = BitSourceBuilder();
    builder.write(0x0D, 4); // Hanzi mode
    builder.write(0x01, 4); // Subset 1 = GB2312 encoding
    builder.write(0x01, 8); // 1 characters
    // A5A2 (U+30A2) => A5A2 - A1A1 = 401, 4*60 + 01 = 0181
    builder.write(0x0181, 13);
    expect(decode(builder), '\u30a2');
  });

  test('UTF-8 ECI', () {
    var bytes = utf8.encode('这是 é 👋');
    var builder = BitSourceBuilder();
    builder.write(0x07, 4); // ECI mode
    builder.write(26, 8); // ECI 26 = UTF-8
    builder.write(0x04, 4); // Byte mode
    builder.write(bytes.length, 8);
    for (var b in bytes) {
      builder.write(b, 8);
    }
    expect(decode(builder), '这是 é 👋');
  });

  test('Guess UTF-8 without ECI', () {
    var bytes = utf8.encode('这是一个二维码');
    var builder = BitSourceBuilder();
    builder.write(0x04, 4); // Byte mode
    builder.write(bytes.length, 8);
    for (var b in bytes) {
      builder.write(b, 8);
    }
    expect(decode(builder), '这是一个二维码');
  });

  test('UTF-8 character set hint', () {
    var bytes = utf8.encode('café');
    var builder = BitSourceBuilder();
    builder.write(0x04, 4); // Byte mode
    builder.write(bytes.length, 8);
    for (var b in bytes) {
      builder.write(b, 8);
    }
    var hints = DecodeHints()..put(DecodeHintType.characterSet, 'UTF-8');
    expect(decode(builder, hints: hints), 'café');
  });

  test('FNC1 in alphanumeric mode', () {
    var builder = BitSourceBuilder();
    builder.write(0x05, 4); // FNC1 in first position
    builder.write(0x02, 4); // Alphanumeric mode
    builder.write(0x05, 9); // 5 characters: "A%%B%"
    builder.write(10 * 45 + 38, 11); // A%
    builder.write(38 * 45 + 11, 11); // %B
    builder.write(38, 6); // %
    expect(decode(builder), 'A%B\x1D');
  });

  test('Symbology modifier', () {
    int modifierOf(BitSourceBuilder builder) => DecodedBitStreamParser.decode(
            builder.toByteArray(),
            Version.getVersionForNumber(1),
            null,
            DecodeHints())
        .symbologyModifier;

    var plain = BitSourceBuilder()
      ..write(0x04, 4) // Byte mode
      ..write(0x01, 8) // 1 byte
      ..write(0x41, 8);
    expect(modifierOf(plain), 1);

    var eci = BitSourceBuilder()
      ..write(0x07, 4) // ECI mode
      ..write(26, 8) // ECI 26 = UTF-8
      ..write(0x04, 4) // Byte mode
      ..write(0x01, 8) // 1 byte
      ..write(0x41, 8);
    expect(modifierOf(eci), 2);

    var gs1 = BitSourceBuilder()
      ..write(0x05, 4) // FNC1 in first position
      ..write(0x01, 4) // Numeric mode
      ..write(0x02, 10) // 2 digits
      ..write(10, 7);
    expect(modifierOf(gs1), 3);
  });

  test('Structured append', () {
    var builder = BitSourceBuilder();
    builder.write(0x03, 4); // Structured append
    builder.write(0x12, 8); // Symbol sequence
    builder.write(0x34, 8); // Parity
    builder.write(0x04, 4); // Byte mode
    builder.write(0x01, 8); // 1 byte
    builder.write(0x41, 8);
    var result = DecodedBitStreamParser.decode(builder.toByteArray(),
        Version.getVersionForNumber(1), null, DecodeHints());
    expect(result.text, 'A');
    expect(result.structuredAppendSequenceNumber, 0x12);
    expect(result.structuredAppendParity, 0x34);
  });
}
