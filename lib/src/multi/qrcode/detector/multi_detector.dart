import '../../../common/detector_result.dart';
import '../../../decode_hint.dart';
import '../../../not_found_exception.dart';
import '../../../qrcode/detector/detector.dart';
import '../../../reader_exception.dart';
import 'multi_finder_pattern_finder.dart';

/// <p>Encapsulates logic that can detect one or more QR Codes in an image, even if the QR Code
/// is rotated or skewed, or partially obscured.</p>
///
/// @author Sean Owen
/// @author Hannes Erven
class MultiDetector extends Detector {
  MultiDetector(super.image);

  List<DetectorResult> detectMulti(DecodeHints hints) {
    var finder = MultiFinderPatternFinder(image,
        resultPointCallback: hints.get(DecodeHintType.needResultPointCallback));
    var infos = finder.findMulti(hints);

    if (infos.isEmpty) {
      throw NotFoundException();
    }

    var result = <DetectorResult>[];
    for (var info in infos) {
      try {
        result.add(processFinderPatternInfo(info));
      } on ReaderException catch (_) {
        // ignore
      }
    }
    return result;
  }
}
