package gfx

import stbtt "deps/odin-stb/stbtt"
import gl "deps/odin-gl"
import "core:os"

/** Bitmap font loaded into a texture */
BakedFont :: struct {
  using atlas: Atlas,
  baked_chars: []stbtt.Baked_Char,
}

/** Loads ascii 32 to 126 into a texture, asserts on failure */
load_font :: proc (filename: string, font_size: f32, filter := Filter.Nearest) -> (b: BakedFont) {
  gl.GetError();
  font_tex_buf: [512 * 512]byte;
  b.w = 512; b.h = 512;
  data, success := os.read_entire_file(filename);
  assert(success);
  defer delete(data);
  baked_chars, ret := stbtt.bake_font_bitmap(data, 0, font_size, font_tex_buf[:], cast(int)b.w, cast(int)b.h, 32, 126); // no guarantee this fits!
  assert(ret > 0, "Couldn't fit font to bitmap");
  b.baked_chars = baked_chars;
  // load texture to GPU
  tex : u32;
  gl.GenTextures(1, &b.tex);
  gl.BindTexture(gl.TEXTURE_2D, b.tex);
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter_to_gl(filter));
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter_to_gl(filter));
  texformat := gl.RED;
  gl.TexImage2D(gl.TEXTURE_2D, 0, cast(i32)texformat, b.w, b.h, 0, cast(u32)texformat, gl.UNSIGNED_BYTE, &font_tex_buf[0]);
  return;
}
