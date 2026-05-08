#version 330
in vec2 fragTexCoord;
out vec4 outColor;

uniform sampler2D normalTexture;
uniform sampler2D colorTexture;
uniform sampler2D ambientTexture;
uniform vec2 texelSize;
uniform float threshold;
uniform vec4 outlineColor;
float ambientStrength = 1;      // e.g. 0.5 — control blend from CPU side

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
    edge += length(nU - nD);        // also add vertical edges — you were missing this
    edge = smoothstep(threshold, threshold + 0.1, edge);

    // Scene + ambient
    vec4 sceneColor  = texture(colorTexture,   uv);
    vec4 ambientMap  = texture(ambientTexture,  uv);

    // Multiply ambient onto scene (standard ambient occlusion / light map blend)
    vec4 litScene = vec4(sceneColor.rgb * (1.0 + ambientMap.rgb * ambientStrength), sceneColor.a);

    outColor = mix(litScene, outlineColor, edge);
}
