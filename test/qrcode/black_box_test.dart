import 'package:zxing2/qrcode.dart';
import '../goldens.dart';

void main() {
  var qrReader = QRCodeReader();

  testGolden('qrcode-1', qrReader, mustPassCount: 17);
  testGolden('qrcode-1', qrReader, mustPassCount: 14, rotation: 90);
  testGolden('qrcode-1', qrReader, mustPassCount: 17, rotation: 180);
  testGolden('qrcode-1', qrReader, mustPassCount: 14, rotation: 270);

  // Needs a full Shift_JIS decoder
  //testGolden('qrcode-2', qrReader, mustPassCount: 31);
  //testGolden('qrcode-2', qrReader, mustPassCount: 30, rotation: 90);
  //testGolden('qrcode-2', qrReader, mustPassCount: 30, rotation: 180);
  //testGolden('qrcode-2', qrReader, mustPassCount: 30, rotation: 270);

  testGolden('qrcode-3', qrReader, mustPassCount: 38);
  testGolden('qrcode-3', qrReader, mustPassCount: 39, rotation: 90);
  testGolden('qrcode-3', qrReader, mustPassCount: 36, rotation: 180);
  testGolden('qrcode-3', qrReader, mustPassCount: 39, rotation: 270);

  testGolden('qrcode-4', qrReader, mustPassCount: 36);
  testGolden('qrcode-4', qrReader, mustPassCount: 35, rotation: 90);
  testGolden('qrcode-4', qrReader, mustPassCount: 35, rotation: 180);
  testGolden('qrcode-4', qrReader, mustPassCount: 35, rotation: 270);

  testGolden('qrcode-5', qrReader, mustPassCount: 19);
  testGolden('qrcode-5', qrReader, mustPassCount: 19, rotation: 90);
  testGolden('qrcode-5', qrReader, mustPassCount: 19, rotation: 180);
  testGolden('qrcode-5', qrReader, mustPassCount: 19, rotation: 270);

  testGolden('qrcode-6', qrReader, mustPassCount: 15);
  testGolden('qrcode-6', qrReader, mustPassCount: 14, rotation: 90);
  testGolden('qrcode-6', qrReader, mustPassCount: 13, rotation: 180);
  testGolden('qrcode-6', qrReader, mustPassCount: 14, rotation: 270);
}
