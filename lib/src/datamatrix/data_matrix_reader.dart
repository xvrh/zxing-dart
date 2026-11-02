import '../barcode_format.dart';
import '../binary_bitmap.dart';
import '../common/bit_matrix.dart';
import '../common/decoder_result.dart';
import '../decode_hint.dart';
import '../not_found_exception.dart';
import '../reader.dart';
import '../result.dart';
import '../result_metadata_type.dart';
import '../result_point.dart';
import 'decoder/decoder.dart';
import 'detector/detector.dart';

/// This implementation can detect and decode Data Matrix codes in an image.
///
/// @author bbrown@google.com (Brian Brown)
class DataMatrixReader implements Reader {
  static const _noPoints = <ResultPoint>[];

  final Decoder _decoder = Decoder();

  /// Locates and decodes a Data Matrix code in an image.
  ///
  /// @return a String representing the content encoded by the Data Matrix code
  /// @throws NotFoundException if a Data Matrix code cannot be found
  /// @throws FormatReaderException if a Data Matrix code cannot be decoded
  /// @throws ChecksumException if error correction fails
  @override
  Result decode(BinaryBitmap image, {DecodeHints? hints}) {
    DecoderResult decoderResult;
    List<ResultPoint> points;
    if (hints != null && hints.contains(DecodeHintType.pureBarcode)) {
      var bits = _extractPureBits(image.getBlackMatrix());
      decoderResult = _decoder.decode(bits);
      points = _noPoints;
    } else {
      var detectorResult = Detector(image.getBlackMatrix()).detect();
      decoderResult = _decoder.decode(detectorResult.bits);
      points = detectorResult.points;
    }
    var result = Result(
        decoderResult.text, decoderResult.rawBytes, BarcodeFormat.dataMatrix,
        points: points);
    var byteSegments = decoderResult.byteSegments;
    if (byteSegments != null) {
      result.putMetadata(ResultMetadataType.byteSegments, byteSegments);
    }
    var ecLevel = decoderResult.ecLevel;
    if (ecLevel != null) {
      result.putMetadata(ResultMetadataType.errorCorrectionLevel, ecLevel);
    }
    result.putMetadata(
        ResultMetadataType.errorsCorrected, decoderResult.errorsCorrected!);
    result.putMetadata(ResultMetadataType.symbologyIdentifier,
        ']d${decoderResult.symbologyModifier}');
    return result;
  }

  @override
  void reset() {
    // do nothing
  }

  /// This method detects a code in a "pure" image -- that is, pure monochrome image
  /// which contains only an unrotated, unskewed, image of a code, with some white border
  /// around it. This is a specialized method that works exceptionally fast in this special
  /// case.
  static BitMatrix _extractPureBits(BitMatrix image) {
    var leftTopBlack = image.getTopLeftOnBit();
    var rightBottomBlack = image.getBottomRightOnBit();
    if (leftTopBlack == null || rightBottomBlack == null) {
      throw NotFoundException();
    }

    var moduleSize = _moduleSize(leftTopBlack, image);

    var top = leftTopBlack[1];
    var bottom = rightBottomBlack[1];
    var left = leftTopBlack[0];
    var right = rightBottomBlack[0];

    var matrixWidth = (right - left + 1) ~/ moduleSize;
    var matrixHeight = (bottom - top + 1) ~/ moduleSize;
    if (matrixWidth <= 0 || matrixHeight <= 0) {
      throw NotFoundException();
    }

    // Push in the "border" by half the module width so that we start
    // sampling in the middle of the module. Just in case the image is a
    // little off, this will help recover.
    var nudge = moduleSize ~/ 2;
    top += nudge;
    left += nudge;

    // Now just read off the bits
    var bits = BitMatrix(matrixWidth, matrixHeight);
    for (var y = 0; y < matrixHeight; y++) {
      var iOffset = top + y * moduleSize;
      for (var x = 0; x < matrixWidth; x++) {
        if (image.get(left + x * moduleSize, iOffset)) {
          bits.set(x, y);
        }
      }
    }
    return bits;
  }

  static int _moduleSize(List<int> leftTopBlack, BitMatrix image) {
    var width = image.width;
    var x = leftTopBlack[0];
    var y = leftTopBlack[1];
    while (x < width && image.get(x, y)) {
      x++;
    }
    if (x == width) {
      throw NotFoundException();
    }

    var moduleSize = x - leftTopBlack[0];
    if (moduleSize == 0) {
      throw NotFoundException();
    }
    return moduleSize;
  }
}
