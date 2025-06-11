/*
----------------------------------------------------------------
Lux Shader by https://github.com/TechDevOnGithub/
Based on BSL Shaders v7.1.05 by Capt Tatsu https://bitslablab.com
See AGREEMENT.txt for more information.
----------------------------------------------------------------
SSGI Implementation
*/

#ifndef SSGI_SETTINGS
#define SSGI_SETTINGS
// Define SSGI_ENABLED, SSGI_INTENSITY, SSGI_SAMPLES, SSGI_RADIUS, etc. in settings.glsl or shaders.properties
// For now, let's add some defaults if not defined by main settings files
#ifndef SSGI_ENABLED
  #define SSGI_ENABLED 1 // 0 to disable, 1 to enable
#endif
#ifndef SSGI_INTENSITY
  #define SSGI_INTENSITY 1.0
#endif
#ifndef SSGI_SAMPLES
  #define SSGI_SAMPLES 8
#endif
#ifndef SSGI_RADIUS
  #define SSGI_RADIUS 0.5 // View-space radius
#endif
#ifndef SSGI_MAX_STEPS
 #define SSGI_MAX_STEPS 5
#endif

#endif // SSGI_SETTINGS

// Required G-Buffer samplers (will be passed as arguments or accessed globally)
// uniform sampler2D depthtex0; // Depth
// uniform sampler2D colortex0; // Albedo
// uniform sampler2D colortex6; // Normals (encoded)

// Uniforms
// uniform mat4 gbufferProjectionInverse;
// uniform mat4 gbufferProjection; // For projecting back to screen space if needed
// uniform vec2 viewSize; // viewWidth, viewHeight

// Helper to reconstruct view space position from depth and screen coordinates
vec3 ReconstructViewPos(vec2 texCoord, float depth, mat4 projectionInverse) {
    float z = depth * 2.0 - 1.0; // To NDC
    vec4 clipSpacePosition = vec4(texCoord * 2.0 - 1.0, z, 1.0);
    vec4 viewSpacePosition = projectionInverse * clipSpacePosition;
    return viewSpacePosition.xyz / viewSpacePosition.w;
}

// Placeholder for the main SSGI function
vec3 CalculateSSGI(
    vec2 texCoord,      // Current pixel screen coordinate
    sampler2D depthSampler,
    sampler2D albedoSampler,
    sampler2D normalSampler, // Encoded normals
    mat4 projectionInverse,
    mat4 projectionMatrix, // For re-projecting to screen space
    vec2 pixelSize         // 1.0/viewWidth, 1.0/viewHeight
) {
    #if SSGI_ENABLED == 0
        return vec3(0.0);
    #endif

    float centerDepth = texture2D(depthSampler, texCoord).r;
    if (centerDepth >= 1.0) { // Sky or far plane
        return vec3(0.0);
    }

    vec3 viewPos = ReconstructViewPos(texCoord, centerDepth, projectionInverse);
    vec2 encodedNormal = texture2D(normalSampler, texCoord).xy;
    vec3 normal = DecodeNormal(encodedNormal); // Assumes DecodeNormal is available

    if (dot(normal, normal) < 0.1) { // Invalid normal (e.g. from sky)
         return vec3(0.0);
    }

    vec3 accumulatedGI = vec3(0.0);
    float totalWeight = 0.0;

    // Simplified random offset, replace with better sampling (e.g. blue noise + hemisphere)
    vec2 randomOffsets[SSGI_SAMPLES];
    for(int i = 0; i < SSGI_SAMPLES; ++i) {
        // Very basic pseudo-random offset for now
        float angle = float(i) / float(SSGI_SAMPLES) * 2.0 * PI;
        randomOffsets[i] = vec2(cos(angle), sin(angle));
    }


    for (int i = 0; i < SSGI_SAMPLES; ++i) {
        vec2 rayDirScreen = randomOffsets[i] * 0.01; // Small initial screen space step, needs better logic

        for (int step = 0; step < SSGI_MAX_STEPS; ++step) {
            vec2 sampleCoord = texCoord + rayDirScreen * float(step + 1);

            // Boundary checks
            if (sampleCoord.x < 0.0 || sampleCoord.x > 1.0 || sampleCoord.y < 0.0 || sampleCoord.y > 1.0) {
                break;
            }

            float sampleDepthLinear = texture2D(depthSampler, sampleCoord).r;
            if (sampleDepthLinear >= 1.0) continue; // Hit sky

            vec3 sampleViewPos = ReconstructViewPos(sampleCoord, sampleDepthLinear, projectionInverse);

            // Check if sample point is in front of current pixel's view plane and within radius
            // This is a very simplified check; true SSGI needs more robust ray-scene intersection
            float viewSpaceDist = length(sampleViewPos - viewPos);

            if (viewSpaceDist > 0.01 && viewSpaceDist < SSGI_RADIUS) { // Arbitrary near cut-off to avoid self-intersection
                 // Check if the sample point is roughly "in front" of the original surface
                 // and if the original surface is roughly "visible" from the sample point (simplified visibility)
                 vec3 toSample = normalize(sampleViewPos - viewPos);
                 if (dot(normal, toSample) < 0.1) continue; // Sample is behind or too oblique to original surface normal

                 vec2 sampleNormalEncoded = texture2D(normalSampler, sampleCoord).xy;
                 vec3 sampleNormal = DecodeNormal(sampleNormalEncoded);
                 if (dot(sampleNormal, sampleNormal) < 0.1) continue; // Invalid sample normal

                 // Check if original point is visible from sample point (cosine weight)
                 // N_sample * -toSample
                 float visibilityFactor = clamp(dot(sampleNormal, -toSample), 0.0, 1.0);
                 if (visibilityFactor < 0.1) continue; // Original point not visible from sample point's normal orientation

                 vec3 sampleAlbedo = texture2D(albedoSampler, sampleCoord).rgb;

                 // Simplified diffuse bounce light calculation
                 float falloff = 1.0 - smoothstep(0.0, SSGI_RADIUS, viewSpaceDist); // Linear falloff
                 falloff *= falloff;

                 vec3 bouncedLight = sampleAlbedo * visibilityFactor * falloff;

                 accumulatedGI += bouncedLight;
                 totalWeight += 1.0;
                 break; // Found a sample along this ray, move to next ray
            }
        }
    }

    if (totalWeight > 0.0) {
        accumulatedGI /= totalWeight;
    }

    return accumulatedGI * SSGI_INTENSITY;
}
