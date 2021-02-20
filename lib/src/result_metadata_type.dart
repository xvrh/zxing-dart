/// Represents some type of metadata about the result of the decoding that the decoder
/// wishes to communicate back to the caller.
///
/// @author Sean Owen
enum ResultMetadataType {
  /// Unspecified, application-specific metadata. Maps to an unspecified {@link Object}.
  other,

  /// Denotes the likely approximate orientation of the barcode in the image. This value
  /// is given as degrees rotated clockwise from the normal, upright orientation.
  /// For example a 1D barcode which was found by reading top-to-bottom would be
  /// said to have orientation "90". This key maps to an {@link Integer} whose
  /// value is in the range [0,360).
  orientation,

  /// <p>2D barcode formats typically encode text, but allow for a sort of 'byte mode'
  /// which is sometimes used to encode binary data. While {@link Result} makes available
  /// the complete raw bytes in the barcode for these formats, it does not offer the bytes
  /// from the byte segments alone.</p>
  ///
  /// <p>This maps to a {@link java.util.List} of byte arrays corresponding to the
  /// raw bytes in the byte segments in the barcode, in order.</p>
  byteSegments,

  /// Error correction level used, if applicable. The value type depends on the
  /// format, but is typically a String.
  errorCorrectionLevel,

  /// For some periodicals, indicates the issue number as an {@link Integer}.
  issueNumber,

  /// For some products, indicates the suggested retail price in the barcode as a
  /// formatted {@link String}.
  suggestedPrice,

  /// For some products, the possible country of manufacture as a {@link String} denoting the
  /// ISO country code. Some map to multiple possible countries, like "US/CA".
  possibleCountry,

  /// For some products, the extension text
  upcEanExtension,

  /// PDF417-specific metadata
  pdf417ExtraMetadata,

  /// If the code format supports structured append and the current scanned code is part of one then the
  /// sequence number is given with it.
  structuredAppendSequence,

  /// If the code format supports structured append and the current scanned code is part of one then the
  /// parity is given with it.
  structuredAppendParity,
}
