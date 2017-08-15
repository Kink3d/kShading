// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_BUILTIN_SHADOW_LIBRARY_INCLUDED
#define UNITY_BUILTIN_SHADOW_LIBRARY_INCLUDED

// Shadowmap helpers.

#if defined( SHADOWS_SCREEN ) && defined( LIGHTMAP_ON )
    #define HANDLE_SHADOWS_BLENDING_IN_GI 1
#endif

// ------------------------------------------------------------------
// Spot light shadows

#if defined (SHADOWS_DEPTH) && defined (SPOT)

// declare shadowmap
#if !defined(SHADOWMAPSAMPLER_DEFINED)
UNITY_DECLARE_SHADOWMAP(_ShadowMapTexture);
#endif

// shadow sampling offsets
#if defined (SHADOWS_SOFT)
float4 _ShadowOffsets[4];
#endif

inline fixed UnitySampleShadowmap (float4 shadowCoord)
{
    // DX11 feature level 9.x shader compiler (d3dcompiler_47 at least)
    // has a bug where trying to do more than one shadowmap sample fails compilation
    // with "inconsistent sampler usage". Until that is fixed, just never compile
    // multi-tap shadow variant on d3d11_9x.

    #if defined (SHADOWS_SOFT) && !defined (SHADER_API_D3D11_9X)

        // 4-tap shadows

        #if defined (SHADOWS_NATIVE)
            #if defined (SHADER_API_D3D9)
                // HLSL for D3D9, when modifying the shadow UV coordinate, really wants to do
                // some funky swizzles, assuming that Z coordinate is unused in texture sampling.
                // So force it to do projective texture reads here, with .w being one.
                float4 coord = shadowCoord / shadowCoord.w;
                half4 shadows;
                shadows.x = UNITY_SAMPLE_SHADOW_PROJ(_ShadowMapTexture, coord + _ShadowOffsets[0]);
                shadows.y = UNITY_SAMPLE_SHADOW_PROJ(_ShadowMapTexture, coord + _ShadowOffsets[1]);
                shadows.z = UNITY_SAMPLE_SHADOW_PROJ(_ShadowMapTexture, coord + _ShadowOffsets[2]);
                shadows.w = UNITY_SAMPLE_SHADOW_PROJ(_ShadowMapTexture, coord + _ShadowOffsets[3]);
                shadows = _LightShadowData.rrrr + shadows * (1-_LightShadowData.rrrr);
            #else
                // On other platforms, no need to do projective texture reads.
                float3 coord = shadowCoord.xyz / shadowCoord.w;
                half4 shadows;
                shadows.x = UNITY_SAMPLE_SHADOW(_ShadowMapTexture, coord + _ShadowOffsets[0]);
                shadows.y = UNITY_SAMPLE_SHADOW(_ShadowMapTexture, coord + _ShadowOffsets[1]);
                shadows.z = UNITY_SAMPLE_SHADOW(_ShadowMapTexture, coord + _ShadowOffsets[2]);
                shadows.w = UNITY_SAMPLE_SHADOW(_ShadowMapTexture, coord + _ShadowOffsets[3]);
                shadows = _LightShadowData.rrrr + shadows * (1-_LightShadowData.rrrr);
            #endif
        #else
            float3 coord = shadowCoord.xyz / shadowCoord.w;
            float4 shadowVals;
            shadowVals.x = SAMPLE_DEPTH_TEXTURE (_ShadowMapTexture, coord + _ShadowOffsets[0].xy);
            shadowVals.y = SAMPLE_DEPTH_TEXTURE (_ShadowMapTexture, coord + _ShadowOffsets[1].xy);
            shadowVals.z = SAMPLE_DEPTH_TEXTURE (_ShadowMapTexture, coord + _ShadowOffsets[2].xy);
            shadowVals.w = SAMPLE_DEPTH_TEXTURE (_ShadowMapTexture, coord + _ShadowOffsets[3].xy);
            half4 shadows = (shadowVals < coord.zzzz) ? _LightShadowData.rrrr : 1.0f;
        #endif

        // average-4 PCF
        half shadow = dot (shadows, 0.25f);

    #else

        // 1-tap shadows

        #if defined (SHADOWS_NATIVE)
        half shadow = UNITY_SAMPLE_SHADOW_PROJ(_ShadowMapTexture, shadowCoord);
        shadow = _LightShadowData.r + shadow * (1-_LightShadowData.r);
        #else
        half shadow = SAMPLE_DEPTH_TEXTURE_PROJ(_ShadowMapTexture, UNITY_PROJ_COORD(shadowCoord)) < (shadowCoord.z / shadowCoord.w) ? _LightShadowData.r : 1.0;
        #endif

    #endif

    return shadow;
}

#endif // #if defined (SHADOWS_DEPTH) && defined (SPOT)

// ------------------------------------------------------------------
// Point light shadows

#if defined (SHADOWS_CUBE)

samplerCUBE_float _ShadowMapTexture;
inline float SampleCubeDistance (float3 vec)
{
    #ifdef UNITY_FAST_COHERENT_DYNAMIC_BRANCHING
        return UnityDecodeCubeShadowDepth(texCUBElod(_ShadowMapTexture, float4(vec, 0)));
    #else
        return UnityDecodeCubeShadowDepth(texCUBE(_ShadowMapTexture, vec));
    #endif
}
inline half UnitySampleShadowmap (float3 vec)
{
    float mydist = length(vec) * _LightPositionRange.w;
    mydist *= 0.97; // bias

    #if defined (SHADOWS_SOFT)
        float z = 1.0/128.0;
        float4 shadowVals;
        shadowVals.x = SampleCubeDistance (vec+float3( z, z, z));
        shadowVals.y = SampleCubeDistance (vec+float3(-z,-z, z));
        shadowVals.z = SampleCubeDistance (vec+float3(-z, z,-z));
        shadowVals.w = SampleCubeDistance (vec+float3( z,-z,-z));
        half4 shadows = (shadowVals < mydist.xxxx) ? _LightShadowData.rrrr : 1.0f;
        return dot(shadows,0.25);
    #else
        float dist = SampleCubeDistance (vec);
        return dist < mydist ? _LightShadowData.r : 1.0;
    #endif
}

#endif // #if defined (SHADOWS_CUBE)


// ------------------------------------------------------------------
// Baked shadows

#if UNITY_LIGHT_PROBE_PROXY_VOLUME

half4 LPPV_SampleProbeOcclusion(float3 worldPos)
{
    const float transformToLocal = unity_ProbeVolumeParams.y;
    const float texelSizeX = unity_ProbeVolumeParams.z;

    //The SH coefficients textures and probe occlusion are packed into 1 atlas.
    //-------------------------
    //| ShR | ShG | ShB | Occ |
    //-------------------------

    float3 position = (transformToLocal == 1.0f) ? mul(unity_ProbeVolumeWorldToObject, float4(worldPos, 1.0)).xyz : worldPos;

    //Get a tex coord between 0 and 1
    float3 texCoord = (position - unity_ProbeVolumeMin.xyz) * unity_ProbeVolumeSizeInv.xyz;

    // Sample fourth texture in the atlas
    // We need to compute proper U coordinate to sample.
    // Clamp the coordinate otherwize we'll have leaking between ShB coefficients and Probe Occlusion(Occ) info
    texCoord.x = max(texCoord.x * 0.25f + 0.75f, 0.75f + 0.5f * texelSizeX);

    return UNITY_SAMPLE_TEX3D_SAMPLER(unity_ProbeVolumeSH, unity_ProbeVolumeSH, texCoord);
}

#endif //#if UNITY_LIGHT_PROBE_PROXY_VOLUME

// ------------------------------------------------------------------
inline fixed UnitySampleBakedOcclusion (float2 lightmapUV, float3 worldPos)
{
    #if defined (SHADOWS_SHADOWMASK)
        #if defined(LIGHTMAP_ON)
            fixed4 rawOcclusionMask = UNITY_SAMPLE_TEX2D_SAMPLER(unity_ShadowMask, unity_Lightmap, lightmapUV.xy);
        #else
            fixed4 rawOcclusionMask = fixed4(1.0, 1.0, 1.0, 1.0);
            #if UNITY_LIGHT_PROBE_PROXY_VOLUME
                if (unity_ProbeVolumeParams.x == 1.0)
                    rawOcclusionMask = LPPV_SampleProbeOcclusion(worldPos);
                else
                    rawOcclusionMask = UNITY_SAMPLE_TEX2D(unity_ShadowMask, lightmapUV.xy);
            #else
                rawOcclusionMask = UNITY_SAMPLE_TEX2D(unity_ShadowMask, lightmapUV.xy);
            #endif
        #endif
        return saturate(dot(rawOcclusionMask, unity_OcclusionMaskSelector));

    #else
        //Handle LPPV baked occlusion for subtractive mode
        #if UNITY_LIGHT_PROBE_PROXY_VOLUME && !defined(LIGHTMAP_ON) && !UNITY_STANDARD_SIMPLE
            fixed4 rawOcclusionMask = fixed4(1.0, 1.0, 1.0, 1.0);
            if (unity_ProbeVolumeParams.x == 1.0)
                rawOcclusionMask = LPPV_SampleProbeOcclusion(worldPos);
            return saturate(dot(rawOcclusionMask, unity_OcclusionMaskSelector));
        #endif

        return 1.0;
    #endif
}

// ------------------------------------------------------------------
inline fixed4 UnityGetRawBakedOcclusions(float2 lightmapUV, float3 worldPos)
{
    #if defined (SHADOWS_SHADOWMASK)
        #if defined(LIGHTMAP_ON)
            return UNITY_SAMPLE_TEX2D_SAMPLER(unity_ShadowMask, unity_Lightmap, lightmapUV.xy);
        #else
            half4 probeOcclusion = unity_ProbesOcclusion;

            #if UNITY_LIGHT_PROBE_PROXY_VOLUME
                if (unity_ProbeVolumeParams.x == 1.0)
                    probeOcclusion = LPPV_SampleProbeOcclusion(worldPos);
            #endif

            return probeOcclusion;
        #endif
    #else
        return fixed4(1.0, 1.0, 1.0, 1.0);
    #endif
}

// --------------------------------------------------------
inline half UnityMixRealtimeAndBakedShadows(half realtimeShadowAttenuation, half bakedShadowAttenuation, half fade)
{
    #if !defined(SHADOWS_DEPTH) && !defined(SHADOWS_SCREEN) && !defined(SHADOWS_CUBE)
        #if defined (LIGHTMAP_SHADOW_MIXING) && !defined (SHADOWS_SHADOWMASK)
            //In subtractive mode when there is no shadow we still want to kill
            //the light contribution because its already baked in the lightmap.
            return 0.0;
        #else
            return bakedShadowAttenuation;
        #endif
    #endif

    #if (SHADER_TARGET <= 20) || UNITY_STANDARD_SIMPLE
        //no fading nor blending on SM 2.0 because of instruction count limit.
        #if defined (SHADOWS_SHADOWMASK)
            return min(realtimeShadowAttenuation, bakedShadowAttenuation);
        #else
            return realtimeShadowAttenuation;
        #endif
    #endif


    #if defined (SHADOWS_SHADOWMASK)
        #if defined (LIGHTMAP_SHADOW_MIXING)
                realtimeShadowAttenuation = saturate(realtimeShadowAttenuation + fade);
                return min(realtimeShadowAttenuation, bakedShadowAttenuation);
        #else
                return lerp(realtimeShadowAttenuation, bakedShadowAttenuation, fade);
        #endif

    #else //no shadowmask
        half attenuation = saturate(realtimeShadowAttenuation + fade);

        //Handle LPPV baked occlusion for subtractive mode
        #if UNITY_LIGHT_PROBE_PROXY_VOLUME && !defined(LIGHTMAP_ON) && !UNITY_STANDARD_SIMPLE
            if (unity_ProbeVolumeParams.x == 1.0)
                attenuation = min(bakedShadowAttenuation, attenuation);
        #endif

        return attenuation;
    #endif
}

// --------------------------------------------------------
// Shadow fade

float UnityComputeShadowFadeDistance(float3 wpos, float z)
{
    float sphereDist = distance(wpos, unity_ShadowFadeCenterAndType.xyz);
    return lerp(z, sphereDist, unity_ShadowFadeCenterAndType.w);
}

// --------------------------------------------------------
half UnityComputeShadowFade(float fadeDist)
{
    return saturate(fadeDist * _LightShadowData.z + _LightShadowData.w);
}

#endif // UNITY_BUILTIN_SHADOW_LIBRARY_INCLUDED
