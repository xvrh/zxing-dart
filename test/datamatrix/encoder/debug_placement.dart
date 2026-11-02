import 'package:zxing2/src/datamatrix/encoder/default_placement.dart';

class DebugPlacement extends DefaultPlacement {
  DebugPlacement(super.codewords, super.numcols, super.numrows);

  List<String> toBitFieldStringArray() {
    var array = List<String>.filled(numrows, '');
    var startpos = 0;
    for (var row = 0; row < numrows; row++) {
      var sb = StringBuffer();
      for (var i = 0; i < numcols; i++) {
        sb.write(bits[startpos + i] == 1 ? '1' : '0');
      }
      array[row] = sb.toString();
      startpos += numcols;
    }
    return array;
  }
}
