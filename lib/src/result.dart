import 'dart:typed_data';
import 'barcode_format.dart';
import 'result_metadata_type.dart';
import 'result_point.dart';

/// <p>Encapsulates the result of decoding a barcode within an image.</p>
///
/// @author Sean Owen
class Result {
  /// @return raw text encoded by the barcode
  final String text;

  /// @return raw bytes encoded by the barcode, if applicable, otherwise {@code null}
  final Int8List? rawBytes;

  /// @return how many bits of {@link #getRawBytes()} are valid; typically 8 times its length
  final int numBits;

  /// @return points related to the barcode in the image. These are typically points
  ///         identifying finder patterns or the corners of the barcode. The exact meaning is
  ///         specific to the type of barcode that was decoded.
  final resultPoints = <ResultPoint>[];

  /// @return {@link BarcodeFormat} representing the format of the barcode that was decoded
  final BarcodeFormat format;

  /// @return {@link Map} mapping {@link ResultMetadataType} keys to values.
  ///  This contains optional metadata about what was detected about the barcode,
  ///   like orientation.
  final resultMetadata = <ResultMetadataType, Object>{};

  final DateTime time;

  Result(this.text, this.rawBytes, this.format,
      {List<ResultPoint>? points, int? numBits, DateTime? time})
      : numBits = numBits ?? (rawBytes == null ? 0 : 8 * rawBytes.length),
        time = time ?? DateTime.now() {
    if (points != null) {
      resultPoints.addAll(points);
    }
  }

  void putMetadata(ResultMetadataType type, Object value) {
    resultMetadata[type] = value;
  }

  void putAllMetadata(Map<ResultMetadataType, Object> metadata) {
    resultMetadata.addAll(metadata);
  }

  void addResultPoints(List<ResultPoint> newPoints) {
    resultPoints.addAll(newPoints);
  }

  @override
  String toString() {
    return text;
  }
}
