import '../barcode_format.dart';
import '../encode_hint.dart';
import '../format_reader_exception.dart';
import 'one_dimensional_code_writer.dart';
import 'upc_ean_reader.dart';
import 'upc_ean_writer.dart';
import 'upce_reader.dart';

/// This object renders an UPC-E code as a {@link BitMatrix}.
///
/// @author 0979097955s@gmail.com (RX)
class UPCEWriter extends UPCEANWriter {
  static const _codeWidth = 3 + // start guard
      (7 * 6) + // bars
      6; // end guard

  @override
  List<BarcodeFormat> get supportedWriteFormats => [BarcodeFormat.upcE];

  @override
  List<bool> encodeContents(String contents, {EncodeHints? hints}) {
    var length = contents.length;
    switch (length) {
      case 7:
        // No check digit present, calculate it and add it
        int check;
        try {
          check = UPCEANReader.getStandardUPCEANChecksum(
              UPCEReader.convertUPCEtoUPCA(contents));
        } on FormatReaderException catch (fe) {
          throw ArgumentError(fe);
        }
        contents += '$check';
      case 8:
        try {
          if (!UPCEANReader.checkStandardUPCEANChecksum(
              UPCEReader.convertUPCEtoUPCA(contents))) {
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

    var firstDigit = _digit(contents, 0);
    if (firstDigit != 0 && firstDigit != 1) {
      throw ArgumentError('Number system must be 0 or 1');
    }

    var checkDigit = _digit(contents, 7);
    var parities =
        UPCEReader.numSysAndCheckDigitPatterns[firstDigit][checkDigit];
    var result = List.filled(_codeWidth, false);

    var pos = OneDimensionalCodeWriter.appendPattern(
        result, 0, UPCEANReader.startEndPattern, true);

    for (var i = 1; i <= 6; i++) {
      var digit = _digit(contents, i);
      if ((parities >> (6 - i) & 1) == 1) {
        digit += 10;
      }
      pos += OneDimensionalCodeWriter.appendPattern(
          result, pos, UPCEANReader.lAndGPatterns[digit], false);
    }

    OneDimensionalCodeWriter.appendPattern(
        result, pos, UPCEANReader.endPattern, false);

    return result;
  }

  static int _digit(String contents, int index) =>
      contents.codeUnitAt(index) - 0x30 /* 0 */;
}
