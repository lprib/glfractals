#version 420

in vec2 position;

uniform vec2 t;

void main() { gl_Position = vec4(position, 0.0, 1.0); }