import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zxing2/src/common/character_set_eci.dart';

void main() {
  String decode(CharacterSetECI eci, List<int> bytes) =>
      eci.encoding.decode(bytes);

  test('Single byte character sets', () {
    expect(decode(CharacterSetECI.Cp437, [0x41, 0x80, 0xE1]), 'AÇß');
    expect(decode(CharacterSetECI.ISO8859_2, [0xA3, 0xB1]), 'Łą');
    expect(decode(CharacterSetECI.ISO8859_5, [0xBF, 0xE0]), 'Пр');
    expect(decode(CharacterSetECI.ISO8859_15, [0xA4]), '€');
    expect(decode(CharacterSetECI.Cp1251, [0xCF, 0xF0]), 'Пр');
    expect(decode(CharacterSetECI.Cp1252, [0x80, 0x93]), '€“');
    expect(decode(CharacterSetECI.ISO8859_11, [0xDB]), '\uFFFD');
  });

  test('Single byte encoding round trip', () {
    var bytes = CharacterSetECI.ISO8859_5.encoding.encode('Привет');
    expect(decode(CharacterSetECI.ISO8859_5, bytes), 'Привет');
    expect(() => CharacterSetECI.ISO8859_5.encoding.encode('这'),
        throwsArgumentError);
  });

  test('Accepts signed bytes', () {
    expect(decode(CharacterSetECI.ISO8859_2, Int8List.fromList([-93])), 'Ł');
    expect(decode(CharacterSetECI.SJIS, Int8List.fromList([-126, -96])), 'あ');
    expect(decode(CharacterSetECI.GB18030, Int8List.fromList([-80, -95])), '啊');
  });

  test('UTF-16BE', () {
    var codec = CharacterSetECI.UnicodeBigUnmarked.encoding;
    expect(codec.decode([0x00, 0x41, 0x4E, 0x2D]), 'A中');
    expect(codec.encode('A中'), [0x00, 0x41, 0x4E, 0x2D]);
  });

  test('Shift_JIS', () {
    var codec = CharacterSetECI.SJIS.encoding;
    expect(codec.decode([0x82, 0xA0, 0x5C, 0x7E]), r'あ\~');
    expect(codec.encode(r'あ\~'), [0x82, 0xA0, 0x5C, 0x7E]);
    // Malformed input doesn't throw
    expect(codec.decode([0x82]), '\uFFFD');
    expect(codec.decode([0x82, 0x20]), '\uFFFD ');
  });

  test('GB2312', () {
    var codec = CharacterSetECI.GB18030.encoding;
    expect(codec.decode([0x41, 0xB0, 0xA1, 0xD6, 0xD0]), 'A啊中');
    expect(codec.encode('A啊中'), [0x41, 0xB0, 0xA1, 0xD6, 0xD0]);
    expect(codec.decode([0xB0]), '\uFFFD');
    expect(codec.decode([0xB0, 0x41]), '\uFFFDA');
  });

  test('Find by name', () {
    expect(CharacterSetECI.findByName('ISO-8859-8'), CharacterSetECI.ISO8859_8);
    expect(CharacterSetECI.findByName('iso8859_9'), CharacterSetECI.ISO8859_9);
    expect(CharacterSetECI.findByName('utf-8'), CharacterSetECI.UTF8);
  });
}
