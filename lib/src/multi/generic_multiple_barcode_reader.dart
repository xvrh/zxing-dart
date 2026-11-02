import '../binary_bitmap.dart';
import '../decode_hint.dart';
import '../not_found_exception.dart';
import '../reader.dart';
import '../reader_exception.dart';
import '../result.dart';
import '../result_point.dart';
import 'multiple_barcode_reader.dart';

/// <p>Attempts to locate multiple barcodes in an image by repeatedly decoding portion of the image.
/// After one barcode is found, the areas left, above, right and below the barcode's
/// [ResultPoint]s are scanned, recursively.</p>
///
/// <p>A caller may want to also employ [ByQuadrantReader] when attempting to find multiple
/// 2D barcodes, like QR Codes, in an image, where the presence of multiple barcodes might prevent
/// detecting any one of them.</p>
///
/// <p>That is, instead of passing a [Reader] a caller might pass
/// `ByQuadrantReader(reader)`.</p>
///
/// @author Sean Owen
class GenericMultipleBarcodeReader implements MultipleBarcodeReader {
  static const _minDimensionToRecur = 100;
  static const _maxDepth = 4;

  final Reader _delegate;

  GenericMultipleBarcodeReader(this._delegate);

  @override
  List<Result> decodeMultiple(BinaryBitmap image, {DecodeHints? hints}) {
    var results = <Result>[];
    _doDecodeMultiple(image, hints, results, 0, 0, 0);
    if (results.isEmpty) {
      throw NotFoundException();
    }
    return results;
  }

  void _doDecodeMultiple(BinaryBitmap image, DecodeHints? hints,
      List<Result> results, int xOffset, int yOffset, int currentDepth) {
    if (currentDepth > _maxDepth) {
      return;
    }

    Result result;
    try {
      result = _delegate.decode(image, hints: hints);
    } on ReaderException catch (_) {
      return;
    }
    var alreadyFound = false;
    for (var existingResult in results) {
      if (existingResult.text == result.text) {
        alreadyFound = true;
        break;
      }
    }
    if (!alreadyFound) {
      results.add(_translateResultPoints(result, xOffset, yOffset));
    }
    var resultPoints = result.resultPoints;
    if (resultPoints.isEmpty) {
      return;
    }
    var width = image.width;
    var height = image.height;
    var minX = width.toDouble();
    var minY = height.toDouble();
    var maxX = 0.0;
    var maxY = 0.0;
    for (var point in resultPoints) {
      var x = point.x;
      var y = point.y;
      if (x < minX) {
        minX = x;
      }
      if (y < minY) {
        minY = y;
      }
      if (x > maxX) {
        maxX = x;
      }
      if (y > maxY) {
        maxY = y;
      }
    }

    // Decode left of barcode
    if (minX > _minDimensionToRecur) {
      _doDecodeMultiple(image.crop(0, 0, minX.toInt(), height), hints, results,
          xOffset, yOffset, currentDepth + 1);
    }
    // Decode above barcode
    if (minY > _minDimensionToRecur) {
      _doDecodeMultiple(image.crop(0, 0, width, minY.toInt()), hints, results,
          xOffset, yOffset, currentDepth + 1);
    }
    // Decode right of barcode
    if (maxX < width - _minDimensionToRecur) {
      _doDecodeMultiple(
          image.crop(maxX.toInt(), 0, width - maxX.toInt(), height),
          hints,
          results,
          xOffset + maxX.toInt(),
          yOffset,
          currentDepth + 1);
    }
    // Decode below barcode
    if (maxY < height - _minDimensionToRecur) {
      _doDecodeMultiple(
          image.crop(0, maxY.toInt(), width, height - maxY.toInt()),
          hints,
          results,
          xOffset,
          yOffset + maxY.toInt(),
          currentDepth + 1);
    }
  }

  static Result _translateResultPoints(
      Result result, int xOffset, int yOffset) {
    var newResultPoints = [
      for (var point in result.resultPoints)
        ResultPoint(point.x + xOffset, point.y + yOffset)
    ];
    var newResult = Result(result.text, result.rawBytes, result.format,
        points: newResultPoints,
        numBits: result.numBits,
        time: result.time,
        version: result.version);
    newResult.putAllMetadata(result.resultMetadata);
    return newResult;
  }
}
