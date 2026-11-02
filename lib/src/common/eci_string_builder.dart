import '../format_reader_exception.dart';
import 'character_set_eci.dart';

/// Class that converts a sequence of ECIs and bytes into a string
///
/// @author Alex Geller
class ECIStringBuilder {
  StringBuffer _currentBytes = StringBuffer();
  StringBuffer? _result;
  CharacterSetECI _currentCharset = CharacterSetECI.ISO8859_1;

  /// Appends {@code value} as a byte value
  ///
  /// @param value character whose lowest byte is to be appended
  void appendCharCode(int value) {
    _currentBytes.writeCharCode(value & 0xff);
  }

  /// Appends the characters in {@code value} as bytes values
  ///
  /// @param value string to append
  void append(String value) {
    _currentBytes.write(value);
  }

  /// Appends ECI value to output.
  ///
  /// @param value ECI value to append, as an int
  /// @throws FormatReaderException on invalid ECI value
  void appendECI(int value) {
    _encodeCurrentBytesIfAny();
    var characterSetECI = CharacterSetECI.getCharacterSetECIByValue(value);
    if (characterSetECI == null) {
      throw FormatReaderException();
    }
    _currentCharset = characterSetECI;
  }

  void _encodeCurrentBytesIfAny() {
    if (_currentBytes.isEmpty) {
      return;
    }
    var result = _result ??= StringBuffer();
    if (_currentCharset == CharacterSetECI.ISO8859_1) {
      result.write(_currentBytes);
    } else {
      var bytes = _currentBytes.toString().codeUnits;
      result.write(_currentCharset.encoding.decode(bytes));
    }
    _currentBytes = StringBuffer();
  }

  /// Appends the characters from {@code value} (unlike all other append methods of this class who append bytes)
  ///
  /// @param value characters to append
  void appendCharacters(String value) {
    _encodeCurrentBytesIfAny();
    (_result ??= StringBuffer()).write(value);
  }

  /// Short for {@code toString().length()} (if possible, use {@link #isEmpty()} instead)
  ///
  /// @return length of string representation in characters
  int get length => toString().length;

  /// @return true iff nothing has been appended
  bool get isEmpty => _currentBytes.isEmpty && (_result?.isEmpty ?? true);

  @override
  String toString() {
    _encodeCurrentBytesIfAny();
    return _result?.toString() ?? '';
  }
}
