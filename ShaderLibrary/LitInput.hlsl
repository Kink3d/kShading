#ifndef KSHADING_LIT_INPUT_INCLUDED
#define KSHADING_LIT_INPUT_INCLUDED

// -------------------------------------
// Includes
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

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
// Macros
#ifdef _SPECULAR_SETUP
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, uv)
#else
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv)
#endif

// -------------------------------------
// Structs
struct SurfaceDataExtended
{
    half3 albedo;
    half3 specular;
    half  metallic;
    half  smoothness;
    half3 normalTS;
    half3 emission;
    half  occlusion;
    half  alpha;
    #ifdef _ANISOTROPY
        half anisotropy;
        half3 direction;
    #endif
    #ifdef _CLEARCOAT
        half clearCoat;
        half clearCoatSmoothness;
    #endif
    #ifdef _SUBSURFACE
        half3 subsurfaceColor;
    #endif
    #ifdef _TRANSMISSION
        half thickness;
    #endif
};

// -------------------------------------
// Material Helpers
half4 SampleMetallicSpecGloss(float2 uv, half albedoAlpha)
{
    half4 specGloss;

#ifdef _METALLICSPECGLOSSMAP
    specGloss = SAMPLE_METALLICSPECULAR(uv);
    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
        specGloss.a = albedoAlpha * _Smoothness;
    #else
        specGloss.a *= _Smoothness;
    #endif
#else // _METALLICSPECGLOSSMAP
    #if _SPECULAR_SETUP
        specGloss.rgb = _SpecColor.rgb;
    #else
        specGloss.rgb = _Metallic.rrr;
    #endif

    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
        specGloss.a = albedoAlpha * _Smoothness;
    #else
        specGloss.a = _Smoothness;
    #endif
#endif

    return specGloss;
}

half SampleOcclusion(float2 uv)
{
#ifdef _OCCLUSIONMAP
// TODO: Controls things like these by exposing SHADER_QUALITY levels (low, medium, high)
#if defined(SHADER_API_GLES)
    return SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
#else
    half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
    return LerpWhiteTo(occ, _OcclusionStrength);
#endif
#else
    return 1.0;
#endif
}

half SampleAnisotropy(float2 uv)
{
#ifdef _ANISOTROPYMAP
    half4 anisotropy = SAMPLE_TEXTURE2D(_AnisotropyMap, sampler_AnisotropyMap, uv);
    return anisotropy.r * _Anisotropy;
#else
    return _Anisotropy;
#endif
}

half3 SampleDirection(float2 uv)
{
#ifdef _DIRECTIONMAP
    half4 direction = SAMPLE_TEXTURE2D(_DirectionMap, sampler_DirectionMap, uv);
    return direction.rgb;
#else
    return half3(1, 0, 0);
#endif
}

half2 SampleClearCoat(float2 uv)
{
    half2 clearCoatGloss;

#ifdef _CLEARCOATMAP
    clearCoatGloss = SAMPLE_TEXTURE2D(_ClearCoatMap, sampler_ClearCoatMap, uv).rg;
    clearCoatGloss.g *= _ClearCoatSmoothness;
#else
    clearCoatGloss.r = _ClearCoat;
    clearCoatGloss.g = _ClearCoatSmoothness;
#endif
    return clearCoatGloss;
}

half3 SampleSubsurface(float2 uv)
{
#ifdef _SUBSURFACEMAP
    half4 subsurface = SAMPLE_TEXTURE2D(_SubsurfaceMap, sampler_SubsurfaceMap, uv);
    return subsurface.rgb * _SubsurfaceColor.rgb;
#else
    return _SubsurfaceColor;
#endif
}

half SampleTransmission(float2 uv)
{
#ifdef _THICKNESSMAP
    half thickness = SAMPLE_TEXTURE2D(_ThicknessMap, sampler_ThicknessMap, uv).r;
    return lerp(thickness, 1, _Thickness);
#else
    return _Thickness;
#endif
}

// -------------------------------------
// SurfaceData
inline void InitializeSurfaceDataExtended(float2 uv, out SurfaceDataExtended outSurfaceData)
{
    half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);

    half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a);
    outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;

#if _SPECULAR_SETUP
    outSurfaceData.metallic = 1.0h;
    outSurfaceData.specular = specGloss.rgb;
#else
    outSurfaceData.metallic = specGloss.r;
    outSurfaceData.specular = half3(0.0h, 0.0h, 0.0h);
#endif

    outSurfaceData.smoothness = specGloss.a;
    outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
    outSurfaceData.occlusion = SampleOcclusion(uv);
    outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));

#ifdef _ANISOTROPY
    outSurfaceData.anisotropy = SampleAnisotropy(uv);
    outSurfaceData.direction = SampleDirection(uv);
#endif
#ifdef _CLEARCOAT
    half2 clearCoatGloss = SampleClearCoat(uv);
    outSurfaceData.clearCoat = clearCoatGloss.r;
    outSurfaceData.clearCoatSmoothness = clearCoatGloss.g;
#endif
#ifdef _SUBSURFACE
    outSurfaceData.subsurfaceColor = SampleSubsurface(uv);
#endif
#ifdef _TRANSMISSION
    outSurfaceData.thickness = SampleTransmission(uv);
#endif
}

#endif
