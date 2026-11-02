import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author bbrown@google.com (Brian Brown)
void main() {
  for (var rotation in [0, 90, 180, 270]) {
    testGolden('datamatrix-1', MultiFormatReader(),
        mustPassCount: 22,
        tryHarderCount: 22,
        expectedFormat: BarcodeFormat.dataMatrix,
        rotation: rotation);
  }
}
