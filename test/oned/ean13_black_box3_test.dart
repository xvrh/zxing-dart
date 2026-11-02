import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author dswitkin@google.com (Daniel Switkin)
void main() {
  testGolden('ean13-3', MultiFormatReader(),
      mustPassCount: 53,
      tryHarderCount: 55,
      expectedFormat: BarcodeFormat.ean13);
  testGolden('ean13-3', MultiFormatReader(),
      mustPassCount: 55,
      tryHarderCount: 55,
      expectedFormat: BarcodeFormat.ean13,
      rotation: 180);
}
