import 'package:test/test.dart';
import 'debug_placement.dart';

/// Tests the DataMatrix placement algorithm.
void main() {
  test('Placement', () {
    var codewords = _unvisualize(
        '66 74 78 66 74 78 129 56 35 102 192 96 226 100 156 1 107 221'); //"AIMAIM" encoded
    var placement = DebugPlacement(codewords, 12, 12);
    placement.place();
    var expected = [
      '011100001111',
      '001010101000',
      '010001010100',
      '001010100010',
      '000111000100',
      '011000010100',
      '000100001101',
      '011000010000',
      '001100001101',
      '100010010111',
      '011101011010',
      '001011001010',
    ];
    var actual = placement.toBitFieldStringArray();
    for (var i = 0; i < actual.length; i++) {
      expect(actual[i], expected[i], reason: 'Row $i');
    }
  });
}

String _unvisualize(String visualized) {
  var sb = StringBuffer();
  for (var token in visualized.split(' ')) {
    sb.writeCharCode(int.parse(token));
  }
  return sb.toString();
}
