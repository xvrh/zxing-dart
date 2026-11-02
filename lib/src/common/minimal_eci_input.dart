import 'dart:typed_data';
import 'character_set_eci.dart';
import 'eci_encoder_set.dart';
import 'eci_input.dart';

/// Class that converts a character string into a sequence of ECIs and bytes
///
/// The implementation uses the Dijkstra algorithm to produce minimal encodings
///
/// @author Alex Geller
class MinimalECIInput implements ECIInput {
  static const _costPerEci = 3; // approximated (latch + 2 codewords)
  static const _maxInt = 0x7fffffff;
  late final Int32List _bytes;
  final int _fnc1;

  /// Constructs a minimal input
  ///
  /// @param stringToEncode the character string to encode
  /// @param priorityCharset The preferred {@link Charset}. When the value of the argument is null, the algorithm
  ///   chooses charsets that leads to a minimal representation. Otherwise the algorithm will use the priority
  ///   charset to encode any character in the input that can be encoded by it if the charset is among the
  ///   supported charsets.
  /// @param fnc1 denotes the character in the input that represents the FNC1 character or -1 if this is not GS1
  ///   input.
  MinimalECIInput(
      String stringToEncode, CharacterSetECI? priorityCharset, int fnc1)
      : _fnc1 = fnc1 {
    var encoderSet = ECIEncoderSet(stringToEncode, priorityCharset, fnc1);
    if (encoderSet.length == 1) {
      //optimization for the case when all can be encoded without ECI in ISO-8859-1
      _bytes = Int32List(stringToEncode.length);
      for (var i = 0; i < _bytes.length; i++) {
        var c = stringToEncode.codeUnitAt(i);
        _bytes[i] = c == fnc1 ? 1000 : c;
      }
    } else {
      _bytes = _encodeMinimally(stringToEncode, encoderSet, fnc1);
    }
  }

  int get fnc1Character {
    return _fnc1;
  }

  /// Returns the length of this input.  The length is the number
  /// of {@code byte}s, FNC1 characters or ECIs in the sequence.
  ///
  /// @return  the number of {@code char}s in this sequence
  @override
  int get length {
    return _bytes.length;
  }

  @override
  bool haveNCharacters(int index, int n) {
    if (index + n - 1 >= _bytes.length) {
      return false;
    }
    for (var i = 0; i < n; i++) {
      if (isECI(index + i)) {
        return false;
      }
    }
    return true;
  }

  /// Returns the {@code byte} value at the specified index.  An index ranges from zero
  /// to {@code length() - 1}.  The first {@code byte} value of the sequence is at
  /// index zero, the next at index one, and so on, as for array
  /// indexing.
  ///
  /// @param   index the index of the {@code byte} value to be returned
  ///
  /// @return  the specified {@code byte} value as character or the FNC1 character
  ///
  /// @throws  IndexOutOfBoundsException
  ///          if the {@code index} argument is negative or not less than
  ///          {length()}
  /// @throws  IllegalArgumentException
  ///          if the value at the {@code index} argument is an ECI (@see #isECI)
  @override
  int charAt(int index) {
    if (index < 0 || index >= length) {
      throw RangeError('$index');
    }
    if (isECI(index)) {
      throw ArgumentError('value at $index is not a character but an ECI');
    }
    return isFNC1(index) ? _fnc1 : _bytes[index];
  }

  /// Returns a {@code CharSequence} that is a subsequence of this sequence.
  /// The subsequence starts with the {@code char} value at the specified index and
  /// ends with the {@code char} value at index {@code end - 1}.  The length
  /// (in {@code char}s) of the
  /// returned sequence is {@code end - start}, so if {@code start == end}
  /// then an empty sequence is returned.
  ///
  /// @param   start   the start index, inclusive
  /// @param   end     the end index, exclusive
  ///
  /// @return  the specified subsequence
  ///
  /// @throws  IndexOutOfBoundsException
  ///          if {@code start} or {@code end} are negative,
  ///          if {@code end} is greater than {@code length()},
  ///          or if {@code start} is greater than {@code end}
  /// @throws  IllegalArgumentException
  ///          if a value in the range {@code start}-{@code end} is an ECI (@see #isECI)
  @override
  String subSequence(int start, int end) {
    if (start < 0 || start > end || end > length) {
      throw RangeError('$start');
    }
    var result = StringBuffer();
    for (var i = start; i < end; i++) {
      if (isECI(i)) {
        throw ArgumentError('value at $i is not a character but an ECI');
      }
      result.writeCharCode(charAt(i));
    }
    return result.toString();
  }

  /// Determines if a value is an ECI
  ///
  /// @param   index the index of the value
  ///
  /// @return  true if the value at position {@code index} is an ECI
  ///
  /// @throws  IndexOutOfBoundsException
  ///          if the {@code index} argument is negative or not less than
  ///          {length()}
  @override
  bool isECI(int index) {
    if (index < 0 || index >= length) {
      throw RangeError('$index');
    }
    return _bytes[index] > 255 && _bytes[index] <= 999;
  }

  /// Determines if a value is the FNC1 character
  ///
  /// @param   index the index of the value
  ///
  /// @return  true if the value at position {@code index} is the FNC1 character
  ///
  /// @throws  IndexOutOfBoundsException
  ///          if the {@code index} argument is negative or not less than
  ///          {length()}
  bool isFNC1(int index) {
    if (index < 0 || index >= length) {
      throw RangeError('$index');
    }
    return _bytes[index] == 1000;
  }

  /// Returns the {@code int} ECI value at the specified index.  An index ranges from zero
  /// to {@code length() - 1}.  The first {@code byte} value of the sequence is at
  /// index zero, the next at index one, and so on, as for array
  /// indexing.
  ///
  /// @param   index the index of the {@code int} value to be returned
  ///
  /// @return  the specified {@code int} ECI value.
  ///          The ECI specified the encoding of all bytes with a higher index until the
  ///          next ECI or until the end of the input if no other ECI follows.
  ///
  /// @throws  IndexOutOfBoundsException
  ///          if the {@code index} argument is negative or not less than
  ///          {length()}
  /// @throws  IllegalArgumentException
  ///          if the value at the {@code index} argument is not an ECI (@see #isECI)
  @override
  int getECIValue(int index) {
    if (index < 0 || index >= length) {
      throw RangeError('$index');
    }
    if (!isECI(index)) {
      throw ArgumentError('value at $index is not an ECI but a character');
    }
    return _bytes[index] - 256;
  }

  @override
  String toString() {
    var result = StringBuffer();
    for (var i = 0; i < length; i++) {
      if (i > 0) {
        result.write(', ');
      }
      if (isECI(i)) {
        result.write('ECI(');
        result.write(getECIValue(i));
        result.write(')');
      } else if (charAt(i) < 128) {
        result.write("'");
        result.writeCharCode(charAt(i));
        result.write("'");
      } else {
        result.write(charAt(i));
      }
    }
    return result.toString();
  }

  static void _addEdge(List<List<_InputEdge?>> edges, int to, _InputEdge edge) {
    var current = edges[to][edge.encoderIndex];
    if (current == null || current.cachedTotalSize > edge.cachedTotalSize) {
      edges[to][edge.encoderIndex] = edge;
    }
  }

  static void _addEdges(String stringToEncode, ECIEncoderSet encoderSet,
      List<List<_InputEdge?>> edges, int from, _InputEdge? previous, int fnc1) {
    var ch = stringToEncode.codeUnitAt(from);

    var start = 0;
    var end = encoderSet.length;
    if (encoderSet.priorityEncoderIndex >= 0 &&
        (ch == fnc1 ||
            encoderSet.canEncode(ch, encoderSet.priorityEncoderIndex))) {
      start = encoderSet.priorityEncoderIndex;
      end = start + 1;
    }

    for (var i = start; i < end; i++) {
      if (ch == fnc1 || encoderSet.canEncode(ch, i)) {
        _addEdge(
            edges, from + 1, _InputEdge(ch, encoderSet, i, previous, fnc1));
      }
    }
  }

  static Int32List _encodeMinimally(
      String stringToEncode, ECIEncoderSet encoderSet, int fnc1) {
    var inputLength = stringToEncode.length;

    // Array that represents vertices. There is a vertex for every character and encoding.
    var edges = List.generate(inputLength + 1,
        (_) => List<_InputEdge?>.filled(encoderSet.length, null));
    _addEdges(stringToEncode, encoderSet, edges, 0, null, fnc1);

    for (var i = 1; i <= inputLength; i++) {
      for (var j = 0; j < encoderSet.length; j++) {
        var edge = edges[i][j];
        if (edge != null && i < inputLength) {
          _addEdges(stringToEncode, encoderSet, edges, i, edge, fnc1);
        }
      }
      //optimize memory by removing edges that have been passed.
      for (var j = 0; j < encoderSet.length; j++) {
        edges[i - 1][j] = null;
      }
    }
    var minimalJ = -1;
    var minimalSize = _maxInt;
    for (var j = 0; j < encoderSet.length; j++) {
      var edge = edges[inputLength][j];
      if (edge != null) {
        if (edge.cachedTotalSize < minimalSize) {
          minimalSize = edge.cachedTotalSize;
          minimalJ = j;
        }
      }
    }
    if (minimalJ < 0) {
      throw StateError('Failed to encode "$stringToEncode"');
    }
    var intsAL = <int>[];
    var current = edges[inputLength][minimalJ];
    while (current != null) {
      if (current.isFNC1) {
        intsAL.insert(0, 1000);
      } else {
        var bytes = encoderSet.encode(current.c, current.encoderIndex);
        for (var i = bytes.length - 1; i >= 0; i--) {
          intsAL.insert(0, bytes[i] & 0xFF);
        }
      }
      var previousEncoderIndex = current.previous?.encoderIndex ?? 0;
      if (previousEncoderIndex != current.encoderIndex) {
        intsAL.insert(0, 256 + encoderSet.getECIValue(current.encoderIndex));
      }
      current = current.previous;
    }
    return Int32List.fromList(intsAL);
  }
}

class _InputEdge {
  final int c;
  final int encoderIndex; //the encoding of this edge
  final _InputEdge? previous;
  late final int cachedTotalSize;

  _InputEdge(int c, ECIEncoderSet encoderSet, this.encoderIndex, this.previous,
      int fnc1)
      : c = c == fnc1 ? 1000 : c {
    var size = this.c == 1000 ? 1 : encoderSet.encode(c, encoderIndex).length;
    var previousEncoderIndex = previous?.encoderIndex ?? 0;
    if (previousEncoderIndex != encoderIndex) {
      size += MinimalECIInput._costPerEci;
    }
    if (previous != null) {
      size += previous!.cachedTotalSize;
    }
    cachedTotalSize = size;
  }

  bool get isFNC1 {
    return c == 1000;
  }
}
