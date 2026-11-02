import '../barcode_format.dart';
import '../common/bit_array.dart';
import '../decode_hint.dart';
import '../not_found_exception.dart';
import '../reader_exception.dart';
import '../result.dart';
import 'ean13_reader.dart';
import 'ean8_reader.dart';
import 'one_d_reader.dart';
import 'upc_ean_reader.dart';
import 'upca_reader.dart';
import 'upce_reader.dart';

/// <p>A reader that can read all available UPC/EAN formats. If a caller wants to try to
/// read all such formats, it is most efficient to use this implementation rather than invoke
/// individual readers.</p>
///
/// @author Sean Owen
class MultiFormatUPCEANReader extends OneDReader {
  final List<UPCEANReader> _readers;

  MultiFormatUPCEANReader([DecodeHints? hints])
      : _readers = _createReaders(hints);

  static List<UPCEANReader> _createReaders(DecodeHints? hints) {
    var possibleFormats = hints?.get(DecodeHintType.possibleFormats);
    var readers = <UPCEANReader>[];
    if (possibleFormats != null) {
      if (possibleFormats.contains(BarcodeFormat.ean13)) {
        readers.add(EAN13Reader());
      } else if (possibleFormats.contains(BarcodeFormat.upcA)) {
        readers.add(UPCAReader());
      }
      if (possibleFormats.contains(BarcodeFormat.ean8)) {
        readers.add(EAN8Reader());
      }
      if (possibleFormats.contains(BarcodeFormat.upcE)) {
        readers.add(UPCEReader());
      }
    }
    if (readers.isEmpty) {
      readers.add(EAN13Reader());
      // UPC-A is covered by EAN-13
      readers.add(EAN8Reader());
      readers.add(UPCEReader());
    }
    return readers;
  }

  @override
  Result decodeRow(int rowNumber, BitArray row, DecodeHints hints) {
    // Compute this location once and reuse it on multiple implementations
    var startGuardPattern = UPCEANReader.findStartGuardPattern(row);
    for (var reader in _readers) {
      try {
        var result = reader.decodeRowWithStartGuard(
            rowNumber, row, startGuardPattern, hints);
        // Special case: a 12-digit code encoded in UPC-A is identical to a "0"
        // followed by those 12 digits encoded as EAN-13. Each will recognize such a code,
        // UPC-A as a 12-digit string and EAN-13 as a 13-digit string starting with "0".
        // Individually these are correct and their readers will both read such a code
        // and correctly call it EAN-13, or UPC-A, respectively.
        //
        // In this case, if we've been looking for both types, we'd like to call it
        // a UPC-A code. But for efficiency we only run the EAN-13 decoder to also read
        // UPC-A. So we special case it here, and convert an EAN-13 result to a UPC-A
        // result if appropriate.
        //
        // But, don't return UPC-A if UPC-A was not a requested format!
        var ean13MayBeUPCA =
            result.format == BarcodeFormat.ean13 && result.text.startsWith('0');
        var possibleFormats = hints.get(DecodeHintType.possibleFormats);
        var canReturnUPCA = possibleFormats == null ||
            possibleFormats.contains(BarcodeFormat.upcA);

        if (ean13MayBeUPCA && canReturnUPCA) {
          // Transfer the metadata across
          var resultUPCA = Result(
              result.text.substring(1), result.rawBytes, BarcodeFormat.upcA,
              points: result.resultPoints);
          resultUPCA.putAllMetadata(result.resultMetadata);
          return resultUPCA;
        }
        return result;
      } on ReaderException catch (_) {
        // continue
      }
    }

    throw NotFoundException();
  }

  @override
  void reset() {
    for (var reader in _readers) {
      reader.reset();
    }
  }
}
