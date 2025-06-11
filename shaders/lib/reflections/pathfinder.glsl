/*
----------------------------------------------------------------
Lux Shader by https://github.com/TechDevOnGithub/
Based on BSL Shaders v7.1.05 by Capt Tatsu https://bitslablab.com
See AGREEMENT.txt for more information.
----------------------------------------------------------------
*/

// Global Include
#include "/lib/global.glsl"

// Uniforms expected to be available from deferred.glsl where this file will be included:
// uniform sampler2D depthtex0; // Main depth buffer for opaque objects
// uniform sampler2D colortex0; // Main color buffer for opaque objects
/*
// Other samplers that might be useful later:
uniform sampler2D depthtex1; // Depth buffer for transparent objects/water
uniform sampler2D colortex3; // Contains material information (smoothness, metalness, etc.)
uniform sampler2D gaux2;     // Auxiliary buffer, often used for previous frame's data in BSL/Lux
*/

// Helper function for screen border fading, adapted from simpleReflections.glsl
// It calculates a factor that is 1.0 in the center and fades towards 0.0 at the edges of the screen.
float cdist(vec2 coord) {
    // coord is expected to be in the 0.0 to 1.0 range.
    // Calculate distance from center (0.5, 0.5) in normalized screen coords.
    // max(abs(coord.x - 0.5), abs(coord.y - 0.5)) gives a square distance from center.
    // Multiplying by 1.85 scales this distance.
	return max(abs(coord.x - 0.5), abs(coord.y - 0.5)) * 1.85;
}

// Main function for Pathfinder Reflections.
// Its purpose is to provide a hybrid reflection solution. It switches between:
// 1. A simple, single-ray path for very smooth surfaces (akin to mirror reflections).
// 2. A more complex, multi-ray path for rougher surfaces to simulate blurry/distorted reflections.
vec4 CalculatePathfinderReflection(
    vec3 viewPos,
    vec3 normal,
    float dither,
    float smoothness,
    float metalness, // Parameter kept for future use in complex path or material interaction
    vec3 albedo,    // Parameter kept for future use
    float f0,       // Parameter kept for future use (Fresnel calculations)
    vec3 cameraPosition, // Parameter kept for future use
    vec3 previousCameraPosition, // Parameter kept for future use (e.g., reprojection)
    float far       // Parameter kept for future use (e.g., ray length limits)
    )
{
    // COMPLEXITY_THRESHOLD determines at what smoothness value the shader switches
    // from the simple, single-ray path to the more complex multi-ray path.
    const float COMPLEXITY_THRESHOLD = 0.8;

    // The Raytrace() function is defined in /lib/reflections/raytrace.glsl
    // It's expected to be available here because deferred.glsl (where pathfinder.glsl will be included)
    // already includes raytrace.glsl.
    // vec4 Raytrace(sampler2D depthtex, vec3 viewPos, vec3 normal, float dither, float maxf, float stp, float ref, float inc)

    if (smoothness >= COMPLEXITY_THRESHOLD) {
        // --- Simple Detail Path ---
        // For very smooth surfaces (e.g., polished metals, calm water),
        // a single, sharp reflection ray is traced. This is computationally cheaper.
        // We primarily reflect opaque geometry, so use depthtex0 (opaque depth) and colortex0 (opaque color).

        // Parameters for Raytrace:
        // depthtex: depthtex0 (opaque depth buffer)
        // viewPos: current fragment's position in view space
        // normal: surface normal of the fragment, used to calculate reflection direction
        // dither: a small random offset to break up banding artifacts, especially in reflections
        // maxf: defines the number of coarse steps along the ray before refinement (4 chosen as per SimpleReflection)
        // stp: initial step size multiplier for the ray marching
        // ref: refinement step multiplier, used after a potential hit is found during coarse steps
        // inc: step increment factor, how much the step size increases with each coarse step
        vec4 hitData = Raytrace(depthtex0, viewPos, normal, dither, 4, 1.0, 0.1, 2.0);
        // According to raytrace.glsl, hitData returns:
        // hitData.xyz: screen position (UV coordinates + depth) of the hit point. UVs are in [0,1] range.
        // hitData.w: distance to the hit point in view space.

        vec3 reflectionColor = vec3(0.0); // Default to no reflection (black)
        float reflectionAlpha = 0.0;      // Default to no hit (fully transparent)

        // Check if the ray hit something. Depth values range from 0 (near plane) to 1 (far plane/sky).
        // A hit on geometry will have a depth value less than 1.0.
        // Using a small epsilon (0.0001) avoids precision issues where sky depth might not be exactly 1.0.
        if (hitData.z < 1.0 - 0.0001) {
            // Sample the color from the main opaque color buffer (colortex0) at the screen coordinates of the hit.
            // Using texture2DLod with LOD 0 ensures we sample the highest resolution.
            reflectionColor = texture2DLod(colortex0, hitData.xy, 0.0).rgb;
            reflectionAlpha = 1.0; // Mark as a successful hit on geometry

            // Apply screen border fade to prevent abrupt reflection cutoff at screen edges.
            // This makes reflections appear to fade out smoothly near screen borders.
            // The formula is adapted from simpleReflections.glsl.
            float borderFactor = Saturate(1.0 - Pow8(Max0(10.0 * cdist(hitData.xy) - 9.0)));
            reflectionAlpha *= borderFactor; // Modulate hit alpha by the border fade factor
        }

        return vec4(reflectionColor, reflectionAlpha);

    } else {
        // --- Complex Detail Path (Basic Multi-Ray) ---
        // For less smooth (rougher) surfaces, this path simulates blurry or distorted reflections
        // by casting multiple rays with slightly perturbed normals and averaging the results.
        // This is more computationally intensive than the simple path.

        vec3 accumulatedColor = vec3(0.0); // Stores the sum of colors from all rays
        float hits = 0.0; // Counts how many rays hit actual scene geometry (not sky)
        float totalAlphaFromHits = 0.0; // Accumulates the alpha values from rays that hit geometry, used for averaging later.

        // NUM_COMPLEX_RAYS defines how many rays are cast for this path.
        // More rays can lead to higher quality (smoother) rough reflections but impact performance.
        const int NUM_COMPLEX_RAYS = 4;

        // Basic hash function (float output) for generating pseudo-random numbers.
        // Source: Simplified from common GLSL hash functions (e.g., ones by Dave Hoskins).
        // It takes a 2D vector and returns a float in the [0,1] range.
        // Used to create varied offsets for perturbing reflection rays.
        float hash1(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
        // Returns a 2D hash vector, with components in [0,1] range.
        vec2 hash2(vec2 p) { return vec2(hash1(p), hash1(p + vec2(7.3,3.7))); }

        for (int i = 0; i < NUM_COMPLEX_RAYS; ++i) {
            // Generate a pseudo-random 2D offset vector for perturbing the reflection.
            // gl_FragCoord.xy provides a screen-position-dependent seed, ensuring different pixels get different patterns.
            // Adding 'float(i)' varies the seed for each ray in the loop.
            vec2 randInput = gl_FragCoord.xy + float(i);
            // hash2 returns values in [0,1] range; map them to [-1,1] to get directional offsets.
            // Modulate offset strength by (1.0 - smoothness): less smooth surfaces get larger offsets,
            // leading to more blur. 0.5 is an arbitrary scaling factor for the overall magnitude of perturbation.
            vec2 randDirectionalOffset = (hash2(randInput) * 2.0 - 1.0) * (1.0 - smoothness) * 0.5;

            // Perturb the surface normal. This is a common and relatively simple technique to simulate
            // rough reflections. A more physically correct method might perturb the reflection vector itself
            // around the perfect specular reflection direction (e.g., using importance sampling of a BRDF lobe),
            // but perturbing the normal is often simpler to integrate with existing ray tracing functions.
            // The Z component of the offset is currently 0.0, meaning perturbation is only in X and Y
            // relative to the normal's orientation. A 3D offset might yield more complex effects but is harder to control.
            vec3 perturbedNormal = normalize(normal + vec3(randDirectionalOffset.x, randDirectionalOffset.y, 0.0));

            // Call Raytrace for the perturbed ray.
            // 'maxf' is reduced to 2 (from 4 in simple path) for performance, as we're casting multiple rays.
            // Dither is slightly varied per ray (dither + float(i)*0.025) to help break up potential patterns
            // if the base dither value has a low frequency or is uniform across a surface.
            vec4 hitData = Raytrace(depthtex0, viewPos, perturbedNormal, dither + float(i)*0.025, 2, 1.0, 0.1, 2.0);

            if (hitData.z < 1.0 - 0.0001) { // Ray hit scene geometry
                // Sample color from the opaque buffer at the hit point.
                accumulatedColor += texture2DLod(colortex0, hitData.xy, 0.0).rgb;
                hits += 1.0; // Increment count of rays that hit geometry.
                // Accumulate alpha from this hit, including the screen border fade.
                // This alpha represents the contribution of this specific geometry hit.
                totalAlphaFromHits += Saturate(1.0 - Pow8(Max0(10.0 * cdist(hitData.xy) - 9.0)));
            } else { // Ray hit sky (missed scene geometry)
                // Calculate reflection vector for sky sampling using the perturbed normal.
                vec3 skyRefPos = reflect(normalize(viewPos), perturbedNormal);

                vec3 currentSkyReflectionColor = vec3(0.0);
                // --- Simplified Placeholder for Sky Color Retrieval ---
                // This section assumes that sky color functions (GetSkyColor, GetEndSkyColor) and
                // associated uniforms (lightCol, netherCol, endCol) are in scope because this
                // pathfinder.glsl file is included within deferred.glsl where they are defined.
                // A more robust/decoupled implementation might require passing sky color/properties
                // or a dedicated sky sampling function to CalculatePathfinderReflection.
                // For now, it uses basic sky colors. Full sky rendering (clouds, aurora) as done in
                // deferred.glsl's original reflection path is not replicated here for simplicity.
                #ifdef OVERWORLD
                    currentSkyReflectionColor = GetSkyColor(skyRefPos, lightCol); // Basic sky color from BSL/Lux
                #elif defined NETHER
                    currentSkyReflectionColor = netherCol.rgb * 0.04; // Standard Nether sky color tint
                #elif defined END
                    currentSkyReflectionColor = GetEndSkyColor(skyRefPos); // Standard End dimension sky color
                #else
                    currentSkyReflectionColor = vec3(0.05, 0.05, 0.1); // A generic dark blue fallback if no dimension matches
                #endif
                accumulatedColor += currentSkyReflectionColor; // Add sky color to the accumulation
                // Note: Sky hits do not increment 'hits' or 'totalAlphaFromHits' because these are specific to geometry.
            }
        }

        if (NUM_COMPLEX_RAYS > 0) {
            // Average the accumulated color from all rays (both geometry and sky hits).
            accumulatedColor /= float(NUM_COMPLEX_RAYS);
        }

        float finalAlpha = 0.0;
        if (hits > 0.0) {
            // If some rays hit geometry, calculate the average alpha contribution from those geometry hits.
            // This alpha determines how much the geometry reflection (already mixed with some sky from missed rays above)
            // will contribute versus the more detailed skybox reflection done in deferred.glsl.
            finalAlpha = totalAlphaFromHits / hits;
        }
        // If 'hits' is 0.0, it means all rays missed geometry and hit the sky.
        // In this scenario, 'finalAlpha' remains 0.0. This correctly signals to the calling shader (deferred.glsl)
        // that the reflection is entirely sky-based, allowing deferred.glsl to use its full, detailed sky
        // calculation for the reflection. If some rays hit geometry and some hit the sky, the 'accumulatedColor'
        // contains a mix, and 'finalAlpha' represents the "strength" or "clarity" of the geometry part of that mix.

        return vec4(accumulatedColor, finalAlpha);
    }
}
