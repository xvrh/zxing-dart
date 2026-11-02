import '../../format_reader_exception.dart';

/// The Version object encapsulates attributes about a particular
/// size Data Matrix Code.
///
/// @author bbrown@google.com (Brian Brown)
class Version {
  static final _versions = _buildVersions();

  final int versionNumber;
  final int symbolSizeRows;
  final int symbolSizeColumns;
  final int dataRegionSizeRows;
  final int dataRegionSizeColumns;
  final ECBlocks ecBlocks;
  final int totalCodewords;

  Version._(this.versionNumber, this.symbolSizeRows, this.symbolSizeColumns,
      this.dataRegionSizeRows, this.dataRegionSizeColumns, this.ecBlocks)
      : totalCodewords = _totalCodewords(ecBlocks);

  // Calculate the total number of codewords
  static int _totalCodewords(ECBlocks ecBlocks) {
    var total = 0;
    var ecCodewords = ecBlocks.ecCodewords;
    for (var ecBlock in ecBlocks.ecBlocks) {
      total += ecBlock.count * (ecBlock.dataCodewords + ecCodewords);
    }
    return total;
  }

  /// <p>Deduces version information from Data Matrix dimensions.</p>
  ///
  /// @param numRows Number of rows in modules
  /// @param numColumns Number of columns in modules
  /// @return Version for a Data Matrix Code of those dimensions
  /// @throws FormatReaderException if dimensions do correspond to a valid Data Matrix size
  static Version getVersionForDimensions(int numRows, int numColumns) {
    if ((numRows & 0x01) != 0 || (numColumns & 0x01) != 0) {
      throw FormatReaderException();
    }

    for (var version in _versions) {
      if (version.symbolSizeRows == numRows &&
          version.symbolSizeColumns == numColumns) {
        return version;
      }
    }

    throw FormatReaderException();
  }

  @override
  String toString() => '$versionNumber';

  /// See ISO 16022:2006 5.5.1 Table 7
  static List<Version> _buildVersions() {
    return [
      Version._(1, 10, 10, 8, 8, ECBlocks(5, [ECB(1, 3)])),
      Version._(2, 12, 12, 10, 10, ECBlocks(7, [ECB(1, 5)])),
      Version._(3, 14, 14, 12, 12, ECBlocks(10, [ECB(1, 8)])),
      Version._(4, 16, 16, 14, 14, ECBlocks(12, [ECB(1, 12)])),
      Version._(5, 18, 18, 16, 16, ECBlocks(14, [ECB(1, 18)])),
      Version._(6, 20, 20, 18, 18, ECBlocks(18, [ECB(1, 22)])),
      Version._(7, 22, 22, 20, 20, ECBlocks(20, [ECB(1, 30)])),
      Version._(8, 24, 24, 22, 22, ECBlocks(24, [ECB(1, 36)])),
      Version._(9, 26, 26, 24, 24, ECBlocks(28, [ECB(1, 44)])),
      Version._(10, 32, 32, 14, 14, ECBlocks(36, [ECB(1, 62)])),
      Version._(11, 36, 36, 16, 16, ECBlocks(42, [ECB(1, 86)])),
      Version._(12, 40, 40, 18, 18, ECBlocks(48, [ECB(1, 114)])),
      Version._(13, 44, 44, 20, 20, ECBlocks(56, [ECB(1, 144)])),
      Version._(14, 48, 48, 22, 22, ECBlocks(68, [ECB(1, 174)])),
      Version._(15, 52, 52, 24, 24, ECBlocks(42, [ECB(2, 102)])),
      Version._(16, 64, 64, 14, 14, ECBlocks(56, [ECB(2, 140)])),
      Version._(17, 72, 72, 16, 16, ECBlocks(36, [ECB(4, 92)])),
      Version._(18, 80, 80, 18, 18, ECBlocks(48, [ECB(4, 114)])),
      Version._(19, 88, 88, 20, 20, ECBlocks(56, [ECB(4, 144)])),
      Version._(20, 96, 96, 22, 22, ECBlocks(68, [ECB(4, 174)])),
      Version._(21, 104, 104, 24, 24, ECBlocks(56, [ECB(6, 136)])),
      Version._(22, 120, 120, 18, 18, ECBlocks(68, [ECB(6, 175)])),
      Version._(23, 132, 132, 20, 20, ECBlocks(62, [ECB(8, 163)])),
      Version._(24, 144, 144, 22, 22, ECBlocks(62, [ECB(8, 156), ECB(2, 155)])),
      Version._(25, 8, 18, 6, 16, ECBlocks(7, [ECB(1, 5)])),
      Version._(26, 8, 32, 6, 14, ECBlocks(11, [ECB(1, 10)])),
      Version._(27, 12, 26, 10, 24, ECBlocks(14, [ECB(1, 16)])),
      Version._(28, 12, 36, 10, 16, ECBlocks(18, [ECB(1, 22)])),
      Version._(29, 16, 36, 14, 16, ECBlocks(24, [ECB(1, 32)])),
      Version._(30, 16, 48, 14, 22, ECBlocks(28, [ECB(1, 49)])),

      // extended forms as specified in
      // ISO 21471:2020 (DMRE) 5.5.1 Table 7
      Version._(31, 8, 48, 6, 22, ECBlocks(15, [ECB(1, 18)])),
      Version._(32, 8, 64, 6, 14, ECBlocks(18, [ECB(1, 24)])),
      Version._(33, 8, 80, 6, 18, ECBlocks(22, [ECB(1, 32)])),
      Version._(34, 8, 96, 6, 22, ECBlocks(28, [ECB(1, 38)])),
      Version._(35, 8, 120, 6, 18, ECBlocks(32, [ECB(1, 49)])),
      Version._(36, 8, 144, 6, 22, ECBlocks(36, [ECB(1, 63)])),
      Version._(37, 12, 64, 10, 14, ECBlocks(27, [ECB(1, 43)])),
      Version._(38, 12, 88, 10, 20, ECBlocks(36, [ECB(1, 64)])),
      Version._(39, 16, 64, 14, 14, ECBlocks(36, [ECB(1, 62)])),
      Version._(40, 20, 36, 18, 16, ECBlocks(28, [ECB(1, 44)])),
      Version._(41, 20, 44, 18, 20, ECBlocks(34, [ECB(1, 56)])),
      Version._(42, 20, 64, 18, 14, ECBlocks(42, [ECB(1, 84)])),
      Version._(43, 22, 48, 20, 22, ECBlocks(38, [ECB(1, 72)])),
      Version._(44, 24, 48, 22, 22, ECBlocks(41, [ECB(1, 80)])),
      Version._(45, 24, 64, 22, 14, ECBlocks(46, [ECB(1, 108)])),
      Version._(46, 26, 40, 24, 18, ECBlocks(38, [ECB(1, 70)])),
      Version._(47, 26, 48, 24, 22, ECBlocks(42, [ECB(1, 90)])),
      Version._(48, 26, 64, 24, 14, ECBlocks(50, [ECB(1, 118)])),
    ];
  }
}

/// <p>Encapsulates a set of error-correction blocks in one symbol version. Most versions will
/// use blocks of differing sizes within one version, so, this encapsulates the parameters for
/// each set of blocks. It also holds the number of error-correction codewords per block since it
/// will be the same across all blocks within one version.</p>
class ECBlocks {
  final int ecCodewords;
  final List<ECB> ecBlocks;

  ECBlocks(this.ecCodewords, this.ecBlocks);
}

/// <p>Encapsulates the parameters for one error-correction block in one symbol version.
/// This includes the number of data codewords, and the number of times a block with these
/// parameters is used consecutively in the Data Matrix code version's format.</p>
class ECB {
  final int count;
  final int dataCodewords;

  ECB(this.count, this.dataCodewords);
}
