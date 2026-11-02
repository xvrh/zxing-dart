import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author Sean Owen
void main() {
  testGolden('upce-1', MultiFormatReader(),
      mustPassCount: 3, tryHarderCount: 3, expectedFormat: BarcodeFormat.upcE);
  testGolden('upce-1', MultiFormatReader(),
      mustPassCount: 3,
      tryHarderCount: 3,
      expectedFormat: BarcodeFormat.upcE,
      rotation: 180);
}
