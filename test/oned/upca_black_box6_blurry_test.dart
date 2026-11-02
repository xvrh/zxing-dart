import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// A set of blurry images taken with a fixed-focus device.
/// @author dswitkin@google.com (Daniel Switkin)
void main() {
  testGolden('upca-6', MultiFormatReader(),
      mustPassCount: 0, tryHarderCount: 0, expectedFormat: BarcodeFormat.upcA);
  testGolden('upca-6', MultiFormatReader(),
      mustPassCount: 0,
      tryHarderCount: 0,
      expectedFormat: BarcodeFormat.upcA,
      rotation: 180);
}
