#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 center;
    vec2 screenSize;
    float radius;
    float softness;
    float invert;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 tex = texture(source, qt_TexCoord0);
    vec2 pos = qt_TexCoord0 * screenSize;
    float d = distance(pos, center);
    
    float edge = smoothstep(radius, max(0.0, radius - softness), d);
    
    if (invert > 0.5) {
        edge = 1.0 - edge;
    }
    
    fragColor = tex * (edge * qt_Opacity);
}
