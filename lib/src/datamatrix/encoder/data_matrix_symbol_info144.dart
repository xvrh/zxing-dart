import 'symbol_info.dart';

class DataMatrixSymbolInfo144 extends SymbolInfo {
  DataMatrixSymbolInfo144() : super(false, 1558, 620, 22, 22, 36, -1, 62);

  @override
  int get interleavedBlockCount {
    return 10;
  }

  @override
  int getDataLengthForInterleavedBlock(int index) {
    return (index <= 8) ? 156 : 155;
  }
}
