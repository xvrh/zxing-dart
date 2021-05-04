import 'dart:typed_data';
import 'package:charcode/charcode.dart';
import 'package:test/test.dart';
import 'package:zxing2/src/common/bit_array.dart';
import 'package:zxing2/src/common/character_set_eci.dart';
import 'package:zxing2/src/common/sjis.dart';
import 'package:zxing2/src/encode_hint.dart';
import 'package:zxing2/src/qrcode/decoder/error_correction_level.dart';
import 'package:zxing2/src/qrcode/decoder/mode.dart';
import 'package:zxing2/src/qrcode/decoder/version.dart';
import 'package:zxing2/src/qrcode/encoder/encoder.dart';
import 'package:zxing2/src/qrcode/encoder/qr_code.dart';
import 'package:zxing2/src/writer_exception.dart';

void main() {
  CharacterSetECI.SJIS.encoding = sjis;

  test('Get alphanumeric code', () {
    // The first ten code points are numbers.
    for (var i = 0; i < 10; ++i) {
      expect(
        i,
        Encoder.getAlphanumericCode($0 + i),
      );
    }

    // The next 26 code points are capital alphabet letters.
    for (var i = 10; i < 36; ++i) {
      expect(
        i,
        Encoder.getAlphanumericCode($A + i - 10),
      );
    }

    // Others are symbol letters
    expect(36, Encoder.getAlphanumericCode(' '.codeUnitAt(0)));
    expect(37, Encoder.getAlphanumericCode(r'$'.codeUnitAt(0)));
    expect(38, Encoder.getAlphanumericCode('%'.codeUnitAt(0)));
    expect(39, Encoder.getAlphanumericCode('*'.codeUnitAt(0)));
    expect(40, Encoder.getAlphanumericCode('+'.codeUnitAt(0)));
    expect(41, Encoder.getAlphanumericCode('-'.codeUnitAt(0)));
    expect(42, Encoder.getAlphanumericCode('.'.codeUnitAt(0)));
    expect(43, Encoder.getAlphanumericCode('/'.codeUnitAt(0)));
    expect(44, Encoder.getAlphanumericCode(':'.codeUnitAt(0)));

    // Should return -1 for other letters;
    expect(-1, Encoder.getAlphanumericCode('a'.codeUnitAt(0)));
    expect(-1, Encoder.getAlphanumericCode('#'.codeUnitAt(0)));
    expect(-1, Encoder.getAlphanumericCode(0));
  });

  test('Choose mode', () {
    // Numeric mode.
    expect(Mode.numeric, Encoder.chooseMode('0'));
    expect(Mode.numeric, Encoder.chooseMode('0123456789'));
    // Alphanumeric mode.
    expect(Mode.alphanumeric, Encoder.chooseMode('A'));
    expect(Mode.alphanumeric,
        Encoder.chooseMode(r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:'));
    // 8-bit byte mode.
    expect(Mode.byte, Encoder.chooseMode('a'));
    expect(Mode.byte, Encoder.chooseMode('#'));
    expect(Mode.byte, Encoder.chooseMode(''));
    // Kanji mode.  We used to use MODE_KANJI for these, but we stopped
    // doing that as we cannot distinguish Shift_JIS from other encodings
    // from data bytes alone.  See also comments in qrcode_encoder.h.

    // AIUE in Hiragana in Shift_JIS
    expect(
        Mode.byte,
        Encoder.chooseMode(
            shiftJISString([0x8, 0xa, 0x8, 0xa, 0x8, 0xa, 0x8, 0xa6])));

    // Nihon in Kanji in Shift_JIS.
    expect(
        Mode.byte, Encoder.chooseMode(shiftJISString([0x9, 0xf, 0x9, 0x7b])));

    // Sou-Utsu-Byou in Kanji in Shift_JIS.
    expect(Mode.byte,
        Encoder.chooseMode(shiftJISString([0xe, 0x4, 0x9, 0x5, 0x9, 0x61])));
  });

  test('Encode', () {
    var qrCode = Encoder.encode('ABCDEF', ErrorCorrectionLevel.h);
    var expected = '''
<<
 mode: ALPHANUMERIC
 ecLevel: H
 version: 1
 maskPattern: 4
 matrix:
 1 1 1 1 1 1 1 0 0 1 0 1 0 0 1 1 1 1 1 1 1
 1 0 0 0 0 0 1 0 1 0 1 0 1 0 1 0 0 0 0 0 1
 1 0 1 1 1 0 1 0 0 0 0 0 0 0 1 0 1 1 1 0 1
 1 0 1 1 1 0 1 0 0 1 0 0 1 0 1 0 1 1 1 0 1
 1 0 1 1 1 0 1 0 0 1 0 1 0 0 1 0 1 1 1 0 1
 1 0 0 0 0 0 1 0 1 0 0 1 1 0 1 0 0 0 0 0 1
 1 1 1 1 1 1 1 0 1 0 1 0 1 0 1 1 1 1 1 1 1
 0 0 0 0 0 0 0 0 1 0 0 0 1 0 0 0 0 0 0 0 0
 0 0 0 0 1 1 1 1 0 1 1 0 1 0 1 1 0 0 0 1 0
 0 0 0 0 1 1 0 1 1 1 0 0 1 1 1 1 0 1 1 0 1
 1 0 0 0 0 1 1 0 0 1 0 1 0 0 0 1 1 1 0 1 1
 1 0 0 1 1 1 0 0 1 1 1 1 0 0 0 0 1 0 0 0 0
 0 1 1 1 1 1 1 0 1 0 1 0 1 1 1 0 0 1 1 0 0
 0 0 0 0 0 0 0 0 1 1 0 0 0 1 1 0 0 0 1 0 1
 1 1 1 1 1 1 1 0 1 1 1 1 0 0 0 0 0 1 1 0 0
 1 0 0 0 0 0 1 0 1 1 0 1 0 0 0 1 0 1 1 1 1
 1 0 1 1 1 0 1 0 1 0 0 1 0 0 0 1 1 0 0 1 1
 1 0 1 1 1 0 1 0 0 0 1 1 0 1 0 0 0 0 1 1 1
 1 0 1 1 1 0 1 0 0 1 0 1 0 0 0 1 1 0 0 0 0
 1 0 0 0 0 0 1 0 0 1 0 0 1 0 0 1 1 0 0 0 1
 1 1 1 1 1 1 1 0 0 0 1 0 0 1 0 0 0 0 1 1 1
>>
''';
    expect(expected, qrCode.toString());
  });

  test('Encode with version', () {
    var hints = EncodeHints();
    hints.put<int>(EncodeHintType.qrVersion, 7);
    var qrCode = Encoder.encode('ABCDEF', ErrorCorrectionLevel.h, hints: hints);
    expect(qrCode.toString().contains(' version: 7\n'), isTrue);
  });

  test('Encode with version too small', () {
    var hints = EncodeHints();
    hints.put<int>(EncodeHintType.qrVersion, 3);
    expect(
        () => Encoder.encode(
            'THISMESSAGEISTOOLONGFORAQRCODEVERSION3', ErrorCorrectionLevel.h,
            hints: hints),
        throwsA(isA<WriterException>()));
  });

  test('Simple utf8 eci', () {
    var hints = EncodeHints();
    hints.put<CharacterSetECI>(
        EncodeHintType.characterSet, CharacterSetECI.UTF8);
    var qrCode = Encoder.encode('hello', ErrorCorrectionLevel.h, hints: hints);
    var expected = '''
<<
 mode: BYTE
 ecLevel: H
 version: 1
 maskPattern: 6
 matrix:
 1 1 1 1 1 1 1 0 0 0 1 1 0 0 1 1 1 1 1 1 1
 1 0 0 0 0 0 1 0 0 0 1 1 0 0 1 0 0 0 0 0 1
 1 0 1 1 1 0 1 0 1 0 0 1 1 0 1 0 1 1 1 0 1
 1 0 1 1 1 0 1 0 1 0 0 0 1 0 1 0 1 1 1 0 1
 1 0 1 1 1 0 1 0 0 1 1 0 0 0 1 0 1 1 1 0 1
 1 0 0 0 0 0 1 0 0 0 0 1 0 0 1 0 0 0 0 0 1
 1 1 1 1 1 1 1 0 1 0 1 0 1 0 1 1 1 1 1 1 1
 0 0 0 0 0 0 0 0 0 1 1 1 1 0 0 0 0 0 0 0 0
 0 0 0 1 1 0 1 1 0 0 0 0 1 0 0 0 0 1 1 0 0
 0 0 0 0 0 0 0 0 1 1 0 1 0 0 1 0 1 1 1 1 1
 1 1 0 0 0 1 1 1 0 0 0 1 1 0 0 1 0 1 0 1 1
 0 0 0 0 1 1 0 0 1 0 0 0 0 0 1 0 1 1 0 0 0
 0 1 1 0 0 1 1 0 0 1 1 1 0 1 1 1 1 1 1 1 1
 0 0 0 0 0 0 0 0 1 1 1 0 1 1 1 1 1 1 1 1 1
 1 1 1 1 1 1 1 0 1 0 1 0 0 0 1 0 0 0 0 0 0
 1 0 0 0 0 0 1 0 0 1 0 0 0 1 0 0 0 1 1 0 0
 1 0 1 1 1 0 1 0 1 0 0 0 1 0 1 0 0 0 1 0 0
 1 0 1 1 1 0 1 0 1 1 1 1 0 1 0 0 1 0 1 1 0
 1 0 1 1 1 0 1 0 0 1 1 1 0 0 1 0 0 1 0 1 1
 1 0 0 0 0 0 1 0 0 0 0 0 0 1 1 0 1 1 0 0 0
 1 1 1 1 1 1 1 0 0 0 0 1 0 1 0 0 1 0 1 0 0
>>
''';
    expect(expected, qrCode.toString());
  });

  test('Encode kanji mode', () {
    var hints = EncodeHints();
    hints.put<CharacterSetECI>(
        EncodeHintType.characterSet, CharacterSetECI.SJIS);
    // Nihon in Kanji
    var qrCode =
        Encoder.encode('\u65e5\u672c', ErrorCorrectionLevel.m, hints: hints);
    var expected = '''
<<
 mode: KANJI
 ecLevel: M
 version: 1
 maskPattern: 0
 matrix:
 1 1 1 1 1 1 1 0 0 1 0 1 0 0 1 1 1 1 1 1 1
 1 0 0 0 0 0 1 0 1 1 0 0 0 0 1 0 0 0 0 0 1
 1 0 1 1 1 0 1 0 0 1 1 1 1 0 1 0 1 1 1 0 1
 1 0 1 1 1 0 1 0 0 0 0 0 1 0 1 0 1 1 1 0 1
 1 0 1 1 1 0 1 0 1 1 1 1 1 0 1 0 1 1 1 0 1
 1 0 0 0 0 0 1 0 0 1 1 1 0 0 1 0 0 0 0 0 1
 1 1 1 1 1 1 1 0 1 0 1 0 1 0 1 1 1 1 1 1 1
 0 0 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0
 1 0 1 0 1 0 1 0 0 0 1 0 1 0 0 0 1 0 0 1 0
 1 1 0 1 0 0 0 1 0 1 1 1 0 1 0 1 0 1 0 0 0
 0 1 0 0 0 0 1 1 1 1 1 1 0 1 1 1 0 1 0 1 0
 1 1 1 0 0 1 0 1 0 0 0 1 1 1 0 1 1 0 1 0 0
 0 1 1 0 0 1 1 0 1 1 0 1 0 1 1 1 0 1 0 0 1
 0 0 0 0 0 0 0 0 1 0 1 0 0 0 1 0 0 0 1 0 1
 1 1 1 1 1 1 1 0 0 0 0 0 1 0 0 0 1 0 0 1 1
 1 0 0 0 0 0 1 0 0 0 1 0 0 0 1 0 0 0 1 1 1
 1 0 1 1 1 0 1 0 1 0 0 0 1 0 1 0 1 0 1 0 1
 1 0 1 1 1 0 1 0 0 0 0 1 0 1 0 1 0 1 0 1 0
 1 0 1 1 1 0 1 0 1 0 1 1 0 1 1 1 0 0 1 0 1
 1 0 0 0 0 0 1 0 0 0 0 1 1 1 0 1 1 1 0 1 0
 1 1 1 1 1 1 1 0 1 1 0 1 0 1 1 1 0 0 1 0 0
>>
''';
    expect(expected, qrCode.toString());
  });

  test('Encode shift jis numeric', () {
    var hints = EncodeHints();
    hints.put<CharacterSetECI>(
        EncodeHintType.characterSet, CharacterSetECI.SJIS);
    var qrCode = Encoder.encode('0123', ErrorCorrectionLevel.m, hints: hints);
    var expected = '''
<<
 mode: NUMERIC
 ecLevel: M
 version: 1
 maskPattern: 2
 matrix:
 1 1 1 1 1 1 1 0 0 1 1 0 1 0 1 1 1 1 1 1 1
 1 0 0 0 0 0 1 0 0 1 0 0 1 0 1 0 0 0 0 0 1
 1 0 1 1 1 0 1 0 1 0 0 0 0 0 1 0 1 1 1 0 1
 1 0 1 1 1 0 1 0 1 0 1 1 1 0 1 0 1 1 1 0 1
 1 0 1 1 1 0 1 0 1 1 0 1 1 0 1 0 1 1 1 0 1
 1 0 0 0 0 0 1 0 1 1 0 0 1 0 1 0 0 0 0 0 1
 1 1 1 1 1 1 1 0 1 0 1 0 1 0 1 1 1 1 1 1 1
 0 0 0 0 0 0 0 0 1 1 1 1 1 0 0 0 0 0 0 0 0
 1 0 1 1 1 1 1 0 0 1 1 0 1 0 1 1 1 1 1 0 0
 1 1 0 0 0 1 0 0 1 0 1 0 1 0 0 1 0 0 1 0 0
 0 1 1 0 1 1 1 1 0 1 1 1 0 1 0 0 1 1 0 1 1
 1 0 1 1 0 1 0 1 0 0 1 0 0 0 0 1 1 0 1 0 0
 0 0 1 0 0 1 1 1 0 0 0 1 0 1 0 0 1 0 1 0 0
 0 0 0 0 0 0 0 0 1 1 0 1 1 1 1 0 0 1 0 0 0
 1 1 1 1 1 1 1 0 0 0 1 0 1 0 1 1 0 0 0 0 0
 1 0 0 0 0 0 1 0 1 1 0 1 1 1 1 0 0 1 0 1 0
 1 0 1 1 1 0 1 0 1 0 1 0 1 0 0 1 0 0 1 0 0
 1 0 1 1 1 0 1 0 1 1 1 0 1 0 0 1 0 0 1 0 0
 1 0 1 1 1 0 1 0 1 1 0 1 0 1 0 0 1 1 1 0 0
 1 0 0 0 0 0 1 0 0 0 1 0 0 0 0 1 1 0 1 1 0
 1 1 1 1 1 1 1 0 1 1 0 1 0 1 0 0 1 1 1 0 0
>>
''';
    expect(expected, qrCode.toString());
  });

  test('Encode gs1 with type hint', () {
    var hints = EncodeHints();
    hints.put<bool>(EncodeHintType.gs1Format, true);
    var qrCode =
        Encoder.encode('100001%11171218', ErrorCorrectionLevel.h, hints: hints);
    _verifyGS1EncodedData(qrCode);
  });

  test('Encode gs1 with false type hint', () {
    var hints = EncodeHints();
    hints.put<bool>(EncodeHintType.gs1Format, false);
    var qrCode = Encoder.encode('ABCDEF', ErrorCorrectionLevel.h, hints: hints);
    _verifyNotGS1EncodedData(qrCode);
  });

  test('GS1 mode header with eci', () {
    var hints = EncodeHints();
    hints.put<CharacterSetECI>(
        EncodeHintType.characterSet, CharacterSetECI.UTF8);
    hints.put<bool>(EncodeHintType.gs1Format, true);
    var qrCode = Encoder.encode('hello', ErrorCorrectionLevel.h, hints: hints);
    var expected = '''
<<
 mode: BYTE
 ecLevel: H
 version: 1
 maskPattern: 5
 matrix:
 1 1 1 1 1 1 1 0 1 0 1 1 0 0 1 1 1 1 1 1 1
 1 0 0 0 0 0 1 0 0 1 1 0 0 0 1 0 0 0 0 0 1
 1 0 1 1 1 0 1 0 1 1 1 0 0 0 1 0 1 1 1 0 1
 1 0 1 1 1 0 1 0 0 1 0 1 0 0 1 0 1 1 1 0 1
 1 0 1 1 1 0 1 0 1 0 1 0 0 0 1 0 1 1 1 0 1
 1 0 0 0 0 0 1 0 0 1 1 1 1 0 1 0 0 0 0 0 1
 1 1 1 1 1 1 1 0 1 0 1 0 1 0 1 1 1 1 1 1 1
 0 0 0 0 0 0 0 0 1 0 1 1 1 0 0 0 0 0 0 0 0
 0 0 0 0 0 1 1 0 0 1 1 0 0 0 1 0 1 0 1 0 1
 0 1 0 1 1 0 0 1 0 1 1 1 1 1 1 0 1 1 1 0 1
 0 1 0 1 1 1 1 0 1 1 0 0 0 1 0 1 0 1 1 0 0
 1 1 1 1 0 1 0 1 0 0 1 0 1 0 0 1 1 1 1 0 0
 1 0 0 1 0 0 1 1 0 1 1 0 1 0 1 0 0 1 0 0 1
 0 0 0 0 0 0 0 0 1 1 1 1 1 0 1 0 1 0 0 1 0
 1 1 1 1 1 1 1 0 0 0 1 1 0 0 1 0 0 0 1 1 0
 1 0 0 0 0 0 1 0 1 1 0 0 0 0 1 0 1 1 1 0 0
 1 0 1 1 1 0 1 0 0 1 0 0 1 0 1 0 1 0 0 0 1
 1 0 1 1 1 0 1 0 0 0 0 0 1 1 1 0 1 1 1 1 0
 1 0 1 1 1 0 1 0 0 0 1 0 0 1 0 0 1 0 1 1 1
 1 0 0 0 0 0 1 0 0 1 0 0 0 1 1 0 0 1 1 1 1
 1 1 1 1 1 1 1 0 0 1 1 1 0 1 1 0 1 0 0 1 0
>>
''';
    expect(expected, qrCode.toString());
  });

  test('Append mode info', () {
    var bits = BitArray();
    Encoder.appendModeInfo(Mode.numeric, bits);
    expect(' ...X', bits.toString());
  });

  test('Append length info', () {
    var bits = BitArray();
    Encoder.appendLengthInfo(
        1, // 1 letter (1/1).
        Version.getVersionForNumber(1),
        Mode.numeric,
        bits);
    expect(' ........ .X', bits.toString()); // 10 bits.
    bits = BitArray();
    Encoder.appendLengthInfo(
        2, // 2 letters (2/1).
        Version.getVersionForNumber(10),
        Mode.alphanumeric,
        bits);
    expect(' ........ .X.', bits.toString()); // 11 bits.
    bits = BitArray();
    Encoder.appendLengthInfo(
        255, // 255 letter (255/1).
        Version.getVersionForNumber(27),
        Mode.byte,
        bits);
    expect(' ........ XXXXXXXX', bits.toString()); // 16 bits.
    bits = BitArray();
    Encoder.appendLengthInfo(
        512, // 512 letters (1024/2).
        Version.getVersionForNumber(40),
        Mode.kanji,
        bits);
    expect(' ..X..... ....', bits.toString()); // 12 bits.
  });

  test('append bytes', () {
    // Should use appendNumericBytes.
    // 1 = 01 = 0001 in 4 bits.
    var bits = BitArray();
    Encoder.appendBytes(
        '1', Mode.numeric, bits, Encoder.defaultByteModeEncoding);
    expect(' ...X', bits.toString());
    // Should use appendAlphanumericBytes.
    // A = 10 = 0xa = 001010 in 6 bits
    bits = BitArray();
    Encoder.appendBytes(
        'A', Mode.alphanumeric, bits, Encoder.defaultByteModeEncoding);
    expect(' ..X.X.', bits.toString());
    // Lower letters such as 'a' cannot be encoded in MODE_ALPHANUMERIC.
    try {
      Encoder.appendBytes(
          'a', Mode.alphanumeric, bits, Encoder.defaultByteModeEncoding);
    } on WriterException catch (_) {
      // good
    }
    // Should use append8BitBytes.
    // 0x61, 0x62, 0x63
    bits = BitArray();
    Encoder.appendBytes(
        'abc', Mode.byte, bits, Encoder.defaultByteModeEncoding);
    expect(' .XX....X .XX...X. .XX...XX', bits.toString());
    // Anything can be encoded in QRCode.MODE_8BIT_BYTE.
    Encoder.appendBytes('\0', Mode.byte, bits, Encoder.defaultByteModeEncoding);
    // Should use appendKanjiBytes.
    // 0x93, 0x5f
    bits = BitArray();
    Encoder.appendBytes(shiftJISString([0x93, 0x5f]), Mode.kanji, bits,
        Encoder.defaultByteModeEncoding);
    expect(' .XX.XX.. XXXXX', bits.toString());
  });

  test('Terminate bits', () {
    var v = BitArray();
    Encoder.terminateBits(0, v);
    expect('', v.toString());
    v = BitArray();
    Encoder.terminateBits(1, v);
    expect(' ........', v.toString());
    v = BitArray();
    v.appendBits(0, 3); // Append 000
    Encoder.terminateBits(1, v);
    expect(' ........', v.toString());
    v = BitArray();
    v.appendBits(0, 5); // Append 00000
    Encoder.terminateBits(1, v);
    expect(' ........', v.toString());
    v = BitArray();
    v.appendBits(0, 8); // Append 00000000
    Encoder.terminateBits(1, v);
    expect(' ........', v.toString());
    v = BitArray();
    Encoder.terminateBits(2, v);
    expect(' ........ XXX.XX..', v.toString());
    v = BitArray();
    v.appendBits(0, 1); // Append 0
    Encoder.terminateBits(3, v);
    expect(' ........ XXX.XX.. ...X...X', v.toString());
  });

  test('Get num data bytes and num ec bytes from block id', () {
    var numDataBytes = Int32List(1);
    var numEcBytes = Int32List(1);
    // Version 1-H.
    Encoder.getNumDataBytesAndNumECBytesForBlockID(
        26, 9, 1, 0, numDataBytes, numEcBytes);
    expect(9, numDataBytes[0]);
    expect(17, numEcBytes[0]);

    // Version 3-H.  2 blocks.
    Encoder.getNumDataBytesAndNumECBytesForBlockID(
        70, 26, 2, 0, numDataBytes, numEcBytes);
    expect(13, numDataBytes[0]);
    expect(22, numEcBytes[0]);
    Encoder.getNumDataBytesAndNumECBytesForBlockID(
        70, 26, 2, 1, numDataBytes, numEcBytes);
    expect(13, numDataBytes[0]);
    expect(22, numEcBytes[0]);

    // Version 7-H. (4 + 1) blocks.
    Encoder.getNumDataBytesAndNumECBytesForBlockID(
        196, 66, 5, 0, numDataBytes, numEcBytes);
    expect(13, numDataBytes[0]);
    expect(26, numEcBytes[0]);
    Encoder.getNumDataBytesAndNumECBytesForBlockID(
        196, 66, 5, 4, numDataBytes, numEcBytes);
    expect(14, numDataBytes[0]);
    expect(26, numEcBytes[0]);

    // Version 40-H. (20 + 61) blocks.
    Encoder.getNumDataBytesAndNumECBytesForBlockID(
        3706, 1276, 81, 0, numDataBytes, numEcBytes);
    expect(15, numDataBytes[0]);
    expect(30, numEcBytes[0]);
    Encoder.getNumDataBytesAndNumECBytesForBlockID(
        3706, 1276, 81, 20, numDataBytes, numEcBytes);
    expect(16, numDataBytes[0]);
    expect(30, numEcBytes[0]);
    Encoder.getNumDataBytesAndNumECBytesForBlockID(
        3706, 1276, 81, 80, numDataBytes, numEcBytes);
    expect(16, numDataBytes[0]);
    expect(30, numEcBytes[0]);
  });

  test('Interleave with ECBytes', () {
    var dataBytes = Int8List.fromList([32, 65, 205, 69, 41, 220, 46, 128, 236]);
    var input = BitArray();
    for (var dataByte in dataBytes) {
      input.appendBits(dataByte, 8);
    }
    var out = Encoder.interleaveWithECBytes(input, 26, 9, 1);
    var expected = Int8List.fromList([
      // Data bytes.
      32, 65, 205, 69, 41, 220, 46, 128, 236,
      // Error correction bytes.
      42, 159, 74, 221, 244, 169, 239, 150, 138, 70,
      237, 85, 224, 96, 74, 219, 61, //
    ]);
    expect(expected.length, out.sizeInBytes);
    var outArray = Int8List(expected.length);
    out.toBytes(0, outArray, 0, expected.length);
    // Can't use Arrays.equals(), because outArray may be longer than out.sizeInBytes()
    for (var x = 0; x < expected.length; x++) {
      expect(expected[x], outArray[x]);
    }
    // Numbers are from http://www.swetake.com/qr/qr8.html
    dataBytes = Int8List.fromList(<int>[
      67, 70, 22, 38, 54, 70, 86, 102, 118, 134, 150, 166, 182,
      198, 214, 230, 247, 7, 23, 39, 55, 71, 87, 103, 119, 135,
      151, 166, 22, 38, 54, 70, 86, 102, 118, 134, 150, 166,
      182, 198, 214, 230, 247, 7, 23, 39, 55, 71, 87, 103, 119,
      135, 151, 160, 236, 17, 236, 17, 236, 17, 236, //
      17, //
    ]);
    input = BitArray();
    for (var dataByte in dataBytes) {
      input.appendBits(dataByte, 8);
    }

    out = Encoder.interleaveWithECBytes(input, 134, 62, 4);
    expected = Int8List.fromList([
      // Data bytes.
      67, 230, 54, 55, 70, 247, 70, 71, 22, 7, 86, 87, 38, 23, 102, 103, 54, 39,
      118, 119, 70, 55, 134, 135, 86, 71, 150, 151, 102, 87, 166,
      160, 118, 103, 182, 236, 134, 119, 198, 17, 150,
      135, 214, 236, 166, 151, 230, 17, 182,
      166, 247, 236, 198, 22, 7, 17, 214, 38, 23, 236, 39, //
      17,
      // Error correction bytes.
      175, 155, 245, 236, 80, 146, 56, 74, 155, 165,
      133, 142, 64, 183, 132, 13, 178, 54, 132, 108, 45,
      113, 53, 50, 214, 98, 193, 152, 233, 147, 50, 71, 65,
      190, 82, 51, 209, 199, 171, 54, 12, 112, 57, 113, 155, 117,
      211, 164, 117, 30, 158, 225, 31, 190, 242, 38,
      140, 61, 179, 154, 214, 138, 147, 87, 27, 96, 77, 47,
      187, 49, 156, 214, //
    ]);
    expect(expected.length, out.sizeInBytes);
    outArray = Int8List(expected.length);
    out.toBytes(0, outArray, 0, expected.length);
    for (var x = 0; x < expected.length; x++) {
      expect(expected[x], outArray[x]);
    }
  });

  test('Append numeric bytes', () {
    // 1 = 01 = 0001 in 4 bits.
    var bits = BitArray();
    Encoder.appendNumericBytes('1', bits);
    expect(' ...X', bits.toString());
    // 12 = 0xc = 0001100 in 7 bits.
    bits = BitArray();
    Encoder.appendNumericBytes('12', bits);
    expect(' ...XX..', bits.toString());
    // 123 = 0x7b = 0001111011 in 10 bits.
    bits = BitArray();
    Encoder.appendNumericBytes('123', bits);
    expect(' ...XXXX. XX', bits.toString());
    // 1234 = "123" + "4" = 0001111011 + 0100
    bits = BitArray();
    Encoder.appendNumericBytes('1234', bits);
    expect(' ...XXXX. XX.X..', bits.toString());
    // Empty.
    bits = BitArray();
    Encoder.appendNumericBytes('', bits);
    expect('', bits.toString());
  });

  test('Append alphanumeric bytes', () {
    // A = 10 = 0xa = 001010 in 6 bits
    var bits = BitArray();
    Encoder.appendAlphanumericBytes('A', bits);
    expect(' ..X.X.', bits.toString());
    // AB = 10 * 45 + 11 = 461 = 0x1cd = 00111001101 in 11 bits
    bits = BitArray();
    Encoder.appendAlphanumericBytes('AB', bits);
    expect(' ..XXX..X X.X', bits.toString());
    // ABC = "AB" + "C" = 00111001101 + 001100
    bits = BitArray();
    Encoder.appendAlphanumericBytes('ABC', bits);
    expect(' ..XXX..X X.X..XX. .', bits.toString());
    // Empty.
    bits = BitArray();
    Encoder.appendAlphanumericBytes('', bits);
    expect('', bits.toString());
    // Invalid data.
    try {
      Encoder.appendAlphanumericBytes('abc', BitArray());
    } on WriterException catch (_) {
      // good
    }
  });

  test('Append 8 bit bytes', () {
    // 0x61, 0x62, 0x63
    var bits = BitArray();
    Encoder.append8BitBytes(
        'abc', bits, Encoder.defaultByteModeEncoding.encoding);
    expect(' .XX....X .XX...X. .XX...XX', bits.toString());
    // Empty.
    bits = BitArray();
    Encoder.append8BitBytes('', bits, Encoder.defaultByteModeEncoding.encoding);
    expect('', bits.toString());
  });

  // Numbers are from page 21 of JISX0510:2004
  test('Append kanji bytes', () {
    var bits = BitArray();
    Encoder.appendKanjiBytes(
        shiftJISString(Int8List.fromList([0x93, 0x5f])), bits);
    expect(' .XX.XX.. XXXXX', bits.toString());
    Encoder.appendKanjiBytes(
        shiftJISString(Int8List.fromList([0xe4, 0xaa])), bits);
    expect(' .XX.XX.. XXXXXXX. X.X.X.X. X.', bits.toString());
  }, skip: 'Investigate');

  // Numbers are from http://www.swetake.com/qr/qr3.html and
  // http://www.swetake.com/qr/qr9.html
  test('generate ECBytes', () {
    var dataBytes = Int8List.fromList([32, 65, 205, 69, 41, 220, 46, 128, 236]);
    var ecBytes = Encoder.generateECBytes(dataBytes, 17);
    var expected = [
      42, 159, 74, 221, 244, 169, 239, 150,
      138, 70, 237, 85, 224, 96, 74, 219, 61, //
    ];
    expect(expected.length, ecBytes.length);
    for (var x = 0; x < expected.length; x++) {
      expect(expected[x], ecBytes[x] & 0xFF);
    }
    dataBytes = Int8List.fromList([
      67, 70, 22, 38, 54, 70, 86, 102,
      118, 134, 150, 166, 182, 198, 214, //
    ]);
    ecBytes = Encoder.generateECBytes(dataBytes, 18);
    expected = <int>[
      175, 80, 155, 64, 178, 45, 214, 233, 65, 209,
      12, 155, 117, 31, 140, 214, 27, 187, //
    ];
    expect(expected.length, ecBytes.length);
    for (var x = 0; x < expected.length; x++) {
      expect(expected[x], ecBytes[x] & 0xFF);
    }
    // High-order zero coefficient case.
    dataBytes = Int8List.fromList([32, 49, 205, 69, 42, 20, 0, 236, 17]);
    ecBytes = Encoder.generateECBytes(dataBytes, 17);
    expected = [
      0, 3, 130, 179, 194, 0, 55, 211, 110, 79, 98, 72, 170, 96, 211, 137,
      213, //
    ];
    expect(expected.length, ecBytes.length);
    for (var x = 0; x < expected.length; x++) {
      expect(expected[x], ecBytes[x] & 0xFF);
    }
  });

  test('But in BitVector num bytes', () {
    // There was a bug in BitVector.sizeInBytes() that caused it to return a
    // smaller-by-one value (ex. 1465 instead of 1466) if the number of bits
    // in the vector is not 8-bit aligned.  In QRCodeEncoder::InitQRCode(),
    // BitVector::sizeInBytes() is used for finding the smallest QR Code
    // version that can fit the given data.  Hence there were corner cases
    // where we chose a wrong QR Code version that cannot fit the given
    // data.  Note that the issue did not occur with MODE_8BIT_BYTE, as the
    // bits in the bit vector are always 8-bit aligned.
    //
    // Before the bug was fixed, the following test didn't pass, because:
    //
    // - MODE_NUMERIC is chosen as all bytes in the data are '0'
    // - The 3518-byte numeric data needs 1466 bytes
    //   - 3518 / 3 * 10 + 7 = 11727 bits = 1465.875 bytes
    //   - 3 numeric bytes are encoded in 10 bits, hence the first
    //     3516 bytes are encoded in 3516 / 3 * 10 = 11720 bits.
    //   - 2 numeric bytes can be encoded in 7 bits, hence the last
    //     2 bytes are encoded in 7 bits.
    // - The version 27 QR Code with the EC level L has 1468 bytes for data.
    //   - 1828 - 360 = 1468
    // - In InitQRCode(), 3 bytes are reserved for a header.  Hence 1465 bytes
    //   (1468 -3) are left for data.
    // - Because of the bug in BitVector::sizeInBytes(), InitQRCode() determines
    //   the given data can fit in 1465 bytes, despite it needs 1466 bytes.
    // - Hence QRCodeEncoder.encode() failed and returned false.
    //   - To be precise, it needs 11727 + 4 (getMode info) + 14 (length info) =
    //     11745 bits = 1468.125 bytes are needed (i.e. cannot fit in 1468
    //     bytes).
    var builder = StringBuffer();
    for (var x = 0; x < 3518; x++) {
      builder.write('0');
    }
    Encoder.encode(builder.toString(), ErrorCorrectionLevel.l);
  });
}

String shiftJISString(List<int> bytes) {
  return CharacterSetECI.SJIS.encoding.decode(bytes);
}

void _verifyGS1EncodedData(QRCode qrCode) {
  var expected = '''
<<
 mode: ALPHANUMERIC
 ecLevel: H
 version: 2
 maskPattern: 4
 matrix:
 1 1 1 1 1 1 1 0 0 1 1 1 1 0 1 0 1 0 1 1 1 1 1 1 1
 1 0 0 0 0 0 1 0 1 1 0 0 0 0 0 1 1 0 1 0 0 0 0 0 1
 1 0 1 1 1 0 1 0 0 0 0 0 1 1 1 0 1 0 1 0 1 1 1 0 1
 1 0 1 1 1 0 1 0 0 1 0 1 0 0 1 1 0 0 1 0 1 1 1 0 1
 1 0 1 1 1 0 1 0 0 0 1 1 1 0 0 0 1 0 1 0 1 1 1 0 1
 1 0 0 0 0 0 1 0 1 1 0 1 1 0 1 1 0 0 1 0 0 0 0 0 1
 1 1 1 1 1 1 1 0 1 0 1 0 1 0 1 0 1 0 1 1 1 1 1 1 1
 0 0 0 0 0 0 0 0 1 1 0 1 1 0 1 1 0 0 0 0 0 0 0 0 0
 0 0 0 0 1 1 1 1 0 0 1 1 0 0 0 1 1 0 1 1 0 0 0 1 0
 0 1 1 0 1 1 0 0 1 1 1 0 0 0 1 1 1 1 1 1 1 0 0 0 1
 0 0 1 1 1 1 1 0 1 1 1 1 1 0 1 0 0 0 0 0 0 1 1 1 0
 1 0 1 1 1 0 0 1 1 1 0 1 1 1 1 1 0 1 1 0 1 1 1 0 0
 0 1 0 1 0 0 1 1 1 1 1 1 0 0 1 1 0 1 0 0 0 0 0 1 0
 1 0 0 1 1 1 0 0 1 1 0 0 0 1 1 0 1 0 1 0 1 0 0 0 0
 0 0 1 0 0 1 1 1 0 1 1 0 1 1 1 0 1 1 1 0 1 1 1 1 0
 0 0 0 1 1 0 0 1 0 0 1 0 0 1 1 0 0 1 0 0 0 1 1 1 0
 1 1 0 1 0 1 1 0 1 0 1 0 0 0 1 1 1 1 1 1 1 0 0 0 0
 0 0 0 0 0 0 0 0 1 1 0 1 0 0 0 1 1 0 0 0 1 1 0 1 0
 1 1 1 1 1 1 1 0 1 0 1 0 1 0 1 1 1 0 1 0 1 0 0 0 0
 1 0 0 0 0 0 1 0 1 1 0 0 0 1 0 1 1 0 0 0 1 0 1 1 0
 1 0 1 1 1 0 1 0 1 1 1 0 0 0 0 0 1 1 1 1 1 1 0 0 1
 1 0 1 1 1 0 1 0 0 0 0 0 0 1 1 1 0 0 1 1 0 1 0 0 0
 1 0 1 1 1 0 1 0 0 0 1 1 0 1 0 1 1 1 0 1 1 0 0 1 0
 1 0 0 0 0 0 1 0 0 1 1 0 1 1 1 1 1 0 1 0 1 1 0 0 0
 1 1 1 1 1 1 1 0 0 0 1 0 0 0 0 1 1 0 0 1 1 0 0 1 1
>>
''';
  expect(expected, qrCode.toString());
}

void _verifyNotGS1EncodedData(QRCode qrCode) {
  var expected = '''
<<
 mode: ALPHANUMERIC
 ecLevel: H
 version: 1
 maskPattern: 4
 matrix:
 1 1 1 1 1 1 1 0 0 1 0 1 0 0 1 1 1 1 1 1 1
 1 0 0 0 0 0 1 0 1 0 1 0 1 0 1 0 0 0 0 0 1
 1 0 1 1 1 0 1 0 0 0 0 0 0 0 1 0 1 1 1 0 1
 1 0 1 1 1 0 1 0 0 1 0 0 1 0 1 0 1 1 1 0 1
 1 0 1 1 1 0 1 0 0 1 0 1 0 0 1 0 1 1 1 0 1
 1 0 0 0 0 0 1 0 1 0 0 1 1 0 1 0 0 0 0 0 1
 1 1 1 1 1 1 1 0 1 0 1 0 1 0 1 1 1 1 1 1 1
 0 0 0 0 0 0 0 0 1 0 0 0 1 0 0 0 0 0 0 0 0
 0 0 0 0 1 1 1 1 0 1 1 0 1 0 1 1 0 0 0 1 0
 0 0 0 0 1 1 0 1 1 1 0 0 1 1 1 1 0 1 1 0 1
 1 0 0 0 0 1 1 0 0 1 0 1 0 0 0 1 1 1 0 1 1
 1 0 0 1 1 1 0 0 1 1 1 1 0 0 0 0 1 0 0 0 0
 0 1 1 1 1 1 1 0 1 0 1 0 1 1 1 0 0 1 1 0 0
 0 0 0 0 0 0 0 0 1 1 0 0 0 1 1 0 0 0 1 0 1
 1 1 1 1 1 1 1 0 1 1 1 1 0 0 0 0 0 1 1 0 0
 1 0 0 0 0 0 1 0 1 1 0 1 0 0 0 1 0 1 1 1 1
 1 0 1 1 1 0 1 0 1 0 0 1 0 0 0 1 1 0 0 1 1
 1 0 1 1 1 0 1 0 0 0 1 1 0 1 0 0 0 0 1 1 1
 1 0 1 1 1 0 1 0 0 1 0 1 0 0 0 1 1 0 0 0 0
 1 0 0 0 0 0 1 0 0 1 0 0 1 0 0 1 1 0 0 0 1
 1 1 1 1 1 1 1 0 0 0 1 0 0 1 0 0 0 0 1 1 1
>>
''';
  expect(expected, qrCode.toString());
}
