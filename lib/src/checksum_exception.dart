import 'reader_exception.dart';

/// Thrown when a barcode was successfully detected and decoded, but
/// was not returned because its checksum feature failed.
class ChecksumException extends ReaderException {
  final Object innerException;

  ChecksumException(this.innerException);

  String toString() => 'ChecksumException(inner: $innerException)';
}
