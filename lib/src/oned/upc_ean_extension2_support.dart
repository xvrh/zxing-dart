import 'dart:typed_data';
import '../barcode_format.dart';
import '../common/bit_array.dart';
import '../not_found_exception.dart';
import '../result.dart';
import '../result_metadata_type.dart';
import '../result_point.dart';
import 'upc_ean_reader.dart';

/// @see UPCEANExtension5Support
class UPCEANExtension2Support {
  final _decodeMiddleCounters = Int32List(4);

  Result decodeRow(int rowNumber, BitArray row, List<int> extensionStartRange) {
    var result = StringBuffer();
    var end = _decodeMiddle(row, extensionStartRange, result);

    var resultString = result.toString();
    var extensionData = _parseExtensionString(resultString);

    var extensionResult =
        Result(resultString, null, BarcodeFormat.upcEanExtension, points: [
      ResultPoint((extensionStartRange[0] + extensionStartRange[1]) / 2.0,
          rowNumber.toDouble()),
      ResultPoint(end.toDouble(), rowNumber.toDouble()),
    ]);
    if (extensionData != null) {
      extensionResult.putAllMetadata(extensionData);
    }
    return extensionResult;
  }

  int _decodeMiddle(
      BitArray row, List<int> startRange, StringBuffer resultString) {
    var counters = _decodeMiddleCounters;
    counters[0] = 0;
    counters[1] = 0;
    counters[2] = 0;
    counters[3] = 0;
    var end = row.size;
    var rowOffset = startRange[1];

    var checkParity = 0;

    for (var x = 0; x < 2 && rowOffset < end; x++) {
      var bestMatch = UPCEANReader.decodeDigit(
          row, counters, rowOffset, UPCEANReader.lAndGPatterns);
      resultString.writeCharCode(0x30 /* 0 */ + bestMatch % 10);
      for (var counter in counters) {
        rowOffset += counter;
      }
      if (bestMatch >= 10) {
        checkParity |= 1 << (1 - x);
      }
      if (x != 1) {
        // Read off separator if not last
        rowOffset = row.getNextSet(rowOffset);
        rowOffset = row.getNextUnset(rowOffset);
      }
    }

    if (resultString.length != 2) {
      throw NotFoundException();
    }

    if (int.parse(resultString.toString()) % 4 != checkParity) {
      throw NotFoundException();
    }

    return rowOffset;
  }

  /// @param raw raw content of extension
  /// @return formatted interpretation of raw content as a {@link Map} mapping
  ///  one {@link ResultMetadataType} to appropriate value, or {@code null} if not known
  static Map<ResultMetadataType, Object>? _parseExtensionString(String raw) {
    if (raw.length != 2) {
      return null;
    }
    return {ResultMetadataType.issueNumber: int.parse(raw)};
  }
}
