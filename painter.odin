package gfx

import linalg "core:math/linalg"
import "core:math"
import gl "deps/odin-gl"
import "core:os"
import "core:fmt"

Vert :: struct #packed {
  x, y, z, u, v: f32,
  col: u32,
}

PaintMode :: enum {
  Text, Image
}

Painter :: struct {
  vert_list: [dynamic]Vert,
  white_tex: Tex,
  uploaded_verts, vao, vbo: u32,
  atlas: ^Atlas,
  img_uniforms, text_uniforms: gl.Uniforms,
  font: BakedFont,
  mode: PaintMode,
  // Shader programs
  img_program, text_program: u32,
}

/** Call after add_tex. This will flush any changes to the atlas through to the
GPU. */
gpu_sync :: proc(p: ^Painter) {
  atlas_gpu_sync(p.atlas);
}

/** Call gpu_sync afterwards to push changes to the GPU */
add_tex :: proc(p: ^Painter, filename: cstring) -> (t: Tex) {
  succ: bool;
  t, succ = atlas_add_tex(p.atlas, filename);
  if !succ {
    fmt.eprintf("\nERROR: Failed to load texture '%v'\n\n", filename);
    panic("Aborting - texture load error");
  }
  return;
}

init_painter :: proc(font_filename: string,
                     font_size: f32 = 14.0,
                     img_vert_shader := "shaders/vert.glsl",
                     img_frag_shader := "shaders/frag.glsl",
                     text_vert_shader := "shaders/vert_text.glsl",
                     text_frag_shader := "shaders/frag_text.glsl") -> (p: Painter)
{
  p.mode = .Image;
  p.font = load_font(font_filename, font_size);
  p.vert_list = [dynamic]Vert{};
  p.atlas = new_clone(create_atlas(1024, 1024));
  img_program, img_shader_success := gl.load_shaders(img_vert_shader, img_frag_shader);
  text_program, text_shader_success := gl.load_shaders(text_vert_shader, text_frag_shader);
  assert(img_shader_success);
  assert(text_shader_success);
  p.img_program = img_program;
  p.text_program = text_program;
  p.img_uniforms = gl.get_uniforms_from_program(img_program);
  p.text_uniforms = gl.get_uniforms_from_program(text_program);
  gl.GenVertexArrays(1, &p.vao);
  gl.BindVertexArray(p.vao);
  gl.GenBuffers(1, &p.vbo);
  gl.BindBuffer(gl.ARRAY_BUFFER, p.vbo);

  // Load white texture into atlas
  p.white_tex = atlas_add_tex_from_data(p.atlas, 1, 1, 1, []u8{255});
  gpu_sync(&p);

  return;
}

draw_text :: proc(p: ^Painter, text: string, x, y: f32, col : u32 = 0xffffffff) {
  assert(len(text) > 0);
  if (p.mode == .Image) {
    flush_render(p);
    p.mode = .Text;
  }
  cpos : f32 = 0;
  for c in text {
    // Lookup char & uv for char
    assert(c >= 32 && c <= 126);
    bc := p.font.baked_chars[c - 32];
    u0 := cast(f32)bc.x0 / cast(f32)p.font.w;
    v0 := cast(f32)bc.y0 / cast(f32)p.font.h;
    u1 := cast(f32)bc.x1 / cast(f32)p.font.w;
    v1 := cast(f32)bc.y1 / cast(f32)p.font.h;

    w, h : f32 = cast(f32)(bc.x1 - bc.x0), cast(f32)(bc.y1 - bc.y0);
    append(&p.vert_list,
           Vert { math.floor(x+bc.xoff+cpos+0), math.floor(y+bc.yoff+0), 0, u0, v0, col },
           Vert { math.floor(x+bc.xoff+cpos+w), math.floor(y+bc.yoff+0), 0, u1, v0, col },
           Vert { math.floor(x+bc.xoff+cpos+w), math.floor(y+bc.yoff+h), 0, u1, v1, col },
           Vert { math.floor(x+bc.xoff+cpos+0), math.floor(y+bc.yoff+0), 0, u0, v0, col },
           Vert { math.floor(x+bc.xoff+cpos+0), math.floor(y+bc.yoff+h), 0, u0, v1, col },
           Vert { math.floor(x+bc.xoff+cpos+w), math.floor(y+bc.yoff+h), 0, u1, v1, col });

    cpos += bc.xadvance;
  }
}

fill_rect :: proc(p: ^Painter, x, y, w, h : f32, col : u32 = 0xffffffff) {
  draw_img(p, p.white_tex, x, y, w, h, col);
}

draw_img :: proc(p: ^Painter, t: Tex, x, y, w, h : f32, col : u32 = 0xffffffff) {
  if (p.mode == .Text) {
    flush_render(p);
    p.mode = .Image;
  }
  assert(t.atlas == p.atlas);
  append(&p.vert_list,
         Vert { math.floor(x)+0, math.floor(y)+0, 0, t.u0, t.v0, col },
         Vert { math.floor(x)+w, math.floor(y)+0, 0, t.u1, t.v0, col },
         Vert { math.floor(x)+w, math.floor(y)+h, 0, t.u1, t.v1, col },
         Vert { math.floor(x)+0, math.floor(y)+0, 0, t.u0, t.v0, col },
         Vert { math.floor(x)+0, math.floor(y)+h, 0, t.u0, t.v1, col },
         Vert { math.floor(x)+w, math.floor(y)+h, 0, t.u1, t.v1, col });
}

/** Doesn't remove uploaded data, just clears CPU buffer */
_clear_buffer :: proc(p: ^Painter) {
  clear(&p.vert_list);
}

/** vbo should be bound to ARRAY_BUFFER */
_upload_buffer :: proc(p: ^Painter) {
  p.uploaded_verts = cast(u32)len(p.vert_list);
  if len(p.vert_list) == 0 {return;}
  gl.BindVertexArray(p.vao);
  gl.BindBuffer(gl.ARRAY_BUFFER, p.vbo);
  gl.BufferData(gl.ARRAY_BUFFER, len(p.vert_list) * size_of(p.vert_list[0]), &p.vert_list[0], gl.STATIC_DRAW);
  // TODO setup col / uv pointers
  gl.EnableVertexAttribArray(0);
  gl.EnableVertexAttribArray(1);
  gl.EnableVertexAttribArray(2);
  gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(Vert), nil);
  gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, size_of(Vert), cast(rawptr)cast(uintptr)(3 * size_of(f32)));
  gl.VertexAttribPointer(2, 4, gl.UNSIGNED_BYTE, gl.TRUE, size_of(Vert), cast(rawptr)cast(uintptr)(5 * size_of(f32)));
}

/** Render this painter. This will flush all current drawing tot he gpu, so
calling this again will render nothing. */
flush_render :: proc(p: ^Painter) {
  _upload_buffer(p);
  _clear_buffer(p);
  mat := linalg.ortho3d(0, 800, 600, 0, -1, 1);

  // Activate img / text shader depending on mode
  uniforms : ^gl.Uniforms;
  switch p.mode {
  case .Image:
    uniforms = &p.img_uniforms;
    gl.UseProgram(p.img_program);
  case .Text:
    uniforms = &p.text_uniforms;
    gl.UseProgram(p.text_program);
  }

  gl.UniformMatrix4fv(uniforms["proj_mat"].location, 1, gl.FALSE, &mat[0][0]);
  gl.Uniform1i(uniforms["atlas"].location, 0);

  gl.BindVertexArray(p.vao);
  gl.BindBuffer(gl.ARRAY_BUFFER, p.vbo);

  // Activate img / text texture depending on mode
  gl.ActiveTexture(gl.TEXTURE0);
  switch p.mode {
  case .Image: gl.BindTexture(gl.TEXTURE_2D, p.atlas.tex);
  case .Text: gl.BindTexture(gl.TEXTURE_2D, p.font.tex);
  }

  gl.DrawArrays(gl.TRIANGLES, 0, cast(i32)p.uploaded_verts);
}
