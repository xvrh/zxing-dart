import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author dswitkin@google.com (Daniel Switkin)
void main() {
  testGolden('upce-2', MultiFormatReader(),
      mustPassCount: 31,
      tryHarderCount: 35,
      maxTryHarderMisreads: 1,
      expectedFormat: BarcodeFormat.upcE);
  testGolden('upce-2', MultiFormatReader(),
      mustPassCount: 31,
      tryHarderCount: 35,
      maxMisreads: 1,
      maxTryHarderMisreads: 1,
      expectedFormat: BarcodeFormat.upcE,
      rotation: 180);
}
