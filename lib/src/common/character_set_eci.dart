import 'dart:convert';

import '../format_reader_exception.dart';

const _defaultAscii = AsciiCodec(allowInvalid: true);
const _defaultLatin1 = Latin1Codec(allowInvalid: true);
const _defaultUtf8 = Utf8Codec(allowMalformed: true);

/// Encapsulates a Character Set ECI, according to "Extended Channel Interpretations" 5.3.1.1
/// of ISO 18004.
class CharacterSetECI {
  static final Cp437 = CharacterSetECI._([0, 2], ['Cp437'], _defaultAscii);
  static final ISO8859_1 =
      CharacterSetECI._([1, 3], ['ISO8859_1', 'ISO-8859-1'], _defaultLatin1);
  static final ISO8859_2 =
      CharacterSetECI._([4], ['ISO8859_2', "ISO-8859-2"], _defaultLatin1);
  static final ISO8859_3 =
      CharacterSetECI._([5], ['ISO8859_3', "ISO-8859-3"], _defaultLatin1);
  static final ISO8859_4 =
      CharacterSetECI._([6], ['ISO8859_4', "ISO-8859-4"], _defaultLatin1);
  static final ISO8859_5 =
      CharacterSetECI._([7], ['ISO8859_5', "ISO-8859-5"], _defaultLatin1);
  static final ISO8859_6 =
      CharacterSetECI._([8], ['ISO8859_6', "ISO-8859-6"], _defaultLatin1);
  static final ISO8859_7 =
      CharacterSetECI._([9], ['ISO8859_7', "ISO-8859-7"], _defaultLatin1);
  static final ISO8859_8 =
      CharacterSetECI._([10], ['ISO8859_8 ', "ISO-8859-8"], _defaultLatin1);
  static final ISO8859_9 =
      CharacterSetECI._([11], ['ISO8859_9 ', "ISO-8859-9"], _defaultLatin1);
  static final ISO8859_10 =
      CharacterSetECI._([12], ['ISO8859_10', "ISO-8859-10"], _defaultLatin1);
  static final ISO8859_11 =
      CharacterSetECI._([13], ['ISO8859_11', "ISO-8859-11"], _defaultLatin1);
  static final ISO8859_13 =
      CharacterSetECI._([15], ['ISO8859_13', "ISO-8859-13"], _defaultLatin1);
  static final ISO8859_14 =
      CharacterSetECI._([16], ['ISO8859_14', "ISO-8859-14"], _defaultLatin1);
  static final ISO8859_15 =
      CharacterSetECI._([17], ['ISO8859_15', "ISO-8859-15"], _defaultLatin1);
  static final ISO8859_16 =
      CharacterSetECI._([18], ['ISO8859_16', "ISO-8859-16"], _defaultLatin1);
  static final SJIS =
      CharacterSetECI._([20], ['SJIS', "Shift_JIS"], _defaultAscii);
  static final Cp1250 =
      CharacterSetECI._([21], ['Cp1250', "windows-1250"], _defaultAscii);
  static final Cp1251 =
      CharacterSetECI._([22], ['Cp1251', "windows-1251"], _defaultAscii);
  static final Cp1252 =
      CharacterSetECI._([23], ['Cp1252', "windows-1252"], _defaultAscii);
  static final Cp1256 =
      CharacterSetECI._([24], ['Cp1256', "windows-1256"], _defaultAscii);
  static final UnicodeBigUnmarked = CharacterSetECI._(
      [25], ['UnicodeBigUnmarked', "UTF-16BE", "UnicodeBig"], _defaultUtf8);
  static final UTF8 = CharacterSetECI._([26], ['UTF8', "UTF-8"], _defaultUtf8);
  static final ASCII =
      CharacterSetECI._([27, 170], ['ASCII', "US-ASCII"], _defaultAscii);
  static final Big5 = CharacterSetECI._([28], ['Big5'], _defaultAscii);
  static final GB18030 = CharacterSetECI._(
      [29], ['GB18030', "GB2312", "EUC_CN", "GBK"], _defaultAscii);
  static final EUC_KR =
      CharacterSetECI._([30], ['EUC_KR', "EUC-KR"], _defaultAscii);

  static final List<CharacterSetECI> all = [
    Cp437,
    ISO8859_1,
    ISO8859_2,
    ISO8859_3,
    ISO8859_4,
    ISO8859_5,
    ISO8859_6,
    ISO8859_7,
    ISO8859_8,
    ISO8859_9,
    ISO8859_10,
    ISO8859_11,
    ISO8859_13,
    ISO8859_14,
    ISO8859_15,
    ISO8859_16,
    SJIS,
    Cp1250,
    Cp1251,
    Cp1252,
    Cp1256,
    UnicodeBigUnmarked,
    UTF8,
    ASCII,
    Big5,
    GB18030,
    EUC_KR,
  ];

  static final _VALUE_TO_ECI = <int, CharacterSetECI>{
    for (var c in all)
      for (var value in c.values) value: c,
  };

  final List<int> values;
  final List<String> encodingNames;
  Encoding encoding;

  CharacterSetECI._(this.values, this.encodingNames, this.encoding);

  int getValue() {
    return values[0];
  }

  /// @param charset Java character set object
  /// @return CharacterSetECI representing ECI for character encoding, or null if it is legal
  ///   but unsupported
  static CharacterSetECI? getCharacterSetECI(Encoding encoding) {
    for (var set in all) {
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
      throw FormatReaderException();
    }
    return _VALUE_TO_ECI[value];
  }

  static CharacterSetECI findByName(String name) {
    name = name.toLowerCase();
    for (var set in all) {
      for (var name in set.encodingNames) {
        if (name.toLowerCase() == name) {
          return set;
        }
      }
    }
    return CharacterSetECI.ASCII;
  }
}
