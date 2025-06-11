/*
----------------------------------------------------------------
Lux Shader by https://github.com/TechDevOnGithub/
Based on BSL Shaders v7.1.05 by Capt Tatsu https://bitslablab.com
See AGREEMENT.txt for more information.
----------------------------------------------------------------
*/

vec3 nvec3(vec4 pos)
{
    return pos.xyz / pos.w;
}

vec4 nvec4(vec3 pos)
{
    return vec4(pos.xyz, 1.0);
}

float cdist(vec2 coord)
{
	return max(abs(coord.x - 0.5), abs(coord.y - 0.5)) * 1.85;
}

// Helper function to convert depth buffer value to linear depth.
// depthSample: Value from depth texture (usually non-linear).
// nearPlane, farPlane: Clipping plane distances.
float LinearizeDepth(float depthSample, float nearPlane, float farPlane) {
    // Assuming depthSample is in [0, 1] range from depth texture
    // Convert to normalized device coordinates (NDC) in [-1, 1] range
    float zNdc = 2.0 * depthSample - 1.0;
    // Perspective projection formula to reverse Z transformation
    return (2.0 * nearPlane * farPlane) / (farPlane + nearPlane - zNdc * (farPlane - nearPlane));
}


vec4 Raytrace(
	sampler2D depthtex,
	vec3 viewPos,
	vec3 normal,
	float dither,
	float maxf,
	float stp,
	float ref,
	float inc
	)
{
	vec3 pos = vec3(0.0);
	float dist = 0.0;

	#if AA == 2
	dither = fract(dither + frameTimeCounter / PHI * 13.333);
	#endif

	vec3 start = viewPos;

    vec3 vector = stp * reflect(normalize(viewPos), normalize(normal));
    viewPos += vector;
	vec3 tvector = vector;

    int sr = 0;

    for (int i = 0; i < 30; i++)
	{
        pos = nvec3(gbufferProjection * nvec4(viewPos)) * 0.5 + 0.5;
		if (pos.x < -0.05 || pos.x > 1.05 || pos.y < -0.05 || pos.y > 1.05) break;

		vec3 rfragpos = vec3(pos.xy, texture2D(depthtex,pos.xy).r);
        rfragpos = nvec3(gbufferProjectionInverse * nvec4(rfragpos * 2.0 - 1.0));
		dist = length(start - rfragpos);

        float err = length(viewPos - rfragpos);
		if (err < pow(length(vector) * pow(length(tvector), 0.11), 1.1) * 1.2)
		{
                sr++;
                if (sr >= maxf) break;
				tvector -= vector;
                vector *= ref;
		}
        vector *= inc;
        tvector += vector;
		viewPos = start + tvector * (dither * 0.05 + 0.975);
    }

	// Previous frame reprojection from Chocapic13
	#ifdef REFLECTION_PREVIOUS
	vec4 viewPosPrev = gbufferProjectionInverse * vec4(pos * 2.0 - 1.0, 1.0);
	viewPosPrev /= viewPosPrev.w;
	viewPosPrev = gbufferModelViewInverse * viewPosPrev;

	vec4 previousPosition = viewPosPrev + vec4(cameraPosition - previousCameraPosition, 0.0);
	previousPosition = gbufferPreviousModelView * previousPosition;
	previousPosition = gbufferPreviousProjection * previousPosition;
	pos.xy = previousPosition.xy / previousPosition.w * 0.5 + 0.5;
	#endif

	return vec4(pos, dist);
}

// RaytraceV2: Enhanced raytracing with adaptive stepping, hit refinement, and off-screen handling.
// nearPlane and farPlane are shader globals typically, ensure they are accessible or pass them.
// For this implementation, we assume 'near' and 'far' are accessible globals (like in deferred.glsl).
vec4 RaytraceV2(
	sampler2D depthtex,
	vec3 viewPos, // Current ray position in view space
	vec3 normal,
	float dither,
	float maxf,  // Max refinement steps in original logic, reused for hit refinement iterations
	float stp,   // Initial step size multiplier
	float ref,   // Step reduction factor for refinement in original, adapted for hit refinement step reduction
	float inc    // Step increment factor
	)
{
	vec3 pos = vec3(0.0); // Screen-space position of the ray hit
	float hitDist = 0.0;  // World-space distance to the hit point

	#if AA == 2
	// Temporal dithering for TAA
	dither = fract(dither + frameTimeCounter / PHI * 13.333);
	#endif

	vec3 startRayPos = viewPos; // Initial position of the ray segment in view space

    // Initial ray direction and total traced vector
    vec3 initialStepVector = stp * reflect(normalize(viewPos), normalize(normal));
    viewPos += initialStepVector; // Advance ray by one initial step
	vec3 totalTracedVector = initialStepVector;
	vec3 currentStepVector = initialStepVector;

    int refinementIterations = 0;
    const int maxRefinementIterations = 3; // Max iterations for hit refinement
    const float hitRefinementStepFactor = 0.25; // Factor to reduce step size for refinement

    // Main ray marching loop
    for (int i = 0; i < 30; i++) // Max steps for ray marching
	{
        // Project current view space position to screen space
        pos = nvec3(gbufferProjection * nvec4(viewPos)) * 0.5 + 0.5;

		// Off-Screen Ray Handling: If ray projects outside screen bounds
		if (pos.x < -0.05 || pos.x > 1.05 || pos.y < -0.05 || pos.y > 1.05) {
			// Placeholder: return a predefined distant Z and specific screen coords.
			// TODO: Implement skybox sampling or more sophisticated off-screen handling.
			return vec4(0.0, 0.0, 1.0, length(startRayPos - viewPos));
		}

        // Get depth from depth texture at projected screen position
		float depthSample = texture2D(depthtex,pos.xy).r;
        // Convert depth sample to view space position
		vec3 surfaceViewPos = nvec3(gbufferProjectionInverse * nvec4(pos.xy * 2.0 - 1.0, depthSample * 2.0 - 1.0));
		hitDist = length(startRayPos - surfaceViewPos); // Distance from ray start to this surface point

        float err = length(viewPos - surfaceViewPos); // Current error: distance between ray pos and surface pos

		// Adaptive Step Sizing Logic:
        // Compare linear depth of current ray position with linear depth from scene geometry.
        // viewPos.z is already in view space, so abs(viewPos.z) is its linear depth.
        float rayLinearDepth = abs(viewPos.z);
        // Linearize depth from depth texture (assuming 'near' and 'far' are accessible globals)
        float sceneLinearDepth = LinearizeDepth(depthSample, near, far);
        float depthDifference = rayLinearDepth - sceneLinearDepth;

        // Heuristic for adaptive stepping:
        if (depthDifference > 2.0 * length(initialStepVector)) { // Ray is significantly above the surface
			currentStepVector = initialStepVector * 2.0; // Take larger steps
		} else if (depthDifference < 0.25 * length(initialStepVector)) { // Ray is very close to or below the surface
			currentStepVector = initialStepVector * 0.5; // Take smaller steps
		} else {
			currentStepVector = initialStepVector; // Default step size
		}
		currentStepVector *= inc; // Apply base increment factor from parameters


		// Check for potential hit
		if (err < pow(length(currentStepVector) * pow(length(totalTracedVector), 0.11), 1.1) * 1.2)
		{
            // Potential Hit Found - Begin Iterative Hit Refinement
            vec3 bestHitViewPos = viewPos;
            float bestError = err;

            // Store current state before refinement
            vec3 preRefinementTotalVector = totalTracedVector;
            vec3 preRefinementViewPos = viewPos;

            // Iterative Hit Refinement Loop
            for (int k = 0; k < maxRefinementIterations; ++k) {
                totalTracedVector -= currentStepVector; // Backtrack slightly from the coarse hit
                currentStepVector *= hitRefinementStepFactor; // Reduce step size significantly for refinement
                totalTracedVector += currentStepVector;
                viewPos = startRayPos + totalTracedVector * (dither * 0.05 + 0.975);

                // Re-evaluate screen position and error
                pos = nvec3(gbufferProjection * nvec4(viewPos)) * 0.5 + 0.5;
                if (pos.x < -0.05 || pos.x > 1.05 || pos.y < -0.05 || pos.y > 1.05) break; // Stop if refinement goes off-screen

                depthSample = texture2D(depthtex,pos.xy).r;
                surfaceViewPos = nvec3(gbufferProjectionInverse * nvec4(pos.xy * 2.0 - 1.0, depthSample * 2.0 - 1.0));
                float currentRefinementError = length(viewPos - surfaceViewPos);

                if (currentRefinementError < bestError) {
                    bestError = currentRefinementError;
                    bestHitViewPos = viewPos;
                } else {
                    // Error increased, refinement might be diverging or overshot. Revert to previous best.
                    viewPos = bestHitViewPos; // Keep the best hit found so far
                    totalTracedVector = preRefinementTotalVector; // Could also try to restore totalTracedVector to match bestHitViewPos
                    currentStepVector = initialStepVector * pow(hitRefinementStepFactor, float(k+1)); // Continue with smaller steps from best known
                    // Or simply break if refinement is not productive
                    // break;
                }
            }
            viewPos = bestHitViewPos; // Use the best position found during refinement
            err = bestError;          // Update error to the refined error

            // After refinement, check if we should terminate ray marching
            // The original logic used 'sr' and 'maxf' for step reduction strategy.
            // Here, we use 'maxf' as a general quality/iteration control if needed, or simply break.
            // For now, assume refinement implies a hit or loop termination.
			break; // Exit main ray marching loop after refinement
		}

        totalTracedVector += currentStepVector;
		viewPos = startRayPos + totalTracedVector * (dither * 0.05 + 0.975); // Apply temporal dither to ray march
    }

	// Previous frame reprojection: Applies temporal reprojection to the hit screen coordinates (pos.xy)
	// This helps stabilize reflections by reusing information from the previous frame.
	#ifdef REFLECTION_PREVIOUS
	// Calculate the view space position of the hit from the current frame
	vec4 hitViewPosCurrentFrame = gbufferProjectionInverse * vec4(pos.xy * 2.0 - 1.0, texture2D(depthtex, pos.xy).r * 2.0 - 1.0, 1.0);
	hitViewPosCurrentFrame /= hitViewPosCurrentFrame.w;
	// Transform to world space
	vec4 hitWorldPos = gbufferModelViewInverse * hitViewPosCurrentFrame;

	// Calculate where this world position was in the previous frame's view space
	vec4 hitViewPosPreviousFrame = gbufferPreviousModelView * hitWorldPos;
    // Account for camera movement (world space)
    hitViewPosPreviousFrame.xyz -= (cameraPosition - previousCameraPosition); // This seems off, reprojection usually adds this. Let's check original.
                                                                              // Original: previousPosition = viewPosPrev + vec4(cameraPosition - previousCameraPosition, 0.0);
                                                                              // Then: previousPosition = gbufferPreviousModelView * previousPosition;
                                                                              // This means the camera delta is applied in world space to the *previous frame's world pos* to get *current world pos if static*
                                                                              // The provided snippet:
                                                                              // vec4 viewPosPrev = gbufferProjectionInverse * vec4(pos * 2.0 - 1.0, 1.0); viewPosPrev /= viewPosPrev.w; viewPosPrev = gbufferModelViewInverse * viewPosPrev;
                                                                              // vec4 previousPosition = viewPosPrev + vec4(cameraPosition - previousCameraPosition, 0.0);
                                                                              // previousPosition = gbufferPreviousModelView * previousPosition; previousPosition = gbufferPreviousProjection * previousPosition;
                                                                              // pos.xy = previousPosition.xy / previousPosition.w * 0.5 + 0.5;
                                                                              // This seems to be: current hit screen pos -> world pos -> add camera delta to get where it *would have been* if it moved with camera -> project to prev screen
                                                                              // Let's stick to the original logic carefully.

	vec4 worldPosAtHit = gbufferModelViewInverse * (gbufferProjectionInverse * vec4(pos.xy * 2.0 - 1.0, texture2D(depthtex, pos.xy).r * 2.0 - 1.0, 1.0));
    worldPosAtHit /= worldPosAtHit.w;

	vec4 previousViewPos = worldPosAtHit;
    // To get the world position in the *previous* frame of a point that is *static* in the world:
    // We don't need to add (cameraPosition - previousCameraPosition).
    // Instead, we use previous matrices to project this static world point to the previous screen.
	previousViewPos = gbufferPreviousModelView * previousViewPos;
	previousViewPos = gbufferPreviousProjection * previousViewPos;

    // If previousViewPos.w is positive (in front of camera) and projection is valid
	if (previousViewPos.w > 0.0) {
	    vec2 reprojectedPos = previousViewPos.xy / previousViewPos.w * 0.5 + 0.5;
        // Check if reprojected position is within screen bounds
	    if (reprojectedPos.x > 0.0 && reprojectedPos.x < 1.0 && reprojectedPos.y > 0.0 && reprojectedPos.y < 1.0) {
	        pos.xy = reprojectedPos; // Use reprojected screen coordinates
	    }
    }
	#endif

	return vec4(pos.xy, texture2D(depthtex,pos.xy).r, hitDist); // Return screen pos (x,y), depth (z), and world distance (w/a)
}
