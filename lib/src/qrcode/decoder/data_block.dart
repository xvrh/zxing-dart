import 'dart:typed_data';
import 'error_correction_level.dart';
import 'version.dart';

/// <p>Encapsulates a block of data within a QR Code. QR Codes may split their data into
/// multiple blocks, each of which is a unit of data and error-correction codewords. Each
/// is represented by an instance of this class.</p>
///
/// @author Sean Owen
class DataBlock {
  final int numDataCodewords;
  final Int8List codewords;

  DataBlock(this.numDataCodewords, this.codewords);

  /// <p>When QR Codes use multiple data blocks, they are actually interleaved.
  /// That is, the first byte of data block 1 to n is written, then the second bytes, and so on. This
  /// method will separate the data into original blocks.</p>
  ///
  /// @param rawCodewords bytes as read directly from the QR Code
  /// @param version version of the QR Code
  /// @param ecLevel error-correction level of the QR Code
  /// @return DataBlocks containing original bytes, "de-interleaved" from representation in the
  ///         QR Code
  static List<DataBlock> getDataBlocks(
      Int8List rawCodewords, Version version, ErrorCorrectionLevel ecLevel) {
    if (rawCodewords.length != version.totalCodewords) {
      throw ArgumentError();
    }

    // Figure out the number and size of data blocks used by this version and
    // error correction level
    var ecBlocks = version.getECBlocksForLevel(ecLevel);

    var ecBlockArray = ecBlocks.ecBlocks;

    // Now establish DataBlocks of the appropriate size and number of data codewords
    var result = <DataBlock>[];
    var numResultBlocks = 0;
    for (var ecBlock in ecBlockArray) {
      for (var i = 0; i < ecBlock.count; i++) {
        var numDataCodewords = ecBlock.dataCodewords;
        var numBlockCodewords = ecBlocks.ecCodewordsPerBlock + numDataCodewords;
        ++numResultBlocks;
        result.add(DataBlock(numDataCodewords, Int8List(numBlockCodewords)));
      }
    }

    // All blocks have the same amount of data, except that the last n
    // (where n may be 0) have 1 more byte. Figure out where these start.
    var shorterBlocksTotalCodewords = result[0].codewords.length;
    var longerBlocksStartAt = result.length - 1;
    while (longerBlocksStartAt >= 0) {
      var numCodewords = result[longerBlocksStartAt].codewords.length;
      if (numCodewords == shorterBlocksTotalCodewords) {
        break;
      }
      longerBlocksStartAt--;
    }
    longerBlocksStartAt++;

    var shorterBlocksNumDataCodewords =
        shorterBlocksTotalCodewords - ecBlocks.ecCodewordsPerBlock;
    // The last elements of result may be 1 element longer;
    // first fill out as many elements as all of them have
    var rawCodewordsOffset = 0;
    for (var i = 0; i < shorterBlocksNumDataCodewords; i++) {
      for (var j = 0; j < numResultBlocks; j++) {
        result[j].codewords[i] = rawCodewords[rawCodewordsOffset++];
      }
    }
    // Fill out the last data block in the longer ones
    for (var j = longerBlocksStartAt; j < numResultBlocks; j++) {
      result[j].codewords[shorterBlocksNumDataCodewords] =
          rawCodewords[rawCodewordsOffset++];
    }
    // Now add in error correction blocks
    var max = result[0].codewords.length;
    for (var i = shorterBlocksNumDataCodewords; i < max; i++) {
      for (var j = 0; j < numResultBlocks; j++) {
        var iOffset = j < longerBlocksStartAt ? i : i + 1;
        result[j].codewords[iOffset] = rawCodewords[rawCodewordsOffset++];
      }
    }
    return result;
  }

  int getNumDataCodewords() {
    return numDataCodewords;
  }
}
