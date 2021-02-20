/// <p>Thrown when an exception occurs during Reed-Solomon decoding, such as when
/// there are too many errors to correct.</p>
///
/// @author Sean Owen
class ReedSolomonException implements Exception {
  final String message;

  ReedSolomonException(this.message);

  @override
  String toString() => 'ReedSolomonException($message)';
}
