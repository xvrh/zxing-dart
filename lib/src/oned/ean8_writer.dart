import '../barcode_format.dart';
import '../encode_hint.dart';
import '../format_reader_exception.dart';
import 'one_dimensional_code_writer.dart';
import 'upc_ean_reader.dart';
import 'upc_ean_writer.dart';

/// This object renders an EAN8 code as a {@link BitMatrix}.
///
/// @author aripollak@gmail.com (Ari Pollak)
class EAN8Writer extends UPCEANWriter {
  static const _codeWidth = 3 + // start guard
      (7 * 4) + // left bars
      5 + // middle guard
      (7 * 4) + // right bars
      3; // end guard

  @override
  List<BarcodeFormat> get supportedWriteFormats => [BarcodeFormat.ean8];

  /// @return a byte array of horizontal pixels (false = white, true = black)
  @override
  List<bool> encodeContents(String contents, {EncodeHints? hints}) {
    var length = contents.length;
    switch (length) {
      case 7:
        // No check digit present, calculate it and add it
        int check;
        try {
          check = UPCEANReader.getStandardUPCEANChecksum(contents);
        } on FormatReaderException catch (fe) {
          throw ArgumentError(fe);
        }
        contents += '$check';
      case 8:
        try {
          if (!UPCEANReader.checkStandardUPCEANChecksum(contents)) {
            throw ArgumentError('Contents do not pass checksum');
          }
        } on FormatReaderException catch (_) {
          throw ArgumentError('Illegal contents');
        }
      default:
        throw ArgumentError(
            'Requested contents should be 7 or 8 digits long, but got $length');
    }

    OneDimensionalCodeWriter.checkNumeric(contents);

    var result = List.filled(_codeWidth, false);
    var pos = 0;

    pos += OneDimensionalCodeWriter.appendPattern(
        result, pos, UPCEANReader.startEndPattern, true);

    for (var i = 0; i <= 3; i++) {
      var digit = _digit(contents, i);
      pos += OneDimensionalCodeWriter.appendPattern(
          result, pos, UPCEANReader.lPatterns[digit], false);
    }

    pos += OneDimensionalCodeWriter.appendPattern(
        result, pos, UPCEANReader.middlePattern, false);

    for (var i = 4; i <= 7; i++) {
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
