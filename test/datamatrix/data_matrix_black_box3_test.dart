import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author gitlost
void main() {
  testGolden('datamatrix-3', MultiFormatReader(),
      mustPassCount: 18,
      tryHarderCount: 18,
      expectedFormat: BarcodeFormat.dataMatrix);
  testGolden('datamatrix-3', MultiFormatReader(),
      mustPassCount: 17,
      tryHarderCount: 17,
      expectedFormat: BarcodeFormat.dataMatrix,
      rotation: 90);
  testGolden('datamatrix-3', MultiFormatReader(),
      mustPassCount: 18,
      tryHarderCount: 18,
      expectedFormat: BarcodeFormat.dataMatrix,
      rotation: 180);
  testGolden('datamatrix-3', MultiFormatReader(),
      mustPassCount: 18,
      tryHarderCount: 18,
      expectedFormat: BarcodeFormat.dataMatrix,
      rotation: 270);
}
