#ifndef KSHADING_LIT_INPUT_INCLUDED
#define KSHADING_LIT_INPUT_INCLUDED

// -------------------------------------
// Includes
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// -------------------------------------
// Uniforms
CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
half4 _BaseColor;
half4 _SpecColor;
half4 _EmissionColor;
half _Cutoff;
half _Smoothness;
half _Metallic;
half _BumpScale;
half _OcclusionStrength;
half _Anisotropy;
half _ClearCoat;
half _ClearCoatSmoothness;
half3 _SubsurfaceColor;
half _Thickness;
CBUFFER_END

TEXTURE2D(_OcclusionMap);       SAMPLER(sampler_OcclusionMap);
TEXTURE2D(_MetallicGlossMap);   SAMPLER(sampler_MetallicGlossMap);
TEXTURE2D(_SpecGlossMap);       SAMPLER(sampler_SpecGlossMap);
TEXTURE2D(_AnisotropyMap);      SAMPLER(sampler_AnisotropyMap);
TEXTURE2D(_DirectionMap);       SAMPLER(sampler_DirectionMap);
TEXTURE2D(_ClearCoatMap);       SAMPLER(sampler_ClearCoatMap);
TEXTURE2D(_SubsurfaceMap);      SAMPLER(sampler_SubsurfaceMap);
TEXTURE2D(_ThicknessMap);       SAMPLER(sampler_ThicknessMap);

// -------------------------------------
// Includes
#include "Packages/com.kink3d.shading/ShaderLibrary/Input.hlsl"
#endif
