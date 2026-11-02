import 'package:zxing2/oned.dart';
import '../goldens.dart';

/// @author Sean Owen
void main() {
  testGolden('code39-2', Code39Reader(false, true),
      mustPassCount: 2,
      tryHarderCount: 2,
      expectedFormat: BarcodeFormat.code39);
  testGolden('code39-2', Code39Reader(false, true),
      mustPassCount: 2,
      tryHarderCount: 2,
      expectedFormat: BarcodeFormat.code39,
      rotation: 180);
}
