import 'dart:typed_data';
import '../system.dart' as system;
import 'generic_gf.dart';
import 'generic_gf_poly.dart';

/// <p>Implements Reed-Solomon encoding, as the name implies.</p>
///
/// @author Sean Owen
/// @author William Rucklidge
class ReedSolomonEncoder {
  final GenericGF _field;
  final _cachedGenerators = <GenericGFPoly>[];

  ReedSolomonEncoder(this._field) {
    _cachedGenerators.add(GenericGFPoly(_field, Int32List.fromList([1])));
  }

  GenericGFPoly buildGenerator(int degree) {
    if (degree >= _cachedGenerators.length) {
      var lastGenerator = _cachedGenerators[_cachedGenerators.length - 1];
      for (var d = _cachedGenerators.length; d <= degree; d++) {
        var nextGenerator = lastGenerator.multiply(GenericGFPoly(_field,
            Int32List.fromList([1, _field.exp(d - 1 + _field.generatorBase)])));
        _cachedGenerators.add(nextGenerator);
        lastGenerator = nextGenerator;
      }
    }
    return _cachedGenerators[degree];
  }

  void encode(List<int> toEncode, int ecBytes) {
    if (ecBytes == 0) {
      throw ArgumentError('No error correction bytes');
    }
    var dataBytes = toEncode.length - ecBytes;
    if (dataBytes <= 0) {
      throw ArgumentError('No data bytes provided');
    }
    var generator = buildGenerator(ecBytes);
    var infoCoefficients = Int32List(dataBytes);
    system.arraycopy(toEncode, 0, infoCoefficients, 0, dataBytes);
    var info = GenericGFPoly(_field, infoCoefficients);
    info = info.multiplyByMonomial(ecBytes, 1);
    var remainder = info.divide(generator)[1];
    var coefficients = remainder.coefficients;
    var numZeroCoefficients = ecBytes - coefficients.length;
    for (var i = 0; i < numZeroCoefficients; i++) {
      toEncode[dataBytes + i] = 0;
    }
    system.arraycopy(coefficients, 0, toEncode, dataBytes + numZeroCoefficients,
        coefficients.length);
  }
}
