void arraycopy(List src, int srcPos, List dest, int destPos, int length) {
  dest.setRange(destPos, destPos + length, src, srcPos);
}
