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

/**
 * <p>See ISO 18004:2006, 6.5.1. This enum encapsulates the four error correction levels
 * defined by the QR code standard.</p>
 *
 * @author Sean Owen
 */
class ErrorCorrectionLevel {
  /** L = ~7% correction */
  static final L = ErrorCorrectionLevel._(0x01, 'L');
  /** M = ~15% correction */
  static final M = ErrorCorrectionLevel._(0x00, 'M');
  /** Q = ~25% correction */
  static final Q = ErrorCorrectionLevel._(0x03, 'Q');
  /** H = ~30% correction */
  static final H = ErrorCorrectionLevel._(0x02, 'H');

  static final FOR_BITS = [M, L, H, Q];

  final int bits;
  final String name;

  ErrorCorrectionLevel._(this.bits, this.name);

  int get ordinal => FOR_BITS.indexOf(this);

  /**
   * @param bits int containing the two bits encoding a QR Code's error correction level
   * @return ErrorCorrectionLevel representing the encoded error correction level
   */
  static ErrorCorrectionLevel forBits(int bits) {
    if (bits < 0 || bits >= FOR_BITS.length) {
      throw new ArgumentError();
    }
    return FOR_BITS[bits];
  }

  String toString() => 'ErrorCorrectionLevel.$name';
}
