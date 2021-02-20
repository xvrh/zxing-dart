import 'dart:typed_data';
import 'generic_gf.dart';
import 'generic_gf_poly.dart';
import 'reed_solomon_exception.dart';

/// <p>Implements Reed-Solomon decoding, as the name implies.</p>
///
/// <p>The algorithm will not be explained here, but the following references were helpful
/// in creating this implementation:</p>
///
/// <ul>
/// <li>Bruce Maggs.
/// <a href="http://www.cs.cmu.edu/afs/cs.cmu.edu/project/pscico-guyb/realworld/www/rs_decode.ps">
/// "Decoding Reed-Solomon Codes"</a> (see discussion of Forney's Formula)</li>
/// <li>J.I. Hall. <a href="www.mth.msu.edu/~jhall/classes/codenotes/GRS.pdf">
/// "Chapter 5. Generalized Reed-Solomon Codes"</a>
/// (see discussion of Euclidean algorithm)</li>
/// </ul>
///
/// <p>Much credit is due to William Rucklidge since portions of this code are an indirect
/// port of his C++ Reed-Solomon implementation.</p>
///
/// @author Sean Owen
/// @author William Rucklidge
/// @author sanfordsquires
class ReedSolomonDecoder {
  final GenericGF field;

  ReedSolomonDecoder(this.field);

  /// <p>Decodes given set of received codewords, which include both data and error-correction
  /// codewords. Really, this means it uses Reed-Solomon to detect and correct errors, in-place,
  /// in the input.</p>
  ///
  /// @param received data and error-correction codewords
  /// @param twoS number of error-correction codewords available
  /// @throws ReedSolomonException if decoding fails for any reason
  void decode(Int32List received, int twoS) {
    var poly = GenericGFPoly(field, received);
    var syndromeCoefficients = Int32List(twoS);
    var noError = true;
    for (var i = 0; i < twoS; i++) {
      var eval = poly.evaluateAt(field.exp(i + field.generatorBase));
      syndromeCoefficients[syndromeCoefficients.length - 1 - i] = eval;
      if (eval != 0) {
        noError = false;
      }
    }
    if (noError) {
      return;
    }
    var syndrome = GenericGFPoly(field, syndromeCoefficients);
    var sigmaOmega =
        runEuclideanAlgorithm(field.buildMonomial(twoS, 1), syndrome, twoS);
    var sigma = sigmaOmega[0];
    var omega = sigmaOmega[1];
    var errorLocations = findErrorLocations(sigma);
    var errorMagnitudes = findErrorMagnitudes(omega, errorLocations);
    for (var i = 0; i < errorLocations.length; i++) {
      var position = received.length - 1 - field.log(errorLocations[i]);
      if (position < 0) {
        throw ReedSolomonException('Bad error location');
      }
      received[position] =
          GenericGF.addOrSubtract(received[position], errorMagnitudes[i]);
    }
  }

  List<GenericGFPoly> runEuclideanAlgorithm(
      GenericGFPoly a, GenericGFPoly b, int R) {
    // Assume a's degree is >= b's
    if (a.getDegree() < b.getDegree()) {
      var temp = a;
      a = b;
      b = temp;
    }

    var rLast = a;
    var r = b;
    var tLast = field.zero;
    var t = field.one;

    // Run Euclidean algorithm until r's degree is less than R/2
    while (r.getDegree() >= R / 2) {
      var rLastLast = rLast;
      var tLastLast = tLast;
      rLast = r;
      tLast = t;

      // Divide rLastLast by rLast, with quotient in q and remainder in r
      if (rLast.isZero) {
        // Oops, Euclidean algorithm already terminated?
        throw ReedSolomonException('r_{i-1} was zero');
      }
      r = rLastLast;
      var q = field.zero;
      var denominatorLeadingTerm = rLast.getCoefficient(rLast.getDegree());
      var dltInverse = field.inverse(denominatorLeadingTerm);
      while (r.getDegree() >= rLast.getDegree() && !r.isZero) {
        var degreeDiff = r.getDegree() - rLast.getDegree();
        var scale = field.multiply(r.getCoefficient(r.getDegree()), dltInverse);
        q = q.addOrSubtract(field.buildMonomial(degreeDiff, scale));
        r = r.addOrSubtract(rLast.multiplyByMonomial(degreeDiff, scale));
      }

      t = q.multiply(tLast).addOrSubtract(tLastLast);

      if (r.getDegree() >= rLast.getDegree()) {
        throw StateError('Division algorithm failed to reduce polynomial?');
      }
    }

    var sigmaTildeAtZero = t.getCoefficient(0);
    if (sigmaTildeAtZero == 0) {
      throw ReedSolomonException('sigmaTilde(0) was zero');
    }

    var inverse = field.inverse(sigmaTildeAtZero);
    var sigma = t.multiplyScalar(inverse);
    var omega = r.multiplyScalar(inverse);
    return [sigma, omega];
  }

  List<int> findErrorLocations(GenericGFPoly errorLocator) {
    // This is a direct application of Chien's search
    var numErrors = errorLocator.getDegree();
    if (numErrors == 1) {
      // shortcut
      return Int32List.fromList([errorLocator.getCoefficient(1)]);
    }
    List<int> result = Int32List(numErrors);
    var e = 0;
    for (var i = 1; i < field.size && e < numErrors; i++) {
      if (errorLocator.evaluateAt(i) == 0) {
        result[e] = field.inverse(i);
        e++;
      }
    }
    if (e != numErrors) {
      throw ReedSolomonException(
          'Error locator degree does not match number of roots ($e != $numErrors)');
    }
    return result;
  }

  List<int> findErrorMagnitudes(
      GenericGFPoly errorEvaluator, List<int> errorLocations) {
    // This is directly applying Forney's Formula
    var s = errorLocations.length;
    List<int> result = Int32List(s);
    for (var i = 0; i < s; i++) {
      var xiInverse = field.inverse(errorLocations[i]);
      var denominator = 1;
      for (var j = 0; j < s; j++) {
        if (i != j) {
          //denominator = field.multiply(denominator,
          //    GenericGF.addOrSubtract(1, field.multiply(errorLocations[j], xiInverse)));
          // Above should work but fails on some Apple and Linux JDKs due to a Hotspot bug.
          // Below is a funny-looking workaround from Steven Parkes
          var term = field.multiply(errorLocations[j], xiInverse);
          var termPlus1 = (term & 0x1) == 0 ? term | 1 : term & ~1;
          denominator = field.multiply(denominator, termPlus1);
        }
      }
      result[i] = field.multiply(
          errorEvaluator.evaluateAt(xiInverse), field.inverse(denominator));
      if (field.generatorBase != 0) {
        result[i] = field.multiply(result[i], xiInverse);
      }
    }
    return result;
  }
}
