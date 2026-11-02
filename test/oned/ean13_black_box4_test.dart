import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// A very difficult set of images taken with extreme shadows and highlights.
/// @author dswitkin@google.com (Daniel Switkin)
void main() {
  testGolden('ean13-4', MultiFormatReader(),
      mustPassCount: 6,
      tryHarderCount: 13,
      maxMisreads: 1,
      maxTryHarderMisreads: 1,
      expectedFormat: BarcodeFormat.ean13);
  testGolden('ean13-4', MultiFormatReader(),
      mustPassCount: 7,
      tryHarderCount: 13,
      maxMisreads: 1,
      maxTryHarderMisreads: 1,
      expectedFormat: BarcodeFormat.ean13,
      rotation: 180);
}
