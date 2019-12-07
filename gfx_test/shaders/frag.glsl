#version 330 core

uniform sampler2D atlas;

in vec2 v_uv;

out vec4 color;

void main() {
    color = texture(atlas, v_uv);
}