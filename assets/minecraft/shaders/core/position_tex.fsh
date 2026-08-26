#version 330

#moj_import <minecraft:dynamictransforms.glsl>

uniform sampler2D Sampler0;

in vec2 texCoord0;

out vec4 fragColor;

void main() {
    vec4 color = texture(Sampler0, texCoord0);
    
    if (color.a == 0.0) {
        discard;
    }

    // 1. CATCH THE SUNSET BAND: Discard the warm horizon overlay quad
    if (ColorModulator.r > ColorModulator.b + 0.2 && ColorModulator.b < 0.6) {
        discard; 
    }

    // 2. FORCE RAW TEXTURE FOR CELESTIAL ELEMENTS (SUN & MOON)
    // Overrides engine white-washing by applying texture colors directly
    if (ColorModulator.r > 0.99 && ColorModulator.g > 0.99 && ColorModulator.b > 0.99) {
        
        // Calculate raw texture brightness
        float texLuminance = max(color.r, max(color.g, color.b));

        // If it's a dark/textured moon, apply glow. Otherwise, draw raw texture 1:1.
        if (texLuminance < 0.8) {
            vec4 finalColor = color * ColorModulator;
            finalColor.rgb *= 1.85;
            vec3 coolGlow = vec3(0.12, 0.22, 0.45);
            finalColor.rgb += coolGlow * pow(texLuminance, 1.2);
            fragColor = finalColor;
            return;
        } else {
            // HIGH-PROMINENCE SUN OUTPUT:
            // Gamma crush strips white glare, 1.45x multiplier pops the inner details
            fragColor = vec4(pow(color.rgb, vec3(2.2)) * 1.45, color.a);
            return;
        }
    }

    fragColor = color * ColorModulator;
}