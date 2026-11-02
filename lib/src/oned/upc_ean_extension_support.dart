import '../common/bit_array.dart';
import '../reader_exception.dart';
import '../result.dart';
import 'upc_ean_extension2_support.dart';
import 'upc_ean_extension5_support.dart';
import 'upc_ean_reader.dart';

class UPCEANExtensionSupport {
  static const _extensionStartPattern = [1, 1, 2];

  final _twoSupport = UPCEANExtension2Support();
  final _fiveSupport = UPCEANExtension5Support();

  Result decodeRow(int rowNumber, BitArray row, int rowOffset) {
    var extensionStartRange = UPCEANReader.findGuardPattern(
        row, rowOffset, false, _extensionStartPattern);
    try {
      return _fiveSupport.decodeRow(rowNumber, row, extensionStartRange);
    } on ReaderException catch (_) {
      return _twoSupport.decodeRow(rowNumber, row, extensionStartRange);
    }
  }
}
