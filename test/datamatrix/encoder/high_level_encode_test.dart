import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zxing2/src/common/character_set_eci.dart';
import 'package:zxing2/src/datamatrix/encoder/high_level_encoder.dart';
import 'package:zxing2/src/datamatrix/encoder/minimal_encoder.dart';
import 'package:zxing2/src/datamatrix/encoder/symbol_info.dart';
import 'package:zxing2/src/datamatrix/encoder/symbol_shape_hint.dart';

final _testSymbols = [
  SymbolInfo(false, 3, 5, 8, 8, 1),
  SymbolInfo(false, 5, 7, 10, 10, 1),
  /*rect*/ SymbolInfo(true, 5, 7, 16, 6, 1),
  SymbolInfo(false, 8, 10, 12, 12, 1),
  /*rect*/ SymbolInfo(true, 10, 11, 14, 6, 2),
  SymbolInfo(false, 13, 0, 0, 0, 1),
  SymbolInfo(false, 77, 0, 0, 0, 1)
  //The last entries are fake entries to test special conditions with C40 encoding
];

void _useTestSymbols() {
  SymbolInfo.overrideSymbolSet(_testSymbols);
}

void _resetSymbols() {
  SymbolInfo.overrideSymbolSet(SymbolInfo.prodSymbols);
}

/// Tests for [HighLevelEncoder] and [MinimalEncoder]
void main() {
  test('ASCII encodation', () {
    var visualized = _encodeHighLevel('123456');
    expect(visualized, '142 164 186');

    visualized = _encodeHighLevel('123456£');
    expect(visualized, '142 164 186 235 36');

    visualized = _encodeHighLevel('30Q324343430794<OQQ');
    expect(visualized, '160 82 162 173 173 173 137 224 61 80 82 82');
  });

  test('C40 encodation basic 1', () {
    var visualized = _encodeHighLevel('AIMAIMAIM');
    expect(visualized, '230 91 11 91 11 91 11 254');
    //230 shifts to C40 encodation, 254 unlatches, "else" case
  });

  test('C40 encodation basic 2', () {
    var visualized = _encodeHighLevel('AIMAIAB');
    expect(visualized, '230 91 11 90 255 254 67 129');
    //"B" is normally encoded as "15" (one C40 value)
    //"else" case: "B" is encoded as ASCII

    visualized = _encodeHighLevel('AIMAIAb');
    expect(visualized, '66 74 78 66 74 66 99 129'); //Encoded as ASCII
    //Alternative solution:
    //assertEquals("230 91 11 90 255 254 99 129", visualized);
    //"b" is normally encoded as "Shift 3, 2" (two C40 values)
    //"else" case: "b" is encoded as ASCII

    visualized = _encodeHighLevel('AIMAIMAIMË');
    expect(visualized, '230 91 11 91 11 91 11 254 235 76');
    //Alternative solution:
    //assertEquals("230 91 11 91 11 91 11 11 9 254", visualized);
    //Expl: 230 = shift to C40, "91 11" = "AIM",
    //"11 9" = "�" = "Shift 2, UpperShift, <char>
    //"else" case

    visualized = _encodeHighLevel('AIMAIMAIMë');
    expect(visualized,
        '230 91 11 91 11 91 11 254 235 108'); //Activate when additional rectangulars are available
    //Expl: 230 = shift to C40, "91 11" = "AIM",
    //"�" in C40 encodes to: 1 30 2 11 which doesn't fit into a triplet
    //"10 243" =
    //254 = unlatch, 235 = Upper Shift, 108 = � = 0xEB/235 - 128 + 1
    //"else" case
  });

  test('C40 encodation spec example', () {
    //Example in Figure 1 in the spec
    var visualized = _encodeHighLevel('A1B2C3D4E5F6G7H8I9J0K1L2');
    expect(visualized,
        '230 88 88 40 8 107 147 59 67 126 206 78 126 144 121 35 47 254');
  });

  test('C40 encodation special cases 1', () {
    //Special tests avoiding ultra-long test strings because these tests are only used
    //with the 16x48 symbol (47 data codewords)
    _useTestSymbols();

    var visualized = _encodeHighLevel('AIMAIMAIMAIMAIMAIM',
        compareSizeToMinimalEncoder: false);
    expect(visualized, '230 91 11 91 11 91 11 91 11 91 11 91 11');
    //case "a": Unlatch is not required

    visualized = _encodeHighLevel('AIMAIMAIMAIMAIMAI',
        compareSizeToMinimalEncoder: false);
    expect(visualized, '230 91 11 91 11 91 11 91 11 91 11 90 241');
    //case "b": Add trailing shift 0 and Unlatch is not required

    visualized = _encodeHighLevel('AIMAIMAIMAIMAIMA');
    expect(visualized, '230 91 11 91 11 91 11 91 11 91 11 254 66');
    //case "c": Unlatch and write last character in ASCII

    _resetSymbols();

    visualized = _encodeHighLevel('AIMAIMAIMAIMAIMAI');
    expect(visualized, '230 91 11 91 11 91 11 91 11 91 11 254 66 74 129 237');

    visualized = _encodeHighLevel('AIMAIMAIMA');
    expect(visualized, '230 91 11 91 11 91 11 66');
    //case "d": Skip Unlatch and write last character in ASCII
  });

  test('C40 encodation special cases 2', () {
    var visualized = _encodeHighLevel('AIMAIMAIMAIMAIMAIMAI');
    expect(visualized, '230 91 11 91 11 91 11 91 11 91 11 91 11 254 66 74');
    //available > 2, rest = 2 --> unlatch and encode as ASCII
  });

  test('Text encodation', () {
    var visualized = _encodeHighLevel('aimaimaim');
    expect(visualized, '239 91 11 91 11 91 11 254');
    //239 shifts to Text encodation, 254 unlatches

    visualized = _encodeHighLevel("aimaimaim'");
    expect(visualized, '239 91 11 91 11 91 11 254 40 129');
    //assertEquals("239 91 11 91 11 91 11 7 49 254", visualized);
    //This is an alternative, but doesn't strictly follow the rules in the spec.

    visualized = _encodeHighLevel('aimaimaIm');
    expect(visualized, '239 91 11 91 11 87 218 110');

    visualized = _encodeHighLevel('aimaimaimB');
    expect(visualized, '239 91 11 91 11 91 11 254 67 129');

    visualized = _encodeHighLevel('aimaimaim{txt}\u0004');
    expect(
        visualized, '239 91 11 91 11 91 11 254 124 117 121 117 126 5 129 237');
  });

  test('X12 encodation', () {
    //238 shifts to X12 encodation, 254 unlatches

    var visualized = _encodeHighLevel('ABC>ABC123>AB');
    expect(visualized, '238 89 233 14 192 100 207 44 31 67');

    visualized = _encodeHighLevel('ABC>ABC123>ABC');
    expect(visualized, '238 89 233 14 192 100 207 44 31 254 67 68');

    visualized = _encodeHighLevel('ABC>ABC123>ABCD');
    expect(visualized, '238 89 233 14 192 100 207 44 31 96 82 254');

    visualized = _encodeHighLevel('ABC>ABC123>ABCDE');
    expect(visualized, '238 89 233 14 192 100 207 44 31 96 82 70');

    visualized = _encodeHighLevel('ABC>ABC123>ABCDEF');
    expect(
        visualized, '238 89 233 14 192 100 207 44 31 96 82 254 70 71 129 237');
  });

  test('EDIFACT encodation', () {
    //240 shifts to EDIFACT encodation

    var visualized = _encodeHighLevel('.A.C1.3.DATA.123DATA.123DATA');
    expect(visualized,
        '240 184 27 131 198 236 238 16 21 1 187 28 179 16 21 1 187 28 179 16 21 1');

    visualized = _encodeHighLevel('.A.C1.3.X.X2..');
    expect(visualized, '240 184 27 131 198 236 238 98 230 50 47 47');

    visualized = _encodeHighLevel('.A.C1.3.X.X2.');
    expect(visualized, '240 184 27 131 198 236 238 98 230 50 47 129');

    visualized = _encodeHighLevel('.A.C1.3.X.X2');
    expect(visualized, '240 184 27 131 198 236 238 98 230 50');

    visualized = _encodeHighLevel('.A.C1.3.X.X');
    expect(visualized, '240 184 27 131 198 236 238 98 230 31');

    visualized = _encodeHighLevel('.A.C1.3.X.');
    expect(visualized, '240 184 27 131 198 236 238 98 231 192');

    visualized = _encodeHighLevel('.A.C1.3.X');
    expect(visualized, '240 184 27 131 198 236 238 89');

    //Checking temporary unlatch from EDIFACT
    visualized = _encodeHighLevel(
        '.XXX.XXX.XXX.XXX.XXX.XXX.üXX.XXX.XXX.XXX.XXX.XXX.XXX');
    expect(
        visualized,
        '240 185 134 24 185 134 24 185 134 24 185 134 24 185 134 24 185 134 24'
        ' 124 47 235 125 240' //<-- this is the temporary unlatch
        ' 97 139 152 97 139 152 97 139 152 97 139 152 97 139 152 97 139 152 89 89');
  });

  test('Base256 encodation', () {
    //231 shifts to Base256 encodation

    var visualized = _encodeHighLevel('\u00ABäöüé\u00BB');
    expect(visualized, '231 44 108 59 226 126 1 104');
    visualized = _encodeHighLevel('\u00ABäöüéà\u00BB');
    expect(visualized, '231 51 108 59 226 126 1 141 254 129');
    visualized = _encodeHighLevel('\u00ABäöüéàá\u00BB');
    expect(visualized, '231 44 108 59 226 126 1 141 36 147');

    visualized = _encodeHighLevel(' 23£'); //ASCII only (for reference)
    expect(visualized, '33 153 235 36 129');

    visualized =
        _encodeHighLevel('\u00ABäöüé\u00BB 234'); //Mixed Base256 + ASCII
    expect(visualized, '231 50 108 59 226 126 1 104 33 153 53 129');

    visualized = _encodeHighLevel('\u00ABäöüé\u00BB 23£ 1234567890123456789');
    expect(
        visualized,
        '231 54 108 59 226 126 1 104 99 10 161 167 33 142 164 186 208'
        ' 220 142 164 186 208 58 129 59 209 104 254 150 45');

    visualized = _encodeHighLevel(_createBinaryMessage(20));
    expect(visualized,
        '231 44 108 59 226 126 1 141 36 5 37 187 80 230 123 17 166 60 210 103 253 150');
    visualized = _encodeHighLevel(
        _createBinaryMessage(19)); //padding necessary at the end
    expect(visualized,
        '231 63 108 59 226 126 1 141 36 5 37 187 80 230 123 17 166 60 210 103 1 129');

    visualized = _encodeHighLevel(_createBinaryMessage(276));
    expect(visualized, startsWith('231 38 219 2 208 120 20 150 35'));
    expect(visualized, endsWith('146 40 194 129'));

    visualized = _encodeHighLevel(_createBinaryMessage(277));
    expect(visualized, startsWith('231 38 220 2 208 120 20 150 35'));
    expect(visualized, endsWith('146 40 190 87'));
  });

  test('Unlatching from C40', () {
    var visualized = _encodeHighLevel('AIMAIMAIMAIMaimaimaim');
    expect(
        visualized, '230 91 11 91 11 91 11 254 66 74 78 239 91 11 91 11 91 11');
  });

  test('Unlatching from text', () {
    var visualized = _encodeHighLevel('aimaimaimaim12345678');
    expect(
        visualized, '239 91 11 91 11 91 11 91 11 254 142 164 186 208 129 237');
  });

  test('Hello world', () {
    var visualized = _encodeHighLevel('Hello World!');
    expect(visualized, '73 239 116 130 175 123 148 64 158 233 254 34');
  });

  test('Bug 1664266', () {
    //There was an exception and the encoder did not handle the unlatching from
    //EDIFACT encoding correctly

    var visualized = _encodeHighLevel('CREX-TAN:h');
    expect(visualized, '68 83 70 89 46 85 66 79 59 105');

    visualized = _encodeHighLevel('CREX-TAN:hh');
    expect(visualized, '68 83 70 89 46 85 66 79 59 105 105 129');

    visualized = _encodeHighLevel('CREX-TAN:hhh');
    expect(visualized, '68 83 70 89 46 85 66 79 59 105 105 105');
  });

  test('X12 unlatch', () {
    var visualized = _encodeHighLevel('*DTCP01');
    expect(visualized, '43 69 85 68 81 131 129 56');
  });

  test('X12 unlatch 2', () {
    var visualized = _encodeHighLevel('*DTCP0');
    expect(visualized, '238 9 10 104 141');
  });

  test('Bug 3048549', () {
    //There was an IllegalArgumentException for an illegal character here because
    //of an encoding problem of the character 0x0060 in Java source code.

    var visualized = _encodeHighLevel('fiykmj*Rh2`,e6');
    expect(visualized,
        '103 106 122 108 110 107 43 83 105 51 97 45 102 55 129 237');
  });

  test('Macro characters', () {
    var visualized =
        _encodeHighLevel('[)>\u001E05\u001D5555\u001C6666\u001E\u0004');
    //assertEquals("92 42 63 31 135 30 185 185 29 196 196 31 5 129 87 237", visualized);
    expect(visualized, '236 185 185 29 196 196 129 56');
  });

  test('Encoding with start as X12 and latch to EDIFACT in the middle', () {
    var visualized = _encodeHighLevel('*MEMANT-1F-MESTECH');
    expect(visualized, '240 168 209 77 4 229 45 196 107 77 21 53 5 12 135 192');
  });

  test('X12 and EDIFACT spec errors', () {
    //X12 encoding error with spec conform float point comparisons in lookAheadTest()
    var visualized =
        _encodeHighLevel('AAAAAAAAAAA**\u00FCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
    expect(
        visualized,
        '230 89 191 89 191 89 191 89 178 56 114 10 243 177 63 89 191 89 191 89 191 89 191 89 191 89 191 89 '
        '191 89 191 89 191 254 66 129');
    //X12 encoding error with integer comparisons in lookAheadTest()
    visualized =
        _encodeHighLevel('AAAAAAAAAAAA0+****AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
    expect(
        visualized,
        '238 89 191 89 191 89 191 89 191 254 240 194 186 170 170 160 65 4 16 65 4 16 65 4 16 65 4 16 65 4 '
        '16 65 4 16 65 4 16 65 124 129 167 62 212 107');
    //EDIFACT encoding error with spec conform float point comparisons in lookAheadTest()
    visualized =
        _encodeHighLevel('AAAAAAAAAAA++++\u00FCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
    expect(
        visualized,
        '230 89 191 89 191 89 191 254 66 66 44 44 44 44 235 125 230 89 191 89 191 89 191 89 191 89 191 89 '
        '191 89 191 89 191 89 191 89 191 254 129 17 167 62 212 107');
    //EDIFACT encoding error with integer comparisons in lookAheadTest()
    visualized =
        _encodeHighLevel('++++++++++AAa0 0++++++++++++++++++++++++++++++');
    expect(
        visualized,
        '240 174 186 235 174 186 235 174 176 65 124 98 240 194 12 43 174 186 235 174 186 235 174 186 235 '
        '174 186 235 174 186 235 174 186 235 174 186 235 173 240 129 167 62 212 107');
    visualized =
        _encodeHighLevel('AAAAAAAAAAAA*+AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
    expect(
        visualized,
        '230 89 191 89 191 89 191 89 191 7 170 64 191 89 191 89 191 89 191 89 191 89 191 89 191 89 191 89 '
        '191 89 191 66');
    visualized =
        _encodeHighLevel('AAAAAAAAAAA*0a0 *AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
    expect(
        visualized,
        '230 89 191 89 191 89 191 89 178 56 227 6 228 7 183 89 191 89 191 89 191 89 191 89 191 89 191 89 '
        '191 89 191 89 191 254 66 66');
  });

  test('Sizes', () {
    var sizes = Int32List(2);
    _encodeHighLevelSizes('A', sizes);
    expect(sizes[0], 3);
    expect(sizes[1], 3);

    _encodeHighLevelSizes('AB', sizes);
    expect(sizes[0], 3);
    expect(sizes[1], 3);

    _encodeHighLevelSizes('ABC', sizes);
    expect(sizes[0], 3);
    expect(sizes[1], 3);

    _encodeHighLevelSizes('ABCD', sizes);
    expect(sizes[0], 5);
    expect(sizes[1], 5);

    _encodeHighLevelSizes('ABCDE', sizes);
    expect(sizes[0], 5);
    expect(sizes[1], 5);

    _encodeHighLevelSizes('ABCDEF', sizes);
    expect(sizes[0], 5);
    expect(sizes[1], 5);

    _encodeHighLevelSizes('ABCDEFG', sizes);
    expect(sizes[0], 8);
    expect(sizes[1], 8);

    _encodeHighLevelSizes('ABCDEFGH', sizes);
    expect(sizes[0], 8);
    expect(sizes[1], 8);

    _encodeHighLevelSizes('ABCDEFGHI', sizes);
    expect(sizes[0], 8);
    expect(sizes[1], 8);

    _encodeHighLevelSizes('ABCDEFGHIJ', sizes);
    expect(sizes[0], 8);
    expect(sizes[1], 8);

    _encodeHighLevelSizes('a', sizes);
    expect(sizes[0], 3);
    expect(sizes[1], 3);

    _encodeHighLevelSizes('ab', sizes);
    expect(sizes[0], 3);
    expect(sizes[1], 3);

    _encodeHighLevelSizes('abc', sizes);
    expect(sizes[0], 3);
    expect(sizes[1], 3);

    _encodeHighLevelSizes('abcd', sizes);
    expect(sizes[0], 5);
    expect(sizes[1], 5);

    _encodeHighLevelSizes('abcdef', sizes);
    expect(sizes[0], 5);
    expect(sizes[1], 5);

    _encodeHighLevelSizes('abcdefg', sizes);
    expect(sizes[0], 8);
    expect(sizes[1], 8);

    _encodeHighLevelSizes('abcdefgh', sizes);
    expect(sizes[0], 8);
    expect(sizes[1], 8);

    _encodeHighLevelSizes('+', sizes);
    expect(sizes[0], 3);
    expect(sizes[1], 3);

    _encodeHighLevelSizes('++', sizes);
    expect(sizes[0], 3);
    expect(sizes[1], 3);

    _encodeHighLevelSizes('+++', sizes);
    expect(sizes[0], 3);
    expect(sizes[1], 3);

    _encodeHighLevelSizes('++++', sizes);
    expect(sizes[0], 5);
    expect(sizes[1], 5);

    _encodeHighLevelSizes('+++++', sizes);
    expect(sizes[0], 5);
    expect(sizes[1], 5);

    _encodeHighLevelSizes('++++++', sizes);
    expect(sizes[0], 8);
    expect(sizes[1], 8);

    _encodeHighLevelSizes('+++++++', sizes);
    expect(sizes[0], 8);
    expect(sizes[1], 8);

    _encodeHighLevelSizes('++++++++', sizes);
    expect(sizes[0], 8);
    expect(sizes[1], 8);

    _encodeHighLevelSizes('+++++++++', sizes);
    expect(sizes[0], 8);
    expect(sizes[1], 8);

    _encodeHighLevelSizes(
        '\u00F0\u00F0'
        'ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEF',
        sizes);
    expect(sizes[0], 114);
    expect(sizes[1], 62);
  });

  test('ECIs', () {
    var visualized = visualize(MinimalEncoder.encodeHighLevel(
        'that particularly stands out to me is \u0625\u0650'
        '\u062C\u064E\u0651\u0627\u0635 (\u02BE\u0101\u1E63) "pear", suggested to have originated from Hebrew '
        '\u05D0\u05B7\u05D2\u05B8\u05BC\u05E1 (ag\u00E1s)'));
    expect(
        visualized,
        '239 209 151 206 214 92 122 140 35 158 144 162 52 205 55 171 137 23 67 206 218 175 147 113 15 254'
        ' 116 33 241 9 231 186 14 206 64 248 144 252 159 33 41 241 27 231 83 171 53 209 35 25 134 6 42 33 35 239 184'
        ' 31 193 234 7 252 205 101 127 241 209 34 24 5 22 23 221 148 179 239 128 140 92 187 106 204 198 59 19 25 114'
        ' 248 118 36 254 231 106 196 19 239 101 27 107 69 189 112 236 156 252 16 174 125 24 10 125 116 42 129');

    visualized = visualize(MinimalEncoder.encodeHighLevel(
        'that particularly stands out to me is \u0625\u0650'
        '\u062C\u064E\u0651\u0627\u0635 (\u02BE\u0101\u1E63) "pear", suggested to have originated from Hebrew '
        '\u05D0\u05B7\u05D2\u05B8\u05BC\u05E1 (ag\u00E1s)',
        priorityCharset: CharacterSetECI.UTF8,
        fnc1: -1,
        shape: SymbolShapeHint.forceNone));
    expect(
        visualized,
        '241 27 239 209 151 206 214 92 122 140 35 158 144 162 52 205 55 171 137 23 67 206 218 175 147 113'
        ' 15 254 116 33 231 202 33 131 77 154 119 225 163 238 206 28 249 93 36 150 151 53 108 246 145 228 217 71'
        ' 199 42 33 35 239 184 31 193 234 7 252 205 101 127 241 209 34 24 5 22 23 221 148 179 239 128 140 92 187 106'
        ' 204 198 59 19 25 114 248 118 36 254 231 43 133 212 175 38 220 44 6 125 49 172 93 189 209 111 61 217 203 62'
        ' 116 42 129 1 151 46 196 91 241 137 32 182 77 227 122 18 168 63 213 108 4 154 49 199 94 244 140 35 185 80');
  });

  test('Padding', () {
    var sizes = Int32List(2);
    _encodeHighLevelSizes(
        'IS010000000000000000000000S1118058599124123S21.2.250.1.213.1.4.8 S3FIRST NAMETEST S5MS618-06'
        '-1985S713201S4LASTNAMETEST',
        sizes);
    expect(sizes[0], 86);
    expect(sizes[1], 86);
  });
}

String _createBinaryMessage(int len) {
  var sb = StringBuffer();
  sb.write('\u00ABäöüéàá-');
  for (var i = 0; i < len - 9; i++) {
    sb.write('\u00B7');
  }
  sb.write('\u00BB');
  return sb.toString();
}

void _encodeHighLevelSizes(String msg, Int32List sizes) {
  sizes[0] = HighLevelEncoder.encodeHighLevel(msg).length;
  sizes[1] = MinimalEncoder.encodeHighLevel(msg).length;
}

String _encodeHighLevel(String msg, {bool compareSizeToMinimalEncoder = true}) {
  var encoded = HighLevelEncoder.encodeHighLevel(msg);
  var encoded2 = MinimalEncoder.encodeHighLevel(msg);
  expect(!compareSizeToMinimalEncoder || encoded2.length <= encoded.length,
      isTrue);
  return visualize(encoded);
}

/// Convert a string of char codewords into a different string which lists each character
/// using its decimal value.
///
/// @param codewords the codewords
/// @return the visualized codewords
String visualize(String codewords) {
  var sb = StringBuffer();
  for (var i = 0; i < codewords.length; i++) {
    if (i > 0) {
      sb.write(' ');
    }
    sb.write(codewords.codeUnitAt(i));
  }
  return sb.toString();
}
