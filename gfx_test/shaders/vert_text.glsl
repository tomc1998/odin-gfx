#version 330 core

uniform mat4 proj_mat;

layout(location = 0) in vec3 pos;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec4 col;

out vec2 v_uv;
out vec4 v_col;

void main() {
  gl_Position = proj_mat * vec4(pos, 1.0);
  v_uv = uv;
  v_col = col;
}
