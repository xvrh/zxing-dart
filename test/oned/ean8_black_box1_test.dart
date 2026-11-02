import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author Sean Owen
void main() {
  testGolden('ean8-1', MultiFormatReader(),
      mustPassCount: 8, tryHarderCount: 8, expectedFormat: BarcodeFormat.ean8);
  testGolden('ean8-1', MultiFormatReader(),
      mustPassCount: 8,
      tryHarderCount: 8,
      expectedFormat: BarcodeFormat.ean8,
      rotation: 180);
}
