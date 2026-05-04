#version 330
in vec3 fragNormal;
out vec4 outColor;

void main() {
    // Pack normals from [-1,1] to [0,1] for storage in color buffer
//outColor = vec4(1,1,1,1);
    outColor = vec4(fragNormal * 0.5 + 0.5, 1.0);
}
