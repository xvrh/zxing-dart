import 'reader_exception.dart';

/// Thrown when a barcode was successfully detected, but some aspect of
/// the content did not conform to the barcode's format rules. This could have
/// been due to a mis-detection.
class FormatReaderException extends ReaderException {}
