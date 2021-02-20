import '../result_point.dart';
import 'bit_matrix.dart';

/// <p>Encapsulates the result of detecting a barcode in an image. This includes the raw
/// matrix of black/white pixels corresponding to the barcode, and possibly points of interest
/// in the image, like the location of finder patterns or corners of the barcode in the image.</p>
class DetectorResult {
  final BitMatrix bits;
  final List<ResultPoint> points;

  DetectorResult(this.bits, this.points);
}
