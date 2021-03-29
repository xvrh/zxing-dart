import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:charcode/charcode.dart';
import 'package:fixnum/fixnum.dart';
import '../../common/bit_array.dart';
import '../../common/character_set_eci.dart';
import '../../common/reedsolomon/generic_gf.dart';
import '../../common/reedsolomon/reed_solomon_encoder.dart';
import '../../encode_hint.dart';
import '../../writer_exception.dart';
import '../decoder/error_correction_level.dart';
import '../decoder/mode.dart';
import '../decoder/version.dart';
import 'block_pair.dart';
import 'byte_matrix.dart';
import 'mask_util.dart';
import 'matrix_util.dart';
import 'qr_code.dart';

/// @author satorux@google.com (Satoru Takabayashi) - creator
/// @author dswitkin@google.com (Daniel Switkin) - ported from C++
class Encoder {
  // The original table is defined in the table 5 of JISX0510:2004 (p.19).
  static final List<int> _alphanumericTable = [
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, // 0x00-0x0f
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, // 0x10-0x1f
    36, -1, -1, -1, 37, 38, -1, -1, -1, -1, 39, 40, -1, 41, 42, 43, // 0x20-0x2f
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 44, -1, -1, -1, -1, -1, // 0x30-0x3f
    -1, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, // 0x40-0x4f
    25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, -1, -1, -1, -1, -1, // 0x50-0x5f
  ];

  static final CharacterSetECI defaultByteModeEncoding =
      CharacterSetECI.ISO8859_1;

  Encoder._();

  // The mask penalty calculation is complicated.  See Table 21 of JISX0510:2004 (p.45) for details.
  // Basically it applies four rules and summate all penalties.
  static int _calculateMaskPenalty(ByteMatrix matrix) {
    return MaskUtil.applyMaskPenaltyRule1(matrix) +
        MaskUtil.applyMaskPenaltyRule2(matrix) +
        MaskUtil.applyMaskPenaltyRule3(matrix) +
        MaskUtil.applyMaskPenaltyRule4(matrix);
  }

  /// @param content text to encode
  /// @param ecLevel error correction level to use
  /// @return {@link QRCode} representing the encoded QR code
  /// @throws WriterException if encoding can't succeed, because of for example invalid content
  ///   or configuration
  static QRCode encode(String content, ErrorCorrectionLevel ecLevel,
      {EncodeHints? hints}) {
    hints ??= EncodeHints();
    // Determine what character encoding has been specified by the caller, if any
    var encoding = defaultByteModeEncoding;
    var hasEncodingHint = hints.contains(EncodeHintType.characterSet);
    if (hasEncodingHint) {
      encoding = hints.get(EncodeHintType.characterSet)!;
    }

    // Pick an encoding mode appropriate for the content. Note that this will not attempt to use
    // multiple modes / segments even if that were more efficient. Twould be nice.
    var mode = chooseMode(content, encoding: encoding);

    // This will store the header information, like mode and
    // length, as well as "header" segments like an ECI segment.
    var headerBits = BitArray();

    // Append ECI segment if applicable
    if (mode == Mode.byte && hasEncodingHint) {
      var eci = encoding;
      _appendECI(eci, headerBits);
    }

    // Append the FNC1 mode header for GS1 formatted data if applicable
    if (hints.get(EncodeHintType.gs1Format) ?? false) {
      // GS1 formatted codes are prefixed with a FNC1 in first position mode header
      appendModeInfo(Mode.fnc1FirstPosition, headerBits);
    }

    // (With ECI in place,) Write the mode marker
    appendModeInfo(mode, headerBits);

    // Collect data within the main segment, separately, to count its size if needed. Don't add it to
    // main payload yet.
    var dataBits = BitArray();
    appendBytes(content, mode, dataBits, encoding);

    Version version;
    var versionNumber = hints.get(EncodeHintType.qrVersion);
    if (versionNumber != null) {
      version = Version.getVersionForNumber(versionNumber);
      var bitsNeeded =
          _calculateBitsNeeded(mode, headerBits, dataBits, version);
      if (!_willFit(bitsNeeded, version, ecLevel)) {
        throw WriterException('Data too big for requested version');
      }
    } else {
      version = _recommendVersion(ecLevel, mode, headerBits, dataBits);
    }

    var headerAndDataBits = BitArray();
    headerAndDataBits.appendBitArray(headerBits);
    // Find "length" of main segment and write it
    var numLetters = mode == Mode.byte ? dataBits.sizeInBytes : content.length;
    appendLengthInfo(numLetters, version, mode, headerAndDataBits);
    // Put data together into the overall payload
    headerAndDataBits.appendBitArray(dataBits);

    var ecBlocks = version.getECBlocksForLevel(ecLevel);
    var numDataBytes = version.totalCodewords - ecBlocks.getTotalECCodewords();

    // Terminate the bits properly.
    terminateBits(numDataBytes, headerAndDataBits);

    // Interleave data bits with error correction code.
    var finalBits = interleaveWithECBytes(headerAndDataBits,
        version.totalCodewords, numDataBytes, ecBlocks.numBlocks);

    var qrCode = QRCode();

    qrCode.ecLevel = ecLevel;
    qrCode.mode = mode;
    qrCode.version = version;

    //  Choose the mask pattern and set to "qrCode".
    var dimension = version.dimensionForVersion;
    var matrix = ByteMatrix(dimension, dimension);

    // Enable manual selection of the pattern to be used via hint
    var maskPattern = -1;
    if (hints.contains(EncodeHintType.qrMaskPattern)) {
      var hintMaskPattern = hints.get(EncodeHintType.qrMaskPattern)!;
      maskPattern =
          QRCode.isValidMaskPattern(hintMaskPattern) ? hintMaskPattern : -1;
    }

    if (maskPattern == -1) {
      maskPattern = _chooseMaskPattern(finalBits, ecLevel, version, matrix);
    }
    qrCode.maskPattern = maskPattern;

    // Build the matrix and set it to "qrCode".
    MatrixUtil.buildMatrix(finalBits, ecLevel, version, maskPattern, matrix);
    qrCode.matrix = matrix;

    return qrCode;
  }

  /// Decides the smallest version of QR code that will contain all of the provided data.
  ///
  /// @throws WriterException if the data cannot fit in any version
  static Version _recommendVersion(ErrorCorrectionLevel ecLevel, Mode mode,
      BitArray headerBits, BitArray dataBits) {
    // Hard part: need to know version to know how many bits length takes. But need to know how many
    // bits it takes to know version. First we take a guess at version by assuming version will be
    // the minimum, 1:
    var provisionalBitsNeeded = _calculateBitsNeeded(
        mode, headerBits, dataBits, Version.getVersionForNumber(1));
    var provisionalVersion = _chooseVersion(provisionalBitsNeeded, ecLevel);

    // Use that guess to calculate the right version. I am still not sure this works in 100% of cases.
    var bitsNeeded =
        _calculateBitsNeeded(mode, headerBits, dataBits, provisionalVersion);
    return _chooseVersion(bitsNeeded, ecLevel);
  }

  static int _calculateBitsNeeded(
      Mode mode, BitArray headerBits, BitArray dataBits, Version version) {
    return headerBits.size +
        mode.getCharacterCountBits(version) +
        dataBits.size;
  }

  /// @return the code point of the table used in alphanumeric mode or
  ///  -1 if there is no corresponding code in the table.
  static int getAlphanumericCode(int code) {
    if (code < _alphanumericTable.length) {
      return _alphanumericTable[code];
    }
    return -1;
  }

  /// Choose the best mode by examining the content. Note that 'encoding' is used as a hint;
  /// if it is Shift_JIS, and the input is only double-byte Kanji, then we return {@link Mode#KANJI}.
  static Mode chooseMode(String content, {CharacterSetECI? encoding}) {
    if (encoding == CharacterSetECI.SJIS && _isOnlyDoubleByteKanji(content)) {
      // Choose Kanji mode if all input are double-byte characters
      return Mode.kanji;
    }
    var hasNumeric = false;
    var hasAlphanumeric = false;
    for (var i = 0; i < content.length; ++i) {
      var c = content.codeUnitAt(i);
      if (c >= $0 && c <= $9) {
        hasNumeric = true;
      } else if (getAlphanumericCode(c) != -1) {
        hasAlphanumeric = true;
      } else {
        return Mode.byte;
      }
    }
    if (hasAlphanumeric) {
      return Mode.alphanumeric;
    }
    if (hasNumeric) {
      return Mode.numeric;
    }
    return Mode.byte;
  }

  static bool _isOnlyDoubleByteKanji(String content) {
    var bytes = CharacterSetECI.SJIS.encoding.encode(content);
    var length = bytes.length;
    if (length % 2 != 0) {
      return false;
    }
    for (var i = 0; i < length; i += 2) {
      var byte1 = bytes[i] & 0xFF;
      if ((byte1 < 0x81 || byte1 > 0x9F) && (byte1 < 0xE0 || byte1 > 0xEB)) {
        return false;
      }
    }
    return true;
  }

  static int _chooseMaskPattern(BitArray bits, ErrorCorrectionLevel ecLevel,
      Version version, ByteMatrix matrix) {
    var minPenalty = Int32.MAX_VALUE.toInt(); // Lower penalty is better.
    var bestMaskPattern = -1;
    // We try all mask patterns to choose the best one.
    for (var maskPattern = 0;
        maskPattern < QRCode.numMaskPatterns;
        maskPattern++) {
      MatrixUtil.buildMatrix(bits, ecLevel, version, maskPattern, matrix);
      var penalty = _calculateMaskPenalty(matrix);
      if (penalty < minPenalty) {
        minPenalty = penalty;
        bestMaskPattern = maskPattern;
      }
    }
    return bestMaskPattern;
  }

  static Version _chooseVersion(
      int numInputBits, ErrorCorrectionLevel ecLevel) {
    for (var versionNum = 1; versionNum <= 40; versionNum++) {
      var version = Version.getVersionForNumber(versionNum);
      if (_willFit(numInputBits, version, ecLevel)) {
        return version;
      }
    }
    throw WriterException('Data too big');
  }

  /// @return true if the number of input bits will fit in a code with the specified version and
  /// error correction level.
  static bool _willFit(
      int numInputBits, Version version, ErrorCorrectionLevel ecLevel) {
    // In the following comments, we use numbers of Version 7-H.
    // numBytes = 196
    var numBytes = version.totalCodewords;
    // getNumECBytes = 130
    var ecBlocks = version.getECBlocksForLevel(ecLevel);
    var numEcBytes = ecBlocks.getTotalECCodewords();
    // getNumDataBytes = 196 - 130 = 66
    var numDataBytes = numBytes - numEcBytes;
    var totalInputBytes = (numInputBits + 7) ~/ 8;
    return numDataBytes >= totalInputBytes;
  }

  /// Terminate bits as described in 8.4.8 and 8.4.9 of JISX0510:2004 (p.24).
  static void terminateBits(int numDataBytes, BitArray bits) {
    var capacity = numDataBytes * 8;
    if (bits.size > capacity) {
      throw WriterException(
          'data bits cannot fit in the QR Code ${bits.size} > $capacity');
    }
    for (var i = 0; i < 4 && bits.size < capacity; ++i) {
      bits.appendBit(false);
    }
    // Append termination bits. See 8.4.8 of JISX0510:2004 (p.24) for details.
    // If the last byte isn't 8-bit aligned, we'll add padding bits.
    var numBitsInLastByte = bits.size & 0x07;
    if (numBitsInLastByte > 0) {
      for (var i = numBitsInLastByte; i < 8; i++) {
        bits.appendBit(false);
      }
    }
    // If we have more space, we'll fill the space with padding patterns defined in 8.4.9 (p.24).
    var numPaddingBytes = numDataBytes - bits.sizeInBytes;
    for (var i = 0; i < numPaddingBytes; ++i) {
      bits.appendBits((i & 0x01) == 0 ? 0xEC : 0x11, 8);
    }
    if (bits.size != capacity) {
      throw WriterException('Bits size does not equal capacity');
    }
  }

  /// Get number of data bytes and number of error correction bytes for block id "blockID". Store
  /// the result in "numDataBytesInBlock", and "numECBytesInBlock". See table 12 in 8.5.1 of
  /// JISX0510:2004 (p.30)
  static void getNumDataBytesAndNumECBytesForBlockID(
      int numTotalBytes,
      int numDataBytes,
      int numRSBlocks,
      int blockID,
      Int32List numDataBytesInBlock,
      Int32List numECBytesInBlock) {
    if (blockID >= numRSBlocks) {
      throw WriterException('Block ID too large');
    }
    // numRsBlocksInGroup2 = 196 % 5 = 1
    var numRsBlocksInGroup2 = numTotalBytes % numRSBlocks;
    // numRsBlocksInGroup1 = 5 - 1 = 4
    var numRsBlocksInGroup1 = numRSBlocks - numRsBlocksInGroup2;
    // numTotalBytesInGroup1 = 196 / 5 = 39
    var numTotalBytesInGroup1 = numTotalBytes ~/ numRSBlocks;
    // numTotalBytesInGroup2 = 39 + 1 = 40
    var numTotalBytesInGroup2 = numTotalBytesInGroup1 + 1;
    // numDataBytesInGroup1 = 66 / 5 = 13
    var numDataBytesInGroup1 = numDataBytes ~/ numRSBlocks;
    // numDataBytesInGroup2 = 13 + 1 = 14
    var numDataBytesInGroup2 = numDataBytesInGroup1 + 1;
    // numEcBytesInGroup1 = 39 - 13 = 26
    var numEcBytesInGroup1 = numTotalBytesInGroup1 - numDataBytesInGroup1;
    // numEcBytesInGroup2 = 40 - 14 = 26
    var numEcBytesInGroup2 = numTotalBytesInGroup2 - numDataBytesInGroup2;
    // Sanity checks.
    // 26 = 26
    if (numEcBytesInGroup1 != numEcBytesInGroup2) {
      throw WriterException('EC bytes mismatch');
    }
    // 5 = 4 + 1.
    if (numRSBlocks != numRsBlocksInGroup1 + numRsBlocksInGroup2) {
      throw WriterException('RS blocks mismatch');
    }
    // 196 = (13 + 26) * 4 + (14 + 26) * 1
    if (numTotalBytes !=
        ((numDataBytesInGroup1 + numEcBytesInGroup1) * numRsBlocksInGroup1) +
            ((numDataBytesInGroup2 + numEcBytesInGroup2) *
                numRsBlocksInGroup2)) {
      throw WriterException('Total bytes mismatch');
    }

    if (blockID < numRsBlocksInGroup1) {
      numDataBytesInBlock[0] = numDataBytesInGroup1;
      numECBytesInBlock[0] = numEcBytesInGroup1;
    } else {
      numDataBytesInBlock[0] = numDataBytesInGroup2;
      numECBytesInBlock[0] = numEcBytesInGroup2;
    }
  }

  /// Interleave "bits" with corresponding error correction bytes. On success, store the result in
  /// "result". The interleave rule is complicated. See 8.6 of JISX0510:2004 (p.37) for details.
  static BitArray interleaveWithECBytes(
      BitArray bits, int numTotalBytes, int numDataBytes, int numRSBlocks) {
    // "bits" must have "getNumDataBytes" bytes of data.
    if (bits.sizeInBytes != numDataBytes) {
      throw WriterException('Number of bits and data bytes does not match');
    }

    // Step 1.  Divide data bytes into blocks and generate error correction bytes for them. We'll
    // store the divided data bytes blocks and error correction bytes blocks into "blocks".
    var dataBytesOffset = 0;
    var maxNumDataBytes = 0;
    var maxNumEcBytes = 0;

    // Since, we know the number of reedsolmon blocks, we can initialize the vector with the number.
    var blocks = <BlockPair>[];

    for (var i = 0; i < numRSBlocks; ++i) {
      var numDataBytesInBlock = Int32List(1);
      var numEcBytesInBlock = Int32List(1);
      getNumDataBytesAndNumECBytesForBlockID(numTotalBytes, numDataBytes,
          numRSBlocks, i, numDataBytesInBlock, numEcBytesInBlock);

      var size = numDataBytesInBlock[0];
      var dataBytes = Int8List(size);
      bits.toBytes(8 * dataBytesOffset, dataBytes, 0, size);
      var ecBytes = generateECBytes(dataBytes, numEcBytesInBlock[0]);
      blocks.add(BlockPair(dataBytes, ecBytes));

      maxNumDataBytes = math.max(maxNumDataBytes, size);
      maxNumEcBytes = math.max(maxNumEcBytes, ecBytes.length);
      dataBytesOffset += numDataBytesInBlock[0];
    }
    if (numDataBytes != dataBytesOffset) {
      throw WriterException('Data bytes does not match offset');
    }

    var result = BitArray();

    // First, place data blocks.
    for (var i = 0; i < maxNumDataBytes; ++i) {
      for (var block in blocks) {
        var dataBytes = block.dataBytes;
        if (i < dataBytes.length) {
          result.appendBits(dataBytes[i], 8);
        }
      }
    }
    // Then, place error correction blocks.
    for (var i = 0; i < maxNumEcBytes; ++i) {
      for (var block in blocks) {
        var ecBytes = block.errorCorrectionBytes;
        if (i < ecBytes.length) {
          result.appendBits(ecBytes[i], 8);
        }
      }
    }
    if (numTotalBytes != result.sizeInBytes) {
      // Should be same.
      throw WriterException(
          'Interleaving error: $numTotalBytes and ${result.sizeInBytes} differ.');
    }

    return result;
  }

  static Int8List generateECBytes(Int8List dataBytes, int numEcBytesInBlock) {
    var numDataBytes = dataBytes.length;
    var toEncode = Int32List(numDataBytes + numEcBytesInBlock);
    for (var i = 0; i < numDataBytes; i++) {
      toEncode[i] = dataBytes[i] & 0xFF;
    }
    ReedSolomonEncoder(GenericGF.qrCodeField256)
        .encode(toEncode, numEcBytesInBlock);

    var ecBytes = Int8List(numEcBytesInBlock);
    for (var i = 0; i < numEcBytesInBlock; i++) {
      ecBytes[i] = toEncode[numDataBytes + i];
    }
    return ecBytes;
  }

  /// Append mode info. On success, store the result in "bits".
  static void appendModeInfo(Mode mode, BitArray bits) {
    bits.appendBits(mode.bits, 4);
  }

  /// Append length info. On success, store the result in "bits".
  static void appendLengthInfo(
      int numLetters, Version version, Mode mode, BitArray bits) {
    var numBits = mode.getCharacterCountBits(version);
    if (numLetters >= (1 << numBits)) {
      throw WriterException('$numLetters is bigger than ${(1 << numBits) - 1}');
    }
    bits.appendBits(numLetters, numBits);
  }

  /// Append "bytes" in "mode" mode (encoding) into "bits". On success, store the result in "bits".
  static void appendBytes(
      String content, Mode mode, BitArray bits, CharacterSetECI encoding) {
    switch (mode) {
      case Mode.numeric:
        appendNumericBytes(content, bits);
        break;
      case Mode.alphanumeric:
        appendAlphanumericBytes(content, bits);
        break;
      case Mode.byte:
        append8BitBytes(content, bits, encoding.encoding);
        break;
      case Mode.kanji:
        appendKanjiBytes(content, bits);
        break;
      default:
        throw WriterException('Invalid mode: $mode');
    }
  }

  static void appendNumericBytes(String content, BitArray bits) {
    var length = content.length;
    var i = 0;
    while (i < length) {
      var num1 = content.codeUnitAt(i) - $0;
      if (i + 2 < length) {
        // Encode three numeric letters in ten bits.
        var num2 = content.codeUnitAt(i + 1) - $0;
        var num3 = content.codeUnitAt(i + 2) - $0;
        bits.appendBits(num1 * 100 + num2 * 10 + num3, 10);
        i += 3;
      } else if (i + 1 < length) {
        // Encode two numeric letters in seven bits.
        var num2 = content.codeUnitAt(i + 1) - $0;
        bits.appendBits(num1 * 10 + num2, 7);
        i += 2;
      } else {
        // Encode one numeric letter in four bits.
        bits.appendBits(num1, 4);
        i++;
      }
    }
  }

  static void appendAlphanumericBytes(String content, BitArray bits) {
    var length = content.length;
    var i = 0;
    while (i < length) {
      var code1 = getAlphanumericCode(content.codeUnitAt(i));
      if (code1 == -1) {
        throw WriterException('');
      }
      if (i + 1 < length) {
        var code2 = getAlphanumericCode(content.codeUnitAt(i + 1));
        if (code2 == -1) {
          throw WriterException('');
        }
        // Encode two alphanumeric letters in 11 bits.
        bits.appendBits(code1 * 45 + code2, 11);
        i += 2;
      } else {
        // Encode one alphanumeric letter in six bits.
        bits.appendBits(code1, 6);
        i++;
      }
    }
  }

  static void append8BitBytes(
      String content, BitArray bits, Encoding encoding) {
    var bytes = encoding.encode(content);
    for (var b in bytes) {
      bits.appendBits(b, 8);
    }
  }

  static void appendKanjiBytes(String content, BitArray bits) {
    var bytes = CharacterSetECI.SJIS.encoding.encode(content);
    if (bytes.length % 2 != 0) {
      throw WriterException('Kanji byte size not even');
    }
    var maxI = bytes.length - 1; // bytes.length must be even
    for (var i = 0; i < maxI; i += 2) {
      var byte1 = bytes[i] & 0xFF;
      var byte2 = bytes[i + 1] & 0xFF;
      var code = (byte1 << 8) | byte2;
      var subtracted = -1;
      if (code >= 0x8140 && code <= 0x9ffc) {
        subtracted = code - 0x8140;
      } else if (code >= 0xe040 && code <= 0xebbf) {
        subtracted = code - 0xc140;
      }
      if (subtracted == -1) {
        throw WriterException('Invalid byte sequence');
      }
      var encoded = ((subtracted >> 8) * 0xc0) + (subtracted & 0xff);
      bits.appendBits(encoded, 13);
    }
  }

  static void _appendECI(CharacterSetECI eci, BitArray bits) {
    bits.appendBits(Mode.eci.bits, 4);
    // This is correct for values up to 127, which is all we need now.
    bits.appendBits(eci.getValue(), 8);
  }
}
