import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author Sean Owen
void main() {
  testGolden('code93-1', MultiFormatReader(),
      mustPassCount: 3,
      tryHarderCount: 3,
      expectedFormat: BarcodeFormat.code93);
  testGolden('code93-1', MultiFormatReader(),
      mustPassCount: 3,
      tryHarderCount: 3,
      expectedFormat: BarcodeFormat.code93,
      rotation: 180);
}
