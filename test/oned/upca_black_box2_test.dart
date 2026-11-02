import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author dswitkin@google.com (Daniel Switkin)
void main() {
  testGolden('upca-2', MultiFormatReader(),
      mustPassCount: 28,
      tryHarderCount: 36,
      maxTryHarderMisreads: 2,
      expectedFormat: BarcodeFormat.upcA);
  testGolden('upca-2', MultiFormatReader(),
      mustPassCount: 29,
      tryHarderCount: 36,
      maxTryHarderMisreads: 2,
      expectedFormat: BarcodeFormat.upcA,
      rotation: 180);
}
