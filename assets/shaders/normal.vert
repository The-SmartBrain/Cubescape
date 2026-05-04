#version 330
in vec3 vertexPosition;
in vec3 vertexNormal;

uniform mat4 mvp;
uniform mat4 matNormal; // transpose(inverse(model)) for correct normal transform

out vec3 fragNormal;

void main() {
    fragNormal = normalize((matNormal * vec4(vertexNormal, 0.0)).xyz);
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
