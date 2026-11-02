import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zxing2/zxing2.dart';
import 'image_luminance_source.dart';

/// Decodes every image of a blackbox folder, like upstream's `AbstractBlackBoxTestCase`.
///
/// When [tryHarderCount] is given, every image is also decoded with the
/// [DecodeHintType.tryHarder] hint and that count is checked too.
/// When [expectedFormat] is given, a result in another format counts as a misread.
/// Expected metadata is read from `<name>.metadata.txt` files when they exist.
void testGolden(
  String folder,
  Reader reader, {
  required int mustPassCount,
  int? tryHarderCount,
  int maxMisreads = 0,
  int maxTryHarderMisreads = 0,
  BarcodeFormat? expectedFormat,
  DecodeHints? hints,
  int rotation = 0,
  List<String> skips = const [],
  @Deprecated('For debugging') bool? solo,
}) {
  test('Golden $folder (rotation: $rotation)', () {
    var normal = _Counts();
    var tryHarder = _Counts();
    for (var pngFile in Directory(p.join('test/resources/blackbox', folder))
        .listSync()
        .whereType<File>()
        .where((f) => p.extension(f.path) == '.png')) {
      if (skips.contains(p.basename(pngFile.path))) {
        ++normal.passed;
        ++tryHarder.passed;
        continue;
      }

      var image = img.decodePng(pngFile.readAsBytesSync())!;
      if (rotation != 0) {
        image = img.copyRotate(image, angle: rotation);
      }

      LuminanceSource source = ImageLuminanceSource(image);
      var bitmap = BinaryBitmap(HybridBinarizer(source));

      var expectedMetadata = _readMetadata(pngFile);
      for (var useTryHarder in [false, if (tryHarderCount != null) true]) {
        var counts = useTryHarder ? tryHarder : normal;
        var decodeHints = hints?.clone() ?? DecodeHints();
        if (useTryHarder) {
          decodeHints.put(DecodeHintType.tryHarder);
        }
        try {
          var result = _decode(reader, bitmap, decodeHints);
          if (_matches(result, pngFile, expectedFormat, expectedMetadata)) {
            ++counts.passed;
          } else {
            ++counts.misread;
          }
        } on ReaderException catch (_) {
          // Not detected
        }
      }
    }

    expect(normal.passed, greaterThanOrEqualTo(mustPassCount),
        reason: 'Too many images failed');
    expect(normal.misread, lessThanOrEqualTo(maxMisreads),
        reason: 'Too many images misread');
    if (tryHarderCount != null) {
      expect(tryHarder.passed, greaterThanOrEqualTo(tryHarderCount),
          reason: 'Try harder, too many images failed');
      expect(tryHarder.misread, lessThanOrEqualTo(maxTryHarderMisreads),
          reason: 'Try harder, too many images misread');
    }
  },
      // ignore: deprecated_member_use, invalid_use_of_do_not_submit_member
      solo: solo ?? false);
}

class _Counts {
  int passed = 0;
  int misread = 0;
}

Result _decode(Reader reader, BinaryBitmap bitmap, DecodeHints hints) {
  // Try in 'pure' mode mostly to exercise PURE_BARCODE code paths for exceptions;
  // not expected to pass, generally
  try {
    return reader.decode(bitmap,
        hints: hints.clone()..put(DecodeHintType.pureBarcode));
  } on ReaderException catch (_) {
    // continue
  }
  return reader.decode(bitmap, hints: hints);
}

bool _matches(Result result, File pngFile, BarcodeFormat? expectedFormat,
    Map<ResultMetadataType, String> expectedMetadata) {
  if (expectedFormat != null && result.format != expectedFormat) {
    return false;
  }

  var textFile = File(p.setExtension(pngFile.path, '.txt'));
  if (textFile.existsSync()) {
    if (result.text != textFile.readAsStringSync()) {
      return false;
    }
  } else {
    var binFile = File(p.setExtension(pngFile.path, '.bin'));
    var expected = binFile.readAsBytesSync().buffer.asInt8List();
    var rawBytes = result.rawBytes;
    if (rawBytes == null ||
        rawBytes.length != expected.length ||
        Iterable<int>.generate(rawBytes.length)
            .any((i) => rawBytes[i] != expected[i])) {
      return false;
    }
  }

  for (var entry in expectedMetadata.entries) {
    if (result.resultMetadata[entry.key]?.toString() != entry.value) {
      return false;
    }
  }
  return true;
}

Map<ResultMetadataType, String> _readMetadata(File pngFile) {
  var metadataFile = File(p.setExtension(pngFile.path, '.metadata.txt'));
  if (!metadataFile.existsSync()) return const {};

  var metadata = <ResultMetadataType, String>{};
  for (var line in LineSplitter.split(metadataFile.readAsStringSync())) {
    var separator = line.indexOf('=');
    if (line.trim().isEmpty || line.startsWith('#') || separator < 0) continue;
    var key = line.substring(0, separator).trim();
    // SUGGESTED_PRICE => suggestedPrice
    var name = key.toLowerCase().replaceAllMapped(
        RegExp('_([a-z0-9])'), (m) => m.group(1)!.toUpperCase());
    metadata[ResultMetadataType.values.byName(name)] =
        line.substring(separator + 1).trim();
  }
  return metadata;
}
