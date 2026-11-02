import 'dart:typed_data';
import '../barcode_format.dart';
import '../encode_hint.dart';
import 'code39_reader.dart';
import 'one_dimensional_code_writer.dart';

/// This object renders a CODE39 code as a {@link BitMatrix}.
///
/// @author erik.barbara@gmail.com (Erik Barbara)
class Code39Writer extends OneDimensionalCodeWriter {
  @override
  List<BarcodeFormat> get supportedWriteFormats => const [BarcodeFormat.code39];

  @override
  List<bool> encodeContents(String contents, {EncodeHints? hints}) {
    var length = contents.length;
    if (length > 80) {
      throw ArgumentError(
          'Requested contents should be less than 80 digits long, but got $length');
    }

    for (var i = 0; i < length; i++) {
      var indexInString = Code39Reader.alphabetString.indexOf(contents[i]);
      if (indexInString < 0) {
        contents = _tryToConvertToExtendedMode(contents);
        length = contents.length;
        if (length > 80) {
          throw ArgumentError(
              'Requested contents should be less than 80 digits long, but got '
              '$length (extended full ASCII mode)');
        }
        break;
      }
    }

    var widths = Int32List(9);
    var codeWidth = 24 + 1 + (13 * length);
    var result = List<bool>.filled(codeWidth, false);
    _toIntArray(Code39Reader.asteriskEncoding, widths);
    var pos = OneDimensionalCodeWriter.appendPattern(result, 0, widths, true);
    var narrowWhite = const [1];
    pos +=
        OneDimensionalCodeWriter.appendPattern(result, pos, narrowWhite, false);
    //append next character to byte matrix
    for (var i = 0; i < length; i++) {
      var indexInString = Code39Reader.alphabetString.indexOf(contents[i]);
      _toIntArray(Code39Reader.characterEncodings[indexInString], widths);
      pos += OneDimensionalCodeWriter.appendPattern(result, pos, widths, true);
      pos += OneDimensionalCodeWriter.appendPattern(
          result, pos, narrowWhite, false);
    }
    _toIntArray(Code39Reader.asteriskEncoding, widths);
    OneDimensionalCodeWriter.appendPattern(result, pos, widths, true);
    return result;
  }

  static void _toIntArray(int a, List<int> toReturn) {
    for (var i = 0; i < 9; i++) {
      var temp = a & (1 << (8 - i));
      toReturn[i] = temp == 0 ? 1 : 2;
    }
  }

  static String _tryToConvertToExtendedMode(String contents) {
    var length = contents.length;
    var extendedContent = StringBuffer();
    for (var i = 0; i < length; i++) {
      var character = contents.codeUnitAt(i);
      switch (character) {
        case 0x00:
          extendedContent.write('%U');
        case 0x20: // ' '
        case 0x2D: // '-'
        case 0x2E: // '.'
          extendedContent.writeCharCode(character);
        case 0x40: // '@'
          extendedContent.write('%V');
        case 0x60: // '`'
          extendedContent.write('%W');
        default:
          if (character <= 26) {
            extendedContent.write(r'$');
            extendedContent.writeCharCode(0x41 + (character - 1));
          } else if (character < 0x20) {
            extendedContent.write('%');
            extendedContent.writeCharCode(0x41 + (character - 27));
          } else if (character <= 0x2C /* ',' */ ||
              character == 0x2F /* '/' */ ||
              character == 0x3A /* ':' */) {
            extendedContent.write('/');
            extendedContent.writeCharCode(0x41 + (character - 33));
          } else if (character <= 0x39 /* '9' */) {
            extendedContent.writeCharCode(0x30 + (character - 48));
          } else if (character <= 0x3F /* '?' */) {
            extendedContent.write('%');
            extendedContent.writeCharCode(0x46 + (character - 59));
          } else if (character <= 0x5A /* 'Z' */) {
            extendedContent.writeCharCode(0x41 + (character - 65));
          } else if (character <= 0x5F /* '_' */) {
            extendedContent.write('%');
            extendedContent.writeCharCode(0x4B + (character - 91));
          } else if (character <= 0x7A /* 'z' */) {
            extendedContent.write('+');
            extendedContent.writeCharCode(0x41 + (character - 97));
          } else if (character <= 127) {
            extendedContent.write('%');
            extendedContent.writeCharCode(0x50 + (character - 123));
          } else {
            throw ArgumentError(
                "Requested content contains a non-encodable character: '${contents[i]}'");
          }
      }
    }

    return extendedContent.toString();
  }
}
