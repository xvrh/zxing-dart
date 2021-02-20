import 'dart:typed_data';
import '../binarizer.dart';
import '../luminance_source.dart';
import '../not_found_exception.dart';
import 'bit_array.dart';
import 'bit_matrix.dart';

/// This Binarizer implementation uses the old ZXing global histogram approach. It is suitable
/// for low-end mobile devices which don't have enough CPU or memory to use a local thresholding
/// algorithm. However, because it picks a global black point, it cannot handle difficult shadows
/// and gradients.
///
/// Faster mobile devices and all desktop applications should probably use HybridBinarizer instead.
///
/// @author dswitkin@google.com (Daniel Switkin)
/// @author Sean Owen
class GlobalHistogramBinarizer extends Binarizer {
  static final int _LUMINANCE_BITS = 5;
  static final int _LUMINANCE_SHIFT = 8 - _LUMINANCE_BITS;
  static final int _LUMINANCE_BUCKETS = 1 << _LUMINANCE_BITS;
  static final Int8List _EMPTY = Int8List(0);

  Int8List _luminances = _EMPTY;
  final Int32List _buckets = Int32List(_LUMINANCE_BUCKETS);

  GlobalHistogramBinarizer(LuminanceSource source) : super(source);

  // Applies simple sharpening to the row data to improve performance of the 1D Readers.
  @override
  BitArray getBlackRow(int y, BitArray? row) {
    var source = luminanceSource;
    var width = source.width;
    if (row == null || row.size < width) {
      row = BitArray(width);
    } else {
      row.clear();
    }

    _initArrays(width);
    var localLuminances = source.getRow(y, _luminances);
    var localBuckets = _buckets;
    for (var x = 0; x < width; x++) {
      localBuckets[(localLuminances[x] & 0xff) >> _LUMINANCE_SHIFT]++;
    }
    var blackPoint = _estimateBlackPoint(localBuckets);

    if (width < 3) {
      // Special case for very small images
      for (var x = 0; x < width; x++) {
        if ((localLuminances[x] & 0xff) < blackPoint) {
          row.set(x);
        }
      }
    } else {
      var left = localLuminances[0] & 0xff;
      var center = localLuminances[1] & 0xff;
      for (var x = 1; x < width - 1; x++) {
        var right = localLuminances[x + 1] & 0xff;
        // A simple -1 4 -1 box filter with a weight of 2.
        if (((center * 4) - left - right) / 2 < blackPoint) {
          row.set(x);
        }
        left = center;
        center = right;
      }
    }
    return row;
  }

  // Does not sharpen the data, as this call is intended to only be used by 2D Readers.
  @override
  BitMatrix getBlackMatrix() {
    var source = luminanceSource;
    var width = source.width;
    var height = source.height;
    var matrix = BitMatrix(width, height);

    // Quickly calculates the histogram by sampling four rows from the image. This proved to be
    // more robust on the blackbox tests than sampling a diagonal as we used to do.
    _initArrays(width);
    var localBuckets = _buckets;
    for (var y = 1; y < 5; y++) {
      var row = height * y ~/ 5;
      var localLuminances = source.getRow(row, _luminances);
      var right = (width * 4) ~/ 5;
      for (var x = width ~/ 5; x < right; x++) {
        var pixel = localLuminances[x] & 0xff;
        localBuckets[pixel >> _LUMINANCE_SHIFT]++;
      }
    }
    var blackPoint = _estimateBlackPoint(localBuckets);

    // We delay reading the entire image luminance until the black point estimation succeeds.
    // Although we end up reading four rows twice, it is consistent with our motto of
    // "fail quickly" which is necessary for continuous scanning.
    var localLuminances = source.getMatrix();
    for (var y = 0; y < height; y++) {
      var offset = y * width;
      for (var x = 0; x < width; x++) {
        var pixel = localLuminances[offset + x] & 0xff;
        if (pixel < blackPoint) {
          matrix.set(x, y);
        }
      }
    }

    return matrix;
  }

  @override
  Binarizer createBinarizer(LuminanceSource source) {
    return GlobalHistogramBinarizer(source);
  }

  void _initArrays(int luminanceSize) {
    if (_luminances.length < luminanceSize) {
      _luminances = Int8List(luminanceSize);
    }
    for (var x = 0; x < _LUMINANCE_BUCKETS; x++) {
      _buckets[x] = 0;
    }
  }

  static int _estimateBlackPoint(Int32List buckets) {
    // Find the tallest peak in the histogram.
    var numBuckets = buckets.length;
    var maxBucketCount = 0;
    var firstPeak = 0;
    var firstPeakSize = 0;
    for (var x = 0; x < numBuckets; x++) {
      if (buckets[x] > firstPeakSize) {
        firstPeak = x;
        firstPeakSize = buckets[x];
      }
      if (buckets[x] > maxBucketCount) {
        maxBucketCount = buckets[x];
      }
    }

    // Find the second-tallest peak which is somewhat far from the tallest peak.
    var secondPeak = 0;
    var secondPeakScore = 0;
    for (var x = 0; x < numBuckets; x++) {
      var distanceToBiggest = x - firstPeak;
      // Encourage more distant second peaks by multiplying by square of distance.
      var score = buckets[x] * distanceToBiggest * distanceToBiggest;
      if (score > secondPeakScore) {
        secondPeak = x;
        secondPeakScore = score;
      }
    }

    // Make sure firstPeak corresponds to the black peak.
    if (firstPeak > secondPeak) {
      var temp = firstPeak;
      firstPeak = secondPeak;
      secondPeak = temp;
    }

    // If there is too little contrast in the image to pick a meaningful black point, throw rather
    // than waste time trying to decode the image, and risk false positives.
    if (secondPeak - firstPeak <= numBuckets / 16) {
      throw NotFoundException();
    }

    // Find a valley between them that is low and closer to the white peak.
    var bestValley = secondPeak - 1;
    var bestValleyScore = -1;
    for (var x = secondPeak - 1; x > firstPeak; x--) {
      var fromFirst = x - firstPeak;
      var score = fromFirst *
          fromFirst *
          (secondPeak - x) *
          (maxBucketCount - buckets[x]);
      if (score > bestValleyScore) {
        bestValley = x;
        bestValleyScore = score;
      }
    }

    return bestValley << _LUMINANCE_SHIFT;
  }
}
