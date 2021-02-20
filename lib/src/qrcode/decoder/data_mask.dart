import '../../common/bit_matrix.dart';

/// <p>Encapsulates data masks for the data bits in a QR code, per ISO 18004:2006 6.8. Implementations
/// of this class can un-mask a raw BitMatrix. For simplicity, they will unmask the entire BitMatrix,
/// including areas used for finder patterns, timing patterns, etc. These areas should be unused
/// after the point they are unmasked anyway.</p>
///
/// <p>Note that the diagram in section 6.8.1 is misleading since it indicates that i is column position
/// and j is row position. In fact, as the text says, i is row position and j is column position.</p>
///
/// @author Sean Owen
class DataMask {
  // See ISO 18004:2006 6.8.1

  /// 000: mask bits for which (x + y) mod 2 == 0
  static final dataMask000 =
      DataMask._(isMasked: (i, j) => ((i + j) & 0x01) == 0);

  /// 001: mask bits for which x mod 2 == 0
  static final dataMask001 = DataMask._(isMasked: (i, j) => (i & 0x01) == 0);

  /// 010: mask bits for which y mod 3 == 0
  static final dataMask010 = DataMask._(isMasked: (i, j) => j % 3 == 0);

  /// 011: mask bits for which (x + y) mod 3 == 0
  static final dataMask011 = DataMask._(isMasked: (i, j) => (i + j) % 3 == 0);

  /// 100: mask bits for which (x/2 + y/3) mod 2 == 0
  static final dataMask100 = DataMask._(isMasked: (i, j) {
    return ((i ~/ 2 + j ~/ 3) & 0x01) == 0;
  });

  /// 101: mask bits for which xy mod 2 + xy mod 3 == 0
  /// equivalently, such that xy mod 6 == 0
  static final dataMask101 = DataMask._(isMasked: (i, j) => (i * j) % 6 == 0);

  /// 110: mask bits for which (xy mod 2 + xy mod 3) mod 2 == 0
  /// equivalently, such that xy mod 6 < 3
  static final dataMask110 = DataMask._(isMasked: (i, j) => ((i * j) % 6) < 3);

  /// 111: mask bits for which ((x+y)mod 2 + xy mod 3) mod 2 == 0
  /// equivalently, such that (x + y + xy mod 3) mod 2 == 0
  static final dataMask111 =
      DataMask._(isMasked: (i, j) => ((i + j + ((i * j) % 3)) & 0x01) == 0);

  static final values = <DataMask>[
    dataMask000,
    dataMask001,
    dataMask010,
    dataMask011,
    dataMask100,
    dataMask101,
    dataMask110,
    dataMask111,
  ];

  /// <p>Implementations of this method reverse the data masking process applied to a QR Code and
  /// make its bits ready to read.</p>
  ///
  /// @param bits representation of QR Code bits
  /// @param dimension dimension of QR Code, represented by bits, being unmasked
  void unmaskBitMatrix(BitMatrix bits, int dimension) {
    for (var i = 0; i < dimension; i++) {
      for (var j = 0; j < dimension; j++) {
        if (isMasked(i, j)) {
          bits.flip(j, i);
        }
      }
    }
  }

  final bool Function(int i, int j) isMasked;

  DataMask._({required this.isMasked});
}
