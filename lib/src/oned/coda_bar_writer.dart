import '../barcode_format.dart';
import '../encode_hint.dart';
import 'coda_bar_reader.dart';
import 'one_dimensional_code_writer.dart';

/// This class renders CodaBar as `List<bool>`.
///
/// @author dsbnatut@gmail.com (Kazuki Nishiura)
class CodaBarWriter extends OneDimensionalCodeWriter {
  static const String _startEndChars = 'ABCD';
  static const String _altStartEndChars = 'TN*E';
  static const String _charsWhichAreTenLengthEachAfterDecoded = '/:+.';
  static const String _defaultGuard = 'A';

  @override
  List<BarcodeFormat> get supportedWriteFormats =>
      const [BarcodeFormat.codabar];

  @override
  List<bool> encodeContents(String contents, {EncodeHints? hints}) {
    if (contents.length < 2) {
      // Can't have a start/end guard, so tentatively add default guards
      contents = _defaultGuard + contents + _defaultGuard;
    } else {
      // Verify input and calculate decoded length.
      var firstChar = contents[0].toUpperCase();
      var lastChar = contents[contents.length - 1].toUpperCase();
      var startsNormal = _startEndChars.contains(firstChar);
      var endsNormal = _startEndChars.contains(lastChar);
      var startsAlt = _altStartEndChars.contains(firstChar);
      var endsAlt = _altStartEndChars.contains(lastChar);
      if (startsNormal) {
        if (!endsNormal) {
          throw ArgumentError('Invalid start/end guards: $contents');
        }
        // else already has valid start/end
      } else if (startsAlt) {
        if (!endsAlt) {
          throw ArgumentError('Invalid start/end guards: $contents');
        }
        // else already has valid start/end
      } else {
        // Doesn't start with a guard
        if (endsNormal || endsAlt) {
          throw ArgumentError('Invalid start/end guards: $contents');
        }
        // else doesn't end with guard either, so add a default
        contents = _defaultGuard + contents + _defaultGuard;
      }
    }

    // The start character and the end character are decoded to 10 length each.
    var resultLength = 20;
    for (var i = 1; i < contents.length - 1; i++) {
      var c = contents.codeUnitAt(i);
      if ((c >= 0x30 && c <= 0x39) || c == 0x2D /* - */ || c == 0x24 /* $ */) {
        resultLength += 9;
      } else if (_charsWhichAreTenLengthEachAfterDecoded
          .contains(contents[i])) {
        resultLength += 10;
      } else {
        throw ArgumentError("Cannot encode : '${contents[i]}'");
      }
    }
    // A blank is placed between each character.
    resultLength += contents.length - 1;

    var result = List<bool>.filled(resultLength, false);
    var position = 0;
    for (var index = 0; index < contents.length; index++) {
      var c = contents[index].toUpperCase();
      if (index == 0 || index == contents.length - 1) {
        // The start/end chars are not in the CodaBarReader.ALPHABET.
        switch (c) {
          case 'T':
            c = 'A';
          case 'N':
            c = 'B';
          case '*':
            c = 'C';
          case 'E':
            c = 'D';
        }
      }
      var code = 0;
      for (var i = 0; i < CodaBarReader.alphabetString.length; i++) {
        // Found any, because I checked above.
        if (c == CodaBarReader.alphabetString[i]) {
          code = CodaBarReader.characterEncodings[i];
          break;
        }
      }
      var color = true;
      var counter = 0;
      var bit = 0;
      while (bit < 7) {
        // A character consists of 7 digit.
        result[position] = color;
        position++;
        if (((code >> (6 - bit)) & 1) == 0 || counter == 1) {
          color = !color; // Flip the color.
          bit++;
          counter = 0;
        } else {
          counter++;
        }
      }
      if (index < contents.length - 1) {
        result[position] = false;
        position++;
      }
    }
    return result;
  }
}
