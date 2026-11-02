import 'dart:convert';
import 'dart:typed_data';
import 'charset_tables.dart';
import 'charsets.dart';

/// Shift_JIS (JIS X 0213), with the bytes 0x00-0x7F kept as ASCII like Java's
/// Shift_JIS.
///
/// Malformed input decodes to U+FFFD. Characters that can't be represented
/// throw an [ArgumentError] when encoding.
const SjisCodec sjis = SjisCodec();

class SjisCodec extends Encoding {
  const SjisCodec();

  @override
  String get name => 'shift_jis';

  @override
  Converter<List<int>, String> get decoder => const _SjisDecoder();

  @override
  Converter<String, List<int>> get encoder => const _SjisEncoder();
}

const _trailFirst = 0x40;
const _trailLast = 0xFC;
const _rowLength = _trailLast - _trailFirst + 1;
const _katakanaFirstByte = 0xA1;
const _katakanaLastByte = 0xDF;
const _katakanaFirstChar = 0xFF61;

final _sjisTable = decodeCharsetTable(sjisTableData);

bool _isLeadByte(int byte) =>
    (byte >= 0x81 && byte <= 0x9F) || (byte >= 0xE0 && byte <= 0xFC);

int _rowOf(int lead) => lead <= 0x9F ? lead - 0x81 : lead - 0xE0 + 0x1F;

int _leadOf(int row) => row < 0x1F ? row + 0x81 : row - 0x1F + 0xE0;

class _SjisDecoder extends Converter<List<int>, String> {
  const _SjisDecoder();

  @override
  String convert(List<int> input) {
    var result = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      var byte = input[i] & 0xFF;
      if (byte < 0x80) {
        result.writeCharCode(byte);
      } else if (byte >= _katakanaFirstByte && byte <= _katakanaLastByte) {
        // Half-width katakana
        result.writeCharCode(_katakanaFirstChar + byte - _katakanaFirstByte);
      } else if (!_isLeadByte(byte) ||
          i + 1 >= input.length ||
          (input[i + 1] & 0xFF) < _trailFirst ||
          (input[i + 1] & 0xFF) > _trailLast) {
        // The next byte, if any, is decoded on its own
        result.writeCharCode(0xFFFD);
      } else {
        var trail = input[++i] & 0xFF;
        var char = _sjisTable[_rowOf(byte) * _rowLength + trail - _trailFirst];
        if (char == 0xFFFD) {
          result.write(sjisExtras[(byte << 8) | trail] ?? '\uFFFD');
        } else {
          result.writeCharCode(char);
        }
      }
    }
    return result.toString();
  }
}

class _SjisEncoder extends Converter<String, List<int>> {
  static final _doubleBytes = () {
    var codes = <int, int>{};
    for (var i = 0; i < _sjisTable.length; i++) {
      var char = _sjisTable[i];
      if (char != 0xFFFD) {
        var lead = _leadOf(i ~/ _rowLength);
        var trail = i % _rowLength + _trailFirst;
        codes.putIfAbsent(char, () => (lead << 8) | trail);
      }
    }
    sjisExtras.forEach((code, text) {
      if (text.runes.length == 1) {
        codes.putIfAbsent(text.runes.first, () => code);
      }
    });
    return codes;
  }();

  const _SjisEncoder();

  @override
  Uint8List convert(String input) {
    var result = BytesBuilder(copy: false);
    for (var rune in input.runes) {
      if (rune < 0x80) {
        result.addByte(rune);
      } else if (rune == 0xA5) {
        // ¥ and ‾ share the bytes of \ and ~ in JIS X 0201
        result.addByte(0x5C);
      } else if (rune == 0x203E) {
        result.addByte(0x7E);
      } else if (rune >= _katakanaFirstChar &&
          rune <= _katakanaFirstChar + _katakanaLastByte - _katakanaFirstByte) {
        result.addByte(rune - _katakanaFirstChar + _katakanaFirstByte);
      } else {
        var code = _doubleBytes[rune];
        if (code == null) {
          throw ArgumentError.value(
              input, 'string', 'Contains characters not in Shift_JIS');
        }
        result
          ..addByte(code >> 8)
          ..addByte(code & 0xFF);
      }
    }
    return result.takeBytes();
  }
}
