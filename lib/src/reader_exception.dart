/// The general exception class throw when something goes wrong during decoding of a barcode.
/// This includes, but is not limited to, failing checksums / error correction algorithms, being
/// unable to locate finder timing patterns, and so on.
///
/// @author Sean Owen
abstract class ReaderException implements Exception {
  final Object? cause;

  ReaderException([this.cause]);

  String toString() {
    Object? message = this.cause;
    if (message == null) return "ReaderException";
    return "ReaderException: $message";
  }
}
