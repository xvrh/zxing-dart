import 'dart:typed_data';
import '../../zxing2.dart';

/// Common string-related functions.
///
/// @author Sean Owen
/// @author Alex Dupre
class StringUtils {
  StringUtils._();

  /// @param bytes bytes encoding a string, whose encoding should be guessed
  /// @param hints decode hints if applicable
  /// @return Charset of guessed encoding; at the moment will only guess one of:
  ///  {@link #SHIFT_JIS_CHARSET}, {@link StandardCharsets#UTF_8},
  ///  {@link StandardCharsets#ISO_8859_1}, or the platform default encoding if
  ///  none of these can possibly be correct
  static CharacterSetECI guessCharset(Int8List bytes, DecodeHints hints) {
    if (hints.contains(DecodeHintType.characterSet)) {
      return CharacterSetECI.findByName(
          hints.get(DecodeHintType.characterSet).toString());
    }
    // For now, merely tries to distinguish ISO-8859-1, UTF-8 and Shift_JIS,
    // which should be by far the most common encodings.
    var length = bytes.length;
    var canBeISO88591 = true;
    var canBeShiftJIS = true;
    var canBeUTF8 = true;
    var utf8BytesLeft = 0;
    var utf2BytesChars = 0;
    var utf3BytesChars = 0;
    var utf4BytesChars = 0;
    var sjisBytesLeft = 0;
    var sjisKatakanaChars = 0;
    var sjisCurKatakanaWordLength = 0;
    var sjisCurDoubleBytesWordLength = 0;
    var sjisMaxKatakanaWordLength = 0;
    var sjisMaxDoubleBytesWordLength = 0;
    var isoHighOther = 0;

    var utf8bom = bytes.length > 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF;

    for (var i = 0;
        i < length && (canBeISO88591 || canBeShiftJIS || canBeUTF8);
        i++) {
      var value = bytes[i] & 0xFF;

      // UTF-8 stuff
      if (canBeUTF8) {
        if (utf8BytesLeft > 0) {
          if ((value & 0x80) == 0) {
            canBeUTF8 = false;
          } else {
            utf8BytesLeft--;
          }
        } else if ((value & 0x80) != 0) {
          if ((value & 0x40) == 0) {
            canBeUTF8 = false;
          } else {
            utf8BytesLeft++;
            if ((value & 0x20) == 0) {
              utf2BytesChars++;
            } else {
              utf8BytesLeft++;
              if ((value & 0x10) == 0) {
                utf3BytesChars++;
              } else {
                utf8BytesLeft++;
                if ((value & 0x08) == 0) {
                  utf4BytesChars++;
                } else {
                  canBeUTF8 = false;
                }
              }
            }
          }
        }
      }

      // ISO-8859-1 stuff
      if (canBeISO88591) {
        if (value > 0x7F && value < 0xA0) {
          canBeISO88591 = false;
        } else if (value > 0x9F &&
            (value < 0xC0 || value == 0xD7 || value == 0xF7)) {
          isoHighOther++;
        }
      }

      // Shift_JIS stuff
      if (canBeShiftJIS) {
        if (sjisBytesLeft > 0) {
          if (value < 0x40 || value == 0x7F || value > 0xFC) {
            canBeShiftJIS = false;
          } else {
            sjisBytesLeft--;
          }
        } else if (value == 0x80 || value == 0xA0 || value > 0xEF) {
          canBeShiftJIS = false;
        } else if (value > 0xA0 && value < 0xE0) {
          sjisKatakanaChars++;
          sjisCurDoubleBytesWordLength = 0;
          sjisCurKatakanaWordLength++;
          if (sjisCurKatakanaWordLength > sjisMaxKatakanaWordLength) {
            sjisMaxKatakanaWordLength = sjisCurKatakanaWordLength;
          }
        } else if (value > 0x7F) {
          sjisBytesLeft++;
          //sjisDoubleBytesChars++;
          sjisCurKatakanaWordLength = 0;
          sjisCurDoubleBytesWordLength++;
          if (sjisCurDoubleBytesWordLength > sjisMaxDoubleBytesWordLength) {
            sjisMaxDoubleBytesWordLength = sjisCurDoubleBytesWordLength;
          }
        } else {
          //sjisLowChars++;
          sjisCurKatakanaWordLength = 0;
          sjisCurDoubleBytesWordLength = 0;
        }
      }
    }

    if (canBeUTF8 && utf8BytesLeft > 0) {
      canBeUTF8 = false;
    }
    if (canBeShiftJIS && sjisBytesLeft > 0) {
      canBeShiftJIS = false;
    }

    // Easy -- if there is BOM or at least 1 valid not-single byte character (and no evidence it can't be UTF-8), done
    if (canBeUTF8 &&
        (utf8bom || utf2BytesChars + utf3BytesChars + utf4BytesChars > 0)) {
      return CharacterSetECI.UTF8;
    }
    // Easy -- if assuming Shift_JIS or >= 3 valid consecutive not-ascii characters (and no evidence it can't be), done
    if (canBeShiftJIS &&
        (sjisMaxKatakanaWordLength >= 3 || sjisMaxDoubleBytesWordLength >= 3)) {
      return CharacterSetECI.SJIS;
    }
    // Distinguishing Shift_JIS and ISO-8859-1 can be a little tough for short words. The crude heuristic is:
    // - If we saw
    //   - only two consecutive katakana chars in the whole text, or
    //   - at least 10% of bytes that could be "upper" not-alphanumeric Latin1,
    // - then we conclude Shift_JIS, else ISO-8859-1
    if (canBeISO88591 && canBeShiftJIS) {
      return (sjisMaxKatakanaWordLength == 2 && sjisKatakanaChars == 2) ||
              isoHighOther * 10 >= length
          ? CharacterSetECI.SJIS
          : CharacterSetECI.ISO8859_1;
    }

    // Otherwise, try in order ISO-8859-1, Shift JIS, UTF-8 and fall back to default platform encoding
    if (canBeISO88591) {
      return CharacterSetECI.ISO8859_1;
    }
    if (canBeShiftJIS) {
      return CharacterSetECI.SJIS;
    }
    if (canBeUTF8) {
      return CharacterSetECI.UTF8;
    }
    // Otherwise, we take a wild guess with platform encoding
    return CharacterSetECI.UTF8;
  }
}
