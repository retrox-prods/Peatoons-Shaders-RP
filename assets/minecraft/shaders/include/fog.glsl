#version 150

layout(std140) uniform Fog {
    vec4 FogColor;
    float FogEnvironmentalStart;
    float FogEnvironmentalEnd;
    float FogRenderDistanceStart;
    float FogRenderDistanceEnd;
    float FogSkyEnd;
    float FogCloudsEnd;
};

const float ENVIRONMENTAL_DENSITY = 1.10; 
const float RENDER_DENSITY        = 1.15; 
const float SKY_DENSITY           = 1.00; 
const float CLOUD_DENSITY         = 1.00; 

const float ENVIRONMENTAL_START_MULT = 0.35;
const float ENVIRONMENTAL_END_MULT   = 0.96;
const float RENDER_START_MULT        = 0.35;
const float RENDER_END_MULT          = 1.00;

// Base daytime and nighttime atmospheric fog
const vec3 FOG_TINT = vec3(0.92, 1.12, 1.45);
const float FOG_TINT_INTENSITY = 0.85;

const vec3 DAY_FOG   = vec3(0.78, 0.93, 1.40);
const vec3 NIGHT_FOG = vec3(0.08, 0.04, 0.10);

// ★ RICH SUNSET & SUNRISE PALETTE ★
const vec3 SUNSET_ORANGE = vec3(1.00, 0.38, 0.08); // Deep fiery horizon orange
const vec3 SUNSET_PURPLE = vec3(0.58, 0.18, 0.68); // Rich twilight purple upper sky
const vec3 SUNRISE_GOLD  = vec3(1.00, 0.65, 0.18); // Amber dawn horizon
const vec3 SUNRISE_PINK  = vec3(0.95, 0.32, 0.58); // Vibrant morning magenta/pink

float linear_fog_value(float vertexDistance, float fogStart, float fogEnd) {
    if (vertexDistance <= fogStart) return 0.0;
    if (vertexDistance >= fogEnd) return 1.0;
    return (vertexDistance - fogStart) / (fogEnd - fogStart);
}

float total_fog_value(float sphericalVertexDistance, float cylindricalVertexDistance,
                      float environmentalStart, float environmentalEnd,
                      float renderDistanceStart, float renderDistanceEnd) {

    float envStart = environmentalStart * ENVIRONMENTAL_START_MULT;
    float envEnd   = environmentalEnd   * ENVIRONMENTAL_END_MULT;
    float rendStart = renderDistanceStart * RENDER_START_MULT;
    float rendEnd   = renderDistanceEnd   * RENDER_END_MULT;

    float environmentalFog = linear_fog_value(
        sphericalVertexDistance,
        envStart * (1.8 / ENVIRONMENTAL_DENSITY),
        envEnd   / ENVIRONMENTAL_DENSITY
    );

    float renderFog = linear_fog_value(
        cylindricalVertexDistance,
        rendStart * (1.0 / RENDER_DENSITY),
        rendEnd   / RENDER_DENSITY
    );

    return max(environmentalFog, renderFog) * 0.4;
}

vec4 apply_fog(vec4 inColor, float sphericalVertexDistance, float cylindricalVertexDistance,
               float environmentalStart, float environmentalEnd,
               float renderDistanceStart, float renderDistanceEnd,
               vec4 fogColor) {

    float fogValue = total_fog_value(
        sphericalVertexDistance, cylindricalVertexDistance,
        environmentalStart, environmentalEnd,
        renderDistanceStart, renderDistanceEnd
    );

    fogValue *= 0.6;

    float skyHeightFactor = clamp((sphericalVertexDistance - (FogSkyEnd * 0.5)) / (FogSkyEnd * 0.5), 0.0, 1.0);

    // Base blend between day and night fog
    vec3 finalFog = mix(DAY_FOG, NIGHT_FOG, skyHeightFactor);

    // Dynamic detection of Sunset/Sunrise using vanilla engine's reddish FogColor signal
    float redDominance = clamp((fogColor.r - fogColor.b) * 2.5, 0.0, 1.0);
    float warmFactor   = clamp((fogColor.r + fogColor.g - fogColor.b * 1.4), 0.0, 1.0);

    // Multi-tone Sunset: Fiery Orange at horizon transitioning to Twilight Purple above
    vec3 sunsetGradient = mix(SUNSET_ORANGE, SUNSET_PURPLE, skyHeightFactor * 0.85);
    
    // Multi-tone Sunrise: Golden Amber horizon into Vivid Pink/Magenta above
    vec3 sunriseGradient = mix(SUNRISE_GOLD, SUNRISE_PINK, skyHeightFactor * 0.75);

    // Strong atmospheric blending during twilight transitions
    if (fogColor.r > fogColor.g) {
        // Evening Sunset transition
        finalFog = mix(finalFog, sunsetGradient, redDominance * 0.88);
    } else {
        // Morning Sunrise transition
        finalFog = mix(finalFog, sunriseGradient, warmFactor * 0.82);
    }

    vec3 mixedColor = mix(inColor.rgb, finalFog, fogValue * fogColor.a);

    // Final color boost to keep sunset colors punchy
    mixedColor *= vec3(1.08, 1.04, 1.12);

    return vec4(mixedColor, inColor.a);
}

float fog_spherical_distance(vec3 pos) {
    return length(pos);
}

float fog_cylindrical_distance(vec3 pos) {
    float distXZ = length(pos.xz);
    float distY = abs(pos.y);
    return max(distXZ, distY);
}