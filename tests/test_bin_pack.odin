package gfx_tests

using import ".."

test_bin_pack :: proc() {
  bin := init_bin(1024, 1024);
  assert(!bin_full(&bin));
  {
    r, fits := add_to_bin(&bin, 256, 256);
    assert(fits);
    assert(r.x == 0);
    assert(r.y == 0);
    assert(bin_full(&bin)); // Assert bin full now
  }
  {
    // Now add something that should go in the right bin
    r, fits := add_to_bin(&bin, 256, 256);
    assert(fits);
    assert(r.x == 256);
    assert(r.y == 0);
  }
  {
    // Now add something that can't fit in the right bin, so should go in the
    r, fits := add_to_bin(&bin, 768, 768);
    assert(fits);
    assert(r.x == 0);
    assert(r.y == 256);
  }
  {
    // Now add something that shouldn't fit any more
    r, fits := add_to_bin(&bin, 512, 512);
    assert(!fits);
  }
  {
    // Check freeing un-fills bin
    free_child_bins(&bin);
    assert(!bin_full(&bin));
  }
}
