/*
----------------------------------------------------------------
Lux Shader by https://github.com/TechDevOnGithub/
Based on BSL Shaders v7.1.05 by Capt Tatsu https://bitslablab.com
See AGREEMENT.txt for more information.
----------------------------------------------------------------
*/

// Global Include
#include "../lib/global.glsl" // This should include settings.glsl

// Fragment Shader
#ifdef FSH

// Varyings
varying vec2 texCoord;

varying vec3 sunVec, upVec;

// Uniforms
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float blindFactor;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;
uniform float nightVision;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform sampler2D colortex0; // Diffuse GBuffer
uniform sampler2D colortex1; // Utility GBuffer
uniform sampler2D colortex2; // Normals GBuffer (assumption for path tracing)
uniform sampler2D depthtex0; // Depth texture
uniform sampler2D depthtex1;
uniform sampler2D noisetex;

#ifdef VOLUMETRIC_FOG
uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;
#endif

// Attributes

// Optifine Constants
const bool colortex5Clear = false;

// Common Variables
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility = clamp(dot(sunVec, upVec) + 0.05, 0.0, 0.1) * 10.0;
float moonVisibility = clamp(dot(sunVec, -upVec) + 0.05, 0.0, 0.1) * 10.0;

// Common Functions
float GetLinearDepth(float depth)
{
	return (2.0 * near) / (far + near - depth * (far - near));
}

// Includes
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/lighting/ambientOcclusion.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/reflections/pathtrace.glsl"


#if defined FOG || defined BLACK_OUTLINE
#include "/lib/atmospherics/waterFog.glsl"
#include "/lib/atmospherics/powderSnowFog.glsl"
#endif

#ifdef VOLUMETRIC_FOG
#include "/lib/atmospherics/volumetricLight.glsl"
#endif

#ifdef FOG
#include "/lib/atmospherics/sky.glsl"
#include "/lib/color/ambientColor.glsl"
#endif

// Program
void main()
{
    vec4 color = texture2D(colortex0, texCoord);
    vec3 translucent = texture2D(colortex1,texCoord).rgb;
	float z0 = texture2D(depthtex0, texCoord).r;
	float z1 = texture2D(depthtex1, texCoord).r;

	vec4 screenPos = vec4(texCoord.x, texCoord.y, z0, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

	// Dither is used by AO, Volumetric Fog, and Path Tracing
    // Ensure dither is defined for Path Tracing if other effects are off.
	#if defined AO || defined VOLUMETRIC_FOG || defined ENABLE_PATH_TRACED_REFLECTIONS
	    float dither = InterleavedGradientNoise(gl_FragCoord.xy);
	#else
	    // If no effect using dither is active, but we might still want it for some reason (though not strictly needed if all are off)
	    // float dither = 0.0; // Or InterleavedGradientNoise(gl_FragCoord.xy); if always wanted
	#endif


	#ifdef AO
    float lz0 = GetLinearDepth(z0) * far;
	if (z1 - z0 > 0.0 && lz0 < 32.0)
	{
		if (dot(translucent, translucent) < 0.02)
		{
            float ao = AmbientOcclusion(depthtex0, dither);
            float aoMix = clamp(0.03125 * lz0, 0.0 , 1.0);
            color.rgb *= mix(ao, 1.0, aoMix);
        }
	}
	#endif

    // Path Traced Reflections Integration
    #ifdef ENABLE_PATH_TRACED_REFLECTIONS
        // Default for path trace intensity if not defined in settings.glsl
        #ifndef PATH_TRACE_INTENSITY
            #define PATH_TRACE_INTENSITY 0.5
        #endif

        if (z0 < 0.9999) // Only calculate for actual geometry, not sky
        {
            // Define parameters for path tracing step and increment
            float pt_stp = 0.05;
            float pt_inc = 1.15;

            // Sample surface normal from colortex2 (assuming packed normals, range [0,1] -> [-1,1])
            vec3 surfaceNormal = normalize(texture2D(colortex2, texCoord).rgb * 2.0 - 1.0);

            // Dither value for path tracing's random number generation
            // Re-using 'dither' if already calculated for AO/VF, otherwise calculate it.
            #if !defined(AO) && !defined(VOLUMETRIC_FOG)
                float dither_for_reflection = InterleavedGradientNoise(gl_FragCoord.xy);
            #else
                float dither_for_reflection = dither; // Use existing dither
            #endif

            // Call the PathTraceReflection function
            vec3 reflectionColor = PathTraceReflection(depthtex0,
                                                       colortex0,
                                                       colortex2,
                                                       viewPos.xyz,
                                                       surfaceNormal,
                                                       dither_for_reflection,
                                                       gbufferProjection, gbufferProjectionInverse,
                                                       cameraPosition,
                                                       pt_stp, pt_inc);

            // Blend the reflection color using intensity from settings
            color.rgb += reflectionColor * PATH_TRACE_INTENSITY;
        }
    #endif


	if (isEyeInWater == 1)
	{
		#if defined OVERWORLD
		vec3 absorptionBase = mix(vec3(0.6196, 0.8667 + moonVisibility * 0.1, 1.0), lightCol, 0.1 * eBS);
		#elif defined NETHER
		vec3 absorptionBase = Lift(netherColSqrt.rgb, 10.0);
		#elif defined END
		vec3 absorptionBase = Lift(endColSqrt.rgb, 10.0);
		#endif

		vec3 absorption = exp2((absorptionBase - 1.0) * (12.0 + GetLinearDepth(z0) * 80.0));
		float mult = 1.0 / GetLuminance(exp2((absorptionBase - 1.0) * 12.0));

		absorption = mix(vec3(GetLuminance(absorption)), absorption, 1.0 - Max0(dot(sunVec, upVec)) * 0.4);

		color.rgb *= absorption * (1.0 - rainStrength) + 1.0 * rainStrength;
		color.rgb *= mult;
	}

	#ifdef FOG
	#ifdef OVERWORLD
	vec3 skyEnvAmbientApprox = GetAmbientColor(vec3(0, 1, 0), lightCol);
	#else
	vec3 skyEnvAmbientApprox = vec3(0.0);
	#endif
	#endif

	#ifdef FOG
	if (isEyeInWater != 0.0)
	{
		float viewDist = length(viewPos.xyz);

		if (isEyeInWater == 1.0) WaterFog(color.rgb, viewDist, waterFog * (1.0 + 0.4 * eBS));
		if (isEyeInWater == 3.0)
		{
			#ifdef OVERWORLD
			PowderSnowFog(color.rgb, viewDist, skyEnvAmbientApprox);
			#elif defined END
			PowderSnowFog(color.rgb, viewDist, endCol.rgb);
			#elif defined NETHER
			PowderSnowFog(color.rgb, viewDist, netherCol.rgb);
			#endif
		}
	}
	#endif

	#ifdef VOLUMETRIC_FOG
        #if defined(AO) || defined(ENABLE_PATH_TRACED_REFLECTIONS) // If dither is already defined
	    vec3 vl = GetVolumetricLight(z0, z1, translucent, dither) + (dither - 0.5) / 255.0;
        #else // If dither is not yet defined, calculate it for VL
        float dither_for_vl = InterleavedGradientNoise(gl_FragCoord.xy);
        vec3 vl = GetVolumetricLight(z0, z1, translucent, dither_for_vl) + (dither_for_vl - 0.5) / 255.0;
        #endif
	#else
	    vec3 vl = vec3(0.0);
    #endif

    /* DRAWBUFFERS:01 */
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(vl, 1.0);

    #ifdef REFLECTION_PREVIOUS
    /* DRAWBUFFERS:015 */
	gl_FragData[2] = vec4(pow(color.rgb, vec3(0.125)) * 0.5, float(z0 < 1.0));
	#endif
}

#endif

// Vertex Shader
#ifdef VSH

// Varyings
varying vec2 texCoord;

varying vec3 sunVec, upVec;

// Uniforms
uniform float timeAngle;

uniform mat4 gbufferModelView;

// Program
void main()
{
	texCoord = gl_MultiTexCoord0.xy;
	gl_Position = ftransform();

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * PI) * -0.5 + 0.5 - ang) / 3.0) * TAU;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);
	upVec = normalize(gbufferModelView[1].xyz);
}

#endif
