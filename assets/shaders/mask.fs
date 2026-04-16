#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform sampler2D mask;
uniform bool useMask;        // toggle

out vec4 finalColor;

void main()
{
    if (useMask)
    {
        vec4 maskColour = texture(mask, fragTexCoord);
        if (maskColour.r < 0.25) discard;
        finalColor = texture(texture0, fragTexCoord) * maskColour;
    }
    else
    {
        finalColor = texture(texture0, fragTexCoord);
    }
}
