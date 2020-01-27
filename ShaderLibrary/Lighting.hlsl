#ifndef KSHADING_LIGHTING_INCLUDED
#define KSHADING_LIGHTING_INCLUDED

// -------------------------------------
// Includes
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// -------------------------------------
// Defines
#define _REFERENCE 0

// -------------------------------------
// Structs
struct InputDataExtended
{
    float3  positionWS;
    half3   normalWS;
    half3   viewDirectionWS;
    float4  shadowCoord;
    half    fogCoord;
    half3   vertexLighting;
    half3   bakedGI;
#ifdef _ANISOTROPY
    half3   tangentWS;
    half3   bitangentWS;
#endif
};

struct BRDFDataExtended
{
    half3 diffuse;
    half3 specular;
    half perceptualRoughness;
    half roughness;
    half roughness2;
    half grazingTerm;

    // We save some light invariant BRDF terms so we don't have to recompute
    // them in the light loop. Take a look at DirectBRDF function for detailed explaination.
    half normalizationTerm;     // roughness * 4.0 + 2.0
    half roughness2MinusOne;    // roughness^2 - 1.0

#ifdef _ANISOTROPY
    half anisotropy;
    half3 anisotropicTangent;
    half3 anisotropicBitangent;
#endif
#ifdef _CLEARCOAT
    half clearCoat;
    half perceptualClearCoatRoughness;
    half clearCoatRoughness;
    half clearCoatRoughness2;
    half clearCoatRoughness2MinusOne;
#endif
#ifdef _SUBSURFACE
    half3 subsurfaceColor;
#endif
#ifdef _TRANSMISSION
    half thickness;
#endif
};

// -------------------------------------
// BRDFData
#if defined(_CLEARCOAT) && defined(_REFERENCE)
    #define CLEAR_COAT_IOR 1.5h
    #define CLEAR_COAT_IETA (1.0h / CLEAR_COAT_IOR) // IETA is the inverse eta which is the ratio of IOR of two interface
#endif

half3 f0ClearCoatToSurface(half3 f0) 
{
    // Approximation of iorTof0(f0ToIor(f0), 1.5)
    // This assumes that the clear coat layer has an IOR of 1.5
#if defined(SHADER_API_MOBILE)
    return saturate(f0 * (f0 * 0.526868h + 0.529324h) - 0.0482256h);
#else
    return saturate(f0 * (f0 * (0.941892h - 0.263008h * f0) + 0.346479h) - 0.0285998h);
#endif
}

inline void InitializeBRDFDataExtended(SurfaceDataExtended surfaceData, InputDataExtended inputData, out BRDFDataExtended outBRDFData)
{
#ifdef _SPECULAR_SETUP
    half reflectivity = ReflectivitySpecular(surfaceData.specular);
    half oneMinusReflectivity = 1.0 - reflectivity;

    outBRDFData.diffuse = surfaceData.albedo * (half3(1.0h, 1.0h, 1.0h) - surfaceData.specular);
    half3 f0 = surfaceData.specular;
#else

    half oneMinusReflectivity = OneMinusReflectivityMetallic(surfaceData.metallic);
    half reflectivity = 1.0 - oneMinusReflectivity;

    outBRDFData.diffuse = surfaceData.albedo * oneMinusReflectivity;
    half3 f0 = kDieletricSpec.rgb;
#endif

    outBRDFData.grazingTerm = saturate(surfaceData.smoothness + reflectivity);
    outBRDFData.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surfaceData.smoothness);
    outBRDFData.roughness = max(PerceptualRoughnessToRoughness(outBRDFData.perceptualRoughness), HALF_MIN);
    outBRDFData.roughness2 = outBRDFData.roughness * outBRDFData.roughness;

#ifdef _ANISOTROPY
    half3 direction = surfaceData.direction;
    half3x3 tangentToWorld = half3x3(inputData.tangentWS, inputData.bitangentWS, inputData.normalWS);
    outBRDFData.anisotropy = surfaceData.anisotropy;
    outBRDFData.anisotropicTangent = normalize(mul(direction, tangentToWorld));
    outBRDFData.anisotropicBitangent = normalize(cross(inputData.normalWS, outBRDFData.anisotropicTangent));
#endif

#ifdef _CLEARCOAT
    // Calculate Roughness of Clear Coat layer
    outBRDFData.clearCoat = surfaceData.clearCoat;
    outBRDFData.perceptualClearCoatRoughness = PerceptualSmoothnessToPerceptualRoughness(surfaceData.clearCoatSmoothness);
    outBRDFData.clearCoatRoughness = PerceptualRoughnessToRoughness(outBRDFData.perceptualClearCoatRoughness);
    outBRDFData.clearCoatRoughness2 = outBRDFData.clearCoatRoughness * outBRDFData.clearCoatRoughness;
    outBRDFData.clearCoatRoughness2MinusOne = outBRDFData.clearCoatRoughness2 - 1.0h;
    
#ifdef _REFERENCE
    // Modify Roughness of base layer
    half ieta = lerp(1.0h, CLEAR_COAT_IETA, outBRDFData.clearCoat);
    half coatRoughnessScale = Sq(ieta);
    half sigma = RoughnessToVariance(PerceptualRoughnessToRoughness(outBRDFData.perceptualRoughness));
    outBRDFData.perceptualRoughness = RoughnessToPerceptualRoughness(VarianceToRoughness(sigma * coatRoughnessScale));
#endif

    f0 = lerp(f0, f0ClearCoatToSurface(f0), outBRDFData.clearCoat);
#endif

#ifdef _SPECULAR_SETUP
    outBRDFData.specular = f0;
#else
    outBRDFData.specular = lerp(f0, surfaceData.albedo, surfaceData.metallic);
#endif

    outBRDFData.normalizationTerm = outBRDFData.roughness * 4.0h + 2.0h;
    outBRDFData.roughness2MinusOne = outBRDFData.roughness2 - 1.0h;

#ifdef _ALPHAPREMULTIPLY_ON
    outBRDFData.diffuse *= surfaceData.alpha;
    surfaceData.alpha = surfaceData.alpha * oneMinusReflectivity + reflectivity;
#endif

#ifdef _SUBSURFACE
    outBRDFData.subsurfaceColor = surfaceData.subsurfaceColor;
#endif
#ifdef _TRANSMISSION
    outBRDFData.thickness = surfaceData.thickness;
#endif
}

// -------------------------------------
// BRDF
#ifdef _CLEARCOAT
half ClearCoat(BRDFDataExtended brdfData, half3 halfDir, half NoH, half LoH, half LoH2) 
{
    half D = NoH * NoH * brdfData.clearCoatRoughness2MinusOne + 1.00001h;
    half specularTerm = brdfData.clearCoatRoughness2 / ((D * D) * max(0.1h, LoH2) * (brdfData.clearCoatRoughness * 4.0 + 2.0)) * brdfData.clearCoat;
    half attenuation = 1 - LoH * brdfData.clearCoat;

#if defined (SHADER_API_MOBILE)
	specularTerm = specularTerm - HALF_MIN;
	specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
#endif

	return specularTerm * attenuation;
}
#endif

// Based on Minimalist CookTorrance BRDF
// Implementation is slightly different from original derivation: http://www.thetenthplanet.de/archives/255
//
// * NDF [Modified] GGX
// * Modified Kelemen and Szirmay-Kalos for Visibility term
// * Fresnel approximated with 1/LdotH
half3 DirectBDRFExtended(BRDFDataExtended brdfData, half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS)
{
#ifndef _SPECULARHIGHLIGHTS_OFF
    float3 halfDir = SafeNormalize(float3(lightDirectionWS) + float3(viewDirectionWS));
    float NoH = saturate(dot(normalWS, halfDir));
    half LoH = saturate(dot(lightDirectionWS, halfDir));
    half LoH2 = LoH * LoH;

    #ifdef _ANISOTROPY
        half ToH = dot(brdfData.anisotropicTangent, halfDir);
        half BoH = dot(brdfData.anisotropicBitangent, halfDir);

        // Anisotropic parameters: at and ab are the roughness along the tangent and bitangent
        // to simplify materials, we derive them from a single roughness parameter
        // Kulla 2017, "Revisiting Physically Based Shading at Imageworks"
        half roughnessT = max(brdfData.roughness * (1.0 + brdfData.anisotropy), HALF_MIN);
        half roughnessB = max(brdfData.roughness * (1.0 - brdfData.anisotropy), HALF_MIN);

        // Anisotropic GGX Distribution multiplied by combined approximation of Visibility and Fresnel
        // V * F = 1.0 / ( LoH^2 * (roughness + 0.5) )
        half d = D_GGXAniso(ToH, BoH, NoH, roughnessT, roughnessB);
        half specularTerm = d * (LoH2 * (brdfData.perceptualRoughness + 0.5) * 4.0);
    #else
        // GGX Distribution multiplied by combined approximation of Visibility and Fresnel
        // BRDFspec = (D * V * F) / 4.0
        // D = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2
        // V * F = 1.0 / ( LoH^2 * (roughness + 0.5) )
        // See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
        // https://community.arm.com/events/1155

        // Final BRDFspec = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2 * (LoH^2 * (roughness + 0.5) * 4.0)
        // We further optimize a few light invariant terms
        // brdfData.normalizationTerm = (roughness + 0.5) * 4.0 rewritten as roughness * 4.0 + 2.0 to a fit a MAD.
        float d = NoH * NoH * brdfData.roughness2MinusOne + 1.00001f;
        half specularTerm = brdfData.roughness2 / ((d * d) * max(0.1h, LoH2) * brdfData.normalizationTerm);
    #endif

    // On platforms where half actually means something, the denominator has a risk of overflow
    // clamp below was added specifically to "fix" that, but dx compiler (we convert bytecode to metal/gles)
    // sees that specularTerm have only non-negative terms, so it skips max(0,..) in clamp (leaving only min(100,...))
#if defined (SHADER_API_MOBILE) || defined (SHADER_API_SWITCH)
    specularTerm = specularTerm - HALF_MIN;
    specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
#endif

    half3 color = specularTerm * brdfData.specular + brdfData.diffuse;

#ifdef _CLEARCOAT
    color += ClearCoat(brdfData, halfDir, NoH, LoH, LoH2);
#endif

    return color;
#else
    return brdfData.diffuse;
#endif
}

// -------------------------------------
// Global Illumination
#ifdef _CLEARCOAT
void GlobalIlluminationClearCoat(BRDFDataExtended brdfData, half3 reflectVector, half fresnelTerm, half occlusion, inout half3 indirectDiffuse, inout half3 indirectSpecular)
{
    fresnelTerm *= brdfData.clearCoat;
    float attenuation = 1 - fresnelTerm;
    indirectDiffuse *= attenuation;
    indirectSpecular *= attenuation * attenuation;
    indirectSpecular += GlossyEnvironmentReflection(reflectVector, brdfData.perceptualClearCoatRoughness, occlusion) * fresnelTerm;
}
#endif

half3 GlobalIlluminationExtended(BRDFDataExtended brdfData, half3 bakedGI, half occlusion, half3 normalWS, half3 viewDirectionWS)
{
#ifdef _ANISOTROPY
    half3 anisotropyDirection = lerp(brdfData.anisotropicBitangent, brdfData.anisotropicTangent, step(brdfData.anisotropy, 0));
    half3 anisotropicTangent = cross(anisotropyDirection, viewDirectionWS);
    half3 anisotropicNormal = cross(anisotropicTangent, anisotropyDirection);
    half bendFactor = abs(brdfData.anisotropy) * saturate(5.0 * brdfData.perceptualRoughness);
    half3 bentNormal = normalize(lerp(normalWS, anisotropicNormal, bendFactor));

    half3 reflectVector = reflect(-viewDirectionWS, bentNormal);
#else
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
#endif

    half fresnelTerm = Pow4(1.0 - saturate(dot(normalWS, viewDirectionWS)));

    half3 indirectDiffuse = bakedGI * occlusion * brdfData.diffuse;
    half3 reflection = GlossyEnvironmentReflection(reflectVector, brdfData.perceptualRoughness, occlusion);
    float surfaceReduction = 1.0 / (brdfData.roughness2 + 1.0);
    half3 indirectSpecular = surfaceReduction * reflection * lerp(brdfData.specular, brdfData.grazingTerm, fresnelTerm);

#ifdef _CLEARCOAT
    GlobalIlluminationClearCoat(brdfData, reflectVector, fresnelTerm, occlusion, indirectDiffuse, indirectSpecular);
#endif

    return indirectDiffuse + indirectSpecular;
}

// -------------------------------------
// Direct Lighting
half3 LightingExtended(BRDFDataExtended brdfData, Light light, half3 normalWS, half3 viewDirectionWS)
{
    half NdotL = saturate(dot(normalWS, light.direction));
    half lightAttenuation = light.distanceAttenuation * light.shadowAttenuation;
    
    half3 internalColor = brdfData.diffuse;
#ifdef _SUBSURFACE
    half NdotLWrap = saturate((dot(normalWS, light.direction) + brdfData.subsurfaceColor) / ((1 + brdfData.subsurfaceColor) * (1 + brdfData.subsurfaceColor)));
    half3 radiance = light.color * (lightAttenuation * lerp(NdotLWrap * brdfData.subsurfaceColor, NdotLWrap, NdotL));
    internalColor = brdfData.subsurfaceColor;
#else
    half3 radiance = light.color * (lightAttenuation * NdotL);
#endif

    half3 color = DirectBDRFExtended(brdfData, normalWS, light.direction, viewDirectionWS) * radiance;

#ifdef _TRANSMISSION
    half3 subsurfaceHalfDir = SafeNormalize(light.direction + normalWS * (0.5 - internalColor * 0.5));
    half subsurfaceVoH = saturate(dot(viewDirectionWS, -subsurfaceHalfDir));
    half3 transmission = subsurfaceVoH * (1 - brdfData.thickness) / ((2 - internalColor) * (2 - internalColor));
    color += transmission * light.color;
#endif
    return color;
}

// -------------------------------------
// Fragment
half4 FragmentLitExtended(InputDataExtended inputData, SurfaceDataExtended surfaceData)
{
    BRDFDataExtended brdfData;
    InitializeBRDFDataExtended(surfaceData, inputData, brdfData);

    Light mainLight = GetMainLight(inputData.shadowCoord);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));

    half3 color = GlobalIlluminationExtended(brdfData, inputData.bakedGI, surfaceData.occlusion, inputData.normalWS, inputData.viewDirectionWS);
    color += LightingExtended(brdfData, mainLight, inputData.normalWS, inputData.viewDirectionWS);

#ifdef _ADDITIONAL_LIGHTS
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, inputData.positionWS);
        color += LightingExtended(brdfData, light, inputData.normalWS, inputData.viewDirectionWS);
    }
#endif

#ifdef _ADDITIONAL_LIGHTS_VERTEX
    color += inputData.vertexLighting * brdfData.diffuse;
#endif

    color += surfaceData.emission;
    return half4(color, surfaceData.alpha);
}

#endif
