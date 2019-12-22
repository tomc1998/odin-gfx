#version 330 core

uniform sampler2D atlas;

in vec2 v_uv;
in vec4 v_col;

out vec4 color;

void main() {
    color = v_col.argb * vec4(1.0, 1.0, 1.0, texture(atlas, v_uv).r);
}
