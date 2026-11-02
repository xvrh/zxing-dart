import 'one_dimensional_code_writer.dart';

/// <p>Encapsulates functionality and implementation that is common to UPC and EAN families
/// of one-dimensional barcodes.</p>
///
/// @author aripollak@gmail.com (Ari Pollak)
/// @author dsbnatut@gmail.com (Kazuki Nishiura)
abstract class UPCEANWriter extends OneDimensionalCodeWriter {
  @override
  int get defaultMargin {
    // Use a different default more appropriate for UPC/EAN
    return 9;
  }
}
