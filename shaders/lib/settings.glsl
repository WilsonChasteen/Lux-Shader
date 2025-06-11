/*
----------------------------------------------------------------
Lux Shader by https://github.com/TechDevOnGithub/
Based on BSL Shaders v7.1.05 by Capt Tatsu https://bitslablab.com
See AGREEMENT.txt for more information.
----------------------------------------------------------------
*/

#define ABOUT 0                                                 // [0]

#define AO
#define AO_STRENGTH 1.00                                        // [0.50 0.75 1.00 1.25 1.50 1.75 2.00]
#define VOLUMETRIC_FOG
#define VOLUMETRIC_FOG_TYPE 0                                   // [0 1]
#define VOLUMETRIC_FOG_STRENGTH 0.75                            // [0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00]
#define BORDER_FOG
#define DESATURATION
#define DESATURATION_FACTOR 1.0                                 // [2.0 1.5 1.0 0.5 0.0]

// --- Reflection Settings ---
#define REFLECTION // Master switch for screen space reflections
#define REFLECTION_TRANSLUCENT
// #define FORCE_REFLECTION // Forces reflection on all surfaces, may ignore material properties
// #define MATERIAL_SUPPORT // Enables more complex material interactions for reflections (e.g. PBR maps)
// #define WHITE_WORLD // Debug: Makes everything white, useful for checking reflection coverage

#define MATERIAL_FORMAT 0                                       // [0 1] // Defines material data packing if MATERIAL_SUPPORT is on
#define REFLECTION_SPECULAR // Enables specular component in screen space reflections
// #define REFLECTION_RAIN // Enables reflections on wet surfaces during rain
#define REFLECTION_RAIN_TYPE 0                                  // [0 1] // Type of rain reflection effect
#define REFLECTION_ROUGH // Enables simulation of rough reflections (blurring)

// --- Path Traced Reflections ---
// Enables experimental path traced reflections. This is performance intensive and replaces standard SSR if enabled.
// #define ENABLE_PATH_TRACED_REFLECTIONS // Uncomment to enable Path Traced Reflections

// Defines the maximum number of bounces for path traced rays. Higher values are more realistic but more expensive.
#define PATH_TRACE_MAX_BOUNCES 3 // Default: 3 [1 to 5]
// #define PATH_TRACE_MAX_BOUNCES 1 // Low (faster, less accurate)
// #define PATH_TRACE_MAX_BOUNCES 5 // High (slower, more accurate indirect lighting)

// Defines the intensity/contribution of path traced reflections.
#define PATH_TRACE_INTENSITY 0.5 // Default: 0.5 [0.0 to 1.0+] (Controls brightness/mix factor)
// #define PATH_TRACE_INTENSITY 0.3 // Low
// #define PATH_TRACE_INTENSITY 0.7 // High

// #define REFLECTION_PREVIOUS // Enables temporal reprojection for reflections to smooth them out
// End of Reflection Settings Section


// #define PARALLAX
#define PARALLAX_DEPTH 1.00                                     // [0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.25 2.50 2.75 3.00 3.25 3.50 3.75 4.00]
// #define SELF_SHADOW
#define SELF_SHADOW_ANGLE 2.0                                   // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0]
#define PARALLAX_QUALITY 64                                     // [16 32 64 128 256 512]
#define PARALLAX_DISTANCE 64                                    // [16 32 48 64 80 96 112 128]
// #define DIRECTIONAL_LIGHTMAP
#define DIRECTIONAL_LIGHTMAP_STRENGTH 1.0                       // [2.0 1.4 1.0 0.7 0.5]

#define CAMERA_FOCUS_MODE 0 			                        // [0 1]
#define CAMERA_FOCUS_DISTANCE 3.0				                // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 10.0 12.0 14.0 16.0 18.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 120.0 140.0 160.0 180.0 200.0 250.0 300.0]
// #define DOF
#define DOF_TYPE 0							                    // [0 1]
#define DOF_STRENGTH 3.0                                        // [0.1 0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 7.0 8.0 9.0 10.0 12.0 14.0 16.0 18.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 110.0 120.0]
#define DOF_SAMPLE_REJECTION
#define DOF_SAMPLE_REJECTION_RESPONSE 160.0                     // [50.0 51.0 ... 280.0]
// #define MOTION_BLUR
#define MOTION_BLUR_STRENGTH 1.00                               // [0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00]
#define BLOOM
#define BLOOM_STRENGTH 1.00                                     // [0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00]
// #define LENS_FLARE
#define LENS_FLARE_STRENGTH 1.00                                // [0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00]
#define AA 2                                                    // [0 1 2]
#define SHARPEN 2                                               // [0 1 2 3 4 5 6 7 8 9 10]
// #define AUTO_EXPOSURE
#define VIGNETTE
#define VIGNETTE_STRENGTH 1.00                                  // [0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00]
// #define DIRTY_LENS
// #define CHROMATIC_ABBERATION
#define CHROMATIC_ABBERATION_STRENGTH 1.00                      // [0.05 ... 4.00]
#define CHROMATIC_ABBERATION_MODE 0                             // [0 1 2]
#define CHROMATIC_ABBERATION_STATIC_STRENGTH 1.00               // [0.05 ... 4.00]
#define CHROMATIC_ABBERATION_ADAPTIVE_STRENGTH
#define CHROMATIC_ABBERATION_ADAPTIVE_STRENGTH_RESPONSE 260.0   // [50.0 ... 360.0]

// #define COLOR_GRADING
#define TONEMAP 2                                               // [1 2]
#define TONEMAP_EXPOSURE 1.0                                    // [0.2 0.4 0.6 0.8 1.0 1.4 2.0 2.8 4.0 5.6 8.0]
#define SATURATION 1.00                                         // [0.00 ... 2.00]
#define VIBRANCE 1.00                                           // [0.00 ... 2.00]

#define CG_RR 255                                               // [0 ... 255]
#define CG_RG 0                                                 // [0 ... 255]
#define CG_RB 0                                                 // [0 ... 255]
#define CG_RI 1.00                                              // [0.05 ... 4.00]
#define CG_RM 0                                                 // [0 ... 255]
#define CG_RC 1.00                                              // [0.05 ... 4.00]

#define CG_GR 0                                                 // [0 ... 255]
#define CG_GG 255                                               // [0 ... 255]
#define CG_GB 0                                                 // [0 ... 255]
#define CG_GI 1.00                                              // [0.05 ... 4.00]
#define CG_GM 0                                                 // [0 ... 255]
#define CG_GC 1.00                                              // [0.05 ... 4.00]

#define CG_BR 0                                                 // [0 ... 255]
#define CG_BG 0                                                 // [0 ... 255]
#define CG_BB 255                                               // [0 ... 255]
#define CG_BI 1.00                                              // [0.05 ... 4.00]
#define CG_BM 0                                                 // [0 ... 255]
#define CG_BC 1.00                                              // [0.05 ... 4.00]

#define CG_TR 255                                               // [0 ... 255]
#define CG_TG 255                                               // [0 ... 255]
#define CG_TB 255                                               // [0 ... 255]
#define CG_TI 1.00                                              // [0.05 ... 4.00]
#define CG_TM 0.0                                               // [0.0 ... 1.0]

const int shadowMapResolution = 2048;                           // [1024 2048 3072 4096 8192]
const float shadowDistance = 256.0;                             // [128.0 256.0 512.0 1024.0]
const float sunPathRotation = -40.0;                            // [-60.0 ... 60.0]
const float shadowMapBias = 1.0 - 25.6 / shadowDistance;
#define SHADOW_COLOR
#define SHADOW_FILTER
#define SHADOW_SUBSURFACE
#define SHADOW_ADVANCED_FILTER 1                                // [0 1]
#define ENTITY_SHADOWS

#ifdef ENTITY_SHADOWS
// Define doesn't show up in settings otherwise
#endif

#define LIGHT_MR 255                                            // [0 ... 255]
#define LIGHT_MG 160                                            // [0 ... 255]
#define LIGHT_MB 80                                             // [0 ... 255]
#define LIGHT_MI 1.20                                           // [0.05 ... 4.00]

#define LIGHT_DR 192                                            // [0 ... 255]
#define LIGHT_DG 208                                            // [0 ... 255]
#define LIGHT_DB 255                                            // [0 ... 255]
#define LIGHT_DI 1.40                                           // [0.05 ... 4.00]

#define LIGHT_ER 255                                            // [0 ... 255]
#define LIGHT_EG 160                                            // [0 ... 255]
#define LIGHT_EB 80                                             // [0 ... 255]
#define LIGHT_EI 1.20                                           // [0.05 ... 4.00]

#define LIGHT_NR 88                                             // [0 ... 255]
#define LIGHT_NG 220                                            // [0 ... 255]
#define LIGHT_NB 255                                            // [0 ... 255]
#define LIGHT_NI 0.9                                            // [0.05 ... 4.00]

#define BLOCKLIGHT_R 255                                        // [0 ... 255]
#define BLOCKLIGHT_G 208                                        // [0 ... 255]
#define BLOCKLIGHT_B 160                                        // [0 ... 255]
#define BLOCKLIGHT_I 1.00                                       // [0.05 ... 4.00]

// #define SKY_VANILLA

#define SKY_R 96                                                // [0 ... 255]
#define SKY_G 160                                               // [0 ... 255]
#define SKY_B 220                                               // [0 ... 255]
#define SKY_I 1.00                                              // [0.05 ... 4.00]

#define WATER_MODE 0                                            // [0 1 2]

#define WATER_R 180                                             // [0 ... 255]
#define WATER_G 224                                             // [0 ... 255]
#define WATER_B 255                                             // [0 ... 255]
#define WATER_I 0.30                                            // [0.05 ... 1.00]
#define WATER_A 0.85                                            // [0.10 ... 1.00]
#define WATER_F 48.0                                            // [16.0 ... 256.0]

#define WEATHER_RR 176                                          // [0 ... 255]
#define WEATHER_RG 224                                          // [0 ... 255]
#define WEATHER_RB 255                                          // [0 ... 255]
#define WEATHER_RI 1.20                                         // [0.05 ... 4.00]

#define WEATHER_CR 216                                          // [0 ... 255]
#define WEATHER_CG 240                                          // [0 ... 255]
#define WEATHER_CB 255                                          // [0 ... 255]
#define WEATHER_CI 1.20                                         // [0.05 ... 4.00]

#define WEATHER_DR 255                                          // [0 ... 255]
#define WEATHER_DG 232                                          // [0 ... 255]
#define WEATHER_DB 180                                          // [0 ... 255]
#define WEATHER_DI 1.20                                         // [0.05 ... 4.00]

#define WEATHER_BR 255                                          // [0 ... 255]
#define WEATHER_BG 216                                          // [0 ... 255]
#define WEATHER_BB 176                                          // [0 ... 255]
#define WEATHER_BI 1.20                                         // [0.05 ... 4.00]

#define WEATHER_SR 200                                          // [0 ... 255]
#define WEATHER_SG 224                                          // [0 ... 255]
#define WEATHER_SB 160                                          // [0 ... 255]
#define WEATHER_SI 1.20                                         // [0.05 ... 4.00]

#define WEATHER_MR 216                                          // [0 ... 255]
#define WEATHER_MG 216                                          // [0 ... 255]
#define WEATHER_MB 255                                          // [0 ... 255]
#define WEATHER_MI 1.20                                         // [0.05 ... 4.00]

#define WEATHER_VR 224                                          // [0 ... 255]
#define WEATHER_VG 224                                          // [0 ... 255]
#define WEATHER_VB 224                                          // [0 ... 255]
#define WEATHER_VI 1.20                                         // [0.05 ... 4.00]

#define NETHER_NR 255                                           // [0 ... 255]
#define NETHER_NG 96                                            // [0 ... 255]
#define NETHER_NB 32                                            // [0 ... 255]
#define NETHER_NI 1.00                                          // [0.05 ... 4.00]

#define NETHER_VR 32                                            // [0 ... 255]
#define NETHER_VG 236                                           // [0 ... 255]
#define NETHER_VB 255                                           // [0 ... 255]
#define NETHER_VI 0.60                                          // [0.05 ... 4.00]

#define NETHER_CR 255                                           // [0 ... 255]
#define NETHER_CG 32                                            // [0 ... 255]
#define NETHER_CB 24                                            // [0 ... 255]
#define NETHER_CI 1.20                                          // [0.05 ... 4.00]

#define NETHER_WR 51                                            // [0 ... 255]
#define NETHER_WG 216                                           // [0 ... 255]
#define NETHER_WB 255                                           // [0 ... 255]
#define NETHER_WI 0.50                                          // [0.05 ... 4.00]

#define NETHER_BR 236                                           // [0 ... 255]
#define NETHER_BG 216                                           // [0 ... 255]
#define NETHER_BB 255                                           // [0 ... 255]
#define NETHER_BI 0.55                                          // [0.05 ... 4.00]

#define END_R 120                                               // [0 ... 255]
#define END_G 104                                               // [0 ... 255]
#define END_B 255                                               // [0 ... 255]
#define END_I 1.00                                              // [0.05 ... 4.00]

#define CLOUDS
#define STARS
#define SHOOTING_STARS
#define SHOOTING_STARS_SCALE 1.2                                // [0.7 ... 1.6]
#define SHOOTING_STARS_SPEED 18.0                               // [8.0 ... 24.0]
#define SHOOTING_STARS_AMOUNT 30.0                              // [1.0 ... 1000.0]
#define SHOOTING_STARS_ROTATION_ITERATIONS 3                    // [1 ... 12]
#define AURORA
#define AURORA_SAMPLES_SKY 8                                    // [4 ... 26]
#define AURORA_SAMPLES_REFLECTION 6                             // [4 ... 26]
#define AURORA_BRIGHTNESS 5.5                                   // [0.5 ... 8.0]
#define AURORA_HEIGHT 12.5                                      // [2.5 7.5 12.5 17.5 22.5]
#define AURORA_COLORING_TYPE 0                                  // [0 1 2 3]
#define AURORA_COLOR_ONE_R 0.1                                  // [0.0 ... 1.0]
#define AURORA_COLOR_ONE_G 0.2                                  // [0.0 ... 1.0]
#define AURORA_COLOR_ONE_B 1.0                                  // [0.0 ... 1.0]
#define AURORA_COLOR_TWO_R 0.1                                  // [0.0 ... 1.0]
#define AURORA_COLOR_TWO_G 1.0                                  // [0.0 ... 1.0]
#define AURORA_COLOR_TWO_B 0.15                                 // [0.0 ... 1.0]
// #define AURORA_PERBIOME
#define ROUND_SUN_MOON
#define SKY_DESATURATION
#define SKYBOX_BRIGHTNESS 2.00                                  // [0.25 ... 4.00]

#define CLOUD_THICKNESS 4                                       // [1 2 4 8 16]
#define CLOUD_AMOUNT 11.0                                       // [13.0 12.0 11.0 10.0 9.0]
#define CLOUD_HEIGHT 15.0                                       // [5.0 10.0 15.0 20.0 25.0]
#define CLOUD_SPEED 1.00                                        // [0.25 ... 4.00]
#define CLOUD_OPACITY 1.0                                       // [0.1 ... 1.0]
#define CLOUD_BRIGHTNESS 1.00                                   // [0.25 ... 4.00]

#define WATER_NORMALS 1                                         // [0 1 2]
#define WATER_PARALLAX
#define WAVE_SPEED 1.0                                          // [0.25 ... 2.0]
#define GERSTNER_WAVE_LENGTH 16.0                               // [8.0 ... 40.0]
#define GERSTNER_WAVE_LACUNARITY 1.4                            // [1.05 ... 1.6]
#define GERSTNER_WAVE_PERSISTANCE 0.93                          // [0.40 ... 0.99]
#define GERSTNER_WAVE_AMPLITUDE 0.34                            // [0.05 ... 0.40]
#define GERSTNER_WAVE_DIR_SPREAD 0.42                           // [0.0 ... 1.0]
#define GERSTNER_WAVE_ITERATIONS 5                              // [0 ... 10]
#define NOISE_WAVE_SCALE 0.007                                  // [0.002 ... 0.01]
#define NOISE_WAVE_LACUNARITY 0.7                               // [0.5 ... 1.5]
#define NOISE_WAVE_AMPLITUDE 0.45                               // [0.0 ... 0.8]
#define NOISE_WAVE_PERSISTANCE 0.75                             // [0.5 ... 1.0]
#define NOISE_WAVE_ITERATIONS 4                                 // [0 ... 10]

#define SCENE_AWARE_WAVING
#define WAVING_GRASS
#define WAVING_CROPS
#define WAVING_PLANT
#define WAVING_TALL_PLANT
#define WAVING_LEAVES
#define WAVING_VINES
#define WAVING_LILYPAD
#define WAVING_FIRE
#define WAVING_WATER
#define WAVING_LAVA
#define WAVING_LANTERN
#define WAVING_HANGING_MANGROVE_PROPAGULE

#define EMISSIVE_BRIGHTNESS 1.0                                 // [0.0 ... 2.0]
#define WEATHER
#define WEATHER_OPACITY 1.00                                    // [0.25 ... 4.00]
#define FOG
#define FOG_DENSITY 1.00                                        // [0.25 ... 4.00]
// #define WORLD_CURVATURE
#define WORLD_CURVATURE_SIZE 256                                // [-256 ... 4096 ... 16]
// #define WORLD_TIME_ANIMATION
#define ANIMATION_SPEED 1.00                                    // [0.25 ... 8.00]
#define WEATHER_PERBIOME
#define SOFT_PARTICLES

#ifdef NETHER
#undef VOLUMETRIC_FOG
#undef LENS_FLARE
#endif

#ifdef END
#undef LENS_FLARE
#endif

#define DYNAMIC_HANDLIGHT

#define MINLIGHT_FACTOR 1.0                                     // [0.0 ... 4.0]

#define AURORA_PROBABILITY 1.0                                  // [0.0 ... 1.0]

#define GLOWING_ORES
