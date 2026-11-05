#version 300 es
precision mediump float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    // Warm 3600K color temperature night filter:
    // Retain 100% red, 90% green, 65% blue
    pixColor.r = min(1.0, pixColor.r * 1.0);
    pixColor.g = min(1.0, pixColor.g * 0.90);
    pixColor.b = min(1.0, pixColor.b * 0.65);
    fragColor = pixColor;
}
