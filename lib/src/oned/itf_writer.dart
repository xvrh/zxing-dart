import 'dart:typed_data';
import '../barcode_format.dart';
import '../encode_hint.dart';
import 'one_dimensional_code_writer.dart';

/// This object renders a ITF code as a {@link BitMatrix}.
///
/// @author erik.barbara@gmail.com (Erik Barbara)
class ITFWriter extends OneDimensionalCodeWriter {
  static const List<int> _startPattern = [1, 1, 1, 1];
  static const List<int> _endPattern = [3, 1, 1];

  static const int _wide = 3; // Pixel width of a 3x wide line
  static const int _narrow = 1; // Pixed width of a narrow line

  // See ITFReader.PATTERNS

  static const List<List<int>> _patterns = [
    [_narrow, _narrow, _wide, _wide, _narrow], // 0
    [_wide, _narrow, _narrow, _narrow, _wide], // 1
    [_narrow, _wide, _narrow, _narrow, _wide], // 2
    [_wide, _wide, _narrow, _narrow, _narrow], // 3
    [_narrow, _narrow, _wide, _narrow, _wide], // 4
    [_wide, _narrow, _wide, _narrow, _narrow], // 5
    [_narrow, _wide, _wide, _narrow, _narrow], // 6
    [_narrow, _narrow, _narrow, _wide, _wide], // 7
    [_wide, _narrow, _narrow, _wide, _narrow], // 8
    [_narrow, _wide, _narrow, _wide, _narrow], // 9
  ];

  @override
  List<BarcodeFormat> get supportedWriteFormats => const [BarcodeFormat.itf];

  @override
  List<bool> encodeContents(String contents, {EncodeHints? hints}) {
    var length = contents.length;
    if (length % 2 != 0) {
      throw ArgumentError('The length of the input should be even');
    }
    if (length > 80) {
      throw ArgumentError(
          'Requested contents should be less than 80 digits long, but got $length');
    }

    OneDimensionalCodeWriter.checkNumeric(contents);

    var result = List<bool>.filled(9 + 9 * length, false);
    var pos =
        OneDimensionalCodeWriter.appendPattern(result, 0, _startPattern, true);
    for (var i = 0; i < length; i += 2) {
      var one = contents.codeUnitAt(i) - 0x30;
      var two = contents.codeUnitAt(i + 1) - 0x30;
      var encoding = Int32List(10);
      for (var j = 0; j < 5; j++) {
        encoding[2 * j] = _patterns[one][j];
        encoding[2 * j + 1] = _patterns[two][j];
      }
      pos +=
          OneDimensionalCodeWriter.appendPattern(result, pos, encoding, true);
    }
    OneDimensionalCodeWriter.appendPattern(result, pos, _endPattern, true);

    return result;
  }
}
