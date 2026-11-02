import 'dart:typed_data';
import '../barcode_format.dart';
import '../checksum_exception.dart';
import '../common/bit_array.dart';
import '../decode_hint.dart';
import '../format_reader_exception.dart';
import '../not_found_exception.dart';
import '../reader_exception.dart';
import '../result.dart';
import '../result_metadata_type.dart';
import '../result_point.dart';
import 'ean_manufacturer_org_support.dart';
import 'one_d_reader.dart';
import 'upc_ean_extension_support.dart';

/// <p>Encapsulates functionality and implementation that is common to UPC and EAN families
/// of one-dimensional barcodes.</p>
///
/// @author dswitkin@google.com (Daniel Switkin)
/// @author Sean Owen
/// @author alasdair@google.com (Alasdair Mackintosh)
abstract class UPCEANReader extends OneDReader {
  // These two values are critical for determining how permissive the decoding will be.
  // We've arrived at these values through a lot of trial and error. Setting them any higher
  // lets false positives creep in quickly.
  static const double _maxAvgVariance = 0.48;
  static const double _maxIndividualVariance = 0.7;

  /// Start/end guard pattern.
  static const startEndPattern = [1, 1, 1];

  /// Pattern marking the middle of a UPC/EAN pattern, separating the two halves.
  static const middlePattern = [1, 1, 1, 1, 1];

  /// end guard pattern.
  static const endPattern = [1, 1, 1, 1, 1, 1];

  /// "Odd", or "L" patterns used to encode UPC/EAN digits.
  static const lPatterns = [
    [3, 2, 1, 1], // 0
    [2, 2, 2, 1], // 1
    [2, 1, 2, 2], // 2
    [1, 4, 1, 1], // 3
    [1, 1, 3, 2], // 4
    [1, 2, 3, 1], // 5
    [1, 1, 1, 4], // 6
    [1, 3, 1, 2], // 7
    [1, 2, 1, 3], // 8
    [3, 1, 1, 2], // 9
  ];

  /// As above but also including the "even", or "G" patterns used to encode UPC/EAN digits.
  static final List<List<int>> lAndGPatterns = [
    ...lPatterns,
    for (var widths in lPatterns) widths.reversed.toList(),
  ];

  final _extensionReader = UPCEANExtensionSupport();
  final _eanManSupport = EANManufacturerOrgSupport();

  static List<int> findStartGuardPattern(BitArray row) {
    var foundStart = false;
    List<int>? startRange;
    var nextStart = 0;
    var counters = Int32List(startEndPattern.length);
    while (!foundStart) {
      counters.fillRange(0, startEndPattern.length, 0);
      startRange =
          findGuardPattern(row, nextStart, false, startEndPattern, counters);
      var start = startRange[0];
      nextStart = startRange[1];
      // Make sure there is a quiet zone at least as big as the start pattern before the barcode.
      // If this check would run off the left edge of the image, do not accept this barcode,
      // as it is very likely to be a false positive.
      var quietStart = start - (nextStart - start);
      if (quietStart >= 0) {
        foundStart = row.isRange(quietStart, start, false);
      }
    }
    return startRange!;
  }

  @override
  Result decodeRow(int rowNumber, BitArray row, DecodeHints hints) {
    return decodeRowWithStartGuard(
        rowNumber, row, findStartGuardPattern(row), hints);
  }

  /// <p>Like {@link #decodeRow(int, BitArray, Map)}, but
  /// allows caller to inform method about where the UPC/EAN start pattern is
  /// found. This allows this to be computed once and reused across many implementations.</p>
  ///
  /// @param rowNumber row index into the image
  /// @param row encoding of the row of the barcode image
  /// @param startGuardRange start/end column where the opening start pattern was found
  /// @param hints optional hints that influence decoding
  /// @return {@link Result} encapsulating the result of decoding a barcode in the row
  /// @throws NotFoundException if no potential barcode is found
  /// @throws ChecksumException if a potential barcode is found but does not pass its checksum
  /// @throws FormatReaderException if a potential barcode is found but format is invalid
  Result decodeRowWithStartGuard(int rowNumber, BitArray row,
      List<int> startGuardRange, DecodeHints hints) {
    var resultPointCallback = hints.get(DecodeHintType.needResultPointCallback);
    var symbologyIdentifier = 0;

    if (resultPointCallback != null) {
      resultPointCallback(ResultPoint(
          (startGuardRange[0] + startGuardRange[1]) / 2.0,
          rowNumber.toDouble()));
    }

    var result = StringBuffer();
    var endStart = decodeMiddle(row, startGuardRange, result);

    if (resultPointCallback != null) {
      resultPointCallback(
          ResultPoint(endStart.toDouble(), rowNumber.toDouble()));
    }

    var endRange = decodeEnd(row, endStart);

    if (resultPointCallback != null) {
      resultPointCallback(
          ResultPoint((endRange[0] + endRange[1]) / 2.0, rowNumber.toDouble()));
    }

    // Make sure there is a quiet zone at least as big as the end pattern after the barcode. The
    // spec might want more whitespace, but in practice this is the maximum we can count on.
    var end = endRange[1];
    var quietEnd = end + (end - endRange[0]);
    if (quietEnd >= row.size || !row.isRange(end, quietEnd, false)) {
      throw NotFoundException();
    }

    var resultString = result.toString();
    // UPC/EAN should never be less than 8 chars anyway
    if (resultString.length < 8) {
      throw FormatReaderException();
    }
    if (!checkChecksum(resultString)) {
      throw ChecksumException('UPC/EAN checksum failed');
    }

    var left = (startGuardRange[1] + startGuardRange[0]) / 2.0;
    var right = (endRange[1] + endRange[0]) / 2.0;
    var format = barcodeFormat;
    var decodeResult = Result(
        resultString,
        null, // no natural byte representation for these barcodes
        format,
        points: [
          ResultPoint(left, rowNumber.toDouble()),
          ResultPoint(right, rowNumber.toDouble()),
        ]);

    var extensionLength = 0;

    try {
      var extensionResult =
          _extensionReader.decodeRow(rowNumber, row, endRange[1]);
      decodeResult.putMetadata(
          ResultMetadataType.upcEanExtension, extensionResult.text);
      decodeResult.putAllMetadata(extensionResult.resultMetadata);
      decodeResult.addResultPoints(extensionResult.resultPoints);
      extensionLength = extensionResult.text.length;
    } on ReaderException catch (_) {
      // continue
    }

    var allowedExtensions = hints.get(DecodeHintType.allowedEanExtensions);
    if (allowedExtensions != null) {
      var valid = false;
      for (var length in allowedExtensions) {
        if (extensionLength == length) {
          valid = true;
          break;
        }
      }
      if (!valid) {
        throw NotFoundException();
      }
    }

    if (format == BarcodeFormat.ean13 || format == BarcodeFormat.upcA) {
      var countryID = _eanManSupport.lookupCountryIdentifier(resultString);
      if (countryID != null) {
        decodeResult.putMetadata(ResultMetadataType.possibleCountry, countryID);
      }
    }
    if (format == BarcodeFormat.ean8) {
      symbologyIdentifier = 4;
    }

    decodeResult.putMetadata(
        ResultMetadataType.symbologyIdentifier, ']E$symbologyIdentifier');

    return decodeResult;
  }

  /// @param s string of digits to check
  /// @return {@link #checkStandardUPCEANChecksum(CharSequence)}
  /// @throws FormatReaderException if the string does not contain only digits
  bool checkChecksum(String s) {
    return checkStandardUPCEANChecksum(s);
  }

  /// Computes the UPC/EAN checksum on a string of digits, and reports
  /// whether the checksum is correct or not.
  ///
  /// @param s string of digits to check
  /// @return true iff string of digits passes the UPC/EAN checksum algorithm
  /// @throws FormatReaderException if the string does not contain only digits
  static bool checkStandardUPCEANChecksum(String s) {
    var length = s.length;
    if (length == 0) {
      return false;
    }
    var check = _digit(s.codeUnitAt(length - 1));
    return getStandardUPCEANChecksum(s.substring(0, length - 1)) == check;
  }

  static int getStandardUPCEANChecksum(String s) {
    var length = s.length;
    var sum = 0;
    for (var i = length - 1; i >= 0; i -= 2) {
      var digit = s.codeUnitAt(i) - 0x30 /* 0 */;
      if (digit < 0 || digit > 9) {
        throw FormatReaderException();
      }
      sum += digit;
    }
    sum *= 3;
    for (var i = length - 2; i >= 0; i -= 2) {
      var digit = s.codeUnitAt(i) - 0x30 /* 0 */;
      if (digit < 0 || digit > 9) {
        throw FormatReaderException();
      }
      sum += digit;
    }
    return (1000 - sum) % 10;
  }

  static int _digit(int codeUnit) {
    var digit = codeUnit - 0x30 /* 0 */;
    return digit >= 0 && digit <= 9 ? digit : -1;
  }

  List<int> decodeEnd(BitArray row, int endStart) {
    return findGuardPattern(row, endStart, false, startEndPattern);
  }

  /// @param row row of black/white values to search
  /// @param rowOffset position to start search
  /// @param whiteFirst if true, indicates that the pattern specifies white/black/white/...
  /// pixel counts, otherwise, it is interpreted as black/white/black/...
  /// @param pattern pattern of counts of number of black and white pixels that are being
  /// searched for as a pattern
  /// @param counters array of counters, as long as pattern, to re-use
  /// @return start/end horizontal offset of guard pattern, as an array of two ints
  /// @throws NotFoundException if pattern is not found
  static List<int> findGuardPattern(
      BitArray row, int rowOffset, bool whiteFirst, List<int> pattern,
      [List<int>? counters]) {
    counters ??= Int32List(pattern.length);
    var width = row.size;
    rowOffset =
        whiteFirst ? row.getNextUnset(rowOffset) : row.getNextSet(rowOffset);
    var counterPosition = 0;
    var patternStart = rowOffset;
    var patternLength = pattern.length;
    var isWhite = whiteFirst;
    for (var x = rowOffset; x < width; x++) {
      if (row.get(x) != isWhite) {
        counters[counterPosition]++;
      } else {
        if (counterPosition == patternLength - 1) {
          if (OneDReader.patternMatchVariance(
                  counters, pattern, _maxIndividualVariance) <
              _maxAvgVariance) {
            return [patternStart, x];
          }
          patternStart += counters[0] + counters[1];
          counters.setRange(0, counterPosition - 1, counters, 2);
          counters[counterPosition - 1] = 0;
          counters[counterPosition] = 0;
          counterPosition--;
        } else {
          counterPosition++;
        }
        counters[counterPosition] = 1;
        isWhite = !isWhite;
      }
    }
    throw NotFoundException();
  }

  /// Attempts to decode a single UPC/EAN-encoded digit.
  ///
  /// @param row row of black/white values to decode
  /// @param counters the counts of runs of observed black/white/black/... values
  /// @param rowOffset horizontal offset to start decoding from
  /// @param patterns the set of patterns to use to decode -- sometimes different encodings
  /// for the digits 0-9 are used, and this indicates the encodings for 0 to 9 that should
  /// be used
  /// @return horizontal offset of first pixel beyond the decoded digit
  /// @throws NotFoundException if digit cannot be decoded
  static int decodeDigit(BitArray row, List<int> counters, int rowOffset,
      List<List<int>> patterns) {
    OneDReader.recordPattern(row, rowOffset, counters);
    var bestVariance = _maxAvgVariance; // worst variance we'll accept
    var bestMatch = -1;
    var max = patterns.length;
    for (var i = 0; i < max; i++) {
      var pattern = patterns[i];
      var variance = OneDReader.patternMatchVariance(
          counters, pattern, _maxIndividualVariance);
      if (variance < bestVariance) {
        bestVariance = variance;
        bestMatch = i;
      }
    }
    if (bestMatch >= 0) {
      return bestMatch;
    } else {
      throw NotFoundException();
    }
  }

  /// Get the format of this decoder.
  ///
  /// @return The 1D format.
  BarcodeFormat get barcodeFormat;

  /// Subclasses override this to decode the portion of a barcode between the start
  /// and end guard patterns.
  ///
  /// @param row row of black/white values to search
  /// @param startRange start/end offset of start guard pattern
  /// @param resultString {@link StringBuilder} to append decoded chars to
  /// @return horizontal offset of first pixel after the "middle" that was decoded
  /// @throws NotFoundException if decoding could not complete successfully
  int decodeMiddle(
      BitArray row, List<int> startRange, StringBuffer resultString);
}
