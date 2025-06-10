/*
----------------------------------------------------------------
Lux Shader by https://github.com/TechDevOnGithub/
Based on BSL Shaders v7.1.05 by Capt Tatsu https://bitslablab.com
See AGREEMENT.txt for more information.
----------------------------------------------------------------

Path Tracing Implementation
*/

#ifdef GL_ES
#extension GL_OES_standard_derivatives : enable
#endif

// Helper function for depth linearization
// Converts a raw depth texture value to a linear depth value in view space units.
float getLinearDepth(float depthVal) {
    return (2.0 * near) / (far + near - depthVal * (far - near));
}

// Helper function to reconstruct view-space position from depth
vec3 viewPosFromDepth(vec2 texCoord, float depthVal) {
    vec2 ndcXY = texCoord * 2.0 - 1.0;
    float ndcZ = depthVal * 2.0 - 1.0;
    vec4 clipSpacePos = vec4(ndcXY, ndcZ, 1.0);
    vec4 viewPos = gbufferProjectionInverse * clipSpacePos;
    return viewPos.xyz / viewPos.w;
}

vec3 tracePath(vec2 screenCoord, float dither) {
    return vec3(1.0, 0.0, 0.0); // DEBUG: Force output to bright red

    // First Intersection (using depth buffer directly for the primary ray)
    float hitDepthSample0 = texture2D(depthtex0, screenCoord).r;

    if (hitDepthSample0 >= 0.999) { // Hit sky with primary ray
        return sunVec.y > 0.0 ? vec3(0.5, 0.7, 1.0) * 0.5 : vec3(0.05, 0.05, 0.1);
    }

    vec3 hitViewPos0 = viewPosFromDepth(screenCoord, hitDepthSample0);

    // Normal for first hit (using derivatives)
    vec3 ddx0 = dFdx(hitViewPos0);
    vec3 ddy0 = dFdy(hitViewPos0);
    vec3 normal0 = normalize(cross(ddx0, ddy0)); // Note: Cross product order might need adjustment depending on coord system
    if (dot(normal0, -normalize(hitViewPos0)) < 0.0) {
        normal0 = -normal0;
    }

    // Material for first hit (basic albedo from colortex0)
    // vec3 albedo0 = texture2D(colortex0, screenCoord).rgb;
    // albedo0 = pow(albedo0, vec3(2.2)) * 0.5; // Hack: attempt to linearize and reduce pre-lit effect
    vec3 albedo0 = vec3(0.5, 0.5, 0.5); // DEBUG: Use constant grey albedo
    return albedo0; // DEBUG: Output albedo0 directly

    // Direct Lighting at first hit
    float NdotL0 = max(0.0, dot(normal0, sunVec)); // sunVec is view space
    vec3 directLightAtHit0 = albedo0 * NdotL0;

    // Initialize for path tracing loop
    vec3 accumulatedColor = directLightAtHit0;
    vec3 throughput = albedo0;

    vec3 currentRayOriginView = hitViewPos0;
    vec3 currentNormalView = normal0;

    const int MAX_BOUNCES = 1; // Number of indirect bounces

    for (int bounce = 0; bounce < MAX_BOUNCES; ++bounce) {
        // Generate new diffuse ray direction
        vec3 randomOffset = vec3(
            (fract(sin(dither + float(bounce) * 0.135 + screenCoord.x * 0.37) * 12345.0) - 0.5) * 2.0,
            (fract(sin(dither + float(bounce) * 0.246 + screenCoord.y * 0.48) * 23456.0) - 0.5) * 2.0,
            (fract(sin(dither + float(bounce) * 0.357 + screenCoord.x * screenCoord.y * 0.59) * 34567.0) - 0.5) * 2.0
        );
        // Ensure randomOffset is normalized before adding to avoid overly strong directionality from the random component
        vec3 secondaryRayDirView = normalize(currentNormalView + normalize(randomOffset));
        if (dot(secondaryRayDirView, currentNormalView) < 0.001) { // If ray is parallel or into surface
             secondaryRayDirView = currentNormalView; // Default to normal if issue
        }
        secondaryRayDirView = normalize(secondaryRayDirView); // Re-normalize just in case


        // Screen-space Ray Marching for the secondary ray
        vec3 P1_secondary_view = currentRayOriginView; // Starting point of the ray in view space

        // Project starting point to screen space
        vec4 P1_secondary_clip = gbufferProjection * vec4(P1_secondary_view, 1.0);
        vec2 P1_secondary_screen = vec2(0.5); // Default to center if w is zero
        if (abs(P1_secondary_clip.w) > 0.0001) { // Avoid division by zero or very small w
             P1_secondary_screen = (P1_secondary_clip.xy / P1_secondary_clip.w) * 0.5 + 0.5;
        }

        // Project a point along the ray direction to find screen space direction
        // The length 1.0 is arbitrary, just to get a second point for direction
        vec3 P2_secondary_view = P1_secondary_view + secondaryRayDirView * 1.0;
        vec4 P2_secondary_clip = gbufferProjection * vec4(P2_secondary_view, 1.0);
        vec2 P2_secondary_screen = P1_secondary_screen + vec2(0.01,0.01); // Default offset if w is zero
        if (abs(P2_secondary_clip.w) > 0.0001) { // Avoid division by zero
            P2_secondary_screen = (P2_secondary_clip.xy / P2_secondary_clip.w) * 0.5 + 0.5;
        }

        vec2 screenRayDirSecondary = P2_secondary_screen - P1_secondary_screen;
        if (length(screenRayDirSecondary) < 0.001) { // If screen direction is too small or zero
            // Fallback: generate a random screen direction
            screenRayDirSecondary = normalize(vec2(fract(sin(dither*1234.5)*123.0)-0.5, fract(cos(dither*5678.9)*456.0)-0.5));
            if (length(screenRayDirSecondary) < 0.001) screenRayDirSecondary = vec2(0.01,0.0); // Final fallback to a default direction
        }
        screenRayDirSecondary = normalize(screenRayDirSecondary);

        vec2 currentScreenCoordSecondary = P1_secondary_screen;

        float stepScreen = 0.02; // Step size in screen space [0,1] range
        float maxMarchDistScreenSecondary = 0.3; // Max march distance in screen space
        float marchedDistScreen = 0.0;

        bool hitFoundNext = false;
        vec3 hitViewPosNext = vec3(0.0);
        vec2 hitScreenCoordNext = vec2(0.0);

        for (int k=0; k < 15; ++k) { // Max march steps
            currentScreenCoordSecondary += screenRayDirSecondary * stepScreen;
            marchedDistScreen += stepScreen;

            if (marchedDistScreen > maxMarchDistScreenSecondary ||
                currentScreenCoordSecondary.x <= 0.001 || currentScreenCoordSecondary.x >= 0.999 ||
                currentScreenCoordSecondary.y <= 0.001 || currentScreenCoordSecondary.y >= 0.999) {
                break; // Stop if out of bounds or max distance exceeded
            }

            float depthSampleNext = texture2D(depthtex0, currentScreenCoordSecondary).r;
            if (depthSampleNext < 0.999) { // If hit something (not sky)
                vec3 tempHitViewPosNext = viewPosFromDepth(currentScreenCoordSecondary, depthSampleNext);
                // Crude check to ensure we're moving forward and not hitting the immediate origin surface again
                if (length(tempHitViewPosNext - P1_secondary_view) > 0.1) {
                    hitViewPosNext = tempHitViewPosNext;
                    hitScreenCoordNext = currentScreenCoordSecondary;
                    hitFoundNext = true;
                    break;
                }
            }
        }

        if (hitFoundNext) {
            vec3 ddx_next = dFdx(hitViewPosNext);
            vec3 ddy_next = dFdy(hitViewPosNext);
            vec3 normalNext = normalize(cross(ddx_next, ddy_next));
            if (dot(normalNext, -normalize(hitViewPosNext)) < 0.0) { // Ensure normal points towards camera
                normalNext = -normalNext;
            }

            vec3 albedoNext = texture2D(colortex0, hitScreenCoordNext).rgb;
            albedoNext = pow(albedoNext, vec3(2.2)) * 0.5; // Hack for albedo

            float NdotL_next = max(0.0, dot(normalNext, sunVec));
            vec3 directLightAtHitNext = albedoNext * NdotL_next;

            accumulatedColor += throughput * directLightAtHitNext;
            throughput *= albedoNext; // Attenuate throughput by albedo for next bounce

            // Prepare for next bounce (if any)
            currentRayOriginView = hitViewPosNext;
            currentNormalView = normalNext;
        } else { // Secondary ray hit sky or went out of bounds
            vec3 skyColor = vec3(0.01, 0.01, 0.015); // Very dark, slightly bluish grey for misses
            accumulatedColor += throughput * skyColor;
            break; // End path tracing for this pixel if secondary ray misses
        }
    }

    return accumulatedColor;
}

// Denoising logic will be implemented here
vec3 denoisePass(vec3 color, vec2 texCoord, float dither) {
    return color; // Placeholder
}
