#version 330 core

uniform sampler2D atlas;

in vec2 v_uv;

out vec4 color;

void main() {
    color = vec4(1.0, 1.0, 1.0, texture(atlas, v_uv).r);
}
