import 'package:test/test.dart';
import 'package:zxing2/oned.dart';
import 'matrix_to_string.dart';

const _fnc1 = '11110101110';
const _fnc2 = '11110101000';
const _fnc3 = '10111100010';
const _fnc4A = '11101011110';
const _fnc4B = '10111101110';
const _startCodeA = '11010000100';
const _startCodeB = '11010010000';
const _startCodeC = '11010011100';
const _switchCodeA = '11101011110';
const _switchCodeB = '10111101110';
const _quietSpace = '00000';
const _stop = '1100011101011';
const _lf = '10000110010';

/// Tests [Code128Writer].
void main() {
  late Writer writer;
  late Code128Reader reader;

  setUp(() {
    writer = Code128Writer();
    reader = Code128Reader();
  });

  BitMatrix encode(String toEncode, bool compact, String? expectedLoopback) {
    var hints = EncodeHints();
    if (compact) {
      hints.put(EncodeHintType.code128Compact, true);
    }
    var encResult =
        writer.encode(toEncode, BarcodeFormat.code128, 0, 0, hints: hints);
    if (expectedLoopback != null) {
      var row = encResult.getRow(0, null);
      var rtResult = reader.decodeRow(0, row, DecodeHints());
      var actual = rtResult.text;
      expect(actual, expectedLoopback);
    }
    if (compact) {
      //check that what is encoded compactly yields the same on loopback as what was encoded fast.
      var row = encResult.getRow(0, null);
      var rtResult = reader.decodeRow(0, row, DecodeHints());
      var actual = rtResult.text;
      var encResultFast = writer.encode(toEncode, BarcodeFormat.code128, 0, 0);
      row = encResultFast.getRow(0, null);
      rtResult = reader.decodeRow(0, row, DecodeHints());
      expect(actual, rtResult.text);
    }
    return encResult;
  }

  void testEncode(String toEncode, String expected) {
    var result = encode(toEncode, false, toEncode);
    var actual = matrixToString(result);
    expect(actual, expected, reason: toEncode);

    var width = result.width;
    result = encode(toEncode, true, toEncode);
    expect(result.width, lessThanOrEqualTo(width));
  }

  test('Encode with func 3', () {
    var toEncode = 'ó' '123';
    var expected = '$_quietSpace$_startCodeB$_fnc3'
        // "1"            "2"             "3"            check digit 51
        '10011100110'
        '11001110010'
        '11001011100'
        '11101000110'
        '$_stop$_quietSpace';

    var result = encode(toEncode, false, '123');

    var actual = matrixToString(result);
    expect(actual, expected);

    var width = result.width;
    result = encode(toEncode, true, '123');

    expect(result.width, width);
  });

  test('Encode with func 2', () {
    var toEncode = 'ò' '123';
    var expected = '$_quietSpace$_startCodeB$_fnc2'
        // "1"            "2"             "3"             check digit 56
        '10011100110'
        '11001110010'
        '11001011100'
        '11100010110'
        '$_stop$_quietSpace';

    var result = encode(toEncode, false, '123');

    var actual = matrixToString(result);
    expect(actual, expected);

    var width = result.width;
    result = encode(toEncode, true, '123');

    expect(result.width, width);
  });

  test('Encode with func 1', () {
    var toEncode = 'ñ' '123';
    var expected = '$_quietSpace$_startCodeC$_fnc1'
        // "12"                           "3"            check digit 92
        '10110011100'
        '$_switchCodeB'
        '11001011100'
        '10101111000'
        '$_stop$_quietSpace';

    var result = encode(toEncode, false, '123');

    var actual = matrixToString(result);
    expect(actual, expected);

    var width = result.width;
    result = encode(toEncode, true, '123');

    expect(result.width, width);
  });

  test('Roundtrip', () {
    var toEncode = 'ñ' '10958' 'ñ' '17160526';
    var expected = '1095817160526';

    var encResult = encode(toEncode, false, expected);

    var width = encResult.width;
    encResult = encode(toEncode, true, expected);
    //Compact encoding has one latch less and encodes as STARTA,FNC1,1,CODEC,09,58,FNC1,17,16,05,26
    expect(width, encResult.width + 11);
  });

  test('Long compact', () {
    //test longest possible input
    var toEncode =
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
    encode(toEncode, true, toEncode);
  });

  test('Shift', () {
    //compare fast to compact
    var toEncode =
        'a\na\na\na\na\na\na\na\na\na\na\na\na\na\na\na\na\na\na\na\na\na\na\na\n';
    var result = encode(toEncode, false, toEncode);

    var width = result.width;
    result = encode(toEncode, true, toEncode);

    //big difference since the fast algoritm doesn't make use of SHIFT
    expect(width, result.width + 253);
  });

  test('Digit mix compaction', () {
    //compare fast to compact
    var toEncode = 'A1A12A123A1234A12345AA1AA12AA123AA1234AA1235';
    var result = encode(toEncode, false, toEncode);

    var width = result.width;
    result = encode(toEncode, true, toEncode);

    //very good, no difference
    expect(width, result.width);
  });

  test('Compaction 1', () {
    //compare fast to compact
    var toEncode = 'AAAAAAAAAAA12AAAAAAAAA';
    var result = encode(toEncode, false, toEncode);

    var width = result.width;
    result = encode(toEncode, true, toEncode);

    //very good, no difference
    expect(width, result.width);
  });

  test('Compaction 2', () {
    //compare fast to compact
    var toEncode = 'AAAAAAAAAAA1212aaaaaaaaa';
    var result = encode(toEncode, false, toEncode);

    var width = result.width;
    result = encode(toEncode, true, toEncode);

    //very good, no difference
    expect(width, result.width);
  });

  test('Encode with func 4', () {
    var toEncode = 'ô' '123';
    var expected = '$_quietSpace$_startCodeB$_fnc4B'
        // "1"            "2"             "3"            check digit 59
        '10011100110'
        '11001110010'
        '11001011100'
        '11100011010'
        '$_stop$_quietSpace';

    var result = encode(toEncode, false, null);

    var actual = matrixToString(result);
    expect(actual, expected);

    var width = result.width;
    result = encode(toEncode, true, null);
    expect(result.width, width);
  });

  test('Encode with fncs and number in codeset A', () {
    var toEncode = '\n' 'ñ' 'ô' '1' '\n';

    var expected = '$_quietSpace$_startCodeA$_lf$_fnc1$_fnc4A'
        '10011100110'
        '$_lf'
        '10101111000'
        '$_stop$_quietSpace';

    var result = encode(toEncode, false, null);

    var actual = matrixToString(result);

    expect(actual, expected);

    var width = result.width;
    result = encode(toEncode, true, null);
    expect(result.width, width);
  });

  test('Encode switch between codesets A and B', () {
    // start with A switch to B and back to A
    testEncode(
        '\u0000ABab\u0010',
        '$_quietSpace$_startCodeA'
            // "\0"            "A"             "B"             Switch to B     "a"             "b"
            '10100001100'
            '10100011000'
            '10001011000'
            '$_switchCodeB'
            '10010110000'
            '10010000110'
            // Switch to A    "\u0010"        check digit
            '$_switchCodeA'
            '10100111100'
            '11001110100'
            '$_stop$_quietSpace');

    // start with B switch to A and back to B
    // the compact encoder encodes this shorter as STARTB,a,b,SHIFT,NUL,a,b
    testEncode(
        'ab\u0000ab',
        '$_quietSpace$_startCodeB'
            //  "a"             "b"            Switch to A     "\0"           Switch to B
            '10010110000'
            '10010000110'
            '$_switchCodeA'
            '10100001100'
            '$_switchCodeB'
            //  "a"             "b"            check digit
            '10010110000'
            '10010000110'
            '11010001110'
            '$_stop$_quietSpace');
  });

  EncodeHints forceCodeSet(String codeSet) =>
      EncodeHints()..put(EncodeHintType.forceCodeSet, codeSet);

  test('Encode with forced code set failure code set A bad character', () {
    // Lower case characters should not be accepted when the code set is forced to A.
    var toEncode = 'ASDFx0123';

    expect(
        () => writer.encode(toEncode, BarcodeFormat.code128, 0, 0,
            hints: forceCodeSet('A')),
        throwsArgumentError);
  });

  test('Encode with forced code set failure code set B bad character', () {
    var toEncode = 'ASdf\u00000123'; // \0 (ascii value 0)
    // Characters with ASCII value below 32 should not be accepted when the code set is forced to B.

    expect(
        () => writer.encode(toEncode, BarcodeFormat.code128, 0, 0,
            hints: forceCodeSet('B')),
        throwsArgumentError);
  });

  test('Encode with forced code set failure code set C bad characters non num',
      () {
    var toEncode = '123a5678';
    // Non-digit characters should not be accepted when the code set is forced to C.

    expect(
        () => writer.encode(toEncode, BarcodeFormat.code128, 0, 0,
            hints: forceCodeSet('C')),
        throwsArgumentError);
  });

  test('Encode with forced code set failure code set C bad characters fnc code',
      () {
    var toEncode = '123òa678';
    // Function codes other than 1 should not be accepted when the code set is forced to C.

    expect(
        () => writer.encode(toEncode, BarcodeFormat.code128, 0, 0,
            hints: forceCodeSet('C')),
        throwsArgumentError);
  });

  test('Encode with forced code set failure code set C wrong amount of digits',
      () {
    var toEncode = '123456789';
    // An uneven amount of digits should not be accepted when the code set is forced to C.

    expect(
        () => writer.encode(toEncode, BarcodeFormat.code128, 0, 0,
            hints: forceCodeSet('C')),
        throwsArgumentError);
  });

  test('Encode with forced code set failure code set A', () {
    var toEncode = 'AB123';
    //                          would default to B   "A"             "B"             "1"
    var expected = '$_quietSpace$_startCodeA'
        '10100011000'
        '10001011000'
        '10011100110'
        // "2"             "3"           check digit 10
        '11001110010'
        '11001011100'
        '11001000100'
        '$_stop$_quietSpace';

    var result = writer.encode(toEncode, BarcodeFormat.code128, 0, 0,
        hints: forceCodeSet('A'));

    var actual = matrixToString(result);
    expect(actual, expected);
  });

  test('Encode with forced code set failure code set B', () {
    var toEncode = '1234';
    //                          would default to C   "1"             "2"             "3"
    var expected = '$_quietSpace$_startCodeB'
        '10011100110'
        '11001110010'
        '11001011100'
        // "4"           check digit 88
        '11001001110'
        '11110010010'
        '$_stop$_quietSpace';

    var result = writer.encode(toEncode, BarcodeFormat.code128, 0, 0,
        hints: forceCodeSet('B'));

    var actual = matrixToString(result);
    expect(actual, expected);
  });
}
