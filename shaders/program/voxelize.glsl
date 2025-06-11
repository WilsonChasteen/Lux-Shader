// shaders/program/voxelize.glsl
// Vertex Shader
#ifdef VSH
// Basic pass-through vertex shader for a full-screen quad
varying vec2 texCoord_v;
void main() {
    gl_Position = ftransform();
    texCoord_v = gl_MultiTexCoord0.xy; // Pass texture coordinates for full-screen quad
}
#endif

// Fragment Shader
#ifdef FSH
#include "/lib/global.glsl"
#include "/lib/util/spaceConversion.glsl"
// DecodeNormal might not be needed here unless checking surface normals for emission directionality

// Voxel Grid Properties (from settings.glsl)
// Example: These should be pulled from settings.glsl or passed as uniforms
#define VOXEL_GRID_RES_X VOXEL_GRID_RESOLUTION_X
#define VOXEL_GRID_RES_Y VOXEL_GRID_RESOLUTION_Y
#define VOXEL_GRID_RES_Z VOXEL_GRID_RESOLUTION_Z
const ivec3 gridResolution = ivec3(VOXEL_GRID_RES_X, VOXEL_GRID_RES_Y, VOXEL_GRID_RES_Z);
const float gridWorldSize = VOXEL_GRID_WORLD_SIZE;
uniform vec3 voxelGridCenter; // Typically camera position, updated each frame

// The 3D texture to write to
layout(rgba16f, binding = 0) uniform image3D voxelEmissionTexture; // Use rgba16f for HDR light, ensure binding is correct

uniform sampler2D depthtex0;
uniform sampler2D colortex0; // Albedo
uniform sampler2D colortex2; // Lightmap (blocklight in .x, skylight in .y)

varying vec2 texCoord_v; // From VSH, for sampling full-screen textures

void main() {
    vec2 texCoord = texCoord_v;
    float depth = texture2D(depthtex0, texCoord).r;

    if (depth >= 1.0) { // Sky or too far
        // No output needed, or could write dummy to avoid issues if required by pipeline
        return;
    }

    // Reconstruct world position
    vec4 viewPos = gbufferProjectionInverse * vec4(texCoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    viewPos /= viewPos.w;
    vec4 worldPos4 = gbufferModelViewInverse * viewPos;
    vec3 worldPos = worldPos4.xyz / worldPos4.w;

    // Get lightmap values
    vec2 lightmapInfo = texture2D(colortex2, texCoord).xy;
    float blockLight = lightmapInfo.x; // intensity of block light (0-1 range from packed lightmap)

    float emissiveStrength = 0.0;
    vec3 emissiveColor = vec3(0.0);

    // Primary source of emission: blocklight (torches, glowstone, lava etc.)
    if (blockLight > 0.05) { // Threshold to consider it an emitter
        // Convert normalized blocklight (0-1) to a more usable intensity range
        // This scaling factor (e.g., 15.0) makes blocklight values more impactful for GI
        // Needs tuning based on desired brightness of voxel GI sources.
        emissiveStrength = blockLight * 15.0;

        // Use global blocklightCol, potentially tinted by albedo if desired (e.g. colored lamps)
        // For now, assume blocklightCol is the pure color of the light emitted.
        // vec3 surfaceAlbedo = texture2D(colortex0, texCoord).rgb;
        // emissiveColor = blocklightCol * surfaceAlbedo; // Tinted by surface
        emissiveColor = blocklightCol; // Pure blocklight color
    }

    // Secondary: Check for explicit emissive materials if a material ID buffer were available
    // float materialID = texture2D(materialIdTex, texCoord).r;
    // if (isEmissiveMaterial(materialID)) {
    //     emissiveStrength = getMaterialEmissiveStrength(materialID);
    //     emissiveColor = getMaterialEmissiveColor(materialID) * texture2D(colortex0, texCoord).rgb;
    // }


    if (emissiveStrength > 0.01) {
        // Convert world position to voxel grid texel coordinates
        vec3 voxelGridMin = voxelGridCenter - gridWorldSize * 0.5;
        vec3 localPos = worldPos - voxelGridMin; // Position relative to grid minimum corner
        vec3 voxelCoord = (localPos / gridWorldSize) * vec3(gridResolution); // Normalized pos (0-1) scaled by resolution

        ivec3 voxelTexelCoord = ivec3(floor(voxelCoord));

        // Boundary check
        if (all(greaterThanEqual(voxelTexelCoord, ivec3(0))) && all(lessThan(voxelTexelCoord, gridResolution))) {
            // Write emissive properties to the voxel texture
            vec4 valueToWrite = vec4(emissiveColor * emissiveStrength, 1.0); // Store pre-multiplied light, Alpha 1.0 for now (could be occupancy)

            // Atomically add to allow multiple fragments to contribute to the same voxel
            // This requires the image format to support atomic operations (e.g., r32f, rgba16f sometimes)
            // And the correct GLSL version / extension for imageAtomicAdd.
            // imageAtomicAdd(voxelEmissionTexture, voxelTexelCoord, valueToWrite.r); // Example for just red channel if single float image
            // For vec4, you might need to pack/unpack or do it per component if atomics are limited.

            // Simpler: imageLoad, add, imageStore (non-atomic, potential race condition if many fragments hit same voxel)
            // For this simplified version, let's stick to the load/add/store approach as atomics add complexity.
            vec4 existingValue = imageLoad(voxelEmissionTexture, voxelTexelCoord);
            imageStore(voxelEmissionTexture, voxelTexelCoord, existingValue + valueToWrite);
        }
    }
    // This shader outputs no color to the main framebuffer. Its work is done via imageStore.
    // Depending on the shader runner, it might need a dummy gl_FragColor.
    // gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0); // Or discard;
}
#endif
