import 'package:zxing/src/common/bit_matrix.dart';
import 'package:zxing/src/common/decoder_result.dart';
import 'package:zxing/src/common/detector_result.dart';

import '../barcode_format.dart';
import '../binary_bitmap.dart';
import '../decode_hint.dart';
import '../reader.dart';
import '../result.dart';
import '../result_metadata_type.dart';
import '../result_point.dart';
import 'decoder/decoder.dart';
import '../not_found_exception.dart';
import 'decoder/qr_code_decoder_meta_data.dart';
import 'detector/detector.dart';

/// This implementation can detect and decode QR Codes in an image.
///
/// @author Sean Owen
class QRCodeReader implements Reader {
  static const NO_POINTS = <ResultPoint>[];

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
    if (hints.contains(DecodeHintType.PURE_BARCODE)) {
      BitMatrix bits = _extractPureBits(image.getBlackMatrix());
      decoderResult = decoder.decode(bits, hints: hints);
      points = NO_POINTS;
    } else {
      DetectorResult detectorResult =
          Detector(image.getBlackMatrix()).detect(hints: hints);
      decoderResult = decoder.decode(detectorResult.bits, hints: hints);
      points = detectorResult.points;
    }

    // If the code was mirrored: swap the bottom-left and the top-right points.
    var other = decoderResult.other;
    if (other is QRCodeDecoderMetaData) {
      other.applyMirroredCorrection(points);
    }

    Result result = Result(
        decoderResult.text, decoderResult.rawBytes, BarcodeFormat.QR_CODE,
        points: points);
    var byteSegments = decoderResult.byteSegments;
    if (byteSegments != null) {
      result.putMetadata(ResultMetadataType.BYTE_SEGMENTS, byteSegments);
    }
    var ecLevel = decoderResult.ecLevel;
    if (ecLevel != null) {
      result.putMetadata(ResultMetadataType.ERROR_CORRECTION_LEVEL, ecLevel);
    }
    if (decoderResult.hasStructuredAppend) {
      result.putMetadata(ResultMetadataType.STRUCTURED_APPEND_SEQUENCE,
          decoderResult.structuredAppendSequenceNumber);
      result.putMetadata(ResultMetadataType.STRUCTURED_APPEND_PARITY,
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

    double moduleSize = _moduleSize(leftTopBlack, image);

    int top = leftTopBlack[1];
    int bottom = rightBottomBlack[1];
    int left = leftTopBlack[0];
    int right = rightBottomBlack[0];

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

    int matrixWidth = ((right - left + 1) / moduleSize).round();
    int matrixHeight = ((bottom - top + 1) / moduleSize).round();
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
    int nudge = moduleSize ~/ 2.0;
    top += nudge;
    left += nudge;

    // But careful that this does not sample off the edge
    // "right" is the farthest-right valid pixel location -- right+1 is not necessarily
    // This is positive by how much the inner x loop below would be too large
    int nudgedTooFarRight =
        left + ((matrixWidth - 1) * moduleSize).toInt() - right;
    if (nudgedTooFarRight > 0) {
      if (nudgedTooFarRight > nudge) {
        // Neither way fits; abort
        throw NotFoundException();
      }
      left -= nudgedTooFarRight;
    }
    // See logic above
    int nudgedTooFarDown =
        top + ((matrixHeight - 1) * moduleSize).toInt() - bottom;
    if (nudgedTooFarDown > 0) {
      if (nudgedTooFarDown > nudge) {
        // Neither way fits; abort
        throw NotFoundException();
      }
      top -= nudgedTooFarDown;
    }

    // Now just read off the bits
    BitMatrix bits = BitMatrix(matrixWidth, matrixHeight);
    for (int y = 0; y < matrixHeight; y++) {
      int iOffset = top + (y * moduleSize).toInt();
      for (int x = 0; x < matrixWidth; x++) {
        if (image.get(left + (x * moduleSize).toInt(), iOffset)) {
          bits.set(x, y);
        }
      }
    }
    return bits;
  }

  static double _moduleSize(List<int> leftTopBlack, BitMatrix image) {
    int height = image.height;
    int width = image.width;
    int x = leftTopBlack[0];
    int y = leftTopBlack[1];
    bool inBlack = true;
    int transitions = 0;
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
