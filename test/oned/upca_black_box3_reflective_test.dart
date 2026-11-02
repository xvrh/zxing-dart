import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author dswitkin@google.com (Daniel Switkin)
void main() {
  testGolden('upca-3', MultiFormatReader(),
      mustPassCount: 7,
      tryHarderCount: 9,
      maxTryHarderMisreads: 2,
      expectedFormat: BarcodeFormat.upcA);
  testGolden('upca-3', MultiFormatReader(),
      mustPassCount: 8,
      tryHarderCount: 9,
      maxTryHarderMisreads: 2,
      expectedFormat: BarcodeFormat.upcA,
      rotation: 180);
}
