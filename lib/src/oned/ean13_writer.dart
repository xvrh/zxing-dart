import '../barcode_format.dart';
import '../encode_hint.dart';
import '../format_reader_exception.dart';
import 'ean13_reader.dart';
import 'one_dimensional_code_writer.dart';
import 'upc_ean_reader.dart';
import 'upc_ean_writer.dart';

/// This object renders an EAN13 code as a {@link BitMatrix}.
///
/// @author aripollak@gmail.com (Ari Pollak)
class EAN13Writer extends UPCEANWriter {
  static const _codeWidth = 3 + // start guard
      (7 * 6) + // left bars
      5 + // middle guard
      (7 * 6) + // right bars
      3; // end guard

  @override
  List<BarcodeFormat> get supportedWriteFormats => [BarcodeFormat.ean13];

  @override
  List<bool> encodeContents(String contents, {EncodeHints? hints}) {
    var length = contents.length;
    switch (length) {
      case 12:
        // No check digit present, calculate it and add it
        int check;
        try {
          check = UPCEANReader.getStandardUPCEANChecksum(contents);
        } on FormatReaderException catch (fe) {
          throw ArgumentError(fe);
        }
        contents += '$check';
      case 13:
        try {
          if (!UPCEANReader.checkStandardUPCEANChecksum(contents)) {
            throw ArgumentError('Contents do not pass checksum');
          }
        } on FormatReaderException catch (_) {
          throw ArgumentError('Illegal contents');
        }
      default:
        throw ArgumentError(
            'Requested contents should be 12 or 13 digits long, but got $length');
    }

    OneDimensionalCodeWriter.checkNumeric(contents);

    var firstDigit = _digit(contents, 0);
    var parities = EAN13Reader.firstDigitEncodings[firstDigit];
    var result = List.filled(_codeWidth, false);
    var pos = 0;

    pos += OneDimensionalCodeWriter.appendPattern(
        result, pos, UPCEANReader.startEndPattern, true);

    // See EAN13Reader for a description of how the first digit & left bars are encoded
    for (var i = 1; i <= 6; i++) {
      var digit = _digit(contents, i);
      if ((parities >> (6 - i) & 1) == 1) {
        digit += 10;
      }
      pos += OneDimensionalCodeWriter.appendPattern(
          result, pos, UPCEANReader.lAndGPatterns[digit], false);
    }

    pos += OneDimensionalCodeWriter.appendPattern(
        result, pos, UPCEANReader.middlePattern, false);

    for (var i = 7; i <= 12; i++) {
      var digit = _digit(contents, i);
      pos += OneDimensionalCodeWriter.appendPattern(
          result, pos, UPCEANReader.lPatterns[digit], true);
    }
    OneDimensionalCodeWriter.appendPattern(
        result, pos, UPCEANReader.startEndPattern, true);

    return result;
  }

  static int _digit(String contents, int index) =>
      contents.codeUnitAt(index) - 0x30 /* 0 */;
}
