import 'dart:typed_data';
import 'package:fixnum/fixnum.dart';
import 'generic_gf_poly.dart';

/// <p>This class contains utility methods for performing mathematical operations over
/// the Galois Fields. Operations use a given primitive polynomial in calculations.</p>
///
/// <p>Throughout this package, elements of the GF are represented as an {@code int}
/// for convenience and speed (but at the cost of memory).
/// </p>
///
/// @author Sean Owen
/// @author David Olivier
class GenericGF {
  static final GenericGF aztecData12 =
      GenericGF(0x1069, 4096, 1); // x^12 + x^6 + x^5 + x^3 + 1
  static final GenericGF aztecData10 =
      GenericGF(0x409, 1024, 1); // x^10 + x^3 + 1
  static final GenericGF aztecData6 = GenericGF(0x43, 64, 1); // x^6 + x + 1
  static final GenericGF aztecParam = GenericGF(0x13, 16, 1); // x^4 + x + 1
  static final GenericGF qrCodeField256 =
      GenericGF(0x011D, 256, 0); // x^8 + x^4 + x^3 + x^2 + 1
  static final GenericGF dataMatrixField256 =
      GenericGF(0x012D, 256, 1); // x^8 + x^5 + x^3 + x^2 + 1
  static final GenericGF aztecData8 = dataMatrixField256;
  static final GenericGF maxicodeField64 = aztecData6;

  final Int32List _expTable;
  final Int32List _logTable;
  late final GenericGFPoly _zero;
  late final GenericGFPoly _one;
  final int size;
  final int primitive;
  final int generatorBase;

  /// Create a representation of GF(size) using the given primitive polynomial.
  ///
  /// @param primitive irreducible polynomial whose coefficients are represented by
  ///  the bits of an int, where the least-significant bit represents the constant
  ///  coefficient
  /// @param size the size of the field
  /// @param b the factor b in the generator polynomial can be 0- or 1-based
  ///  (g(x) = (x+a^b)(x+a^(b+1))...(x+a^(b+2t-1))).
  ///  In most cases it should be 1, but for QR code it is 0.
  GenericGF(this.primitive, this.size, this.generatorBase)
      : _expTable = Int32List(size),
        _logTable = Int32List(size) {
    var x = 1;
    for (var i = 0; i < size; i++) {
      _expTable[i] = x;
      x *= 2; // we're assuming the generator alpha is 2
      if (x >= size) {
        x ^= primitive;
        x &= size - 1;
      }
    }
    for (var i = 0; i < size - 1; i++) {
      _logTable[_expTable[i]] = i;
    }
    // logTable[0] == 0 but this should never be used
    _zero = GenericGFPoly(this, Int32List.fromList([0]));
    _one = GenericGFPoly(this, Int32List.fromList([1]));
  }

  GenericGFPoly get zero {
    return _zero;
  }

  GenericGFPoly get one {
    return _one;
  }

  /// @return the monomial representing coefficient * x^degree
  GenericGFPoly buildMonomial(int degree, int coefficient) {
    if (degree < 0) {
      throw ArgumentError();
    }
    if (coefficient == 0) {
      return zero;
    }
    var coefficients = Int32List(degree + 1);
    coefficients[0] = coefficient;
    return GenericGFPoly(this, coefficients);
  }

  /// Implements both addition and subtraction -- they are the same in GF(size).
  ///
  /// @return sum/difference of a and b
  static int addOrSubtract(int a, int b) {
    return (Int32(a) ^ Int32(b)).toInt();
  }

  /// @return 2 to the power of a in GF(size)
  int exp(int a) {
    return _expTable[a];
  }

  /// @return base 2 log of a in GF(size)
  int log(int a) {
    if (a == 0) {
      throw ArgumentError();
    }
    return _logTable[a];
  }

  /// @return multiplicative inverse of a
  int inverse(int a) {
    if (a == 0) {
      throw ArgumentError();
    }
    return _expTable[size - _logTable[a] - 1];
  }

  /// @return product of a and b in GF(size)
  int multiply(int a, int b) {
    if (a == 0 || b == 0) {
      return 0;
    }
    return _expTable[(_logTable[a] + _logTable[b]) % (size - 1)];
  }

  @override
  String toString() {
    return 'GF(0x${primitive.toRadixString(16)},$size)';
  }
}
