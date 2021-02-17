/*
 * Copyright 2007 ZXing authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:typed_data';

import 'package:zxing/src/common/bit_matrix.dart';
import 'package:zxing/src/common/decoder_result.dart';
import 'package:zxing/src/common/reedsolomon/generic_gf.dart';
import 'package:zxing/src/common/reedsolomon/reed_solomon_decoder.dart';
import 'package:zxing/src/common/reedsolomon/reed_solomon_exception.dart';
import 'package:zxing/src/qrcode/decoder/version.dart';

import '../../checksum_exception.dart';
import '../../decode_hint.dart';
import 'bit_matrix_parser.dart';
import 'data_block.dart';
import 'decoded_bit_stream_parser.dart';
import 'error_correction_level.dart';
import 'qr_code_decoder_meta_data.dart';

/**
 * <p>The main class which implements QR Code decoding -- as opposed to locating and extracting
 * the QR Code from an image.</p>
 *
 * @author Sean Owen
 */
class Decoder {
  final ReedSolomonDecoder rsDecoder =
      ReedSolomonDecoder(GenericGF.QR_CODE_FIELD_256);

  /**
   * <p>Decodes a QR Code represented as a {@link BitMatrix}. A 1 or "true" is taken to mean a black module.</p>
   *
   * @param bits booleans representing white/black QR Code modules
   * @param hints decoding hints that should be used to influence decoding
   * @return text and bytes encoded within the QR Code
   * @throws FormatException if the QR Code cannot be decoded
   * @throws ChecksumException if error correction fails
   */
  DecoderResult decode(BitMatrix bits, {required Hints hints}) {
    // Construct a parser and read version, error-correction level
    BitMatrixParser parser = new BitMatrixParser(bits);
    FormatException? fe = null;
    ChecksumException? ce = null;
    try {
      return _decode(parser, hints);
    } on FormatException catch (e) {
      fe = e;
    } on ChecksumException catch (e) {
      ce = e;
    }

    try {
      // Revert the bit matrix
      parser.remask();

      // Will be attempting a mirrored reading of the version and format info.
      parser.setMirror(true);

      // Preemptively read the version.
      parser.readVersion();

      // Preemptively read the format information.
      parser.readFormatInformation();

      /*
       * Since we're here, this means we have successfully detected some kind
       * of version and format information when mirrored. This is a good sign,
       * that the QR code may be mirrored, and we should try once more with a
       * mirrored content.
       */
      // Prepare for a mirrored reading.
      parser.mirror();

      DecoderResult result = _decode(parser, hints);

      // Success! Notify the caller that the code was mirrored.
      result.other = new QRCodeDecoderMetaData(mirrored: true);

      return result;
    } on FormatException catch (_) {
      // Throw the exception from the original reading
      if (fe != null) {
        throw fe;
      }
      throw ce!; // If fe is null, this can't be
    } on ChecksumException catch (_) {
      // Throw the exception from the original reading
      if (fe != null) {
        throw fe;
      }
      throw ce!; // If fe is null, this can't be
    }
  }

  DecoderResult _decode(BitMatrixParser parser, Hints hints) {
    Version version = parser.readVersion();
    ErrorCorrectionLevel ecLevel =
        parser.readFormatInformation().errorCorrectionLevel;

    // Read codewords
    Uint8List codewords = parser.readCodewords();
    // Separate into data blocks
    List<DataBlock> dataBlocks =
        DataBlock.getDataBlocks(codewords, version, ecLevel);

    // Count total number of data bytes
    int totalBytes = 0;
    for (DataBlock dataBlock in dataBlocks) {
      totalBytes += dataBlock.getNumDataCodewords();
    }
    Uint8List resultBytes = Uint8List(totalBytes);
    int resultOffset = 0;

    // Error-correct and copy data blocks together into a stream of bytes
    for (DataBlock dataBlock in dataBlocks) {
      Uint8List codewordBytes = dataBlock.codewords;
      int numDataCodewords = dataBlock.getNumDataCodewords();
      _correctErrors(codewordBytes, numDataCodewords);
      for (int i = 0; i < numDataCodewords; i++) {
        resultBytes[resultOffset++] = codewordBytes[i];
      }
    }

    // Decode the contents of that stream of bytes
    return DecodedBitStreamParser.decode(resultBytes, version, ecLevel, hints);
  }

  /**
   * <p>Given data and error-correction codewords received, possibly corrupted by errors, attempts to
   * correct the errors in-place using Reed-Solomon error correction.</p>
   *
   * @param codewordBytes data and error correction codewords
   * @param numDataCodewords number of codewords that are data bytes
   * @throws ChecksumException if error correction fails
   */
  void _correctErrors(Uint8List codewordBytes, int numDataCodewords) {
    int numCodewords = codewordBytes.length;
    // First read into an array of ints
    var codewordsInts = Int32List(numCodewords);
    for (int i = 0; i < numCodewords; i++) {
      codewordsInts[i] = codewordBytes[i] & 0xFF;
    }
    try {
      rsDecoder.decode(codewordsInts, codewordBytes.length - numDataCodewords);
    } on ReedSolomonException catch (e) {
      throw ChecksumException(e);
    }
    // Copy back into array of bytes -- only need to worry about the bytes that were data
    // We don't care about errors in the error-correction codewords
    for (int i = 0; i < numDataCodewords; i++) {
      codewordBytes[i] = codewordsInts[i];
    }
  }
}
