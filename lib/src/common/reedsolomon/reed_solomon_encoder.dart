/*
 * Copyright 2008 ZXing authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:typed_data';

import 'generic_gf.dart';
import 'generic_gf_poly.dart';
import '../system.dart' as system;

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
      GenericGFPoly lastGenerator =
          _cachedGenerators[_cachedGenerators.length - 1];
      for (int d = _cachedGenerators.length; d <= degree; d++) {
        GenericGFPoly nextGenerator = lastGenerator.multiply(GenericGFPoly(
            _field,
            Int32List.fromList([1, _field.exp(d - 1 + _field.generatorBase)])));
        _cachedGenerators.add(nextGenerator);
        lastGenerator = nextGenerator;
      }
    }
    return _cachedGenerators[degree];
  }

  void encode(List<int> toEncode, int ecBytes) {
    if (ecBytes == 0) {
      throw ArgumentError("No error correction bytes");
    }
    int dataBytes = toEncode.length - ecBytes;
    if (dataBytes <= 0) {
      throw ArgumentError("No data bytes provided");
    }
    GenericGFPoly generator = buildGenerator(ecBytes);
    var infoCoefficients = Int32List(dataBytes);
    system.arraycopy(toEncode, 0, infoCoefficients, 0, dataBytes);
    GenericGFPoly info = GenericGFPoly(_field, infoCoefficients);
    info = info.multiplyByMonomial(ecBytes, 1);
    GenericGFPoly remainder = info.divide(generator)[1];
    var coefficients = remainder.coefficients;
    int numZeroCoefficients = ecBytes - coefficients.length;
    for (int i = 0; i < numZeroCoefficients; i++) {
      toEncode[dataBytes + i] = 0;
    }
    system.arraycopy(coefficients, 0, toEncode, dataBytes + numZeroCoefficients,
        coefficients.length);
  }
}
