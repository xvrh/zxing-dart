import 'dart:convert';
import 'dart:typed_data';
import 'charset_tables.dart';

/// Decodes a table written by tool/generate_charsets.py: base64 of the
/// zigzag varint deltas between consecutive code units.
Uint16List decodeCharsetTable(String data) {
  var bytes = base64.decode(data);
  var codes = <int>[];
  var previous = 0;
  var value = 0;
  var shift = 0;
  for (var byte in bytes) {
    value |= (byte & 0x7F) << shift;
    if (byte & 0x80 != 0) {
      shift += 7;
      continue;
    }
    var delta = (value >> 1) ^ -(value & 1);
    previous += delta;
    codes.add(previous);
    value = 0;
    shift = 0;
  }
  return Uint16List.fromList(codes);
}

/// A character set where each byte maps to one code point, and the bytes
/// 0x00-0x7F are ASCII.
///
/// Undefined bytes decode to U+FFFD. Characters that can't be represented
/// throw an [ArgumentError] when encoding, like [Latin1Codec] does.
class SingleByteCodec extends Encoding {
  @override
  final String name;
  final List<int> _high;

  const SingleByteCodec(this.name, this._high);

  @override
  Converter<List<int>, String> get decoder => _SingleByteDecoder(_high);

  @override
  Converter<String, List<int>> get encoder => _SingleByteEncoder(name, _high);
}

class _SingleByteDecoder extends Converter<List<int>, String> {
  final List<int> _high;

  const _SingleByteDecoder(this._high);

  @override
  String convert(List<int> input) {
    var codes = Uint16List(input.length);
    for (var i = 0; i < input.length; i++) {
      var byte = input[i] & 0xFF;
      codes[i] = byte < 0x80 ? byte : _high[byte - 0x80];
    }
    return String.fromCharCodes(codes);
  }
}

class _SingleByteEncoder extends Converter<String, List<int>> {
  static final _reverseTables = <String, Map<int, int>>{};

  final String _name;
  final List<int> _high;

  const _SingleByteEncoder(this._name, this._high);

  Map<int, int> get _reverse => _reverseTables.putIfAbsent(_name, () {
        return {
          for (var i = 0; i < _high.length; i++)
            if (_high[i] != 0xFFFD) _high[i]: i + 0x80,
        };
      });

  @override
  Uint8List convert(String input) {
    var result = Uint8List(input.length);
    for (var i = 0; i < input.length; i++) {
      var code = input.codeUnitAt(i);
      if (code < 0x80) {
        result[i] = code;
      } else {
        var byte = _reverse[code];
        if (byte == null) {
          throw ArgumentError.value(
              input, 'string', 'Contains characters not in $_name');
        }
        result[i] = byte;
      }
    }
    return result;
  }
}

/// GB2312 in its EUC-CN form, as used by the QR code Hanzi mode.
///
/// Bytes that are not valid GB2312 decode to U+FFFD.
class Gb2312Codec extends Encoding {
  const Gb2312Codec();

  @override
  String get name => 'gb2312';

  @override
  Converter<List<int>, String> get decoder => const _Gb2312Decoder();

  @override
  Converter<String, List<int>> get encoder => const _Gb2312Encoder();
}

const _gb2312FirstByte = 0xA1;
const _gb2312LastLead = 0xF7;
const _gb2312LastTrail = 0xFE;
const _gb2312RowLength = 94;

final _gb2312Table = decodeCharsetTable(gb2312TableData);

class _Gb2312Decoder extends Converter<List<int>, String> {
  const _Gb2312Decoder();

  @override
  String convert(List<int> input) {
    var result = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      var lead = input[i] & 0xFF;
      if (lead < 0x80) {
        result.writeCharCode(lead);
        continue;
      }
      if (lead < _gb2312FirstByte ||
          lead > _gb2312LastLead ||
          i + 1 >= input.length ||
          (input[i + 1] & 0xFF) < _gb2312FirstByte ||
          (input[i + 1] & 0xFF) > _gb2312LastTrail) {
        // The next byte, if any, is decoded on its own
        result.writeCharCode(0xFFFD);
        continue;
      }
      var trail = input[++i] & 0xFF;
      result.writeCharCode(_gb2312Table[
          (lead - _gb2312FirstByte) * _gb2312RowLength +
              trail -
              _gb2312FirstByte]);
    }
    return result.toString();
  }
}

class _Gb2312Encoder extends Converter<String, List<int>> {
  static final _reverse = () {
    var reverse = <int, int>{};
    for (var i = 0; i < _gb2312Table.length; i++) {
      var code = _gb2312Table[i];
      if (code != 0xFFFD) {
        var lead = _gb2312FirstByte + i ~/ _gb2312RowLength;
        var trail = _gb2312FirstByte + i % _gb2312RowLength;
        reverse[code] = (lead << 8) | trail;
      }
    }
    return reverse;
  }();

  const _Gb2312Encoder();

  @override
  Uint8List convert(String input) {
    var result = BytesBuilder(copy: false);
    for (var i = 0; i < input.length; i++) {
      var code = input.codeUnitAt(i);
      if (code < 0x80) {
        result.addByte(code);
        continue;
      }
      var bytes = _reverse[code];
      if (bytes == null) {
        throw ArgumentError.value(
            input, 'string', 'Contains characters not in GB2312');
      }
      result
        ..addByte(bytes >> 8)
        ..addByte(bytes & 0xFF);
    }
    return result.takeBytes();
  }
}

/// UTF-16 big endian, without byte order mark.
class Utf16BeCodec extends Encoding {
  const Utf16BeCodec();

  @override
  String get name => 'utf-16be';

  @override
  Converter<List<int>, String> get decoder => const _Utf16BeDecoder();

  @override
  Converter<String, List<int>> get encoder => const _Utf16BeEncoder();
}

class _Utf16BeDecoder extends Converter<List<int>, String> {
  const _Utf16BeDecoder();

  @override
  String convert(List<int> input) {
    var codes = Uint16List((input.length + 1) ~/ 2);
    for (var i = 0; i + 1 < input.length; i += 2) {
      codes[i ~/ 2] = ((input[i] & 0xFF) << 8) | (input[i + 1] & 0xFF);
    }
    if (input.length.isOdd) {
      codes[codes.length - 1] = 0xFFFD;
    }
    return String.fromCharCodes(codes);
  }
}

class _Utf16BeEncoder extends Converter<String, List<int>> {
  const _Utf16BeEncoder();

  @override
  Uint8List convert(String input) {
    var result = Uint8List(input.length * 2);
    for (var i = 0; i < input.length; i++) {
      var code = input.codeUnitAt(i);
      result[2 * i] = code >> 8;
      result[2 * i + 1] = code & 0xFF;
    }
    return result;
  }
}
