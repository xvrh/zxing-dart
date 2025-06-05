import 'dart:typed_data';

/// <p>Encapsulates the result of decoding a matrix of bits. This typically
/// applies to 2D barcode formats. For now it contains the raw bytes obtained,
/// as well as a String interpretation of those bytes, if applicable.</p>
class DecoderResult {
  /// @return raw bytes representing the result, or {@code null} if not applicable
  final Int8List? rawBytes;

  /// @return how many bits of {@link #getRawBytes()} are valid; typically 8 times its length
  int numBits;

  /// @return text representation of the result
  final String text;

  /// @return list of byte segments in the result, or {@code null} if not applicable
  final List<Int8List>? byteSegments;

  /// @return name of error correction level used, or {@code null} if not applicable
  final String? ecLevel;

  /// @return number of errors corrected, or {@code null} if not applicable
  int? errorsCorrected;

  /// @return number of erasures corrected, or {@code null} if not applicable
  int? erasures;

  /// @return arbitrary additional metadata
  Object? other;

  final int structuredAppendParity;
  final int structuredAppendSequenceNumber;

  /// The QR code version as an integer, if available
  final int? version;

  DecoderResult({
    this.rawBytes,
    required this.text,
    required this.byteSegments,
    required this.ecLevel,
    this.structuredAppendParity = -1,
    this.structuredAppendSequenceNumber = -1,
    this.version,
  }) : numBits = rawBytes == null ? 0 : 8 * rawBytes.length;

  bool get hasStructuredAppend {
    return structuredAppendParity >= 0 && structuredAppendSequenceNumber >= 0;
  }
}
