package gfx

import glfw "deps/odin-glfw"
import gl "deps/odin-gl"
import "core:runtime"
import "core:fmt"

KeyCallback :: proc(key: i32, action: KeyAction, mods: i32);

_GlfwUserState :: struct {
  key_callback: KeyCallback,
}

Window :: struct {
  glfw_window: glfw.Window_Handle,
  _glfw_user_state: ^_GlfwUserState,
}

destroy_window :: proc(w: ^Window) {
  free(w._glfw_user_state);
  glfw.destroy_window(w.glfw_window);
}

window_should_close :: proc (w: ^Window) -> bool {
  return glfw.window_should_close(w.glfw_window);
}

swap_buffers :: proc(w: ^Window) {
  glfw.swap_buffers(w.glfw_window);
}

poll_events :: proc() {
  glfw.poll_events();
}

clear_window :: proc(w: ^Window) {
  gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
}

KeyAction :: enum i32 {
  Press = i32(glfw.Key_State.PRESS), Release = i32(glfw.Key_State.RELEASE)
}

_internal_glfw_key_callback :: proc "c" (
  w: glfw.Window_Handle,
  key: i32, scancode: i32, action: i32, mods: i32)
{
  context = runtime.default_context();
  user_data := cast(^_GlfwUserState)(glfw.get_window_user_pointer(w));
  if user_data.key_callback != nil {
    user_data.key_callback(key, KeyAction(action), mods);
  }
}

/** See input_constants.odin for key values and mod values */
set_key_callback :: proc(window: ^Window, fn: KeyCallback) {
  window._glfw_user_state.key_callback = fn;
  glfw.set_key_callback(window.glfw_window, _internal_glfw_key_callback);
}

/** See input_constants.odin */
key_down :: proc(w: ^Window, key: int) -> bool {
  return glfw.get_key(w.glfw_window, cast(glfw.Key)key) == glfw.PRESS;
}

create_window :: proc (windowName: string) -> (w: Window) {
  assert(glfw.init());

  w._glfw_user_state = new(_GlfwUserState);

  // Init window + GL context
  glfw.window_hint(glfw.CONTEXT_VERSION_MAJOR, 3);
  glfw.window_hint(glfw.CONTEXT_VERSION_MINOR, 3);
  glfw.window_hint(glfw.OPENGL_PROFILE, cast(int)glfw.OPENGL_CORE_PROFILE);
  w.glfw_window = glfw.create_window(800, 600, windowName, nil, nil);
  glfw.set_window_user_pointer(w.glfw_window, w._glfw_user_state);
  glfw.make_context_current(w.glfw_window);
  gl.load_up_to(3, 3, glfw.set_proc_address);
  gl.Enable(gl.BLEND);
  gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
  gl.Enable(gl.DEPTH_TEST);
  gl.ClearColor(0.0, 0.0, 0.0, 1.0);

  return;
}
