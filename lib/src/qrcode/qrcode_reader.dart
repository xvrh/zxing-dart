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
import 'decoder/qr_code_decoder_meta_data.dart';
import 'detector/detector.dart';

/// This implementation can detect and decode QR Codes in an image.
///
/// @author Sean Owen
class QRCodeReader implements Reader {
  static const _kNoPoints = <ResultPoint>[];

  final Decoder decoder = Decoder();

  /// Locates and decodes a QR code in an image.
  ///
  /// @return a String representing the content encoded by the QR code
  /// @throws NotFoundException if a QR code cannot be found
  /// @throws FormatReaderException if a QR code cannot be decoded
  /// @throws ChecksumException if error correction fails
  @override
  Result decode(BinaryBitmap image, {DecodeHints? hints}) {
    hints ??= DecodeHints();
    DecoderResult decoderResult;
    List<ResultPoint> points;
    if (hints.contains(DecodeHintType.pureBarcode)) {
      var bits = _extractPureBits(image.getBlackMatrix());
      decoderResult = decoder.decode(bits, hints: hints);
      points = _kNoPoints;
    } else {
      var detectorResult =
          Detector(image.getBlackMatrix()).detect(hints: hints);
      decoderResult = decoder.decode(detectorResult.bits, hints: hints);
      points = detectorResult.points;
    }

    // If the code was mirrored: swap the bottom-left and the top-right points.
    var other = decoderResult.other;
    if (other is QRCodeDecoderMetaData) {
      other.applyMirroredCorrection(points);
    }

    var result = Result(
        decoderResult.text, decoderResult.rawBytes, BarcodeFormat.qrCode,
        points: points);
    var byteSegments = decoderResult.byteSegments;
    if (byteSegments != null) {
      result.putMetadata(ResultMetadataType.byteSegments, byteSegments);
    }
    var version = decoderResult.version;
    if (version != null) {
      result.putMetadata(ResultMetadataType.version, version);
    }
    var ecLevel = decoderResult.ecLevel;
    if (ecLevel != null) {
      result.putMetadata(ResultMetadataType.errorCorrectionLevel, ecLevel);
    }
    if (decoderResult.hasStructuredAppend) {
      result.putMetadata(ResultMetadataType.structuredAppendSequence,
          decoderResult.structuredAppendSequenceNumber);
      result.putMetadata(ResultMetadataType.structuredAppendParity,
          decoderResult.structuredAppendParity);
    }
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

    // Sanity check!
    if (left >= right || top >= bottom) {
      throw NotFoundException();
    }

    if (bottom - top != right - left) {
      // Special case, where bottom-right module wasn't black so we found something else in the last row
      // Assume it's a square, so use height as the width
      right = left + (bottom - top);
      if (right >= image.width) {
        // Abort if that would not make sense -- off image
        throw NotFoundException();
      }
    }

    var matrixWidth = ((right - left + 1) / moduleSize).round();
    var matrixHeight = ((bottom - top + 1) / moduleSize).round();
    if (matrixWidth <= 0 || matrixHeight <= 0) {
      throw NotFoundException();
    }
    if (matrixHeight != matrixWidth) {
      // Only possibly decode square regions
      throw NotFoundException();
    }

    // Push in the "border" by half the module width so that we start
    // sampling in the middle of the module. Just in case the image is a
    // little off, this will help recover.
    var nudge = moduleSize ~/ 2.0;
    top += nudge;
    left += nudge;

    // But careful that this does not sample off the edge
    // "right" is the farthest-right valid pixel location -- right+1 is not necessarily
    // This is positive by how much the inner x loop below would be too large
    var nudgedTooFarRight =
        left + ((matrixWidth - 1) * moduleSize).toInt() - right;
    if (nudgedTooFarRight > 0) {
      if (nudgedTooFarRight > nudge) {
        // Neither way fits; abort
        throw NotFoundException();
      }
      left -= nudgedTooFarRight;
    }
    // See logic above
    var nudgedTooFarDown =
        top + ((matrixHeight - 1) * moduleSize).toInt() - bottom;
    if (nudgedTooFarDown > 0) {
      if (nudgedTooFarDown > nudge) {
        // Neither way fits; abort
        throw NotFoundException();
      }
      top -= nudgedTooFarDown;
    }

    // Now just read off the bits
    var bits = BitMatrix(matrixWidth, matrixHeight);
    for (var y = 0; y < matrixHeight; y++) {
      var iOffset = top + (y * moduleSize).toInt();
      for (var x = 0; x < matrixWidth; x++) {
        if (image.get(left + (x * moduleSize).toInt(), iOffset)) {
          bits.set(x, y);
        }
      }
    }
    return bits;
  }

  static double _moduleSize(List<int> leftTopBlack, BitMatrix image) {
    var height = image.height;
    var width = image.width;
    var x = leftTopBlack[0];
    var y = leftTopBlack[1];
    var inBlack = true;
    var transitions = 0;
    while (x < width && y < height) {
      if (inBlack != image.get(x, y)) {
        if (++transitions == 5) {
          break;
        }
        inBlack = !inBlack;
      }
      x++;
      y++;
    }
    if (x == width || y == height) {
      throw NotFoundException();
    }
    return (x - leftTopBlack[0]) / 7.0;
  }
}
