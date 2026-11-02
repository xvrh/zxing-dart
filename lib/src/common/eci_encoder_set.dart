import 'character_set_eci.dart';

/// Set of CharsetEncoders for a given input string
///
/// Invariants:
/// - The list contains only encoders from CharacterSetECI (list is shorter then the list of encoders available on
///   the platform for which ECI values are defined).
/// - The list contains encoders at least one encoder for every character in the input.
/// - The first encoder in the list is always the ISO-8859-1 encoder even of no character in the input can be encoded
///       by it.
/// - If the input contains a character that is not in ISO-8859-1 then the last two entries in the list will be the
///   UTF-8 encoder and the UTF-16BE encoder.
///
/// @author Alex Geller
class ECIEncoderSet {
  // List of encoders that potentially encode characters not in ISO-8859-1 in one byte.
  static final List<CharacterSetECI> _availableEncoders = [
    CharacterSetECI.ISO8859_2,
    CharacterSetECI.ISO8859_3,
    CharacterSetECI.ISO8859_4,
    CharacterSetECI.ISO8859_5,
    CharacterSetECI.ISO8859_6,
    CharacterSetECI.ISO8859_7,
    CharacterSetECI.ISO8859_8,
    CharacterSetECI.ISO8859_9,
    CharacterSetECI.ISO8859_10,
    CharacterSetECI.ISO8859_11,
    CharacterSetECI.ISO8859_13,
    CharacterSetECI.ISO8859_14,
    CharacterSetECI.ISO8859_15,
    CharacterSetECI.ISO8859_16,
    CharacterSetECI.Cp1250,
    CharacterSetECI.Cp1251,
    CharacterSetECI.Cp1252,
    CharacterSetECI.Cp1256,
    CharacterSetECI.SJIS,
  ];

  final List<CharacterSetECI> _encoders;

  //  returns -1 if no priority charset was defined
  final int priorityEncoderIndex;

  ECIEncoderSet._(this._encoders, this.priorityEncoderIndex);

  /// Constructs an encoder set
  ///
  /// @param stringToEncode the string that needs to be encoded
  /// @param priorityCharset The preferred {@link Charset} or null.
  /// @param fnc1 fnc1 denotes the character in the input that represents the FNC1 character or -1 for a non-GS1 bar
  /// code. When specified, it is considered an error to pass it as argument to the methods canEncode() or encode().
  factory ECIEncoderSet(
      String stringToEncode, CharacterSetECI? priorityCharset, int fnc1) {
    var neededEncoders = <CharacterSetECI>[];

    //we always need the ISO-8859-1 encoder. It is the default encoding
    neededEncoders.add(CharacterSetECI.ISO8859_1);
    var needUnicodeEncoder = priorityCharset == CharacterSetECI.UTF8 ||
        priorityCharset == CharacterSetECI.UnicodeBigUnmarked;

    //Walk over the input string and see if all characters can be encoded with the list of encoders
    for (var i = 0; i < stringToEncode.length; i++) {
      var canEncode = false;
      for (var encoder in neededEncoders) {
        var c = stringToEncode.codeUnitAt(i);
        if (c == fnc1 || _canEncodeWith(encoder, c)) {
          canEncode = true;
          break;
        }
      }

      if (!canEncode) {
        //for the character at position i we don't yet have an encoder in the list
        for (var encoder in _availableEncoders) {
          if (_canEncodeWith(encoder, stringToEncode.codeUnitAt(i))) {
            //Good, we found an encoder that can encode the character. We add him to the list and continue scanning
            //the input
            neededEncoders.add(encoder);
            canEncode = true;
            break;
          }
        }
      }

      if (!canEncode) {
        //The character is not encodeable by any of the single byte encoders so we remember that we will need a
        //Unicode encoder.
        needUnicodeEncoder = true;
      }
    }

    List<CharacterSetECI> encoders;
    if (neededEncoders.length == 1 && !needUnicodeEncoder) {
      //the entire input can be encoded by the ISO-8859-1 encoder
      encoders = [neededEncoders[0]];
    } else {
      // we need more than one single byte encoder or we need a Unicode encoder.
      // In this case we append a UTF-8 and UTF-16 encoder to the list
      encoders = [
        ...neededEncoders,
        CharacterSetECI.UTF8,
        CharacterSetECI.UnicodeBigUnmarked,
      ];
    }

    //Compute priorityEncoderIndex by looking up priorityCharset in encoders
    var priorityEncoderIndexValue =
        priorityCharset != null ? encoders.indexOf(priorityCharset) : -1;
    //invariants
    assert(encoders[0] == CharacterSetECI.ISO8859_1);
    return ECIEncoderSet._(encoders, priorityEncoderIndexValue);
  }

  int get length {
    return _encoders.length;
  }

  String getCharsetName(int index) {
    assert(index < length);
    return _encoders[index].encoding.name;
  }

  CharacterSetECI getCharset(int index) {
    assert(index < length);
    return _encoders[index];
  }

  int getECIValue(int encoderIndex) {
    return _encoders[encoderIndex].getValue();
  }

  bool canEncode(int c, int encoderIndex) {
    assert(encoderIndex < length);
    var encoder = _encoders[encoderIndex];
    return _canEncodeWith(encoder, c);
  }

  List<int> encode(int c, int encoderIndex) {
    assert(encoderIndex < length);
    var encoder = _encoders[encoderIndex];
    assert(_canEncodeWith(encoder, c));
    return encoder.encoding.encode(String.fromCharCode(c));
  }

  List<int> encodeString(String s, int encoderIndex) {
    assert(encoderIndex < length);
    var encoder = _encoders[encoderIndex];
    return encoder.encoding.encode(s);
  }

  static bool _canEncodeWith(CharacterSetECI encoder, int c) {
    try {
      encoder.encoding.encode(String.fromCharCode(c));
      return true;
    } on ArgumentError catch (_) {
      return false;
    } on FormatException catch (_) {
      return false;
    }
  }
}
