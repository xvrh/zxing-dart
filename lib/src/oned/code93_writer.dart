import '../barcode_format.dart';
import '../encode_hint.dart';
import 'code93_reader.dart';
import 'one_dimensional_code_writer.dart';

/// This object renders a CODE93 code as a BitMatrix
class Code93Writer extends OneDimensionalCodeWriter {
  @override
  List<BarcodeFormat> get supportedWriteFormats => const [BarcodeFormat.code93];

  /// @param contents barcode contents to encode. It should not be encoded for extended characters.
  /// @return a `List<bool>` of horizontal pixels (false = white, true = black)
  @override
  List<bool> encodeContents(String contents, {EncodeHints? hints}) {
    contents = convertToExtended(contents);
    var length = contents.length;
    if (length > 80) {
      throw ArgumentError(
          'Requested contents should be less than 80 digits long after '
          'converting to extended encoding, but got $length');
    }

    //length of code + 2 start/stop characters + 2 checksums, each of 9 bits, plus a termination bar
    var codeWidth = (contents.length + 2 + 2) * 9 + 1;

    var result = List<bool>.filled(codeWidth, false);

    //start character (*)
    var pos = _appendPattern(result, 0, Code93Reader.asteriskEncoding);

    for (var i = 0; i < length; i++) {
      var indexInString = Code93Reader.alphabetString.indexOf(contents[i]);
      pos += _appendPattern(
          result, pos, Code93Reader.characterEncodings[indexInString]);
    }

    //add two checksums
    var check1 = _computeChecksumIndex(contents, 20);
    pos += _appendPattern(result, pos, Code93Reader.characterEncodings[check1]);

    //append the contents to reflect the first checksum added
    contents += Code93Reader.alphabetString[check1];

    var check2 = _computeChecksumIndex(contents, 15);
    pos += _appendPattern(result, pos, Code93Reader.characterEncodings[check2]);

    //end character (*)
    pos += _appendPattern(result, pos, Code93Reader.asteriskEncoding);

    //termination bar (single black bar)
    result[pos] = true;

    return result;
  }

  static int _appendPattern(List<bool> target, int pos, int a) {
    for (var i = 0; i < 9; i++) {
      var temp = a & (1 << (8 - i));
      target[pos + i] = temp != 0;
    }
    return 9;
  }

  static int _computeChecksumIndex(String contents, int maxWeight) {
    var weight = 1;
    var total = 0;

    for (var i = contents.length - 1; i >= 0; i--) {
      var indexInString = Code93Reader.alphabetString.indexOf(contents[i]);
      total += indexInString * weight;
      if (++weight > maxWeight) {
        weight = 1;
      }
    }
    return total % 47;
  }

  static String convertToExtended(String contents) {
    var length = contents.length;
    var extendedContent = StringBuffer();
    for (var i = 0; i < length; i++) {
      var character = contents.codeUnitAt(i);
      // ($)=a, (%)=b, (/)=c, (+)=d. see Code93Reader.ALPHABET_STRING
      if (character == 0) {
        // NUL: (%)U
        extendedContent.write('bU');
      } else if (character <= 26) {
        // SOH - SUB: ($)A - ($)Z
        extendedContent.write('a');
        extendedContent.writeCharCode(0x41 + character - 1);
      } else if (character <= 31) {
        // ESC - US: (%)A - (%)E
        extendedContent.write('b');
        extendedContent.writeCharCode(0x41 + character - 27);
      } else if (character == 0x20 /* ' ' */ ||
          character == 0x24 /* '$' */ ||
          character == 0x25 /* '%' */ ||
          character == 0x2B /* '+' */) {
        // space $ % +
        extendedContent.writeCharCode(character);
      } else if (character <= 0x2C /* ',' */) {
        // ! " # & ' ( ) * ,: (/)A - (/)L
        extendedContent.write('c');
        extendedContent.writeCharCode(0x41 + character - 0x21);
      } else if (character <= 0x39 /* '9' */) {
        extendedContent.writeCharCode(character);
      } else if (character == 0x3A /* ':' */) {
        // :: (/)Z
        extendedContent.write('cZ');
      } else if (character <= 0x3F /* '?' */) {
        // ; - ?: (%)F - (%)J
        extendedContent.write('b');
        extendedContent.writeCharCode(0x46 + character - 0x3B);
      } else if (character == 0x40 /* '@' */) {
        // @: (%)V
        extendedContent.write('bV');
      } else if (character <= 0x5A /* 'Z' */) {
        // A - Z
        extendedContent.writeCharCode(character);
      } else if (character <= 0x5F /* '_' */) {
        // [ - _: (%)K - (%)O
        extendedContent.write('b');
        extendedContent.writeCharCode(0x4B + character - 0x5B);
      } else if (character == 0x60 /* '`' */) {
        // `: (%)W
        extendedContent.write('bW');
      } else if (character <= 0x7A /* 'z' */) {
        // a - z: (*)A - (*)Z
        extendedContent.write('d');
        extendedContent.writeCharCode(0x41 + character - 0x61);
      } else if (character <= 127) {
        // { - DEL: (%)P - (%)T
        extendedContent.write('b');
        extendedContent.writeCharCode(0x50 + character - 0x7B);
      } else {
        throw ArgumentError(
            "Requested content contains a non-encodable character: '${contents[i]}'");
      }
    }
    return extendedContent.toString();
  }
}
