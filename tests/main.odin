package gfx_tests

import "core:fmt"
using import "."

main :: proc() {
  fmt.println("Testing bin packing");
  test_bin_pack();
}
