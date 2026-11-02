import '../../dimension.dart';
import 'data_matrix_symbol_info144.dart';
import 'symbol_shape_hint.dart';

/// Symbol info table for DataMatrix.
///
/// @version $Id$
class SymbolInfo {
  static final prodSymbols = <SymbolInfo>[
    SymbolInfo(false, 3, 5, 8, 8, 1),
    SymbolInfo(false, 5, 7, 10, 10, 1),
    /*rect*/ SymbolInfo(true, 5, 7, 16, 6, 1),
    SymbolInfo(false, 8, 10, 12, 12, 1),
    /*rect*/ SymbolInfo(true, 10, 11, 14, 6, 2),
    SymbolInfo(false, 12, 12, 14, 14, 1),
    /*rect*/ SymbolInfo(true, 16, 14, 24, 10, 1),
    SymbolInfo(false, 18, 14, 16, 16, 1),
    SymbolInfo(false, 22, 18, 18, 18, 1),
    /*rect*/ SymbolInfo(true, 22, 18, 16, 10, 2),
    SymbolInfo(false, 30, 20, 20, 20, 1),
    /*rect*/ SymbolInfo(true, 32, 24, 16, 14, 2),
    SymbolInfo(false, 36, 24, 22, 22, 1),
    SymbolInfo(false, 44, 28, 24, 24, 1),
    /*rect*/ SymbolInfo(true, 49, 28, 22, 14, 2),
    SymbolInfo(false, 62, 36, 14, 14, 4),
    SymbolInfo(false, 86, 42, 16, 16, 4),
    SymbolInfo(false, 114, 48, 18, 18, 4),
    SymbolInfo(false, 144, 56, 20, 20, 4),
    SymbolInfo(false, 174, 68, 22, 22, 4),
    SymbolInfo(false, 204, 84, 24, 24, 4, 102, 42),
    SymbolInfo(false, 280, 112, 14, 14, 16, 140, 56),
    SymbolInfo(false, 368, 144, 16, 16, 16, 92, 36),
    SymbolInfo(false, 456, 192, 18, 18, 16, 114, 48),
    SymbolInfo(false, 576, 224, 20, 20, 16, 144, 56),
    SymbolInfo(false, 696, 272, 22, 22, 16, 174, 68),
    SymbolInfo(false, 816, 336, 24, 24, 16, 136, 56),
    SymbolInfo(false, 1050, 408, 18, 18, 36, 175, 68),
    SymbolInfo(false, 1304, 496, 20, 20, 36, 163, 62),
    DataMatrixSymbolInfo144(),
  ];

  static List<SymbolInfo> _symbols = prodSymbols;

  final bool _rectangular;
  final int dataCapacity;
  final int errorCodewords;
  final int matrixWidth;
  final int matrixHeight;
  final int _dataRegions;
  final int _rsBlockData;
  final int _rsBlockError;

  /// Overrides the symbol info set used by this class. Used for testing purposes.
  ///
  /// @param override the symbol info set to use
  static void overrideSymbolSet(List<SymbolInfo> override) {
    _symbols = override;
  }

  SymbolInfo(this._rectangular, this.dataCapacity, this.errorCodewords,
      this.matrixWidth, this.matrixHeight, this._dataRegions,
      [int? rsBlockData, int? rsBlockError])
      : _rsBlockData = rsBlockData ?? dataCapacity,
        _rsBlockError = rsBlockError ?? errorCodewords;

  static SymbolInfo? lookup(int dataCodewords,
      {SymbolShapeHint shape = SymbolShapeHint.forceNone,
      Dimension? minSize,
      Dimension? maxSize,
      bool fail = true}) {
    for (var symbol in _symbols) {
      if (shape == SymbolShapeHint.forceSquare && symbol._rectangular) {
        continue;
      }
      if (shape == SymbolShapeHint.forceRectangle && !symbol._rectangular) {
        continue;
      }
      if (minSize != null &&
          (symbol.symbolWidth < minSize.width ||
              symbol.symbolHeight < minSize.height)) {
        continue;
      }
      if (maxSize != null &&
          (symbol.symbolWidth > maxSize.width ||
              symbol.symbolHeight > maxSize.height)) {
        continue;
      }
      if (dataCodewords <= symbol.dataCapacity) {
        return symbol;
      }
    }
    if (fail) {
      throw ArgumentError(
          "Can't find a symbol arrangement that matches the message. Data codewords: $dataCodewords");
    }
    return null;
  }

  int get _horizontalDataRegions {
    switch (_dataRegions) {
      case 1:
        return 1;
      case 2:
      case 4:
        return 2;
      case 16:
        return 4;
      case 36:
        return 6;
      default:
        throw StateError('Cannot handle this number of data regions');
    }
  }

  int get _verticalDataRegions {
    switch (_dataRegions) {
      case 1:
      case 2:
        return 1;
      case 4:
        return 2;
      case 16:
        return 4;
      case 36:
        return 6;
      default:
        throw StateError('Cannot handle this number of data regions');
    }
  }

  int get symbolDataWidth {
    return _horizontalDataRegions * matrixWidth;
  }

  int get symbolDataHeight {
    return _verticalDataRegions * matrixHeight;
  }

  int get symbolWidth {
    return symbolDataWidth + (_horizontalDataRegions * 2);
  }

  int get symbolHeight {
    return symbolDataHeight + (_verticalDataRegions * 2);
  }

  int get codewordCount {
    return dataCapacity + errorCodewords;
  }

  int get interleavedBlockCount {
    return dataCapacity ~/ _rsBlockData;
  }

  int getDataLengthForInterleavedBlock(int index) {
    return _rsBlockData;
  }

  int getErrorLengthForInterleavedBlock(int index) {
    return _rsBlockError;
  }

  @override
  String toString() {
    return '${_rectangular ? 'Rectangular Symbol:' : 'Square Symbol:'}'
        ' data region ${matrixWidth}x$matrixHeight'
        ', symbol size ${symbolWidth}x$symbolHeight'
        ', symbol data size ${symbolDataWidth}x$symbolDataHeight'
        ', codewords $dataCapacity+$errorCodewords';
  }
}
