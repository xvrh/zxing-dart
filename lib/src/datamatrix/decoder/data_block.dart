import 'dart:typed_data';
import 'version.dart';

/// <p>Encapsulates a block of data within a Data Matrix Code. Data Matrix Codes may split their data into
/// multiple blocks, each of which is a unit of data and error-correction codewords. Each
/// is represented by an instance of this class.</p>
///
/// @author bbrown@google.com (Brian Brown)
class DataBlock {
  final int numDataCodewords;
  final Int8List codewords;

  DataBlock._(this.numDataCodewords, this.codewords);

  /// <p>When Data Matrix Codes use multiple data blocks, they actually interleave the bytes of each of them.
  /// That is, the first byte of data block 1 to n is written, then the second bytes, and so on. This
  /// method will separate the data into original blocks.</p>
  ///
  /// @param rawCodewords bytes as read directly from the Data Matrix Code
  /// @param version version of the Data Matrix Code
  /// @return DataBlocks containing original bytes, "de-interleaved" from representation in the
  ///         Data Matrix Code
  static List<DataBlock> getDataBlocks(Int8List rawCodewords, Version version) {
    // Figure out the number and size of data blocks used by this version
    var ecBlocks = version.ecBlocks;

    // Now establish DataBlocks of the appropriate size and number of data codewords
    var result = <DataBlock>[];
    for (var ecBlock in ecBlocks.ecBlocks) {
      for (var i = 0; i < ecBlock.count; i++) {
        var numDataCodewords = ecBlock.dataCodewords;
        var numBlockCodewords = ecBlocks.ecCodewords + numDataCodewords;
        result.add(DataBlock._(numDataCodewords, Int8List(numBlockCodewords)));
      }
    }
    var numResultBlocks = result.length;

    // All blocks have the same amount of data, except that the last n
    // (where n may be 0) have 1 less byte. Figure out where these start.
    // TODO(bbrown): There is only one case where there is a difference for Data Matrix for size 144
    var longerBlocksTotalCodewords = result[0].codewords.length;

    var longerBlocksNumDataCodewords =
        longerBlocksTotalCodewords - ecBlocks.ecCodewords;
    var shorterBlocksNumDataCodewords = longerBlocksNumDataCodewords - 1;
    // The last elements of result may be 1 element shorter for 144 matrix
    // first fill out as many elements as all of them have minus 1
    var rawCodewordsOffset = 0;
    for (var i = 0; i < shorterBlocksNumDataCodewords; i++) {
      for (var j = 0; j < numResultBlocks; j++) {
        result[j].codewords[i] = rawCodewords[rawCodewordsOffset++];
      }
    }

    // Fill out the last data block in the longer ones
    var specialVersion = version.versionNumber == 24;
    var numLongerBlocks = specialVersion ? 8 : numResultBlocks;
    for (var j = 0; j < numLongerBlocks; j++) {
      result[j].codewords[longerBlocksNumDataCodewords - 1] =
          rawCodewords[rawCodewordsOffset++];
    }

    // Now add in error correction blocks
    var max = result[0].codewords.length;
    for (var i = longerBlocksNumDataCodewords; i < max; i++) {
      for (var j = 0; j < numResultBlocks; j++) {
        var jOffset = specialVersion ? (j + 8) % numResultBlocks : j;
        var iOffset = specialVersion && jOffset > 7 ? i - 1 : i;
        result[jOffset].codewords[iOffset] = rawCodewords[rawCodewordsOffset++];
      }
    }

    if (rawCodewordsOffset != rawCodewords.length) {
      throw ArgumentError();
    }

    return result;
  }
}
