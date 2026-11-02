import '../../dimension.dart';
import 'symbol_info.dart';
import 'symbol_shape_hint.dart';

class EncoderContext {
  final String message;
  SymbolShapeHint symbolShape = SymbolShapeHint.forceNone;
  Dimension? _minSize;
  Dimension? _maxSize;
  final StringBuffer codewords = StringBuffer();
  int pos = 0;
  int _newEncoding = -1;
  SymbolInfo? _symbolInfo;
  int skipAtEnd = 0;

  EncoderContext(String msg) : message = msg {
    //From this point on Strings are not Unicode anymore!
    for (var i = 0; i < msg.length; i++) {
      if (msg.codeUnitAt(i) > 0xff) {
        throw ArgumentError(
            'Message contains characters outside ISO-8859-1 encoding.');
      }
    }
  }

  void setSizeConstraints(Dimension? minSize, Dimension? maxSize) {
    _minSize = minSize;
    _maxSize = maxSize;
  }

  int get currentChar {
    return message.codeUnitAt(pos);
  }

  int get current {
    return message.codeUnitAt(pos);
  }

  void writeCodewords(String codewords) {
    this.codewords.write(codewords);
  }

  void writeCodeword(int codeword) {
    codewords.writeCharCode(codeword);
  }

  int get codewordCount {
    return codewords.length;
  }

  int get newEncoding {
    return _newEncoding;
  }

  void signalEncoderChange(int encoding) {
    _newEncoding = encoding;
  }

  void resetEncoderSignal() {
    _newEncoding = -1;
  }

  bool get hasMoreCharacters {
    return pos < _totalMessageCharCount;
  }

  int get _totalMessageCharCount {
    return message.length - skipAtEnd;
  }

  int get remainingCharacters {
    return _totalMessageCharCount - pos;
  }

  SymbolInfo get symbolInfo {
    return _symbolInfo!;
  }

  void updateSymbolInfo([int? len]) {
    len ??= codewordCount;
    if (_symbolInfo == null || len > _symbolInfo!.dataCapacity) {
      _symbolInfo = SymbolInfo.lookup(len,
          shape: symbolShape, minSize: _minSize, maxSize: _maxSize);
    }
  }

  void resetSymbolInfo() {
    _symbolInfo = null;
  }
}
