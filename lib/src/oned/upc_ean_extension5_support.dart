import 'dart:typed_data';
import '../barcode_format.dart';
import '../common/bit_array.dart';
import '../not_found_exception.dart';
import '../result.dart';
import '../result_metadata_type.dart';
import '../result_point.dart';
import 'upc_ean_reader.dart';

/// @see UPCEANExtension2Support
class UPCEANExtension5Support {
  static const _checkDigitEncodings = [
    0x18, 0x14, 0x12, 0x11, 0x0C, 0x06, 0x03, 0x0A, 0x09, 0x05 //
  ];

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

    var lgPatternFound = 0;

    for (var x = 0; x < 5 && rowOffset < end; x++) {
      var bestMatch = UPCEANReader.decodeDigit(
          row, counters, rowOffset, UPCEANReader.lAndGPatterns);
      resultString.writeCharCode(0x30 /* 0 */ + bestMatch % 10);
      for (var counter in counters) {
        rowOffset += counter;
      }
      if (bestMatch >= 10) {
        lgPatternFound |= 1 << (4 - x);
      }
      if (x != 4) {
        // Read off separator if not last
        rowOffset = row.getNextSet(rowOffset);
        rowOffset = row.getNextUnset(rowOffset);
      }
    }

    if (resultString.length != 5) {
      throw NotFoundException();
    }

    var checkDigit = _determineCheckDigit(lgPatternFound);
    if (_extensionChecksum(resultString.toString()) != checkDigit) {
      throw NotFoundException();
    }

    return rowOffset;
  }

  static int _extensionChecksum(String s) {
    var length = s.length;
    var sum = 0;
    for (var i = length - 2; i >= 0; i -= 2) {
      sum += s.codeUnitAt(i) - 0x30 /* 0 */;
    }
    sum *= 3;
    for (var i = length - 1; i >= 0; i -= 2) {
      sum += s.codeUnitAt(i) - 0x30 /* 0 */;
    }
    sum *= 3;
    return sum % 10;
  }

  static int _determineCheckDigit(int lgPatternFound) {
    for (var d = 0; d < 10; d++) {
      if (lgPatternFound == _checkDigitEncodings[d]) {
        return d;
      }
    }
    throw NotFoundException();
  }

  /// @param raw raw content of extension
  /// @return formatted interpretation of raw content as a {@link Map} mapping
  ///  one {@link ResultMetadataType} to appropriate value, or {@code null} if not known
  static Map<ResultMetadataType, Object>? _parseExtensionString(String raw) {
    if (raw.length != 5) {
      return null;
    }
    var value = _parseExtension5String(raw);
    if (value == null) {
      return null;
    }
    return {ResultMetadataType.suggestedPrice: value};
  }

  static String? _parseExtension5String(String raw) {
    String currency;
    switch (raw[0]) {
      case '0':
        currency = '£';
      case '5':
        currency = r'$';
      case '9':
        // Reference: http://www.jollytech.com
        switch (raw) {
          case '90000':
            // No suggested retail price
            return null;
          case '99991':
            // Complementary
            return '0.00';
          case '99990':
            return 'Used';
        }
        // Otherwise... unknown currency?
        currency = '';
      default:
        currency = '';
    }
    var rawAmount = int.parse(raw.substring(1));
    var unitsString = '${rawAmount ~/ 100}';
    var hundredths = rawAmount % 100;
    var hundredthsString = hundredths < 10 ? '0$hundredths' : '$hundredths';
    return '$currency$unitsString.$hundredthsString';
  }
}
