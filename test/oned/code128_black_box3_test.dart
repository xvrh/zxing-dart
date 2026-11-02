import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author Sean Owen
void main() {
  testGolden('code128-3', MultiFormatReader(),
      mustPassCount: 2,
      tryHarderCount: 2,
      expectedFormat: BarcodeFormat.code128);
  testGolden('code128-3', MultiFormatReader(),
      mustPassCount: 2,
      tryHarderCount: 2,
      expectedFormat: BarcodeFormat.code128,
      rotation: 180);
}
