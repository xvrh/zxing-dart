/*
 * Copyright 2008 ZXing authors
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

import 'dart:convert';

/// Encapsulates a Character Set ECI, according to "Extended Channel Interpretations" 5.3.1.1
/// of ISO 18004.
///
/// @author Sean Owen
class CharacterSetECI {
  static const List<CharacterSetECI> sets = [
    CharacterSetECI._([0, 2], ['Cp437'], ascii),
    CharacterSetECI._([1, 3], ['ISO8859_1', 'ISO-8859-1'], latin1),
    CharacterSetECI._([4], ['ISO8859_2', "ISO-8859-2"], latin1),
    CharacterSetECI._([5], ['ISO8859_3', "ISO-8859-3"], latin1),
    CharacterSetECI._([6], ['ISO8859_4', "ISO-8859-4"], latin1),
    CharacterSetECI._([7], ['ISO8859_5', "ISO-8859-5"], latin1),
    CharacterSetECI._([8], ['ISO8859_6', "ISO-8859-6"], latin1),
    CharacterSetECI._([9], ['ISO8859_7', "ISO-8859-7"], latin1),
    CharacterSetECI._([10], ['ISO8859_8 ', "ISO-8859-8"], latin1),
    CharacterSetECI._([11], ['ISO8859_9 ', "ISO-8859-9"], latin1),
    CharacterSetECI._([12], ['ISO8859_10', "ISO-8859-10"], latin1),
    CharacterSetECI._([13], ['ISO8859_11', "ISO-8859-11"], latin1),
    CharacterSetECI._([15], ['ISO8859_13', "ISO-8859-13"], latin1),
    CharacterSetECI._([16], ['ISO8859_14', "ISO-8859-14"], latin1),
    CharacterSetECI._([17], ['ISO8859_15', "ISO-8859-15"], latin1),
    CharacterSetECI._([18], ['ISO8859_16', "ISO-8859-16"], latin1),
    CharacterSetECI._([20], ['SJIS', "Shift_JIS"], ascii),

    //TODO(xha): take the encodings here: https://github.com/Enough-Software/enough_convert
    CharacterSetECI._([21], ['Cp1250', "windows-1250"], ascii),
    CharacterSetECI._([22], ['Cp1251', "windows-1251"], ascii),
    CharacterSetECI._([23], ['Cp1252', "windows-1252"], ascii),
    CharacterSetECI._([24], ['Cp1256', "windows-1256"], ascii),

    // Revive: https://github.com/dart-archive/utf
    CharacterSetECI._(
        [25], ['UnicodeBigUnmarked', "UTF-16BE", "UnicodeBig"], utf8),
    CharacterSetECI._([26], ['UTF8', "UTF-8"], utf8),
    CharacterSetECI._([27, 170], ['ASCII', "US-ASCII"], ascii),
    CharacterSetECI._([28], ['Big5'], ascii),
    CharacterSetECI._([29], ['GB18030', "GB2312", "EUC_CN", "GBK"], ascii),
    CharacterSetECI._([30], ['EUC_KR', "EUC-KR"], ascii),
  ];

  static final _VALUE_TO_ECI = <int, CharacterSetECI>{
    for (var c in sets)
      for (var value in c.values) value: c,
  };

  final List<int> values;
  final List<String> encodingNames;
  final Encoding encoding;

  const CharacterSetECI._(this.values, this.encodingNames, this.encoding);

  int getValue() {
    return values[0];
  }

  /// @param charset Java character set object
  /// @return CharacterSetECI representing ECI for character encoding, or null if it is legal
  ///   but unsupported
  static CharacterSetECI? getCharacterSetECI(Encoding encoding) {
    for (var set in sets) {
      if (set.encoding == encoding) {
        return set;
      }
    }
    return null;
  }

  /// @param value character set ECI value
  /// @return {@code CharacterSetECI} representing ECI of given value, or null if it is legal but
  ///   unsupported
  /// @throws FormatException if ECI value is invalid
  static CharacterSetECI? getCharacterSetECIByValue(int value) {
    if (value < 0 || value >= 900) {
      throw FormatException();
    }
    return _VALUE_TO_ECI[value];
  }
}
