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

vec4 Raytrace(
	sampler2D depthtex, 
	vec3 viewPos, 
	vec3 normal, 
	float dither,
	float maxf, 
	float stp, 
	float ref, 
	float inc
	// Removed: float maxRayDist, sampler2D gbufferMaterial, vec2 fragScreenUV
	)
{
	// The fourth component of the return value ('result.w') will be used as a status:
	// result.w >= 0.0: Valid hit, value is the actual distance.
	// result.w = -1.0: Sky hit.
	// result.w = -2.0: Miss.
	vec4 result = vec4(0.0, 0.0, 0.0, -2.0); // Default to miss
	int hitType = 0; // 0 = miss, 1 = surface, 2 = sky.

	// float roughness = texture2D(gbufferMaterial, fragScreenUV).g; // Removed

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

		// Optimized pow for inner_pow: pow(length(tvector), 0.11)
		float len_tvector = length(tvector);
		float inner_pow = (len_tvector == 0.0) ? 0.0 : exp(0.11 * log(len_tvector)); // Second pow opt here

		float outer_val = length(vector) * inner_pow;

		// Optimized pow for threshold_val: outer_val^1.1 (First pow opt was here)
		float threshold_val = (outer_val == 0.0) ? 0.0 : outer_val * exp(0.1 * log(outer_val));

		if (err < threshold_val * 1.2)
		{
                sr++;
                if (sr >= maxf) break; // Max refinements reached
				tvector -= vector;    // Retract step
                vector *= ref;        // Reduce step size for refinement
		} else {
            // Adaptive step: if error is large, increase next step's base size moderately
            // This helps to step faster through empty space.
            // Clamp factor to prevent overly large steps, e.g., max 1.5x
            float err_scale = clamp(err / (threshold_val * 1.2), 1.0, 1.5);
            vector *= err_scale;
        }
        vector *= inc; // Apply base increment factor
        tvector += vector;
		viewPos = start + tvector * (dither * 0.05 + 0.975);

        // Perturb ray position for glossy reflections if roughness is significant // Removed
        // if (roughness > 0.01) {
        //     // Generate a pseudo-random 3D offset
        //     // Seed incorporates screen position (fragScreenUV), frame variation (dither), and ray step (i)
        //     vec2 seed = fragScreenUV.xy + vec2(float(i) * 0.13, dither * 0.07);
        //
        //     float rdx = fract(sin(dot(seed, vec2(12.9898, 78.233))) * 43758.5453);
        //     float rdy = fract(sin(dot(seed + rdx, vec2(34.324, 67.897))) * 3758.5453);
        //     float rdz = fract(sin(dot(seed - rdy, vec2(56.123, 90.456))) * 63758.5453);
        //
        //     vec3 randomOffset = normalize(vec3(rdx * 2.0 - 1.0, rdy * 2.0 - 1.0, rdz * 2.0 - 1.0));
        //
        //     // Scale perturbation by roughness and current step length (vector)
        //     // The factor 0.1 is arbitrary to keep perturbations relatively small.
        //     float perturbationStrength = roughness * length(vector) * 0.1;
        //     viewPos += randomOffset * perturbationStrength;
        // }

		// Early exit if ray travels too far // Removed
		// if (length(tvector) > maxRayDist) break;
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