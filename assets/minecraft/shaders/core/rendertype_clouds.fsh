#version 150

#moj_import <minecraft:fog.glsl>

in float vertexDistance;
in vec4 vertexColor;
in vec3 Pos;
in vec3 PlayerPos;

out vec4 fragColor;

void main() {

    vec4 color = vertexColor;

    float darkness = 1.0 - clamp((color.r + color.g + color.b) / 3.0, 0.0, 1.0);

    float dayFactor = 1.0 - darkness;
    color.rgb = mix(color.rgb, vec3(1.0), dayFactor * 0.89);

    vec3 nightCloudColor = vec3(0.25, 0.48, 0.78);
    color.rgb = mix(color.rgb, nightCloudColor, darkness * 0.90);

    float brightness = (color.r + color.g + color.b) / 3.0;
    color = mix(color, FogColor, 0.15 * (1.0 - brightness));

    color.a *= 1.0f - linear_fog_value(vertexDistance, 0, FogCloudsEnd);

    float fadeDirection = (PlayerPos.y + 15.0) / 10.0;
    float fadeIntensity = abs(PlayerPos.y / 40.0);

    float topFadeHeight = 1.0 - ((0.6 - Pos.y) / 0.6);
    float bottomFadeHeight = 1.0 - (Pos.y / 3.0);
    float fadeHeight = mix(topFadeHeight, bottomFadeHeight, clamp(fadeDirection, 0.0, 1.0));
    float fadeFinal = mix(1.0, fadeHeight, clamp(fadeIntensity, 0.0, 1.0));

    color.a *= mix(fadeFinal, 1.0, 0.55);

    fragColor = color;
}