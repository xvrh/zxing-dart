//https://gist.github.com/jtmcdole/297434f327077dbfe5fb19da3b4ef5be
/// Returns the number of trailing zeros in a 32bit unsigned integer.
///
/// Hacker's Delight, Reiser's algorithm.
/// "Three ops including a "remainder, plus an indexed load."
///
/// Works because each bit in the 32 bit integer hash uniquely to the
/// prime number 37. The lowest set bit is returned via (x & -x).
int numberOfTrailingZerosInt32(int x) {
  assert(x < 0x100000000, 'only 32bit numbers  supported');
  return _ntzLut32[(x & -x) % 37];
}

const _ntzLut32 = [
  32, 0, 1, 26, 2, 23, 27, 0, //
  3, 16, 24, 30, 28, 11, 0, 13,
  4, 7, 17, 0, 25, 22, 31, 15,
  29, 10, 12, 6, 0, 21, 14, 9,
  5, 20, 8, 19, 18
];

// Assumes i is <= 32-bit.
int bitCount(int i) {
// See "Hacker's Delight", section 5-1, "Counting 1-Bits".

// The basic strategy is to use "divide and conquer" to
// add pairs (then quads, etc.) of bits together to obtain
// sub-counts.
//
// A straightforward approach would look like:
//
// i = (i & 0x55555555) + ((i >>  1) & 0x55555555);
// i = (i & 0x33333333) + ((i >>  2) & 0x33333333);
// i = (i & 0x0F0F0F0F) + ((i >>  4) & 0x0F0F0F0F);
// i = (i & 0x00FF00FF) + ((i >>  8) & 0x00FF00FF);
// i = (i & 0x0000FFFF) + ((i >> 16) & 0x0000FFFF);
//
// The code below removes unnecessary &'s and uses a
// trick to remove one instruction in the first line.

  i -= ((i >> 1) & 0x55555555);
  i = (i & 0x33333333) + ((i >> 2) & 0x33333333);
  i = ((i + (i >> 4)) & 0x0F0F0F0F);
  i += (i >> 8);
  i += (i >> 16);
  return (i & 0x0000003F);
}
