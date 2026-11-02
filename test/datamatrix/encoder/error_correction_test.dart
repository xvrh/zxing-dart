import 'package:test/test.dart';
import 'package:zxing2/src/datamatrix/encoder/error_correction.dart';
import 'package:zxing2/src/datamatrix/encoder/symbol_info.dart';
import 'high_level_encode_test.dart' show visualize;

/// Tests for the ECC200 error correction.
void main() {
  test('RS', () {
    //Sample from Annexe R in ISO/IEC 16022:2000(E)
    var cw = [142, 164, 186];
    var symbolInfo = SymbolInfo.lookup(3)!;
    var s = ErrorCorrection.encodeECC200(String.fromCharCodes(cw), symbolInfo);
    expect(visualize(s), '142 164 186 114 25 5 88 102');

    //"A" encoded (ASCII encoding + 2 padding characters)
    cw = [66, 129, 70];
    s = ErrorCorrection.encodeECC200(String.fromCharCodes(cw), symbolInfo);
    expect(visualize(s), '66 129 70 138 234 82 82 95');
  });
}
