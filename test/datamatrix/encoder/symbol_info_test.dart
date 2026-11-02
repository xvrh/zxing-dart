import 'package:test/test.dart';
import 'package:zxing2/src/datamatrix/encoder/symbol_info.dart';
import 'package:zxing2/src/datamatrix/encoder/symbol_shape_hint.dart';
import 'package:zxing2/src/dimension.dart';

/// Tests the SymbolInfo class.
void main() {
  test('Symbol info', () {
    SymbolInfo? info = SymbolInfo.lookup(3)!;
    expect(info.errorCodewords, 5);
    expect(info.matrixWidth, 8);
    expect(info.matrixHeight, 8);
    expect(info.symbolWidth, 10);
    expect(info.symbolHeight, 10);

    info = SymbolInfo.lookup(3, shape: SymbolShapeHint.forceRectangle)!;
    expect(info.errorCodewords, 7);
    expect(info.matrixWidth, 16);
    expect(info.matrixHeight, 6);
    expect(info.symbolWidth, 18);
    expect(info.symbolHeight, 8);

    info = SymbolInfo.lookup(9)!;
    expect(info.errorCodewords, 11);
    expect(info.matrixWidth, 14);
    expect(info.matrixHeight, 6);
    expect(info.symbolWidth, 32);
    expect(info.symbolHeight, 8);

    info = SymbolInfo.lookup(9, shape: SymbolShapeHint.forceSquare)!;
    expect(info.errorCodewords, 12);
    expect(info.matrixWidth, 14);
    expect(info.matrixHeight, 14);
    expect(info.symbolWidth, 16);
    expect(info.symbolHeight, 16);

    expect(() => SymbolInfo.lookup(1559), throwsArgumentError,
        reason:
            "There's no rectangular symbol for more than 1558 data codewords");
    expect(() => SymbolInfo.lookup(50, shape: SymbolShapeHint.forceRectangle),
        throwsArgumentError,
        reason: "There's no rectangular symbol for 50 data codewords");

    info = SymbolInfo.lookup(35)!;
    expect(info.symbolWidth, 24);
    expect(info.symbolHeight, 24);

    var fixedSize = Dimension(26, 26);
    info = SymbolInfo.lookup(35,
        minSize: fixedSize, maxSize: fixedSize, fail: false);
    expect(info, isNotNull);
    expect(info!.symbolWidth, 26);
    expect(info.symbolHeight, 26);

    info = SymbolInfo.lookup(45,
        minSize: fixedSize, maxSize: fixedSize, fail: false);
    expect(info, isNull);

    var minSize = fixedSize;
    var maxSize = Dimension(32, 32);

    info =
        SymbolInfo.lookup(35, minSize: minSize, maxSize: maxSize, fail: false);
    expect(info, isNotNull);
    expect(info!.symbolWidth, 26);
    expect(info.symbolHeight, 26);

    info =
        SymbolInfo.lookup(40, minSize: minSize, maxSize: maxSize, fail: false);
    expect(info, isNotNull);
    expect(info!.symbolWidth, 26);
    expect(info.symbolHeight, 26);

    info =
        SymbolInfo.lookup(45, minSize: minSize, maxSize: maxSize, fail: false);
    expect(info, isNotNull);
    expect(info!.symbolWidth, 32);
    expect(info.symbolHeight, 32);

    info =
        SymbolInfo.lookup(63, minSize: minSize, maxSize: maxSize, fail: false);
    expect(info, isNull);
  });
}
