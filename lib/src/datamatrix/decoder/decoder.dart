import 'dart:typed_data';
import '../../checksum_exception.dart';
import '../../common/bit_matrix.dart';
import '../../common/decoder_result.dart';
import '../../common/reedsolomon/generic_gf.dart';
import '../../common/reedsolomon/reed_solomon_decoder.dart';
import '../../common/reedsolomon/reed_solomon_exception.dart';
import 'bit_matrix_parser.dart';
import 'data_block.dart';
import 'decoded_bit_stream_parser.dart';

/// <p>The main class which implements Data Matrix Code decoding -- as opposed to locating and extracting
/// the Data Matrix Code from an image.</p>
///
/// @author bbrown@google.com (Brian Brown)
class Decoder {
  final ReedSolomonDecoder _rsDecoder =
      ReedSolomonDecoder(GenericGF.dataMatrixField256);

  /// <p>Decodes a Data Matrix Code represented as a {@link BitMatrix}. A 1 or "true" is taken
  /// to mean a black module.</p>
  ///
  /// @param bits booleans representing white/black Data Matrix Code modules
  /// @return text and bytes encoded within the Data Matrix Code
  /// @throws FormatReaderException if the Data Matrix Code cannot be decoded
  /// @throws ChecksumException if error correction fails
  DecoderResult decode(BitMatrix bits) {
    // Construct a parser and read version, error-correction level
    var parser = BitMatrixParser(bits);
    var version = parser.version;

    // Read codewords
    var codewords = parser.readCodewords();
    // Separate into data blocks
    var dataBlocks = DataBlock.getDataBlocks(codewords, version);

    // Count total number of data bytes
    var totalBytes = 0;
    for (var db in dataBlocks) {
      totalBytes += db.numDataCodewords;
    }
    var resultBytes = Int8List(totalBytes);

    var errorsCorrected = 0;
    var dataBlocksCount = dataBlocks.length;
    // Error-correct and copy data blocks together into a stream of bytes
    for (var j = 0; j < dataBlocksCount; j++) {
      var dataBlock = dataBlocks[j];
      var codewordBytes = dataBlock.codewords;
      var numDataCodewords = dataBlock.numDataCodewords;
      errorsCorrected += _correctErrors(codewordBytes, numDataCodewords);
      for (var i = 0; i < numDataCodewords; i++) {
        // De-interlace data blocks.
        resultBytes[i * dataBlocksCount + j] = codewordBytes[i];
      }
    }

    // Decode the contents of that stream of bytes
    var result = DecodedBitStreamParser.decode(resultBytes);
    result.errorsCorrected = errorsCorrected;
    return result;
  }

  /// <p>Given data and error-correction codewords received, possibly corrupted by errors, attempts to
  /// correct the errors in-place using Reed-Solomon error correction.</p>
  ///
  /// @param codewordBytes data and error correction codewords
  /// @param numDataCodewords number of codewords that are data bytes
  /// @return the number of errors corrected
  /// @throws ChecksumException if error correction fails
  int _correctErrors(Int8List codewordBytes, int numDataCodewords) {
    var numCodewords = codewordBytes.length;
    // First read into an array of ints
    var codewordsInts = Int32List(numCodewords);
    for (var i = 0; i < numCodewords; i++) {
      codewordsInts[i] = codewordBytes[i] & 0xFF;
    }
    var errorsCorrected = 0;
    try {
      errorsCorrected = _rsDecoder.decodeWithECCount(
          codewordsInts, codewordBytes.length - numDataCodewords);
    } on ReedSolomonException catch (e) {
      throw ChecksumException(e);
    }
    // Copy back into array of bytes -- only need to worry about the bytes that were data
    // We don't care about errors in the error-correction codewords
    for (var i = 0; i < numDataCodewords; i++) {
      codewordBytes[i] = codewordsInts[i];
    }
    return errorsCorrected;
  }
}
