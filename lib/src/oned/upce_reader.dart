import 'dart:typed_data';
import '../barcode_format.dart';
import '../common/bit_array.dart';
import '../not_found_exception.dart';
import 'upc_ean_reader.dart';

/// <p>Implements decoding of the UPC-E format.</p>
/// <p><a href="http://www.barcodeisland.com/upce.phtml">This</a> is a great reference for
/// UPC-E information.</p>
///
/// @author Sean Owen
class UPCEReader extends UPCEANReader {
  /// The pattern that marks the middle, and end, of a UPC-E pattern.
  /// There is no "second half" to a UPC-E barcode.
  static const _middleEndPattern = [1, 1, 1, 1, 1, 1];

  // For an UPC-E barcode, the final digit is represented by the parities used
  // to encode the middle six digits, according to the table below.
  //
  //                Parity of next 6 digits
  //    Digit   0     1     2     3     4     5
  //       0    Even   Even  Even Odd  Odd   Odd
  //       1    Even   Even  Odd  Even Odd   Odd
  //       2    Even   Even  Odd  Odd  Even  Odd
  //       3    Even   Even  Odd  Odd  Odd   Even
  //       4    Even   Odd   Even Even Odd   Odd
  //       5    Even   Odd   Odd  Even Even  Odd
  //       6    Even   Odd   Odd  Odd  Even  Even
  //       7    Even   Odd   Even Odd  Even  Odd
  //       8    Even   Odd   Even Odd  Odd   Even
  //       9    Even   Odd   Odd  Even Odd   Even
  //
  // The encoding is represented by the following array, which is a bit pattern
  // using Odd = 0 and Even = 1. For example, 5 is represented by:
  //
  //              Odd Even Even Odd Odd Even
  // in binary:
  //                0    1    1   0   0    1   == 0x19
  //

  /// See {@link #L_AND_G_PATTERNS}; these values similarly represent patterns of
  /// even-odd parity encodings of digits that imply both the number system (0 or 1)
  /// used, and the check digit.
  static const numSysAndCheckDigitPatterns = [
    [0x38, 0x34, 0x32, 0x31, 0x2C, 0x26, 0x23, 0x2A, 0x29, 0x25],
    [0x07, 0x0B, 0x0D, 0x0E, 0x13, 0x19, 0x1C, 0x15, 0x16, 0x1A]
  ];

  final _decodeMiddleCounters = Int32List(4);

  @override
  int decodeMiddle(BitArray row, List<int> startRange, StringBuffer result) {
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
      result.writeCharCode(0x30 /* 0 */ + bestMatch % 10);
      for (var counter in counters) {
        rowOffset += counter;
      }
      if (bestMatch >= 10) {
        lgPatternFound |= 1 << (5 - x);
      }
    }

    _determineNumSysAndCheckDigit(result, lgPatternFound);

    return rowOffset;
  }

  @override
  List<int> decodeEnd(BitArray row, int endStart) {
    return UPCEANReader.findGuardPattern(
        row, endStart, true, _middleEndPattern);
  }

  @override
  bool checkChecksum(String s) {
    return super.checkChecksum(convertUPCEtoUPCA(s));
  }

  static void _determineNumSysAndCheckDigit(
      StringBuffer resultString, int lgPatternFound) {
    for (var numSys = 0; numSys <= 1; numSys++) {
      for (var d = 0; d < 10; d++) {
        if (lgPatternFound == numSysAndCheckDigitPatterns[numSys][d]) {
          var digits = resultString.toString();
          resultString
            ..clear()
            ..writeCharCode(0x30 /* 0 */ + numSys)
            ..write(digits)
            ..writeCharCode(0x30 /* 0 */ + d);
          return;
        }
      }
    }
    throw NotFoundException();
  }

  @override
  BarcodeFormat get barcodeFormat => BarcodeFormat.upcE;

  /// Expands a UPC-E value back into its full, equivalent UPC-A code value.
  ///
  /// @param upce UPC-E code as string of digits
  /// @return equivalent UPC-A code as string of digits
  static String convertUPCEtoUPCA(String upce) {
    var upceChars = upce.substring(1, 7);
    var result = StringBuffer();
    result.write(upce[0]);
    var lastChar = upceChars[5];
    switch (lastChar) {
      case '0':
      case '1':
      case '2':
        result.write(upceChars.substring(0, 2));
        result.write(lastChar);
        result.write('0000');
        result.write(upceChars.substring(2, 5));
      case '3':
        result.write(upceChars.substring(0, 3));
        result.write('00000');
        result.write(upceChars.substring(3, 5));
      case '4':
        result.write(upceChars.substring(0, 4));
        result.write('00000');
        result.write(upceChars[4]);
      default:
        result.write(upceChars.substring(0, 5));
        result.write('0000');
        result.write(lastChar);
    }
    // Only append check digit in conversion if supplied
    if (upce.length >= 8) {
      result.write(upce[7]);
    }
    return result.toString();
  }
}
