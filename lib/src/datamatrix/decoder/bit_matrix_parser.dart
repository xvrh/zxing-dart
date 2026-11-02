import 'dart:typed_data';
import '../../common/bit_matrix.dart';
import '../../format_reader_exception.dart';
import 'version.dart';

/// @author bbrown@google.com (Brian Brown)
class BitMatrixParser {
  late final BitMatrix _mappingBitMatrix;
  late final BitMatrix _readMappingMatrix;
  late final Version version;

  /// @param bitMatrix {@link BitMatrix} to parse
  /// @throws FormatReaderException if dimension is < 8 or > 144 or not 0 mod 2
  BitMatrixParser(BitMatrix bitMatrix) {
    var dimension = bitMatrix.height;
    if (dimension < 8 || dimension > 144 || (dimension & 0x01) != 0) {
      throw FormatReaderException();
    }

    version = _readVersion(bitMatrix);
    _mappingBitMatrix = _extractDataRegion(bitMatrix);
    _readMappingMatrix =
        BitMatrix(_mappingBitMatrix.width, _mappingBitMatrix.height);
  }

  /// <p>Creates the version object based on the dimension of the original bit matrix from
  /// the datamatrix code.</p>
  ///
  /// <p>See ISO 16022:2006 Table 7 - ECC 200 symbol attributes</p>
  ///
  /// @param bitMatrix Original {@link BitMatrix} including alignment patterns
  /// @return {@link Version} encapsulating the Data Matrix Code's "version"
  /// @throws FormatReaderException if the dimensions of the mapping matrix are not valid
  /// Data Matrix dimensions.
  static Version _readVersion(BitMatrix bitMatrix) {
    var numRows = bitMatrix.height;
    var numColumns = bitMatrix.width;
    return Version.getVersionForDimensions(numRows, numColumns);
  }

  /// <p>Reads the bits in the {@link BitMatrix} representing the mapping matrix (No alignment patterns)
  /// in the correct order in order to reconstitute the codewords bytes contained within the
  /// Data Matrix Code.</p>
  ///
  /// @return bytes encoded within the Data Matrix Code
  /// @throws FormatReaderException if the exact number of bytes expected is not read
  Int8List readCodewords() {
    var result = Int8List(version.totalCodewords);
    var resultOffset = 0;

    var row = 4;
    var column = 0;

    var numRows = _mappingBitMatrix.height;
    var numColumns = _mappingBitMatrix.width;

    var corner1Read = false;
    var corner2Read = false;
    var corner3Read = false;
    var corner4Read = false;

    // Read all of the codewords
    do {
      // Check the four corner cases
      if ((row == numRows) && (column == 0) && !corner1Read) {
        result[resultOffset++] = _readCorner1(numRows, numColumns);
        row -= 2;
        column += 2;
        corner1Read = true;
      } else if ((row == numRows - 2) &&
          (column == 0) &&
          ((numColumns & 0x03) != 0) &&
          !corner2Read) {
        result[resultOffset++] = _readCorner2(numRows, numColumns);
        row -= 2;
        column += 2;
        corner2Read = true;
      } else if ((row == numRows + 4) &&
          (column == 2) &&
          ((numColumns & 0x07) == 0) &&
          !corner3Read) {
        result[resultOffset++] = _readCorner3(numRows, numColumns);
        row -= 2;
        column += 2;
        corner3Read = true;
      } else if ((row == numRows - 2) &&
          (column == 0) &&
          ((numColumns & 0x07) == 4) &&
          !corner4Read) {
        result[resultOffset++] = _readCorner4(numRows, numColumns);
        row -= 2;
        column += 2;
        corner4Read = true;
      } else {
        // Sweep upward diagonally to the right
        do {
          if ((row < numRows) &&
              (column >= 0) &&
              !_readMappingMatrix.get(column, row)) {
            result[resultOffset++] =
                _readUtah(row, column, numRows, numColumns);
          }
          row -= 2;
          column += 2;
        } while ((row >= 0) && (column < numColumns));
        row += 1;
        column += 3;

        // Sweep downward diagonally to the left
        do {
          if ((row >= 0) &&
              (column < numColumns) &&
              !_readMappingMatrix.get(column, row)) {
            result[resultOffset++] =
                _readUtah(row, column, numRows, numColumns);
          }
          row += 2;
          column -= 2;
        } while ((row < numRows) && (column >= 0));
        row += 3;
        column += 1;
      }
    } while ((row < numRows) || (column < numColumns));

    if (resultOffset != version.totalCodewords) {
      throw FormatReaderException();
    }
    return result;
  }

  /// <p>Reads a bit of the mapping matrix accounting for boundary wrapping.</p>
  ///
  /// @param row Row to read in the mapping matrix
  /// @param column Column to read in the mapping matrix
  /// @param numRows Number of rows in the mapping matrix
  /// @param numColumns Number of columns in the mapping matrix
  /// @return value of the given bit in the mapping matrix
  bool _readModule(int row, int column, int numRows, int numColumns) {
    // Adjust the row and column indices based on boundary wrapping
    if (row < 0) {
      row += numRows;
      column += 4 - ((numRows + 4) & 0x07);
    }
    if (column < 0) {
      column += numColumns;
      row += 4 - ((numColumns + 4) & 0x07);
    }
    if (row >= numRows) {
      row -= numRows;
    }
    _readMappingMatrix.set(column, row);
    return _mappingBitMatrix.get(column, row);
  }

  /// <p>Reads the 8 bits of the standard Utah-shaped pattern.</p>
  ///
  /// <p>See ISO 16022:2006, 5.8.1 Figure 6</p>
  ///
  /// @param row Current row in the mapping matrix, anchored at the 8th bit (LSB) of the pattern
  /// @param column Current column in the mapping matrix, anchored at the 8th bit (LSB) of the pattern
  /// @param numRows Number of rows in the mapping matrix
  /// @param numColumns Number of columns in the mapping matrix
  /// @return byte from the utah shape
  int _readUtah(int row, int column, int numRows, int numColumns) {
    var currentByte = 0;
    if (_readModule(row - 2, column - 2, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(row - 2, column - 1, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(row - 1, column - 2, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(row - 1, column - 1, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(row - 1, column, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(row, column - 2, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(row, column - 1, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(row, column, numRows, numColumns)) {
      currentByte |= 1;
    }
    return currentByte;
  }

  /// <p>Reads the 8 bits of the special corner condition 1.</p>
  ///
  /// <p>See ISO 16022:2006, Figure F.3</p>
  ///
  /// @param numRows Number of rows in the mapping matrix
  /// @param numColumns Number of columns in the mapping matrix
  /// @return byte from the Corner condition 1
  int _readCorner1(int numRows, int numColumns) {
    var currentByte = 0;
    if (_readModule(numRows - 1, 0, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(numRows - 1, 1, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(numRows - 1, 2, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(0, numColumns - 2, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(0, numColumns - 1, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(1, numColumns - 1, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(2, numColumns - 1, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(3, numColumns - 1, numRows, numColumns)) {
      currentByte |= 1;
    }
    return currentByte;
  }

  /// <p>Reads the 8 bits of the special corner condition 2.</p>
  ///
  /// <p>See ISO 16022:2006, Figure F.4</p>
  ///
  /// @param numRows Number of rows in the mapping matrix
  /// @param numColumns Number of columns in the mapping matrix
  /// @return byte from the Corner condition 2
  int _readCorner2(int numRows, int numColumns) {
    var currentByte = 0;
    if (_readModule(numRows - 3, 0, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(numRows - 2, 0, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(numRows - 1, 0, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(0, numColumns - 4, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(0, numColumns - 3, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(0, numColumns - 2, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(0, numColumns - 1, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(1, numColumns - 1, numRows, numColumns)) {
      currentByte |= 1;
    }
    return currentByte;
  }

  /// <p>Reads the 8 bits of the special corner condition 3.</p>
  ///
  /// <p>See ISO 16022:2006, Figure F.5</p>
  ///
  /// @param numRows Number of rows in the mapping matrix
  /// @param numColumns Number of columns in the mapping matrix
  /// @return byte from the Corner condition 3
  int _readCorner3(int numRows, int numColumns) {
    var currentByte = 0;
    if (_readModule(numRows - 1, 0, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(numRows - 1, numColumns - 1, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(0, numColumns - 3, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(0, numColumns - 2, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(0, numColumns - 1, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(1, numColumns - 3, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(1, numColumns - 2, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(1, numColumns - 1, numRows, numColumns)) {
      currentByte |= 1;
    }
    return currentByte;
  }

  /// <p>Reads the 8 bits of the special corner condition 4.</p>
  ///
  /// <p>See ISO 16022:2006, Figure F.6</p>
  ///
  /// @param numRows Number of rows in the mapping matrix
  /// @param numColumns Number of columns in the mapping matrix
  /// @return byte from the Corner condition 4
  int _readCorner4(int numRows, int numColumns) {
    var currentByte = 0;
    if (_readModule(numRows - 3, 0, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(numRows - 2, 0, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(numRows - 1, 0, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(0, numColumns - 2, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(0, numColumns - 1, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(1, numColumns - 1, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(2, numColumns - 1, numRows, numColumns)) {
      currentByte |= 1;
    }
    currentByte <<= 1;
    if (_readModule(3, numColumns - 1, numRows, numColumns)) {
      currentByte |= 1;
    }
    return currentByte;
  }

  /// <p>Extracts the data region from a {@link BitMatrix} that contains
  /// alignment patterns.</p>
  ///
  /// @param bitMatrix Original {@link BitMatrix} with alignment patterns
  /// @return BitMatrix that has the alignment patterns removed
  BitMatrix _extractDataRegion(BitMatrix bitMatrix) {
    var symbolSizeRows = version.symbolSizeRows;
    var symbolSizeColumns = version.symbolSizeColumns;

    if (bitMatrix.height != symbolSizeRows) {
      throw ArgumentError('Dimension of bitMatrix must match the version size');
    }

    var dataRegionSizeRows = version.dataRegionSizeRows;
    var dataRegionSizeColumns = version.dataRegionSizeColumns;

    var numDataRegionsRow = symbolSizeRows ~/ dataRegionSizeRows;
    var numDataRegionsColumn = symbolSizeColumns ~/ dataRegionSizeColumns;

    var sizeDataRegionRow = numDataRegionsRow * dataRegionSizeRows;
    var sizeDataRegionColumn = numDataRegionsColumn * dataRegionSizeColumns;

    var bitMatrixWithoutAlignment =
        BitMatrix(sizeDataRegionColumn, sizeDataRegionRow);
    for (var dataRegionRow = 0;
        dataRegionRow < numDataRegionsRow;
        ++dataRegionRow) {
      var dataRegionRowOffset = dataRegionRow * dataRegionSizeRows;
      for (var dataRegionColumn = 0;
          dataRegionColumn < numDataRegionsColumn;
          ++dataRegionColumn) {
        var dataRegionColumnOffset = dataRegionColumn * dataRegionSizeColumns;
        for (var i = 0; i < dataRegionSizeRows; ++i) {
          var readRowOffset = dataRegionRow * (dataRegionSizeRows + 2) + 1 + i;
          var writeRowOffset = dataRegionRowOffset + i;
          for (var j = 0; j < dataRegionSizeColumns; ++j) {
            var readColumnOffset =
                dataRegionColumn * (dataRegionSizeColumns + 2) + 1 + j;
            if (bitMatrix.get(readColumnOffset, readRowOffset)) {
              var writeColumnOffset = dataRegionColumnOffset + j;
              bitMatrixWithoutAlignment.set(writeColumnOffset, writeRowOffset);
            }
          }
        }
      }
    }
    return bitMatrixWithoutAlignment;
  }
}
