import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author Sean Owen
void main() {
  testGolden('ean13-1', MultiFormatReader(),
      mustPassCount: 30,
      tryHarderCount: 32,
      expectedFormat: BarcodeFormat.ean13);
  testGolden('ean13-1', MultiFormatReader(),
      mustPassCount: 27,
      tryHarderCount: 32,
      expectedFormat: BarcodeFormat.ean13,
      rotation: 180);
}
