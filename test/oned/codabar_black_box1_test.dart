import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author Sean Owen
void main() {
  testGolden('codabar-1', MultiFormatReader(),
      mustPassCount: 11,
      tryHarderCount: 11,
      expectedFormat: BarcodeFormat.codabar);
  testGolden('codabar-1', MultiFormatReader(),
      mustPassCount: 11,
      tryHarderCount: 11,
      expectedFormat: BarcodeFormat.codabar,
      rotation: 180);
}
