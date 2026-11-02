import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// This is a set of mobile image taken at 480x360 with difficult lighting.
///
/// @author dswitkin@google.com (Daniel Switkin)
void main() {
  testGolden('ean13-2', MultiFormatReader(),
      mustPassCount: 12,
      tryHarderCount: 17,
      maxTryHarderMisreads: 1,
      expectedFormat: BarcodeFormat.ean13);
  testGolden('ean13-2', MultiFormatReader(),
      mustPassCount: 11,
      tryHarderCount: 17,
      maxTryHarderMisreads: 1,
      expectedFormat: BarcodeFormat.ean13,
      rotation: 180);
}
