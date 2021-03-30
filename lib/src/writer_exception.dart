/// A base class which covers the range of exceptions which may occur when encoding a barcode using
/// the Writer framework.
///
/// @author dswitkin@google.com (Daniel Switkin)
class WriterException implements Exception {
  final String? message;
  final Object? cause;

  WriterException(this.message, {this.cause});

  @override
  String toString() {
    return 'WriterException(${[
      if (message != null) message,
      if (cause != null) 'cause: $cause'
    ].join(', ')})';
  }
}
