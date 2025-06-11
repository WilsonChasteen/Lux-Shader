/*
----------------------------------------------------------------
Lux Shader by https://github.com/TechDevOnGithub/
Based on BSL Shaders v7.1.05 by Capt Tatsu https://bitslablab.com
See AGREEMENT.txt for more information.
----------------------------------------------------------------
*/

#include "/lib/settings.glsl" // Include shader settings

// Default settings for Path Tracing if not defined in settings.glsl
#ifndef PATH_TRACE_MAX_BOUNCES
    #define PATH_TRACE_MAX_BOUNCES 1 // Default to 1 bounce if not set
#endif

// Constants (PI is still useful, SKY_COLOR can be overridden by a setting later if needed)
const float PI = 3.14159265359;
const vec3 SKY_COLOR = vec3(0.7, 0.8, 1.0); // Default sky color if ray escapes
const float SURFACE_HIT_OFFSET = 0.001;    // Small offset to avoid self-intersection
const float MAX_RAY_MARCH_DISTANCE = 200.0; // Max travel distance for a ray segment
const int MAX_MARCH_STEPS = 96;             // Max march steps per ray segment

// Helper to convert homogeneous coordinates to vec3
vec3 nvec3(vec4 pos) {
    return pos.xyz / pos.w;
}

// Helper to convert vec3 to homogeneous coordinates
vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

// Simple pseudo-random number generator
// Input 'co' should be varied to produce different results
float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

// Generates a cosine-weighted random direction in a hemisphere oriented by 'normalDir'
vec3 diffuseReflection(vec3 normalDir, float ditherSeed) {
    // Use ditherSeed and normalDir components to vary the random sequence per pixel/bounce
    float r1 = rand(vec2(ditherSeed * 0.123, dot(normalDir.xy, vec2(ditherSeed*0.456, ditherSeed*0.789)) ));
    float r2 = rand(vec2(ditherSeed * 0.321, dot(normalDir.yz, vec2(ditherSeed*0.654, ditherSeed*0.987)) ));

    float phi = 2.0 * PI * r1;
    float cosTheta = sqrt(1.0 - r2);
    float sinTheta = sqrt(r2);

    vec3 sampleDirCanonical = vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);

    vec3 upApprox = abs(normalDir.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 tangent = normalize(cross(upApprox, normalDir));
    vec3 bitangent = cross(normalDir, tangent);
    mat3 tbn = mat3(tangent, bitangent, normalDir);

    return normalize(tbn * sampleDirCanonical);
}

// Main Path Tracing Reflection Function
vec3 PathTraceReflection(
    sampler2D depthtex,         // Depth buffer
    sampler2D colortex0,        // Scene color (albedo)
    sampler2D gbufferNormal,    // Scene normals
    vec3 viewPos,               // World-space position on the primary surface
    vec3 viewNormal,            // World-space normal of the primary surface
    float dither,               // Dither value for seeding random numbers
    // Matrix and camera uniforms
    mat4 gbufferProjection,
    mat4 gbufferProjectionInverse,
    vec3 cameraPosition,        // World-space camera position
    // Screen-space ray marching parameters
    float stp,                  // Initial step size
    float inc                   // Step increment factor
) {
    vec3 accumulatedColor = vec3(0.0);
    vec3 rayColorMultiplier = vec3(1.0);

    vec3 incidentViewVec = normalize(viewPos - cameraPosition);
    vec3 currentRayDir = normalize(reflect(incidentViewVec, normalize(viewNormal)));
    vec3 currentRayOrigin = viewPos;

    float randomSeed = dither;

    // Main bounce loop - uses PATH_TRACE_MAX_BOUNCES from settings.glsl
    for (int bounce = 0; bounce < PATH_TRACE_MAX_BOUNCES; ++bounce) {
        vec3 marchOrigin = currentRayOrigin + currentRayDir * SURFACE_HIT_OFFSET * stp;
        vec3 marchDirNormalized = currentRayDir;

        vec3 hitPosScreen = vec3(0.0);
        vec3 hitPosWorld = vec3(0.0);
        bool hitFoundThisBounce = false;

        float travelDistanceThisSegment = 0.0;
        float currentStepSize = stp;

        for (int marchStep = 0; marchStep < MAX_MARCH_STEPS; ++marchStep) {
            vec3 pointOnRay = marchOrigin + marchDirNormalized * travelDistanceThisSegment;
            hitPosScreen = nvec3(gbufferProjection * nvec4(pointOnRay)) * 0.5 + 0.5;

            if (hitPosScreen.x < 0.0 || hitPosScreen.x > 1.0 ||
                hitPosScreen.y < 0.0 || hitPosScreen.y > 1.0 ||
                hitPosScreen.z < 0.0 || hitPosScreen.z > 1.0) {
                break;
            }

            float depthFromTex = texture2D(depthtex, hitPosScreen.xy).r;
            if (depthFromTex >= 0.9999) {
                 travelDistanceThisSegment += currentStepSize;
                 currentStepSize *= inc;
                 if (travelDistanceThisSegment > MAX_RAY_MARCH_DISTANCE) break;
                 continue;
            }

            vec3 surfacePosDevice = vec3(hitPosScreen.xy, depthFromTex);
            vec3 surfacePosWorld = nvec3(gbufferProjectionInverse * nvec4(surfacePosDevice * 2.0 - 1.0));

            float travelToSurface = dot(surfacePosWorld - marchOrigin, marchDirNormalized);

            if (travelToSurface > 0.0 && travelToSurface < travelDistanceThisSegment + currentStepSize * 1.5) {
                if (length(pointOnRay - surfacePosWorld) < currentStepSize * 2.0 + (travelDistanceThisSegment * 0.05) ) {
                    hitPosWorld = surfacePosWorld;
                    hitFoundThisBounce = true;
                    break;
                }
            }

            travelDistanceThisSegment += currentStepSize;
            currentStepSize *= inc;
            if (travelDistanceThisSegment > MAX_RAY_MARCH_DISTANCE) break;
        }

        if (hitFoundThisBounce) {
            vec3 surfaceAlbedo = texture2D(colortex0, hitPosScreen.xy).rgb;
            accumulatedColor += surfaceAlbedo * rayColorMultiplier;
            rayColorMultiplier *= 0.5; // Basic diffuse attenuation

            vec3 hitSurfaceNormal = normalize(texture2D(gbufferNormal, hitPosScreen.xy).xyz * 2.0 - 1.0);

            randomSeed += float(bounce) * 0.1 + length(hitPosScreen.xy) * 0.01;
            currentRayDir = diffuseReflection(hitSurfaceNormal, randomSeed);
            currentRayOrigin = hitPosWorld;

            if (dot(rayColorMultiplier, rayColorMultiplier) < 0.001) {
                break;
            }
        } else {
            accumulatedColor += SKY_COLOR * rayColorMultiplier;
            break;
        }
    }
    return accumulatedColor;
}
