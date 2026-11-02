import 'dart:typed_data';
import '../barcode_format.dart';
import '../common/bit_array.dart';
import 'upc_ean_reader.dart';

/// <p>Implements decoding of the EAN-8 format.</p>
///
/// @author Sean Owen
class EAN8Reader extends UPCEANReader {
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

    for (var x = 0; x < 4 && rowOffset < end; x++) {
      var bestMatch = UPCEANReader.decodeDigit(
          row, counters, rowOffset, UPCEANReader.lPatterns);
      result.writeCharCode(0x30 /* 0 */ + bestMatch);
      for (var counter in counters) {
        rowOffset += counter;
      }
    }

    var middleRange = UPCEANReader.findGuardPattern(
        row, rowOffset, true, UPCEANReader.middlePattern);
    rowOffset = middleRange[1];

    for (var x = 0; x < 4 && rowOffset < end; x++) {
      var bestMatch = UPCEANReader.decodeDigit(
          row, counters, rowOffset, UPCEANReader.lPatterns);
      result.writeCharCode(0x30 /* 0 */ + bestMatch);
      for (var counter in counters) {
        rowOffset += counter;
      }
    }

    return rowOffset;
  }

  @override
  BarcodeFormat get barcodeFormat => BarcodeFormat.ean8;
}
