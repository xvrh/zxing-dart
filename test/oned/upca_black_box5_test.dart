import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author dswitkin@google.com (Daniel Switkin)
void main() {
  testGolden('upca-5', MultiFormatReader(),
      mustPassCount: 20,
      tryHarderCount: 23,
      expectedFormat: BarcodeFormat.upcA);
  testGolden('upca-5', MultiFormatReader(),
      mustPassCount: 22,
      tryHarderCount: 23,
      expectedFormat: BarcodeFormat.upcA,
      rotation: 180);
}
