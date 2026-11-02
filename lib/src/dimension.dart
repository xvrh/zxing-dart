/// Simply encapsulates a width and height.
class Dimension {
  final int width;
  final int height;

  Dimension(this.width, this.height) {
    if (width < 0 || height < 0) {
      throw ArgumentError();
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is Dimension) {
      return width == other.width && height == other.height;
    }
    return false;
  }

  @override
  int get hashCode {
    return width * 32713 + height;
  }

  @override
  String toString() {
    return '${width}x$height';
  }
}
