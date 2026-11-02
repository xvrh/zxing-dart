import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author Sean Owen
void main() {
  testGolden('code39-1', MultiFormatReader(),
      mustPassCount: 4,
      tryHarderCount: 4,
      expectedFormat: BarcodeFormat.code39);
  testGolden('code39-1', MultiFormatReader(),
      mustPassCount: 4,
      tryHarderCount: 4,
      expectedFormat: BarcodeFormat.code39,
      rotation: 180);
}
