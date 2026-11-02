import 'dart:math' as math;
import '../binary_bitmap.dart';
import '../common/bit_array.dart';
import '../decode_hint.dart';
import '../not_found_exception.dart';
import '../reader.dart';
import '../reader_exception.dart';
import '../result.dart';
import '../result_metadata_type.dart';
import '../result_point.dart';

/// Encapsulates functionality and implementation that is common to all families
/// of one-dimensional barcodes.
///
/// @author dswitkin@google.com (Daniel Switkin)
/// @author Sean Owen
abstract class OneDReader implements Reader {
  // Note that we don't try rotation without the try harder flag, even if rotation was supported.
  @override
  Result decode(BinaryBitmap image, {DecodeHints? hints}) {
    hints ??= DecodeHints();
    try {
      return _doDecode(image, hints);
    } on NotFoundException catch (_) {
      var tryHarder = hints.contains(DecodeHintType.tryHarder);
      if (tryHarder && image.isRotateSupported()) {
        var rotatedImage = image.rotateCounterClockwise();
        var result = _doDecode(rotatedImage, hints);
        // Record that we found it rotated 90 degrees CCW / 270 degrees CW
        var metadata = result.resultMetadata;
        var orientation = 270;
        var foundOrientation = metadata[ResultMetadataType.orientation];
        if (foundOrientation is int) {
          // But if we found it reversed in doDecode(), add in that result here:
          orientation = (orientation + foundOrientation) % 360;
        }
        result.putMetadata(ResultMetadataType.orientation, orientation);
        // Update result points
        var points = result.resultPoints;
        var height = rotatedImage.height;
        for (var i = 0; i < points.length; i++) {
          points[i] = ResultPoint(height - points[i].y - 1, points[i].x);
        }
        return result;
      } else {
        rethrow;
      }
    }
  }

  @override
  void reset() {
    // do nothing
  }

  /// We're going to examine rows from the middle outward, searching alternately above and below the
  /// middle, and farther out each time. rowStep is the number of rows between each successive
  /// attempt above and below the middle. So we'd scan row middle, then middle - rowStep, then
  /// middle + rowStep, then middle - (2 * rowStep), etc.
  /// rowStep is bigger as the image is taller, but is always at least 1. We've somewhat arbitrarily
  /// decided that moving up and down by about 1/16 of the image is pretty good; we try more of the
  /// image if "trying harder".
  ///
  /// @param image The image to decode
  /// @param hints Any hints that were requested
  /// @return The contents of the decoded barcode
  /// @throws NotFoundException Any spontaneous errors which occur
  Result _doDecode(BinaryBitmap image, DecodeHints hints) {
    var width = image.width;
    var height = image.height;
    var row = BitArray(width);

    var tryHarder = hints.contains(DecodeHintType.tryHarder);
    var rowStep = math.max(1, height >> (tryHarder ? 8 : 5));
    int maxLines;
    if (tryHarder) {
      maxLines = height; // Look at the whole image, not just the center
    } else {
      maxLines =
          15; // 15 rows spaced 1/32 apart is roughly the middle half of the image
    }

    var middle = height ~/ 2;
    for (var x = 0; x < maxLines; x++) {
      // Scanning from the middle out. Determine which row we're looking at next:
      var rowStepsAboveOrBelow = (x + 1) ~/ 2;
      var isAbove = (x & 0x01) == 0; // i.e. is x even?
      var rowNumber = middle +
          rowStep * (isAbove ? rowStepsAboveOrBelow : -rowStepsAboveOrBelow);
      if (rowNumber < 0 || rowNumber >= height) {
        // Oops, if we run off the top or bottom, stop
        break;
      }

      // Estimate black point for this row and load it:
      try {
        row = image.getBlackRow(rowNumber, row);
      } on NotFoundException catch (_) {
        continue;
      }

      // While we have the image data in a BitArray, it's fairly cheap to reverse it in place to
      // handle decoding upside down barcodes.
      for (var attempt = 0; attempt < 2; attempt++) {
        if (attempt == 1) {
          // trying again?
          row.reverse(); // reverse the row and continue
          // This means we will only ever draw result points *once* in the life of this method
          // since we want to avoid drawing the wrong points after flipping the row, and,
          // don't want to clutter with noise from every single row scan -- just the scans
          // that start on the center line.
          if (hints.contains(DecodeHintType.needResultPointCallback)) {
            hints = hints.clone()
              ..remove(DecodeHintType.needResultPointCallback);
          }
        }
        try {
          // Look for a barcode
          var result = decodeRow(rowNumber, row, hints);
          // We found our barcode
          if (attempt == 1) {
            // But it was upside down, so note that
            result.putMetadata(ResultMetadataType.orientation, 180);
            // And remember to flip the result points horizontally.
            var points = result.resultPoints;
            if (points.length >= 2) {
              points[0] = ResultPoint(width - points[0].x - 1, points[0].y);
              points[1] = ResultPoint(width - points[1].x - 1, points[1].y);
            }
          }
          return result;
        } on ReaderException catch (_) {
          // continue -- just couldn't decode this row
        }
      }
    }

    throw NotFoundException();
  }

  /// Records the size of successive runs of white and black pixels in a row, starting at a given point.
  /// The values are recorded in the given array, and the number of runs recorded is equal to the size
  /// of the array. If the row starts on a white pixel at the given start point, then the first count
  /// recorded is the run of white pixels starting from that point; likewise it is the count of a run
  /// of black pixels if the row begin on a black pixels at that point.
  ///
  /// @param row row to count from
  /// @param start offset into row to start at
  /// @param counters array into which to record counts
  /// @throws NotFoundException if counters cannot be filled entirely from row before running out
  ///  of pixels
  static void recordPattern(BitArray row, int start, List<int> counters) {
    var numCounters = counters.length;
    counters.fillRange(0, numCounters, 0);
    var end = row.size;
    if (start >= end) {
      throw NotFoundException();
    }
    var isWhite = !row.get(start);
    var counterPosition = 0;
    var i = start;
    while (i < end) {
      if (row.get(i) != isWhite) {
        counters[counterPosition]++;
      } else {
        if (++counterPosition == numCounters) {
          break;
        } else {
          counters[counterPosition] = 1;
          isWhite = !isWhite;
        }
      }
      i++;
    }
    // If we read fully the last section of pixels and filled up our counters -- or filled
    // the last counter but ran off the side of the image, OK. Otherwise, a problem.
    if (!(counterPosition == numCounters ||
        (counterPosition == numCounters - 1 && i == end))) {
      throw NotFoundException();
    }
  }

  static void recordPatternInReverse(
      BitArray row, int start, List<int> counters) {
    // This could be more efficient I guess
    var numTransitionsLeft = counters.length;
    var last = row.get(start);
    while (start > 0 && numTransitionsLeft >= 0) {
      if (row.get(--start) != last) {
        numTransitionsLeft--;
        last = !last;
      }
    }
    if (numTransitionsLeft >= 0) {
      throw NotFoundException();
    }
    recordPattern(row, start + 1, counters);
  }

  /// Determines how closely a set of observed counts of runs of black/white values matches a given
  /// target pattern. This is reported as the ratio of the total variance from the expected pattern
  /// proportions across all pattern elements, to the length of the pattern.
  ///
  /// @param counters observed counters
  /// @param pattern expected pattern
  /// @param maxIndividualVariance The most any counter can differ before we give up
  /// @return ratio of total variance between counters and pattern compared to total pattern size
  static double patternMatchVariance(
      List<int> counters, List<int> pattern, double maxIndividualVariance) {
    var numCounters = counters.length;
    var total = 0;
    var patternLength = 0;
    for (var i = 0; i < numCounters; i++) {
      total += counters[i];
      patternLength += pattern[i];
    }
    if (total < patternLength) {
      // If we don't even have one pixel per unit of bar width, assume this is too small
      // to reliably match, so fail:
      return double.infinity;
    }

    var unitBarWidth = total / patternLength;
    maxIndividualVariance *= unitBarWidth;

    var totalVariance = 0.0;
    for (var x = 0; x < numCounters; x++) {
      var counter = counters[x];
      var scaledPattern = pattern[x] * unitBarWidth;
      var variance = counter > scaledPattern
          ? counter - scaledPattern
          : scaledPattern - counter;
      if (variance > maxIndividualVariance) {
        return double.infinity;
      }
      totalVariance += variance;
    }
    return totalVariance / total;
  }

  /// <p>Attempts to decode a one-dimensional barcode format given a single row of
  /// an image.</p>
  ///
  /// @param rowNumber row number from top of the row
  /// @param row the black/white pixel data of the row
  /// @param hints decode hints
  /// @return {@link Result} containing encoded string and start/end of barcode
  /// @throws NotFoundException if no potential barcode is found
  /// @throws ChecksumException if a potential barcode is found but does not pass its checksum
  /// @throws FormatReaderException if a potential barcode is found but format is invalid
  Result decodeRow(int rowNumber, BitArray row, DecodeHints hints);
}
