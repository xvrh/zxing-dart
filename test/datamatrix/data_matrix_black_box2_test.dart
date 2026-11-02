import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author dswitkin@google.com (Daniel Switkin)
void main() {
  testGolden('datamatrix-2', MultiFormatReader(),
      mustPassCount: 13,
      tryHarderCount: 13,
      maxTryHarderMisreads: 1,
      expectedFormat: BarcodeFormat.dataMatrix);
  testGolden('datamatrix-2', MultiFormatReader(),
      mustPassCount: 15,
      tryHarderCount: 15,
      maxTryHarderMisreads: 1,
      expectedFormat: BarcodeFormat.dataMatrix,
      rotation: 90);
  testGolden('datamatrix-2', MultiFormatReader(),
      mustPassCount: 17,
      tryHarderCount: 16,
      maxTryHarderMisreads: 1,
      expectedFormat: BarcodeFormat.dataMatrix,
      rotation: 180);
  testGolden('datamatrix-2', MultiFormatReader(),
      mustPassCount: 15,
      tryHarderCount: 15,
      maxTryHarderMisreads: 1,
      expectedFormat: BarcodeFormat.dataMatrix,
      rotation: 270);
}
