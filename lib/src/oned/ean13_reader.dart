import 'dart:typed_data';
import '../barcode_format.dart';
import '../common/bit_array.dart';
import '../not_found_exception.dart';
import 'upc_ean_reader.dart';

/// <p>Implements decoding of the EAN-13 format.</p>
///
/// @author dswitkin@google.com (Daniel Switkin)
/// @author Sean Owen
/// @author alasdair@google.com (Alasdair Mackintosh)
class EAN13Reader extends UPCEANReader {
  // For an EAN-13 barcode, the first digit is represented by the parities used
  // to encode the next six digits, according to the table below. For example,
  // if the barcode is 5 123456 789012 then the value of the first digit is
  // signified by using odd for '1', even for '2', even for '3', odd for '4',
  // odd for '5', and even for '6'. See http://en.wikipedia.org/wiki/EAN-13
  //
  //                Parity of next 6 digits
  //    Digit   0     1     2     3     4     5
  //       0    Odd   Odd   Odd   Odd   Odd   Odd
  //       1    Odd   Odd   Even  Odd   Even  Even
  //       2    Odd   Odd   Even  Even  Odd   Even
  //       3    Odd   Odd   Even  Even  Even  Odd
  //       4    Odd   Even  Odd   Odd   Even  Even
  //       5    Odd   Even  Even  Odd   Odd   Even
  //       6    Odd   Even  Even  Even  Odd   Odd
  //       7    Odd   Even  Odd   Even  Odd   Even
  //       8    Odd   Even  Odd   Even  Even  Odd
  //       9    Odd   Even  Even  Odd   Even  Odd
  //
  // Note that the encoding for '0' uses the same parity as a UPC barcode. Hence
  // a UPC barcode can be converted to an EAN-13 barcode by prepending a 0.
  //
  // The encoding is represented by the following array, which is a bit pattern
  // using Odd = 0 and Even = 1. For example, 5 is represented by:
  //
  //              Odd Even Even Odd Odd Even
  // in binary:
  //                0    1    1   0   0    1   == 0x19
  //
  static const firstDigitEncodings = [
    0x00, 0x0B, 0x0D, 0xE, 0x13, 0x19, 0x1C, 0x15, 0x16, 0x1A //
  ];

  final _decodeMiddleCounters = Int32List(4);

  @override
  int decodeMiddle(
      BitArray row, List<int> startRange, StringBuffer resultString) {
    var counters = _decodeMiddleCounters;
    counters[0] = 0;
    counters[1] = 0;
    counters[2] = 0;
    counters[3] = 0;
    var end = row.size;
    var rowOffset = startRange[1];

    var lgPatternFound = 0;

    for (var x = 0; x < 6 && rowOffset < end; x++) {
      var bestMatch = UPCEANReader.decodeDigit(
          row, counters, rowOffset, UPCEANReader.lAndGPatterns);
      resultString.writeCharCode(0x30 /* 0 */ + bestMatch % 10);
      for (var counter in counters) {
        rowOffset += counter;
      }
      if (bestMatch >= 10) {
        lgPatternFound |= 1 << (5 - x);
      }
    }

    _determineFirstDigit(resultString, lgPatternFound);

    var middleRange = UPCEANReader.findGuardPattern(
        row, rowOffset, true, UPCEANReader.middlePattern);
    rowOffset = middleRange[1];

    for (var x = 0; x < 6 && rowOffset < end; x++) {
      var bestMatch = UPCEANReader.decodeDigit(
          row, counters, rowOffset, UPCEANReader.lPatterns);
      resultString.writeCharCode(0x30 /* 0 */ + bestMatch);
      for (var counter in counters) {
        rowOffset += counter;
      }
    }

    return rowOffset;
  }

  @override
  BarcodeFormat get barcodeFormat => BarcodeFormat.ean13;

  /// Based on pattern of odd-even ('L' and 'G') patterns used to encoded the explicitly-encoded
  /// digits in a barcode, determines the implicitly encoded first digit and adds it to the
  /// result string.
  ///
  /// @param resultString string to insert decoded first digit into
  /// @param lgPatternFound int whose bits indicates the pattern of odd/even L/G patterns used to
  ///  encode digits
  /// @throws NotFoundException if first digit cannot be determined
  static void _determineFirstDigit(
      StringBuffer resultString, int lgPatternFound) {
    for (var d = 0; d < 10; d++) {
      if (lgPatternFound == firstDigitEncodings[d]) {
        var digits = resultString.toString();
        resultString
          ..clear()
          ..writeCharCode(0x30 /* 0 */ + d)
          ..write(digits);
        return;
      }
    }
    throw NotFoundException();
  }
}
