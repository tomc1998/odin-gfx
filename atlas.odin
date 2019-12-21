package gfx

import stbi "deps/odin-stb/stbi"
import gl "deps/odin-gl"
import "core:mem"

/** Corresponds 1 to 1 with a gpu texture */
Atlas :: struct {
  /** Width / height in pixels */
  w, h: i32,
  /** Data on cpu, use bufferData to transfer to the gpu */
  cpu_tex: []u8,
  /** GPU tex */
  tex: u32,
  /** A texture view of the whole atlas */
  whole_tex: Tex,
  /** Bin for bin packing */
  bin: Bin,
}

Tex :: struct {
  atlas: ^Atlas,
  u0, v0, u1, v1: f32,
}

Filter :: enum {
  Linear, Nearest
}

filter_to_gl :: proc(f: Filter) -> i32 {
  switch(f) {
  case Filter.Nearest: return gl.NEAREST;
  case Filter.Linear: return gl.LINEAR;
  }
  assert(false);
  return 0;
}

/** Returns the texture type given bpp - RED, RG, RGB, or RGBA */
bpp_to_gl :: proc(bpp: i32) -> i32 {
  switch (bpp) {
  case 1: return gl.RED;
  case 2: return gl.RG;
  case 3: return gl.RGB;
  case 4: return gl.RGBA;
    case: assert(false);
  }
  return -1;
}

/** Create an atlass with the given w / h, for bin packing */
create_atlas :: proc(w: i32, h: i32, filter: Filter = Filter.Nearest) -> (a: Atlas) {
  // Allocate atlas in cpu
  a.cpu_tex = make([]u8, w * h * 4);
  a.bin = init_bin(w, h);
  a.w = w;
  a.h = h;
  gl.GenTextures(1, &a.tex);
  gl.BindTexture(gl.TEXTURE_2D, a.tex);
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter_to_gl(filter));
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter_to_gl(filter));
  texformat := bpp_to_gl(4);
  gl.TexImage2D(gl.TEXTURE_2D, 0, texformat, a.w, a.h, 0, cast(u32)texformat,
                gl.UNSIGNED_BYTE, &a.cpu_tex[0]);
  return;
}

atlas_add_tex_from_data :: proc(a: ^Atlas, w: i32, h: i32, bpp: i32, data: []u8) -> (t: Tex) {
  // Now bin pack
  packed_res, fits := add_to_bin(&a.bin, w, h);
  if !fits {
    panic("Failed to pack to atlas - no room");
  }
  t = init_tex(a, packed_res.x, packed_res.y, w, h);
  // Blit to cpu tex
  for xx : i32 = 0; xx < w; xx += 1 {
    for yy : i32 = 0; yy < h; yy += 1 {
      x := packed_res.x + xx;
      y := packed_res.y + yy;
      bb : i32 = 0;
      for ; bb < bpp; bb += 1 {
        a.cpu_tex[(x + y * a.w) * 4 + bb] = data[(xx + yy * w) * bpp + bb];
      }
      for ; bb < 4; bb += 1 {
        a.cpu_tex[(x + y * a.w) * 4 + bb] = 255;
      }
    }
  }
  return;
}

/** Add a texture from a filename to the atlas, bin packing. Panic if bin full. */
atlas_add_tex :: proc(a: ^Atlas, filename: cstring) -> (t: Tex, succ: bool) {
  succ = true;
  w, h, bpp: i32;
  data := stbi.load(filename, &w, &h, &bpp, 0);
  defer stbi.image_free(data);
  if data == nil {
    succ = false;
    return;
  }
  succ = true;
  t = atlas_add_tex_from_data(a, w, h, bpp, mem.slice_ptr(data, cast(int)(w*h*bpp)));
  return;
}

/** Sync the cpu texture to the GPU texture - call this after add_tex for
changes to actually take effect. */
atlas_gpu_sync :: proc(a: ^Atlas) {
  // TODO Optimize - only update sections which have been updated in cpu tex
  gl.BindTexture(gl.TEXTURE_2D, a.tex);
  texformat := cast(u32)bpp_to_gl(4);
  gl.TexSubImage2D(gl.TEXTURE_2D, 0, 0, 0, a.w, a.h, texformat, gl.UNSIGNED_BYTE, &a.cpu_tex[0]);
}

init_tex :: proc(a: ^Atlas, x, y, w, h: i32) -> (out: Tex) {
  out.atlas = a;
  out.u0 = cast(f32)x / cast(f32)a.w;
  out.v0 = cast(f32)y / cast(f32)a.h;
  out.u1 = cast(f32)(x+w) / cast(f32)a.w;
  out.v1 = cast(f32)(y+h) / cast(f32)a.h;
  return;
}

sub_tex :: proc(t: Tex, x, y, w, h: i32) -> (out: Tex) {
  out.atlas = t.atlas;
  out.u0 = t.u0 + cast(f32)x / cast(f32)t.atlas.w;
  out.v0 = t.v0 + cast(f32)y / cast(f32)t.atlas.h;
  out.u1 = t.u0 + cast(f32)(x+w) / cast(f32)t.atlas.w;
  out.v1 = t.v0 + cast(f32)(y+h) / cast(f32)t.atlas.h;
  return;
}
