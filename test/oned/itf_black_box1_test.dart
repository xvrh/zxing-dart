import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author kevin.osullivan@sita.aero
void main() {
  testGolden('itf-1', MultiFormatReader(),
      mustPassCount: 14, tryHarderCount: 14, expectedFormat: BarcodeFormat.itf);
  testGolden('itf-1', MultiFormatReader(),
      mustPassCount: 14,
      tryHarderCount: 14,
      expectedFormat: BarcodeFormat.itf,
      rotation: 180);
}
