import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author dswitkin@google.com (Daniel Switkin)
void main() {
  testGolden('code39-3', MultiFormatReader(),
      mustPassCount: 17,
      tryHarderCount: 17,
      expectedFormat: BarcodeFormat.code39);
  testGolden('code39-3', MultiFormatReader(),
      mustPassCount: 17,
      tryHarderCount: 17,
      expectedFormat: BarcodeFormat.code39,
      rotation: 180);
}
