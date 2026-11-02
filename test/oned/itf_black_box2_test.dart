import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author dswitkin@google.com (Daniel Switkin)
void main() {
  testGolden('itf-2', MultiFormatReader(),
      mustPassCount: 14, tryHarderCount: 14, expectedFormat: BarcodeFormat.itf);
  testGolden('itf-2', MultiFormatReader(),
      mustPassCount: 14,
      tryHarderCount: 14,
      expectedFormat: BarcodeFormat.itf,
      rotation: 180);
}
