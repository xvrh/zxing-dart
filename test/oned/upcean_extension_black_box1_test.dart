import 'package:zxing2/zxing2.dart';
import '../goldens.dart';

/// @author Sean Owen
void main() {
  testGolden('upcean-extension-1', MultiFormatReader(),
      mustPassCount: 2, tryHarderCount: 2, expectedFormat: BarcodeFormat.ean13);
}
