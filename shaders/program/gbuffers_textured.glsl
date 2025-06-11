/*
----------------------------------------------------------------
Lux Shader by https://github.com/TechDevOnGithub/
Based on BSL Shaders v7.1.05 by Capt Tatsu https://bitslablab.com
See AGREEMENT.txt for more information.
----------------------------------------------------------------
*/

// Global Include
#include "/lib/global.glsl"

// Fragment Shader
#ifdef FSH

// Extensions

// Varyings
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

// Uniforms
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float far, near;
uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrength;
uniform float screenBrightness;
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;
uniform sampler2D depthtex0; // Made unconditional

#ifdef MATERIAL_SUPPORT
uniform sampler2D specular; // This would only be present if gbuffers_textured also handled full PBR, which it might not.
uniform sampler2D normals;  // Same as above.
#endif

#if AA == 2
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
#endif

// Common Variables
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.05, 0.0, 0.1) * 10.0;
float moonVisibility = clamp(dot(-sunVec,upVec) + 0.05, 0.0, 0.1) * 10.0;

#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

// Common Functions
#ifdef SOFT_PARTICLES // This GetLinearDepth is only needed if SOFT_PARTICLES is on.
                      // However, a global GetLinearDepth might be available from common.glsl via global.glsl
                      // For safety, keeping it conditional if it's only used by soft particles here.
                      // If other features in this specific file started using it, it would need to be unconditional too.
float GetLinearDepth(float depth)
{
   return (2.0 * near) / (far + near - depth * (far - near));
}
#endif

// Includes
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/lighting/forwardLighting.glsl"
#include "/lib/atmospherics/sky.glsl"
#include "/lib/color/ambientColor.glsl"

#if AA == 2
#include "/lib/vertex/jitter.glsl"
#endif

// Program
void main()
{
    vec4 albedo = texture2D(texture, texCoord) * color;

	if (albedo.a > 0.001)
	{
		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));

		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		#if AA == 2
		vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5, cameraPosition, previousCameraPosition), screenPos.z));
		#else
		vec3 viewPos = ToNDC(screenPos);
		#endif
		vec3 worldPos = ToWorld(viewPos);

		albedo.rgb = SRGBToLinear(albedo.rgb);

		#ifdef WHITE_WORLD
		albedo.rgb = vec3(0.5);
		#endif

		float NdotL = 1.0;

		float quarterNdotU = clamp(0.25 * dot(normal, upVec) + 0.75, 0.5, 1.0);
		quarterNdotU *= quarterNdotU;

		vec3 shadow = vec3(0.0);

		#ifdef OVERWORLD
		vec3 skyEnvAmbientApprox = GetAmbientColor(normal, lightCol);
		#else
		vec3 skyEnvAmbientApprox = vec3(0.0);
		#endif

		GetLighting(albedo.rgb, shadow, viewPos, worldPos, lightmap, 1.0, NdotL, 1.0, 1.0, 0.0, 0.0, skyEnvAmbientApprox);
	}

	#ifdef SOFT_PARTICLES
	// Ensure LinearizeDepth is available here. If the local one was removed and no global one is included, this will fail.
	// Assuming LinearizeDepth is accessible (e.g., from global.glsl or if kept locally for SOFT_PARTICLES)
	float linearZ = GetLinearDepth(gl_FragCoord.z) * (far - near); // This might be problematic if GetLinearDepth was removed and not globally available
	float backZ = texture2D(depthtex0, gl_FragCoord.xy / vec2(viewWidth, viewHeight)).r;
	float linearBackZ = GetLinearDepth(backZ) * (far - near); // Same here
	float difference = Saturate(linearBackZ - linearZ);
	difference = Smooth3(difference);

	albedo.a *= difference;
	#endif

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = albedo;

	#ifdef MATERIAL_SUPPORT
	// This program (gbuffers_textured) typically does not output to these material buffers
	// as it handles simple textured surfaces (like particles, beacon beams, text)
	// not full PBR materials. If it were to, these would be needed.
	// For now, this is likely dead code or for a variant not being used.
	/* DRAWBUFFERS:0367 */
	// gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0); // smoothness, metalData, skymapMod
	// gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0); // encodedNormal, depthNonLinear (unused)
	// gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0); // rawAlbedo
	#endif
}

#endif

// Vertex Shader
#ifdef VSH

// Varyings
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

// Uniforms
uniform int worldTime;

uniform float frameTimeCounter;
uniform float timeAngle;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;

#if AA == 2
uniform int frameCounter;

uniform float viewWidth, viewHeight;
#endif

#ifdef SOFT_PARTICLES // near and far only needed by VSH if SOFT_PARTICLES logic is here
uniform float far, near;
#endif

#if AA == 2
uniform vec3 previousCameraPosition;
#endif

// Attributes
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

// Common Variables
#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

// Common Functions
#ifdef SOFT_PARTICLES // Local GetLinearDepth/GetLogarithmicDepth for VSH if needed by SOFT_PARTICLES logic here
float GetLinearDepth(float depth)
{
   return (2.0 * near) / (far + near - depth * (far - near));
}

float GetLogarithmicDepth(float depth)
{
	return -(2.0 * near / depth - (far + near)) / (far - near);
}
#endif

// Includes
#if AA == 2
#include "/lib/vertex/jitter.glsl"
#endif

#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

// Program
void main()
{
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = Saturate((lmCoord - 0.03125) * 1.06667);
	normal = normalize(gl_NormalMatrix * gl_Normal);
	color = gl_Color;

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * PI) * -0.5 + 0.5 - ang) / 3.0) * TAU;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);
	upVec = normalize(gbufferModelView[1].xyz);

    #ifdef WORLD_CURVATURE
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	position.y -= WorldCurvature(position.xz);
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	#else
	gl_Position = ftransform();
    #endif

	#ifdef SOFT_PARTICLES
	// This logic assumes gl_Position is in clip space.
	// It converts Z to linear, applies an offset, then converts back to a Z suitable for depth buffer.
	// Requires 'near' and 'far' uniforms to be available in VSH if SOFT_PARTICLES is on.
	gl_Position.z = GetLinearDepth(gl_Position.z / gl_Position.w) * (far - near); // Convert to linear view depth (0 to far-near)
	gl_Position.z -= 0.25; // Apply offset
	gl_Position.z = GetLogarithmicDepth(gl_Position.z / (far - near)) * gl_Position.w; // Convert back to clip-space like Z
	#endif

	#if AA == 2
	gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w, cameraPosition, previousCameraPosition);
	#endif
}

#endif
