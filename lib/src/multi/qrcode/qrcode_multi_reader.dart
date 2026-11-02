import 'dart:typed_data';
import '../../barcode_format.dart';
import '../../binary_bitmap.dart';
import '../../decode_hint.dart';
import '../../qrcode/decoder/qr_code_decoder_meta_data.dart';
import '../../qrcode/qrcode_reader.dart';
import '../../reader_exception.dart';
import '../../result.dart';
import '../../result_metadata_type.dart';
import '../multiple_barcode_reader.dart';
import 'detector/multi_detector.dart';

/// This implementation can detect and decode multiple QR Codes in an image.
///
/// @author Sean Owen
/// @author Hannes Erven
class QRCodeMultiReader extends QRCodeReader implements MultipleBarcodeReader {
  @override
  List<Result> decodeMultiple(BinaryBitmap image, {DecodeHints? hints}) {
    hints ??= DecodeHints();
    var results = <Result>[];
    var detectorResults =
        MultiDetector(image.getBlackMatrix()).detectMulti(hints);
    for (var detectorResult in detectorResults) {
      try {
        var decoderResult = decoder.decode(detectorResult.bits, hints: hints);
        var points = detectorResult.points;
        // If the code was mirrored: swap the bottom-left and the top-right points.
        var other = decoderResult.other;
        if (other is QRCodeDecoderMetaData) {
          other.applyMirroredCorrection(points);
        }
        var result = Result(
            decoderResult.text, decoderResult.rawBytes, BarcodeFormat.qrCode,
            points: points, version: decoderResult.version);
        var byteSegments = decoderResult.byteSegments;
        if (byteSegments != null) {
          result.putMetadata(ResultMetadataType.byteSegments, byteSegments);
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
        results.add(result);
      } on ReaderException catch (_) {
        // ignore and continue
      }
    }
    if (results.isEmpty) {
      return results;
    } else {
      return processStructuredAppend(results);
    }
  }

  static List<Result> processStructuredAppend(List<Result> results) {
    var newResults = <Result>[];
    var saResults = <Result>[];
    for (var result in results) {
      if (result.resultMetadata
          .containsKey(ResultMetadataType.structuredAppendSequence)) {
        saResults.add(result);
      } else {
        newResults.add(result);
      }
    }
    if (saResults.isEmpty) {
      return results;
    }

    // sort and concatenate the SA list items
    int sequenceOf(Result result) =>
        result.resultMetadata[ResultMetadataType.structuredAppendSequence]!
            as int;
    saResults.sort((a, b) => sequenceOf(a).compareTo(sequenceOf(b)));
    var newText = StringBuffer();
    var newRawBytes = BytesBuilder();
    var newByteSegment = BytesBuilder();
    for (var saResult in saResults) {
      newText.write(saResult.text);
      var saBytes = saResult.rawBytes;
      if (saBytes != null) {
        newRawBytes.add(saBytes);
      }
      var byteSegments = saResult
          .resultMetadata[ResultMetadataType.byteSegments] as List<Int8List>?;
      if (byteSegments != null) {
        for (var segment in byteSegments) {
          newByteSegment.add(segment);
        }
      }
    }

    var newResult = Result(newText.toString(),
        Int8List.fromList(newRawBytes.takeBytes()), BarcodeFormat.qrCode,
        points: []);
    if (newByteSegment.isNotEmpty) {
      newResult.putMetadata(ResultMetadataType.byteSegments,
          [Int8List.fromList(newByteSegment.takeBytes())]);
    }
    newResults.add(newResult);
    return newResults;
  }
}
