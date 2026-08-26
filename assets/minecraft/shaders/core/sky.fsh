#version 150

#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:dynamictransforms.glsl>
#moj_import <minecraft:globals.glsl>
#moj_import <minecraft:projection.glsl>

in float sphericalVertexDistance;
in float cylindricalVertexDistance;

out vec4 fragColor;

float snoise( vec3 P ) {
    const float SKEWFACTOR = 1.0/3.0;
    const float UNSKEWFACTOR = 1.0/6.0;
    const float SIMPLEX_CORNER_POS = 0.5;
    const float SIMPLEX_TETRAHADRON_HEIGHT = 0.70710678118654752440084436210485;

    P *= SIMPLEX_TETRAHADRON_HEIGHT;
    vec3 Pi = floor( P + dot( P, vec3( SKEWFACTOR) ) );

    vec3 x0 = P - Pi + dot(Pi, vec3( UNSKEWFACTOR ) );
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 Pi_1 = min( g.xyz, l.zxy );
    vec3 Pi_2 = max( g.xyz, l.zxy );
    vec3 x1 = x0 - Pi_1 + UNSKEWFACTOR;
    vec3 x2 = x0 - Pi_2 + SKEWFACTOR;
    vec3 x3 = x0 - SIMPLEX_CORNER_POS;

    vec4 v1234_x = vec4( x0.x, x1.x, x2.x, x3.x );
    vec4 v1234_y = vec4( x0.y, x1.y, x2.y, x3.y );
    vec4 v1234_z = vec4( x0.z, x1.z, x2.z, x3.z );

    Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
    vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

    vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
    Pt *= Pt;
    vec4 V1xy_V2xy = mix( Pt.xyxy, Pt.zwzw, vec4( Pi_1.xy, Pi_2.xy ) );
    Pt = vec4( Pt.x, V1xy_V2xy.xz, Pt.z ) * vec4( Pt.y, V1xy_V2xy.yw, Pt.w );
    const vec3 SOMELARGEFLOATS = vec3( 635.298681, 682.357502, 668.926525 );
    const vec3 ZINC = vec3( 48.500388, 65.294118, 63.934599 );
    vec3 lowz_mods = vec3( 1.0 / ( SOMELARGEFLOATS.xyz + Pi.zzz * ZINC.xyz ) );
    vec3 highz_mods = vec3( 1.0 / ( SOMELARGEFLOATS.xyz + Pi_inc1.zzz * ZINC.xyz ) );
    Pi_1 = ( Pi_1.z < 0.5 ) ? lowz_mods : highz_mods;
    Pi_2 = ( Pi_2.z < 0.5 ) ? lowz_mods : highz_mods;
    vec4 hash_0 = fract( Pt * vec4( lowz_mods.x, Pi_1.x, Pi_2.x, highz_mods.x ) ) - 0.49999;
    vec4 hash_1 = fract( Pt * vec4( lowz_mods.y, Pi_1.y, Pi_2.y, highz_mods.y ) ) - 0.49999;
    vec4 hash_2 = fract( Pt * vec4( lowz_mods.z, Pi_1.z, Pi_2.z, highz_mods.z ) ) - 0.49999;

    vec4 grad_results = inversesqrt( hash_0 * hash_0 + hash_1 * hash_1 + hash_2 * hash_2 ) * ( hash_0 * v1234_x + hash_1 * v1234_y + hash_2 * v1234_z );

    const float FINAL_NORMALIZATION = 37.837227241611314102871574478976;

    vec4 kernel_weights = v1234_x * v1234_x + v1234_y * v1234_y + v1234_z * v1234_z;
    kernel_weights = max(0.5 - kernel_weights, 0.0);
    kernel_weights = kernel_weights*kernel_weights*kernel_weights;

    return dot( kernel_weights, grad_results ) * FINAL_NORMALIZATION;
}

float fbm(vec3 x) {
    const int octaves = 4;
    float lacunarity = 2.5;
    float gain = 0.5;

    float amplitude = 0.5;
    float frequency = 1.0;
    float y = 0.0;

    for (int i = 0; i < octaves; i++) {
        y += amplitude * snoise(frequency*x);
        frequency *= lacunarity;
        amplitude *= gain;
    }
    return y;
}

vec3 sampleStarfield(vec3 v) {
    float stars = max(0.0, snoise(v * 100.0 + GameTime*100.0)-0.7) * 5.0;
    float starfield = max(0.05, snoise(v * vec3(1.0, 1.0, 0.5) + GameTime*100.0));
    stars *= starfield;

    // Soft cyan-tinted atmospheric gradient
    float height = clamp(v.y * 0.5 + 0.5, 0.0, 1.0);
    vec3 nightHorizon = vec3(0.05, 0.18, 0.52);
    vec3 nightZenith  = vec3(0.02, 0.07, 0.33);
    vec3 sky = mix(nightHorizon, nightZenith, height);

    // Cyan cloud/nebula overlay highlights
    float res = fbm(v * 2.0 + vec3(GameTime*10.0, 0.0, 0.0));
    sky += max(0.0, res+0.1) * vec3(12.0, 55.0, 155.0)/255.0;

    sky += stars;
    sky += starfield * 0.05;

    float grid_position = fract(dot(gl_FragCoord.xy - vec2(0.5,0.5), vec2(1.0/16.0,10.0/36.0)+0.25));
    sky += grid_position / 256.0;

    return sky;
}

void main() {
    bool isCloud = (ColorModulator.r > 0.9 && ColorModulator.g > 0.9 && ColorModulator.b > 0.9);
    float nightFactor = clamp(1.0 - (ColorModulator.r + ColorModulator.g + ColorModulator.b) / 1.5, 0.0, 1.0);

    vec2 pos = gl_FragCoord.xy / ScreenSize;
    pos -= vec2(0.5, 0.5);
    pos *= 2.0;

    vec4 cast_pos = vec4(pos, 1.0, 1.0);
    cast_pos = inverse(ProjMat) * cast_pos;
    cast_pos = normalize(cast_pos);

    vec3 v = normalize(cast_pos.xyz * mat3(ModelViewMat));

    // Deep zenith sky tone
    vec3 deepSkyBlue = ColorModulator.rgb * vec3(0.48, 0.72, 1.15);
    
    // Brighter light sky blue tone for horizon
    vec3 lightHorizonBlue = ColorModulator.rgb * vec3(0.72, 0.94, 1.25);

    // Smoothstep stretched to (0.02, 0.50) to carry the gradient higher into the sky
    float horizonFactor = v.y;
    vec3 daySky = mix(lightHorizonBlue, deepSkyBlue, smoothstep(0.02, 0.50, horizonFactor));

    vec3 nightSky = sampleStarfield(v);

    if (isCloud) {
        fragColor = ColorModulator;
    } else {
        fragColor = vec4(mix(daySky, nightSky, nightFactor), 1.0);
    }
}