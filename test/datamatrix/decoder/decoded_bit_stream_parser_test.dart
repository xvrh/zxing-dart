import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zxing2/src/datamatrix/decoder/decoded_bit_stream_parser.dart';

/// @author bbrown@google.com (Brian Brown)
void main() {
  test('Ascii standard decode', () {
    // ASCII characters 0-127 are encoded as the value + 1
    var bytes = Int8List.fromList([
      'a'.codeUnitAt(0) + 1,
      'b'.codeUnitAt(0) + 1,
      'c'.codeUnitAt(0) + 1,
      'A'.codeUnitAt(0) + 1,
      'B'.codeUnitAt(0) + 1,
      'C'.codeUnitAt(0) + 1,
    ]);
    var decodedString = DecodedBitStreamParser.decode(bytes).text;
    expect(decodedString, 'abcABC');
  });

  test('Ascii double digit decode', () {
    // ASCII double digit (00 - 99) Numeric Value + 130
    var bytes = Int8List.fromList([130, 1 + 130, 98 + 130, 99 + 130]);
    var decodedString = DecodedBitStreamParser.decode(bytes).text;
    expect(decodedString, '00019899');
  });

  // TODO(bbrown): Add test cases for each encoding type
  // TODO(bbrown): Add test cases for switching encoding types
}
