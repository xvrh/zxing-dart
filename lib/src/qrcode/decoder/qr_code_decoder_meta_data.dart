import 'package:zxing/src/result_point.dart';

/// Meta-data container for QR Code decoding. Instances of this class may be used to convey information back to the
/// decoding caller. Callers are expected to process this.
///
/// @see com.google.zxing.common.DecoderResult#getOther()
class QRCodeDecoderMetaData {
  /// @return true if the QR Code was mirrored.
  final bool mirrored;

  QRCodeDecoderMetaData({required this.mirrored});

  /// Apply the result points' order correction due to mirroring.
  ///
  /// @param points Array of points to apply mirror correction to.
  void applyMirroredCorrection(List<ResultPoint>? points) {
    if (!mirrored || points == null || points.length < 3) {
      return;
    }
    ResultPoint bottomLeft = points[0];
    points[0] = points[2];
    points[2] = bottomLeft;
    // No need to 'fix' top-left and alignment pattern.
  }
}
