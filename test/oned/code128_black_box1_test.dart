import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author Sean Owen
void main() {
  testGolden('code128-1', MultiFormatReader(),
      mustPassCount: 6,
      tryHarderCount: 6,
      expectedFormat: BarcodeFormat.code128);
  testGolden('code128-1', MultiFormatReader(),
      mustPassCount: 6,
      tryHarderCount: 6,
      expectedFormat: BarcodeFormat.code128,
      rotation: 180);
}
