import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

/// An integer-indexed collection to test membership status.
abstract class BitSet {
  /// Whether the value specified by the [index] is member of the collection.
  bool operator [](int index);

  /// The largest addressable or contained member of the [BitSet]:
  /// - Immutable sets should return the largest contained member.
  /// - Fixed-memory sets should return the maximum addressable value.
  int get length;

  /// The number of members.
  int get cardinality;

  /// Creates a copy of the current [BitSet].
  BitSet clone();

  /// Returns an iterable wrapper that returns the content of the [BitSet] as
  /// 32-bit int blocks. Members are iterated from a zero-based index and each
  /// block contains 32 values as a bit index.
  Iterable<int> asUint32Iterable();

  /// Returns an iterable wrapper of the [BitSet] that iterates over the index
  /// members that are set to true.
  Iterable<int> asIntIterable();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is BitSet &&
        runtimeType == other.runtimeType &&
        length == other.length) {
      final iter = asUint32Iterable().iterator;
      final otherIter = other.asUint32Iterable().iterator;
      while (iter.moveNext() && otherIter.moveNext()) {
        if (iter.current != otherIter.current) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  @override
  int get hashCode =>
      asUint32Iterable().fold(
          0, (int previousValue, element) => previousValue ^ element.hashCode) ^
      length.hashCode;
}

/// Memory-efficient empty [BitSet].
class EmptySet implements BitSet {
  const EmptySet();

  @override
  bool operator [](int index) => false;

  @override
  int get length => 0;

  @override
  int get cardinality => 0;

  @override
  BitSet clone() => this;

  @override
  Iterable<int> asIntIterable() => const Iterable<int>.empty();

  @override
  Iterable<int> asUint32Iterable() => const Iterable<int>.empty();
}

/// Memory-efficient empty [BitSet] instance.
const emptyBitSet = EmptySet();

/// A list-based [BitSet] implementation.
class ListSet extends BitSet {
  final List<int> _list;

  ListSet.fromSorted(this._list);

  /// The list of values, in a sorted order.
  ///
  /// Exposed only for serialization, do NOT call or modify them directly.
  List<int> get values => _list;

  @override
  bool operator [](int index) {
    var left = 0;
    var right = _list.length - 1;
    while (left <= right) {
      final mid = (left + right) >> 1;
      final value = _list[mid];
      if (value < index) {
        left = mid + 1;
      } else if (value > index) {
        right = mid - 1;
      } else {
        return true;
      }
    }
    return false;
  }

  @override
  int get length => _list.isEmpty ? 0 : _list.last;

  @override
  int get cardinality {
    return _list.length;
  }

  @override
  BitSet clone() {
    return ListSet.fromSorted(_cloneList(_list));
  }

  @override
  Iterable<int> asUint32Iterable() => _toUint32Iterable(asIntIterable());

  @override
  Iterable<int> asIntIterable() => _list;
}

/// A range-based [BitSet] implementation.
class RangeSet extends BitSet {
  final List<int> _list;

  RangeSet.fromSortedRangeLength(this._list);

  /// The list of range+length encoded ranges, in a sorted order.
  ///
  /// Exposed only for serialization, do NOT call or modify them directly.
  List<int> get rangeLengthValues => _list;

  @override
  bool operator [](int index) {
    var left = 0;
    var right = (_list.length >> 1) - 1;
    while (left <= right) {
      final mid = (left + right) >> 1;
      final midIndex = mid << 1;
      final start = _list[midIndex];
      final end = start + _list[midIndex + 1];
      if (end < index) {
        left = mid + 1;
      } else if (start > index) {
        right = mid - 1;
      } else {
        return true;
      }
    }
    return false;
  }

  @override
  int get length {
    if (_list.isEmpty) return 0;
    final lastIndex = _list.length - 2;
    return _list[lastIndex] + _list[lastIndex + 1];
  }

  @override
  int get cardinality {
    var value = _list.length >> 1;
    for (var i = 1; i < _list.length; i += 2) {
      value += _list[i];
    }
    return value;
  }

  @override
  BitSet clone() {
    return ListSet.fromSorted(_cloneList(_list));
  }

  @override
  Iterable<int> asUint32Iterable() => _toUint32Iterable(asIntIterable());

  @override
  Iterable<int> asIntIterable() sync* {
    for (var i = 0; i < _list.length; i += 2) {
      var value = _list[i];
      for (var j = _list[i + 1]; j >= 0; j--) {
        yield value;
        value++;
      }
    }
  }
}

Iterable<int> _toUint32Iterable(Iterable<int> values) sync* {
  final iter = values.iterator;
  var blockOffset = 0;
  var blockLast = 31;
  var block = 0;
  var hasCurrent = iter.moveNext();
  while (hasCurrent) {
    if (block == 0 && iter.current > blockLast) {
      yield 0;
      blockOffset += 32;
      blockLast += 32;
      continue;
    } else if (iter.current <= blockLast) {
      final offset = iter.current - blockOffset;
      block |= _bitMask[offset];
      hasCurrent = iter.moveNext();
      continue;
    } else {
      yield block;
      block = 0;
      blockOffset += 32;
      blockLast += 32;
    }
  }
  if (block != 0) {
    yield block;
  }
}

List<int> _cloneList(List<int> list) {
  if (list is Uint16List) {
    final clone = Uint16List(list.length);
    clone.setRange(0, list.length, list);
    return clone;
  } else if (list is Uint8List) {
    final clone = Uint8List(list.length);
    clone.setRange(0, list.length, list);
    return clone;
  } else if (list is Uint32List) {
    final clone = Uint32List(list.length);
    clone.setRange(0, list.length, list);
    return clone;
  } else {
    return List<int>.from(list);
  }
}

/// Bit array to store bits.
class BitSetArray extends BitSet {
  Uint32List _data;
  int _length;

  BitSetArray._(this._data) : _length = _data.length << 5;

  /// Creates a bit array with maximum [length] items.
  ///
  /// [length] will be rounded up to match the 32-bit boundary.
  factory BitSetArray(int length) =>
      BitSetArray._(Uint32List(_bufferLength32(length)));

  /// Creates a bit array using a byte buffer.
  factory BitSetArray.fromByteBuffer(ByteBuffer buffer) {
    final data = buffer.asUint32List();
    return BitSetArray._(data);
  }

  /// Creates a bit array using a generic bit set.
  factory BitSetArray.fromBitSet(BitSet set, {int? length}) {
    length ??= set.length;
    final setDataLength = _bufferLength32(set.length);
    final data = Uint32List(_bufferLength32(length));
    data.setRange(0, setDataLength, set.asUint32Iterable());
    return BitSetArray._(data);
  }

  /// The value of the bit with the specified [index].
  @override
  bool operator [](int index) {
    return (_data[index >> 5] & _bitMask[index & 0x1f]) != 0;
  }

  /// Sets the bit specified by the [index] to the [value].
  void operator []=(int index, bool value) {
    if (value) {
      setBit(index);
    } else {
      clearBit(index);
    }
  }

  /// The number of bit in this [BitSetArray].
  ///
  /// [length] will be rounded up to match the 32-bit boundary.
  ///
  /// The valid index values for the array are `0` through `length - 1`.
  @override
  int get length => _length;
  set length(int value) {
    if (_length == value) {
      return;
    }
    final data = Uint32List(_bufferLength32(value));
    data.setRange(0, math.min(data.length, _data.length), _data);
    _data = data;
    _length = _data.length << 5;
  }

  /// The number of bits set to true.
  @override
  int get cardinality => _data.buffer
      .asUint8List()
      .fold(0, (sum, value) => sum + _cardinalityBitCounts[value]);

  /// Whether the [BitSetArray] is empty == has only zero values.
  bool get isEmpty {
    return _data.every((i) => i == 0);
  }

  /// Whether the [BitSetArray] is not empty == has set values.
  bool get isNotEmpty {
    return _data.any((i) => i != 0);
  }

  /// Sets the bit specified by the [index] to false.
  void clearBit(int index) {
    _data[index >> 5] &= _clearMask[index & 0x1f];
  }

  /// Sets the bits specified by the [indexes] to false.
  void clearBits(Iterable<int> indexes) {
    indexes.forEach(clearBit);
  }

  /// Sets all of the bits in the current [BitSetArray] to false.
  void clearAll() {
    for (var i = 0; i < _data.length; i++) {
      _data[i] = 0;
    }
  }

  /// Sets the bit specified by the [index] to true.
  void setBit(int index) {
    _data[index >> 5] |= _bitMask[index & 0x1f];
  }

  /// Sets the bits specified by the [indexes] to true.
  void setBits(Iterable<int> indexes) {
    indexes.forEach(setBit);
  }

  /// Sets all the bit values in the current [BitSetArray] to true.
  void setAll() {
    for (var i = 0; i < _data.length; i++) {
      _data[i] = -1;
    }
  }

  /// Inverts the bit specified by the [index].
  void invertBit(int index) {
    this[index] = !this[index];
  }

  /// Inverts the bits specified by the [indexes].
  void invertBits(Iterable<int> indexes) {
    indexes.forEach(invertBit);
  }

  /// Inverts all the bit values in the current [BitSetArray].
  void invertAll() {
    for (var i = 0; i < _data.length; i++) {
      _data[i] = ~(_data[i]);
    }
  }

  /// Update the current [BitSetArray] using a logical AND operation with the
  /// corresponding elements in the specified [set].
  /// Excess size of the [set] is ignored.
  void and(BitSet set) {
    final iter = set.asUint32Iterable().iterator;
    var i = 0;
    for (; i < _data.length && iter.moveNext(); i++) {
      _data[i] &= iter.current;
    }
    for (; i < _data.length; i++) {
      _data[i] = 0;
    }
  }

  /// Update the current [BitSetArray] using a logical AND NOT operation with the
  /// corresponding elements in the specified [set].
  /// Excess size of the [set] is ignored.
  void andNot(BitSet set) {
    final iter = set.asUint32Iterable().iterator;
    for (var i = 0; i < _data.length && iter.moveNext(); i++) {
      _data[i] &= ~iter.current;
    }
  }

  /// Update the current [BitSetArray] using a logical OR operation with the
  /// corresponding elements in the specified [set].
  /// Excess size of the [set] is ignored.
  void or(BitSet set) {
    final iter = set.asUint32Iterable().iterator;
    for (var i = 0; i < _data.length && iter.moveNext(); i++) {
      _data[i] |= iter.current;
    }
  }

  /// Update the current [BitSetArray] using a logical XOR operation with the
  /// corresponding elements in the specified [set].
  /// Excess size of the [set] is ignored.
  void xor(BitSet set) {
    final iter = set.asUint32Iterable().iterator;
    for (var i = 0; i < _data.length && iter.moveNext(); i++) {
      _data[i] = _data[i] ^ iter.current;
    }
  }

  /// Creates a copy of the current [BitSetArray].
  @override
  BitSetArray clone() {
    final newData = Uint32List(_data.length);
    newData.setRange(0, _data.length, _data);
    return BitSetArray._(newData);
  }

  /// Creates a [BitSetArray] using a logical AND operation with the
  /// corresponding elements in the specified [set].
  /// Excess size of the [set] is ignored.
  BitSetArray operator &(BitSet set) => clone()..and(set);

  /// Creates a [BitSetArray] using a logical AND NOT operation with the
  /// corresponding elements in the specified [set].
  /// Excess size of the [set] is ignored.
  BitSetArray operator %(BitSet set) => clone()..andNot(set);

  /// Creates a [BitSetArray] using a logical OR operation with the
  /// corresponding elements in the specified [set].
  /// Excess size of the [set] is ignored.
  BitSetArray operator |(BitSet set) => clone()..or(set);

  /// Creates a [BitSetArray] using a logical XOR operation with the
  /// corresponding elements in the specified [set].
  /// Excess size of the [set] is ignored.
  BitSetArray operator ^(BitSet set) => clone()..xor(set);

  /// Creates a string of 0s and 1s of the content of the array.
  String toBinaryString() {
    final sb = StringBuffer();
    for (var i = 0; i < length; i++) {
      sb.write(this[i] ? '1' : '0');
    }
    return sb.toString();
  }

  /// The backing, mutable byte buffer of the [BitSetArray].
  /// Use with caution.
  ByteBuffer get byteBuffer => _data.buffer;

  /// Returns an iterable wrapper of the bit array that iterates over the index
  /// numbers and returns the 32-bit int blocks.
  @override
  Iterable<int> asUint32Iterable() => _data;

  /// Returns an iterable wrapper of the bit array that iterates over the index
  /// numbers that match [value] (by default the bits that are set).
  @override
  Iterable<int> asIntIterable([bool value = true]) {
    return _IntIterable(this, value);
  }
}

final _bitMask = List<int>.generate(32, (i) => 1 << i);
final _clearMask = List<int>.generate(32, (i) => ~(1 << i));
final _cardinalityBitCounts = List<int>.generate(256, _cardinalityOfByte);

int _cardinalityOfByte(int value) {
  var result = 0;
  while (value > 0) {
    if (value & 0x01 != 0) {
      result++;
    }
    value = value >> 1;
  }
  return result;
}

class _IntIterable extends IterableBase<int> {
  final BitSetArray _array;
  final bool _value;
  _IntIterable(this._array, this._value);

  @override
  Iterator<int> get iterator =>
      _IntIterator(_array._data, _array.length, _value);
}

class _IntIterator implements Iterator<int> {
  final Uint32List _buffer;
  final int _length;
  final bool _matchValue;
  final int _skipMatch;
  final int _cursorMax = (1 << 31);
  int _current = -1;
  int _cursor = 0;
  int _cursorByte = 0;
  int _cursorMask = 1;

  _IntIterator(this._buffer, this._length, this._matchValue)
      : _skipMatch = _matchValue ? 0x00 : 0xffffffff;

  @override
  int get current => _current;

  @override
  bool moveNext() {
    while (_cursor < _length) {
      final value = _buffer[_cursorByte];
      if (_cursorMask == 1 && value == _skipMatch) {
        _cursorByte++;
        _cursor += 32;
        continue;
      }
      final isSet = (value & _cursorMask) != 0;
      if (isSet == _matchValue) {
        _current = _cursor;
        _increment();
        return true;
      }
      _increment();
    }
    return false;
  }

  void _increment() {
    if (_cursorMask == _cursorMax) {
      _cursorMask = 1;
      _cursorByte++;
    } else {
      _cursorMask <<= 1;
    }
    _cursor++;
  }
}

int _bufferLength32(int length) {
  final hasExtra = (length & 0x1f) != 0;
  return (length >> 5) + (hasExtra ? 1 : 0);
}
