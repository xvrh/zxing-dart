/// Converters for SJIS(shift_jis)
///
/// SjisEncoder and SjisDecoders are extended to implement MS932 d/encoder.
/// Thus they clone the sjis_utf table in constructors of them.
/// Because they patches these table in constructors of MS932 d/encoder.
library sjis;

import 'dart:async';
import 'dart:convert';

part 'sjis_utf_map.dart';

const SjisCodec sjis = SjisCodec();

/// SjisCodec encodes strings to SJIS code units (bytes) and decodes
/// SJIS code units to strings.
class SjisCodec extends Encoding {
  const SjisCodec();

  @override
  String get name => 'shift_jis';

  @override
  Converter<String, List<int>> get encoder => SjisEncoder();
  @override
  Converter<List<int>, String> get decoder => SjisDecoder();
}

/// This class converts Strings to their SJIS code units.
class SjisEncoder extends Converter<String, List<int>> {
  static final _instance = SjisEncoder._internal();
  final utfSjis =
      <int, int>{}; // utf_sjis is generated at constructor of SjisEncoder.

  factory SjisEncoder() => _instance;

  SjisEncoder._internal() {
    gSjisUtf.forEach((k, v) {
      utfSjis[v] = k;
    });
  }

  @override
  List<int> convert(String input) {
    var sjisCodeUnits = <int>[];

    for (var codeUnit in input.runes) {
      var sjisCodeUnit = utfSjis[codeUnit];
      if (sjisCodeUnit != null) {
        if (sjisCodeUnit < 256) {
          sjisCodeUnits.add(sjisCodeUnit);
        } else {
          sjisCodeUnits.add(sjisCodeUnit >> 8);
          sjisCodeUnits.add(sjisCodeUnit & 255);
        }
      } else {
        throw FormatException(
            "Couldn't find corresponding code to U+${codeUnit.toRadixString(16)}");
      }
    }

    return sjisCodeUnits;
  }

  // Override the base-classes bind, to provide a better type.
  @override
  Stream<List<int>> bind(Stream<String> stream) => super.bind(stream);
}

/// This class converts SJIS code units to a string.
class SjisDecoder extends Converter<List<int>, String> {
  final sjisUtf = <int, int>{};
  static final _instance = SjisDecoder._internal();

  factory SjisDecoder() => _instance;

  SjisDecoder._internal() {
    sjisUtf.addAll(gSjisUtf);
  }

  @override
  String convert(List<int> input) {
    var stringBuffer = StringBuffer();

    void addToBuffer(int charCode) {
      var key = sjisUtf[charCode];
      if (key != null) {
        stringBuffer.writeCharCode(key);
      } else {
        throw FormatException('Bad encoding 0x${charCode.toRadixString(16)}');
      }
    }

    for (var i = 0; i < input.length; i++) {
      var byte = input[i];

      if (gDoubleBytes.contains(byte)) {
        // Double byte char
        i++;

        if (i >= input.length) {
          throw FormatException('Bad encoding 0x${byte.toRadixString(16)}');
        }

        var doubleBytes = (byte << 8) + input[i];
        addToBuffer(doubleBytes);
      } else {
        addToBuffer(byte);
      }
    }

    return stringBuffer.toString();
  }

  // Override the base-classes bind, to provide a better type.
  @override
  Stream<String> bind(Stream<List<int>> stream) => super.bind(stream);
}
