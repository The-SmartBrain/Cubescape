#version 330

out vec4 finalColor;

in vec4 fragColor;
in vec3 fragPosition;
in vec3 fragNormal;
in vec2 fragTexCoord;
  
uniform vec3 ambientColor;
uniform sampler2D texture0;
uniform vec3 lightPosition;
float ambientStrength = 0.2;

void main()
{
    // ambient
    vec3 ambient = ambientStrength * ambientColor;
    
    // diffuse 
    vec3 norm = normalize(fragNormal);
    vec3 lightDir = normalize(lightPosition - fragPosition);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diff * ambientColor;
            
    vec3 result = (ambient + diffuse) * fragColor.rgb;
    vec4 texelColor = texture(texture0, fragTexCoord);
    finalColor = texelColor * vec4(diffuse,fragColor.a);
} 
