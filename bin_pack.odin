package gfx

Bin :: struct {
  consumed_w, consumed_h, total_w, total_h: i32,
  right: ^Bin,
  bottom: ^Bin,
}

bin_full :: proc(bin: ^Bin) -> bool {
  return bin.right != nil;
}

init_bin :: proc(w: i32, h: i32) -> (b: Bin) {
  b.total_w = w;
  b.total_h = h;
  b.right = nil;
  return;
}

PackResult :: struct {
  x: i32, y: i32
}

/** @return The pack result, and true if success, false if no space */
add_to_bin :: proc(b: ^Bin, w: i32, h: i32) -> (r: PackResult, fits: bool) {
  if (b.total_w < w || b.total_h < h) {
    fits = false;
    return;
  }
  if !bin_full(b) {
    fits = true;
    b.consumed_w = w;
    b.consumed_h = h;
    b.right = new_clone(init_bin(b.total_w - b.consumed_w, b.consumed_h));
    b.bottom = new_clone(init_bin(b.total_w, b.total_h - b.consumed_h));
    r.x = 0;
    r.y = 0;
    return;
  } else {
    // Recurse
    if r, fits = add_to_bin(b.right, w, h); fits {
      r.x += b.consumed_w;
      return;
    }
    r, fits = add_to_bin(b.bottom, w, h);
    r.y += b.consumed_h;
    return;
  }
}

/** Free all child bins recursively */
free_child_bins :: proc(b: ^Bin) {
  if bin_full(b) {
    free_child_bins(b.right);
    free_child_bins(b.bottom);
    free(b.right);
    free(b.bottom);
    b.right = nil;
  }
}

