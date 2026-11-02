import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author dswitkin@google.com (Daniel Switkin)
void main() {
  testGolden('code128-2', MultiFormatReader(),
      mustPassCount: 36,
      tryHarderCount: 39,
      expectedFormat: BarcodeFormat.code128);
  testGolden('code128-2', MultiFormatReader(),
      mustPassCount: 36,
      tryHarderCount: 39,
      expectedFormat: BarcodeFormat.code128,
      rotation: 180);
}
