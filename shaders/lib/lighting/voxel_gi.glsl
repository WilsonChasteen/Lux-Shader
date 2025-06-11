/*
----------------------------------------------------------------
Lux Shader by https://github.com/TechDevOnGithub/
Based on BSL Shaders v7.1.05 by Capt Tatsu https://bitslablab.com
See AGREEMENT.txt for more information.
----------------------------------------------------------------
Voxel GI Implementation
*/

#ifndef VOXEL_GI_SETTINGS
#define VOXEL_GI_SETTINGS
// Defines like VOXEL_GI_ENABLED, VOXEL_GI_INTENSITY, VOXEL_GRID_RESOLUTION, VOXEL_GRID_WORLD_SIZE
// will come from settings.glsl
#ifndef VOXEL_GI_ENABLED
  #define VOXEL_GI_ENABLED 1
#endif
#ifndef VOXEL_GI_INTENSITY
  #define VOXEL_GI_INTENSITY 1.0
#endif
#ifndef VOXEL_TRACE_STEPS
  #define VOXEL_TRACE_STEPS 8
#endif
 #ifndef VOXEL_CONE_ANGLE // Approximate cone angle for sampling
  #define VOXEL_CONE_ANGLE 0.2 // Radians
 #endif
#endif // VOXEL_GI_SETTINGS

// The 3D texture to read from
// uniform sampler3D voxelEmissionTextureSampler; // Use a sampler for reading

// Voxel Grid Properties (should match those in voxelize.glsl)
// uniform vec3 voxelGridCenter;
// uniform float VOXEL_GRID_WORLD_SIZE;
// uniform ivec3 VOXEL_GRID_RESOLUTION;


// Function to sample voxel GI at a given world position and normal
vec3 CalculateVoxelGI(
    vec3 worldPos,
    vec3 worldNormal,
    sampler3D voxelTexture, // Pass the voxel texture sampler
    vec3 voxelGridOrigin, // worldPos of voxelGridMin (center - size/2)
    float voxelGridWorldSize, // Actual world size of the grid
    ivec3 voxelGridResolution // Resolution of the grid
) {
    #if VOXEL_GI_ENABLED == 0
        return vec3(0.0);
    #endif

    vec3 accumulatedGI = vec3(0.0);
    float totalWeight = 0.0;

    // Simple cone tracing towards the normal
    // More advanced: multiple cones, different distributions

    // Convert world position to normalized voxel grid UVW (0-1 range)
    vec3 voxelUVW = (worldPos - voxelGridOrigin) / voxelGridWorldSize;

    // Check if receiver is outside the voxel grid bounds for sampling (optional, depends on strategy)
    // if (any(lessThan(voxelUVW, vec3(0.0))) || any(greaterThan(voxelUVW, vec3(1.0)))) {
    //     return vec3(0.0); // Outside grid, no GI from this grid
    // }

    // Trace a cone in the direction of the normal
    // More advanced methods would use multiple cones/rays in a hemisphere
    vec3 traceDir = worldNormal;
    float voxelSize = voxelGridWorldSize / float(voxelGridResolution.x); // Approximate voxel size in world units
    float stepSize = voxelSize * 1.5; // Step a bit more than one voxel to avoid self-sampling

    for (int i = 1; i <= VOXEL_TRACE_STEPS; ++i) {
        float dist = float(i) * stepSize;
        vec3 samplePointWorld = worldPos + traceDir * dist;

        // Convert sample point to voxel UVW coordinates
        vec3 sampleUVW = (samplePointWorld - voxelGridOrigin) / voxelGridWorldSize;

        // Boundary check for sampling UVW
        if (sampleUVW.x < 0.0 || sampleUVW.x > 1.0 ||
            sampleUVW.y < 0.0 || sampleUVW.y > 1.0 ||
            sampleUVW.z < 0.0 || sampleUVW.z > 1.0) {
            break; // Ray exited the voxel grid
        }

        // Sample the voxel grid (trilinear filtering is handled by sampler3D)
        vec4 voxelValue = texture(voxelTexture, sampleUVW); // RGBA, A might be occupancy or confidence
        vec3 emissiveLight = voxelValue.rgb;
        float occlusion = 1.0 - voxelValue.a; // If A stores occupancy, (1-A) is how much light passes

         if (dot(emissiveLight, emissiveLight) > 0.001) {
             // Basic attenuation and cone spread approximation
             float falloff = 1.0 / (1.0 + dist * dist * 0.1); // Inverse square-ish falloff

             // Approximate cone solid angle contribution - very rough
             // As distance increases, the sample represents a larger cone solid angle
             float coneFactor = pow(dist * tan(VOXEL_CONE_ANGLE), 2.0);
             coneFactor = clamp(coneFactor, 0.1, 1.0);


             accumulatedGI += emissiveLight * falloff * coneFactor * occlusion; // Modulate by occlusion
             totalWeight += coneFactor * occlusion;

             // Simple occlusion model: if we hit bright light, assume it blocks further rays in this cone
             // More advanced: proper volumetric transport
             if(voxelValue.a > 0.95) break; // Highly occluded / very bright source stops trace
         }
    }

    if (totalWeight > 0.0) {
        accumulatedGI /= totalWeight;
    }

    return accumulatedGI * VOXEL_GI_INTENSITY;
}
