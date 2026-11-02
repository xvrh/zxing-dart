import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author Sean Owen
void main() {
  testGolden('upca-1', MultiFormatReader(),
      mustPassCount: 14,
      tryHarderCount: 18,
      maxTryHarderMisreads: 1,
      expectedFormat: BarcodeFormat.upcA);
  testGolden('upca-1', MultiFormatReader(),
      mustPassCount: 16,
      tryHarderCount: 18,
      maxTryHarderMisreads: 1,
      expectedFormat: BarcodeFormat.upcA,
      rotation: 180);
}
