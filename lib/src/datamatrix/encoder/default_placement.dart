import 'dart:typed_data';

/// Symbol Character Placement Program. Adapted from Annex M.1 in ISO/IEC 16022:2000(E).
class DefaultPlacement {
  final String _codewords;
  final int numrows;
  final int numcols;
  final Int8List bits;

  /// Main constructor
  ///
  /// @param codewords the codewords to place
  /// @param numcols   the number of columns
  /// @param numrows   the number of rows
  DefaultPlacement(String codewords, this.numcols, this.numrows)
      : _codewords = codewords,
        bits = Int8List(numcols * numrows) {
    bits.fillRange(0, bits.length, -1); //Initialize with "not set" value
  }

  bool getBit(int col, int row) {
    return bits[row * numcols + col] == 1;
  }

  void _setBit(int col, int row, bool bit) {
    bits[row * numcols + col] = bit ? 1 : 0;
  }

  bool _noBit(int col, int row) {
    return bits[row * numcols + col] < 0;
  }

  void place() {
    var pos = 0;
    var row = 4;
    var col = 0;

    do {
      // repeatedly first check for one of the special corner cases, then...
      if ((row == numrows) && (col == 0)) {
        _corner1(pos++);
      }
      if ((row == numrows - 2) && (col == 0) && ((numcols % 4) != 0)) {
        _corner2(pos++);
      }
      if ((row == numrows - 2) && (col == 0) && (numcols % 8 == 4)) {
        _corner3(pos++);
      }
      if ((row == numrows + 4) && (col == 2) && ((numcols % 8) == 0)) {
        _corner4(pos++);
      }
      // sweep upward diagonally, inserting successive characters...
      do {
        if ((row < numrows) && (col >= 0) && _noBit(col, row)) {
          _utah(row, col, pos++);
        }
        row -= 2;
        col += 2;
      } while (row >= 0 && (col < numcols));
      row++;
      col += 3;

      // and then sweep downward diagonally, inserting successive characters, ...
      do {
        if ((row >= 0) && (col < numcols) && _noBit(col, row)) {
          _utah(row, col, pos++);
        }
        row += 2;
        col -= 2;
      } while ((row < numrows) && (col >= 0));
      row += 3;
      col++;

      // ...until the entire array is scanned
    } while ((row < numrows) || (col < numcols));

    // Lastly, if the lower right-hand corner is untouched, fill in fixed pattern
    if (_noBit(numcols - 1, numrows - 1)) {
      _setBit(numcols - 1, numrows - 1, true);
      _setBit(numcols - 2, numrows - 2, true);
    }
  }

  void _module(int row, int col, int pos, int bit) {
    if (row < 0) {
      row += numrows;
      col += 4 - ((numrows + 4) % 8);
    }
    if (col < 0) {
      col += numcols;
      row += 4 - ((numcols + 4) % 8);
    }
    // Note the conversion:
    var v = _codewords.codeUnitAt(pos);
    v &= 1 << (8 - bit);
    _setBit(col, row, v != 0);
  }

  /// Places the 8 bits of a utah-shaped symbol character in ECC200.
  ///
  /// @param row the row
  /// @param col the column
  /// @param pos character position
  void _utah(int row, int col, int pos) {
    _module(row - 2, col - 2, pos, 1);
    _module(row - 2, col - 1, pos, 2);
    _module(row - 1, col - 2, pos, 3);
    _module(row - 1, col - 1, pos, 4);
    _module(row - 1, col, pos, 5);
    _module(row, col - 2, pos, 6);
    _module(row, col - 1, pos, 7);
    _module(row, col, pos, 8);
  }

  void _corner1(int pos) {
    _module(numrows - 1, 0, pos, 1);
    _module(numrows - 1, 1, pos, 2);
    _module(numrows - 1, 2, pos, 3);
    _module(0, numcols - 2, pos, 4);
    _module(0, numcols - 1, pos, 5);
    _module(1, numcols - 1, pos, 6);
    _module(2, numcols - 1, pos, 7);
    _module(3, numcols - 1, pos, 8);
  }

  void _corner2(int pos) {
    _module(numrows - 3, 0, pos, 1);
    _module(numrows - 2, 0, pos, 2);
    _module(numrows - 1, 0, pos, 3);
    _module(0, numcols - 4, pos, 4);
    _module(0, numcols - 3, pos, 5);
    _module(0, numcols - 2, pos, 6);
    _module(0, numcols - 1, pos, 7);
    _module(1, numcols - 1, pos, 8);
  }

  void _corner3(int pos) {
    _module(numrows - 3, 0, pos, 1);
    _module(numrows - 2, 0, pos, 2);
    _module(numrows - 1, 0, pos, 3);
    _module(0, numcols - 2, pos, 4);
    _module(0, numcols - 1, pos, 5);
    _module(1, numcols - 1, pos, 6);
    _module(2, numcols - 1, pos, 7);
    _module(3, numcols - 1, pos, 8);
  }

  void _corner4(int pos) {
    _module(numrows - 1, 0, pos, 1);
    _module(numrows - 1, numcols - 1, pos, 2);
    _module(0, numcols - 3, pos, 3);
    _module(0, numcols - 2, pos, 4);
    _module(0, numcols - 1, pos, 5);
    _module(1, numcols - 3, pos, 6);
    _module(1, numcols - 2, pos, 7);
    _module(1, numcols - 1, pos, 8);
  }
}
