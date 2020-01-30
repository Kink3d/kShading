#ifndef KSHADING_TOON_LIGHTING_INCLUDED
#define KSHADING_TOON_LIGHTING_INCLUDED

// -------------------------------------
// Includes
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// -------------------------------------
// Macros
#define DIRECTSPECULAR(NoH, LoH2, perceptualRoughness, roughness2MinusOne, roughness2, normalizationTerm) DirectSpecularToon(NoH, LoH2, perceptualRoughness, roughness2MinusOne, roughness2, normalizationTerm)
#define DIRECTSPECULARANISOTROPIC(NoH, LoH2, halfDir, perceptualRoughness, roughness, anisotropy, anisotropicTangent, anisotropicBitangent) DirectSpecularAnisotropicToon(NoH, LoH2, halfDir, perceptualRoughness, roughness, anisotropy, anisotropicTangent, anisotropicBitangent)
#define DIRECTSPECULARCLEARCOAT(NoH, LoH, LoH2, halfDir, clearCoat, perceptualClearCoatRoughness, clearCoatRoughness, clearCoatRoughness2, clearCoatRoughness2MinusOne) DirectSpecularClearCoatToon(NoH, LoH, LoH2, halfDir, clearCoat, perceptualClearCoatRoughness, clearCoatRoughness, clearCoatRoughness2, clearCoatRoughness2MinusOne) 
#define GLOSSYENVIRONMENT(reflectVector, positionSS, perceptualClearCoatRoughness, occlusion) GlossyEnvironmentToon(reflectVector, positionSS, perceptualClearCoatRoughness, occlusion)
#define RADIANCE(normalWS, lightDirectionWS, lightColor, lightAttenuation, subsurfaceColor) RadianceToon(normalWS, lightDirectionWS, lightColor, lightAttenuation, subsurfaceColor)

// -------------------------------------
// BRDF
void StepSpecular(half perceptualRoughness, inout half specularTerm)
{
    // Step the Specular term in two lobes
    // 1 - Wide, dull term at smoothness value gets narrower
    // 2 - Narrow, sharp term at high value eases in and out
    half smoothness = 1 - perceptualRoughness;
    half lobe1 = step(smoothness, specularTerm) * smoothness;
    half lobe2 = step(8, specularTerm) * 8;
    specularTerm = lobe1 + lobe2;
}

half DirectSpecularToon(float NoH, half LoH2, 
    half perceptualRoughness, half roughness2MinusOne, half roughness2, half normalizationTerm)
{
    // GGX Distribution multiplied by combined approximation of Visibility and Fresnel
    // BRDFspec = (D * V * F) / 4.0
    // D = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2
    // V * F = 1.0 / ( LoH^2 * (roughness + 0.5) )
    // See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
    // https://community.arm.com/events/1155

    // Final BRDFspec = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2 * (LoH^2 * (roughness + 0.5) * 4.0)
    // We further optimize a few light invariant terms
    // brdfData.normalizationTerm = (roughness + 0.5) * 4.0 rewritten as roughness * 4.0 + 2.0 to a fit a MAD.
    float d = NoH * NoH * roughness2MinusOne + 1.00001f;
    half specularTerm = roughness2 / ((d * d) * max(0.1h, LoH2) * normalizationTerm);

    StepSpecular(perceptualRoughness, specularTerm);
    return specularTerm;
}

half DirectSpecularAnisotropicToon(float NoH, half LoH2, float3 halfDir, 
    half perceptualRoughness, half roughness, half anisotropy, half3 anisotropicTangent, half3 anisotropicBitangent)
{
    half ToH = dot(anisotropicTangent, halfDir);
    half BoH = dot(anisotropicBitangent, halfDir);

    // Anisotropic parameters: at and ab are the roughness along the tangent and bitangent
    // to simplify materials, we derive them from a single roughness parameter
    // Kulla 2017, "Revisiting Physically Based Shading at Imageworks"
    half roughnessT = max(roughness * (1.0 + anisotropy), HALF_MIN);
    half roughnessB = max(roughness * (1.0 - anisotropy), HALF_MIN);

    // Anisotropic GGX Distribution multiplied by combined approximation of Visibility and Fresnel
    // V * F = 1.0 / ( LoH^2 * (roughness + 0.5) )
    // If roughness is 0, returns (NdotH == 1 ? 1 : 0).
    // That is, it returns 1 for perfect mirror reflection, and 0 otherwise.
    half a2 = roughnessT * roughnessB;
    half3 v = half3(roughnessB * ToH, roughnessT * BoH, a2 * NoH);
    half s = dot(v, v);
    half d = SafeDiv(a2 * a2 * a2, s * s);

    half specularTerm = d * (LoH2 * (roughness + 0.5) * 4.0);

    StepSpecular(perceptualRoughness, specularTerm);
    return specularTerm;
}

half DirectSpecularClearCoatToon(half NoH, half LoH, half LoH2, half3 halfDir, 
    half clearCoat, half perceptualClearCoatRoughness, half clearCoatRoughness, half clearCoatRoughness2, half clearCoatRoughness2MinusOne) 
{
    half D = NoH * NoH * clearCoatRoughness2MinusOne + 1.00001h;
    half specularTerm = clearCoatRoughness2 / ((D * D) * max(0.1h, LoH2) * (clearCoatRoughness * 4.0 + 2.0)) * clearCoat;
    half attenuation = 1 - LoH * clearCoat;

#if defined (SHADER_API_MOBILE)
	specularTerm = specularTerm - HALF_MIN;
	specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
#endif

    StepSpecular(perceptualClearCoatRoughness, specularTerm);
	return specularTerm * attenuation;
}

// -------------------------------------
// Global Illumination
half3 GlossyEnvironmentToon(half3 reflectVector, half2 positionSS,  half perceptualRoughness, half occlusion)
{
#if !defined(_ENVIRONMENTREFLECTIONS_OFF)
    half mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);

#ifdef _ENVIRONMENTREFLECTIONS_MIRROR
    half4 encodedIrradiance = SAMPLE_TEXTURE2D_LOD(_ReflectionMap, sampler_ReflectionMap, positionSS, mip);
#ifdef _BLEND_MIRRORS
    half4 encodedIrradienceLocal = SAMPLE_TEXTURE2D_LOD(_LocalReflectionMap, sampler_LocalReflectionMap, positionSS, mip);
    encodedIrradience = lerp(encodedIrradiance, encodedIrradienceLocal, _LocalMirror);
#endif
#else
    half4 encodedIrradiance = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVector, mip);
#endif

#if !defined(UNITY_USE_NATIVE_HDR)
    half3 irradiance = DecodeHDREnvironment(encodedIrradiance, unity_SpecCube0_HDR);
#else
    half3 irradiance = encodedIrradiance.rbg;
#endif

    half3 reflection = irradiance * occlusion;
    #ifdef _TOON_REFLECTIONS
        reflection = round(reflection / (1 / _ReflectionSteps)) * (1 / _ReflectionSteps);
    #endif
    return reflection;
#else
    return _GlossyEnvironmentColor.rgb * occlusion;
#endif
}

// -------------------------------------
// Direct Lighting
half3 RadianceToon(half3 normalWS, half3 lightDirectionWS, half3 lightColor, half lightAttenuation, half3 subsurfaceColor)
{
    half NdotL = ceil(saturate(dot(normalWS, lightDirectionWS)));
    
#ifdef _SUBSURFACE
    half subsurfaceLuminance = Luminance(subsurfaceColor);
    half NdotLWrap = ceil(saturate((dot(normalWS, lightDirectionWS) + subsurfaceLuminance) / ((1 + subsurfaceLuminance) * (1 + subsurfaceLuminance))));
    return lightColor * (lightAttenuation * lerp(NdotLWrap * subsurfaceColor, lerp(NdotLWrap * subsurfaceColor, NdotLWrap, 1 - subsurfaceLuminance), NdotL));
#else
    return lightColor * (lightAttenuation * NdotL);
#endif
}

#endif
