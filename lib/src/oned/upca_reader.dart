import '../barcode_format.dart';
import '../binary_bitmap.dart';
import '../common/bit_array.dart';
import '../decode_hint.dart';
import '../format_reader_exception.dart';
import '../result.dart';
import 'ean13_reader.dart';
import 'upc_ean_reader.dart';

/// <p>Implements decoding of the UPC-A format.</p>
///
/// @author dswitkin@google.com (Daniel Switkin)
/// @author Sean Owen
class UPCAReader extends UPCEANReader {
  final UPCEANReader _ean13Reader = EAN13Reader();

  @override
  Result decodeRowWithStartGuard(int rowNumber, BitArray row,
      List<int> startGuardRange, DecodeHints hints) {
    return _maybeReturnResult(_ean13Reader.decodeRowWithStartGuard(
        rowNumber, row, startGuardRange, hints));
  }

  @override
  Result decodeRow(int rowNumber, BitArray row, DecodeHints hints) {
    return _maybeReturnResult(_ean13Reader.decodeRow(rowNumber, row, hints));
  }

  @override
  Result decode(BinaryBitmap image, {DecodeHints? hints}) {
    return _maybeReturnResult(_ean13Reader.decode(image, hints: hints));
  }

  @override
  BarcodeFormat get barcodeFormat => BarcodeFormat.upcA;

  @override
  int decodeMiddle(
      BitArray row, List<int> startRange, StringBuffer resultString) {
    return _ean13Reader.decodeMiddle(row, startRange, resultString);
  }

  static Result _maybeReturnResult(Result result) {
    var text = result.text;
    if (text.startsWith('0')) {
      var upcaResult = Result(text.substring(1), null, BarcodeFormat.upcA,
          points: result.resultPoints);
      upcaResult.putAllMetadata(result.resultMetadata);
      return upcaResult;
    } else {
      throw FormatReaderException();
    }
  }
}
