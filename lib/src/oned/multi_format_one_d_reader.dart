import '../barcode_format.dart';
import '../common/bit_array.dart';
import '../decode_hint.dart';
import '../not_found_exception.dart';
import '../reader_exception.dart';
import '../result.dart';
import 'coda_bar_reader.dart';
import 'code128_reader.dart';
import 'code39_reader.dart';
import 'code93_reader.dart';
import 'itf_reader.dart';
import 'multi_format_upc_ean_reader.dart';
import 'one_d_reader.dart';

/// @author dswitkin@google.com (Daniel Switkin)
/// @author Sean Owen
class MultiFormatOneDReader extends OneDReader {
  final List<OneDReader> _readers;

  MultiFormatOneDReader([DecodeHints? hints])
      : _readers = _createReaders(hints);

  static List<OneDReader> _createReaders(DecodeHints? hints) {
    var possibleFormats = hints?.get(DecodeHintType.possibleFormats);
    var useCode39CheckDigit =
        hints?.contains(DecodeHintType.assumeCode39CheckDigit) ?? false;
    var readers = <OneDReader>[];
    if (possibleFormats != null) {
      if (possibleFormats.contains(BarcodeFormat.ean13) ||
          possibleFormats.contains(BarcodeFormat.upcA) ||
          possibleFormats.contains(BarcodeFormat.ean8) ||
          possibleFormats.contains(BarcodeFormat.upcE)) {
        readers.add(MultiFormatUPCEANReader(hints));
      }
      if (possibleFormats.contains(BarcodeFormat.code39)) {
        readers.add(Code39Reader(useCode39CheckDigit));
      }
      if (possibleFormats.contains(BarcodeFormat.code93)) {
        readers.add(Code93Reader());
      }
      if (possibleFormats.contains(BarcodeFormat.code128)) {
        readers.add(Code128Reader());
      }
      if (possibleFormats.contains(BarcodeFormat.itf)) {
        readers.add(ITFReader());
      }
      if (possibleFormats.contains(BarcodeFormat.codabar)) {
        readers.add(CodaBarReader());
      }
    }
    if (readers.isEmpty) {
      readers.add(MultiFormatUPCEANReader(hints));
      readers.add(Code39Reader());
      readers.add(CodaBarReader());
      readers.add(Code93Reader());
      readers.add(Code128Reader());
      readers.add(ITFReader());
    }
    return readers;
  }

  @override
  Result decodeRow(int rowNumber, BitArray row, DecodeHints hints) {
    for (var reader in _readers) {
      try {
        return reader.decodeRow(rowNumber, row, hints);
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
