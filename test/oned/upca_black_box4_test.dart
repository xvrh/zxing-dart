import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author dswitkin@google.com (Daniel Switkin)
void main() {
  testGolden('upca-4', MultiFormatReader(),
      mustPassCount: 9,
      tryHarderCount: 11,
      maxTryHarderMisreads: 1,
      expectedFormat: BarcodeFormat.upcA);
  testGolden('upca-4', MultiFormatReader(),
      mustPassCount: 9,
      tryHarderCount: 11,
      maxTryHarderMisreads: 1,
      expectedFormat: BarcodeFormat.upcA,
      rotation: 180);
}
