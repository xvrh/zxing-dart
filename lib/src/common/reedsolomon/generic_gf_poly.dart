import 'dart:typed_data';
import '../system.dart' as system;
import 'generic_gf.dart';

/// <p>Represents a polynomial whose coefficients are elements of a GF.
/// Instances of this class are immutable.</p>
///
/// <p>Much credit is due to William Rucklidge since portions of this code are an indirect
/// port of his C++ Reed-Solomon implementation.</p>
///
/// @author Sean Owen
class GenericGFPoly {
  final GenericGF _field;
  late final Int32List _coefficients;

  /// @param field the {@link GenericGF} instance representing the field to use
  /// to perform computations
  /// @param coefficients coefficients as ints representing elements of GF(size), arranged
  /// from most significant (highest-power term) coefficient to least significant
  /// @throws ArgumentError if argument is null or empty,
  /// or if leading coefficient is 0 and this is not a
  /// constant polynomial (that is, it is not the monomial "0")
  GenericGFPoly(this._field, Int32List coefficients) {
    if (coefficients.isEmpty) {
      throw ArgumentError();
    }
    var coefficientsLength = coefficients.length;
    if (coefficientsLength > 1 && coefficients[0] == 0) {
      // Leading term must be non-zero for anything except the constant polynomial "0"
      var firstNonZero = 1;
      while (firstNonZero < coefficientsLength &&
          coefficients[firstNonZero] == 0) {
        firstNonZero++;
      }
      if (firstNonZero == coefficientsLength) {
        _coefficients = Int32List.fromList([0]);
      } else {
        _coefficients = Int32List(coefficientsLength - firstNonZero);
        system.arraycopy(coefficients, firstNonZero, this.coefficients, 0,
            this.coefficients.length);
      }
    } else {
      _coefficients = coefficients;
    }
  }

  Int32List get coefficients => _coefficients;

  /// @return degree of this polynomial
  int getDegree() {
    return coefficients.length - 1;
  }

  /// @return true iff this polynomial is the monomial "0"
  bool get isZero {
    return coefficients[0] == 0;
  }

  /// @return coefficient of x^degree term in this polynomial
  int getCoefficient(int degree) {
    return coefficients[coefficients.length - 1 - degree];
  }

  /// @return evaluation of this polynomial at a given point
  int evaluateAt(int a) {
    if (a == 0) {
      // Just return the x^0 coefficient
      return getCoefficient(0);
    }
    if (a == 1) {
      // Just the sum of the coefficients
      var result = 0;
      for (var coefficient in coefficients) {
        result = GenericGF.addOrSubtract(result, coefficient);
      }
      return result;
    }
    var result = coefficients[0];
    var size = coefficients.length;
    for (var i = 1; i < size; i++) {
      result =
          GenericGF.addOrSubtract(_field.multiply(a, result), coefficients[i]);
    }
    return result;
  }

  GenericGFPoly addOrSubtract(GenericGFPoly other) {
    if (_field != other._field) {
      throw ArgumentError('GenericGFPolys do not have same GenericGF field');
    }
    if (isZero) {
      return other;
    }
    if (other.isZero) {
      return this;
    }

    var smallerCoefficients = coefficients;
    var largerCoefficients = other.coefficients;
    if (smallerCoefficients.length > largerCoefficients.length) {
      var temp = smallerCoefficients;
      smallerCoefficients = largerCoefficients;
      largerCoefficients = temp;
    }
    var sumDiff = Int32List(largerCoefficients.length);
    var lengthDiff = largerCoefficients.length - smallerCoefficients.length;
    // Copy high-order terms only found in higher-degree polynomial's coefficients
    system.arraycopy(largerCoefficients, 0, sumDiff, 0, lengthDiff);

    for (var i = lengthDiff; i < largerCoefficients.length; i++) {
      sumDiff[i] = GenericGF.addOrSubtract(
          smallerCoefficients[i - lengthDiff], largerCoefficients[i]);
    }

    return GenericGFPoly(_field, sumDiff);
  }

  GenericGFPoly multiply(GenericGFPoly other) {
    if (_field != other._field) {
      throw ArgumentError('GenericGFPolys do not have same GenericGF field');
    }
    if (isZero || other.isZero) {
      return _field.zero;
    }
    var aCoefficients = coefficients;
    var aLength = aCoefficients.length;
    var bCoefficients = other.coefficients;
    var bLength = bCoefficients.length;
    var product = Int32List(aLength + bLength - 1);
    for (var i = 0; i < aLength; i++) {
      var aCoeff = aCoefficients[i];
      for (var j = 0; j < bLength; j++) {
        product[i + j] = GenericGF.addOrSubtract(
            product[i + j], _field.multiply(aCoeff, bCoefficients[j]));
      }
    }
    return GenericGFPoly(_field, product);
  }

  GenericGFPoly multiplyScalar(int scalar) {
    if (scalar == 0) {
      return _field.zero;
    }
    if (scalar == 1) {
      return this;
    }
    var size = coefficients.length;
    var product = Int32List(size);
    for (var i = 0; i < size; i++) {
      product[i] = _field.multiply(coefficients[i], scalar);
    }
    return GenericGFPoly(_field, product);
  }

  GenericGFPoly multiplyByMonomial(int degree, int coefficient) {
    if (degree < 0) {
      throw ArgumentError();
    }
    if (coefficient == 0) {
      return _field.zero;
    }
    var size = coefficients.length;
    var product = Int32List(size + degree);
    for (var i = 0; i < size; i++) {
      product[i] = _field.multiply(coefficients[i], coefficient);
    }
    return GenericGFPoly(_field, product);
  }

  List<GenericGFPoly> divide(GenericGFPoly other) {
    if (_field != other._field) {
      throw ArgumentError('GenericGFPolys do not have same GenericGF field');
    }
    if (other.isZero) {
      throw ArgumentError('Divide by 0');
    }

    var quotient = _field.zero;
    var remainder = this;

    var denominatorLeadingTerm = other.getCoefficient(other.getDegree());
    var inverseDenominatorLeadingTerm = _field.inverse(denominatorLeadingTerm);

    while (remainder.getDegree() >= other.getDegree() && !remainder.isZero) {
      var degreeDifference = remainder.getDegree() - other.getDegree();
      var scale = _field.multiply(
          remainder.getCoefficient(remainder.getDegree()),
          inverseDenominatorLeadingTerm);
      var term = other.multiplyByMonomial(degreeDifference, scale);
      var iterationQuotient = _field.buildMonomial(degreeDifference, scale);
      quotient = quotient.addOrSubtract(iterationQuotient);
      remainder = remainder.addOrSubtract(term);
    }

    return [quotient, remainder];
  }

  @override
  String toString() {
    if (isZero) {
      return '0';
    }
    var result = StringBuffer();
    for (var degree = getDegree(); degree >= 0; degree--) {
      var coefficient = getCoefficient(degree);
      if (coefficient != 0) {
        if (coefficient < 0) {
          if (degree == getDegree()) {
            result.write('-');
          } else {
            result.write(' - ');
          }
          coefficient = -coefficient;
        } else {
          if (result.length > 0) {
            result.write(' + ');
          }
        }
        if (degree == 0 || coefficient != 1) {
          var alphaPower = _field.log(coefficient);
          if (alphaPower == 0) {
            result.write('1');
          } else if (alphaPower == 1) {
            result.write('a');
          } else {
            result.write('a^');
            result.write(alphaPower);
          }
        }
        if (degree != 0) {
          if (degree == 1) {
            result.write('x');
          } else {
            result.write('x^');
            result.write(degree);
          }
        }
      }
    }
    return result.toString();
  }
}
