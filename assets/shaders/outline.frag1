#version 330
in vec2 fragTexCoord;
out vec4 outColor;

uniform sampler2D normalTexture;
uniform sampler2D colorTexture;   // your actual rendered scene
uniform vec2 texelSize;           // 1.0/screenWidth, 1.0/screenHeight
uniform float threshold;          // e.g. 0.1
uniform vec4 outlineColor;        // e.g. black

void main() {
    vec2 uv = fragTexCoord;

    // Sample neighbors
    vec3 nC = texture(normalTexture, uv).rgb * 2.0 - 1.0;
    vec3 nL = texture(normalTexture, uv + vec2(-texelSize.x, 0.0)).rgb * 2.0 - 1.0;
    vec3 nR = texture(normalTexture, uv + vec2( texelSize.x, 0.0)).rgb * 2.0 - 1.0;
    vec3 nU = texture(normalTexture, uv + vec2(0.0,  texelSize.y)).rgb * 2.0 - 1.0;
    vec3 nD = texture(normalTexture, uv + vec2(0.0, -texelSize.y)).rgb * 2.0 - 1.0;

    // Measure normal divergence
    float edge = 0.0;
    edge += length(nR - nL);
    edge += length(nU - nD);
    edge *= 0.5;

    edge = smoothstep(threshold, threshold + 0.1, edge);

    vec4 sceneColor = texture(colorTexture, uv);
    outColor = mix(sceneColor, outlineColor, edge);
}
