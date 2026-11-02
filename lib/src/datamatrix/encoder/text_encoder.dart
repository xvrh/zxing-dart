import 'package:charcode/charcode.dart';
import 'c40_encoder.dart';
import 'high_level_encoder.dart';

class TextEncoder extends C40Encoder {
  @override
  int get encodingMode {
    return HighLevelEncoder.textEncodation;
  }

  @override
  int encodeChar(int c, List<int> sb) {
    if (c == $space) {
      sb.add(3);
      return 1;
    }
    if (c >= $0 && c <= $9) {
      sb.add(c - 48 + 4);
      return 1;
    }
    if (c >= $a && c <= $z) {
      sb.add(c - 97 + 14);
      return 1;
    }
    if (c < $space) {
      sb.add(0); //Shift 1 Set
      sb.add(c);
      return 2;
    }
    if (c <= $slash) {
      sb.add(1); //Shift 2 Set
      sb.add(c - 33);
      return 2;
    }
    if (c <= $at) {
      sb.add(1); //Shift 2 Set
      sb.add(c - 58 + 15);
      return 2;
    }
    if (c >= $lbracket && c <= $underscore) {
      sb.add(1); //Shift 2 Set
      sb.add(c - 91 + 22);
      return 2;
    }
    if (c == $backquote) {
      sb.add(2); //Shift 3 Set
      sb.add(0); // '`' - 96 == 0
      return 2;
    }
    if (c <= $Z) {
      sb.add(2); //Shift 3 Set
      sb.add(c - 65 + 1);
      return 2;
    }
    if (c <= 127) {
      sb.add(2); //Shift 3 Set
      sb.add(c - 123 + 27);
      return 2;
    }
    sb.addAll([1, 0x1e]); //Shift 2, Upper Shift
    var len = 2;
    len += encodeChar(c - 128, sb);
    return len;
  }
}
