#version 330
in vec2 fragTexCoord;
out vec4 outColor;
uniform sampler2D normalTexture;
uniform sampler2D colorTexture;
uniform vec2 texelSize;
uniform float threshold;

float luminance(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
    vec2 uv = fragTexCoord;

    vec3 nL = texture(normalTexture, uv + vec2(-texelSize.x, 0.0)).rgb * 2.0 - 1.0;
    vec3 nR = texture(normalTexture, uv + vec2( texelSize.x, 0.0)).rgb * 2.0 - 1.0;
    vec3 nU = texture(normalTexture, uv + vec2(0.0,  texelSize.y)).rgb * 2.0 - 1.0;
    vec3 nD = texture(normalTexture, uv + vec2(0.0, -texelSize.y)).rgb * 2.0 - 1.0;

    float edge = 0.0;
    edge += length(nR - nL);
    edge += length(nU - nD);
    edge *= 0.5;
    edge = smoothstep(threshold, threshold + 0.1, edge);

    vec4 sceneColor = texture(colorTexture, uv);

    // Sample a small area around the pixel to get the background color
    vec3 bgColor = vec3(0.0);
    bgColor += texture(colorTexture, uv + vec2(-texelSize.x, 0.0)).rgb;
    bgColor += texture(colorTexture, uv + vec2( texelSize.x, 0.0)).rgb;
    bgColor += texture(colorTexture, uv + vec2(0.0,  texelSize.y)).rgb;
    bgColor += texture(colorTexture, uv + vec2(0.0, -texelSize.y)).rgb;
    bgColor /= 4.0;

    // Pick black or white based on background luminance
    float lum = luminance(bgColor);
    vec3 outline = lum > 0.5 ? vec3(0.0) : vec3(1.0);

    outColor = mix(sceneColor, vec4(outline, 1.0), edge);
}
