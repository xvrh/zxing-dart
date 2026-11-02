import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author dswitkin@google.com (Daniel Switkin)
void main() {
  testGolden('upce-3', MultiFormatReader(),
      mustPassCount: 6, tryHarderCount: 8, expectedFormat: BarcodeFormat.upcE);
  testGolden('upce-3', MultiFormatReader(),
      mustPassCount: 6,
      tryHarderCount: 8,
      expectedFormat: BarcodeFormat.upcE,
      rotation: 180);
}
