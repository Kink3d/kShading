// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_BUILTIN_3X_TREE_LIBRARY_INCLUDED
#define UNITY_BUILTIN_3X_TREE_LIBRARY_INCLUDED

// Shared tree shader functionality for Unity 3.x Tree Creator shaders

#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "TerrainEngine.cginc"

fixed4 _Color;
fixed3 _TranslucencyColor;
fixed _TranslucencyViewDependency;
half _ShadowStrength;

struct LeafSurfaceOutput {
    fixed3 Albedo;
    fixed3 Normal;
    fixed3 Emission;
    fixed Translucency;
    half Specular;
    fixed Gloss;
    fixed Alpha;
};

inline half4 LightingTreeLeaf (LeafSurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
{
    half3 h = normalize (lightDir + viewDir);

    half nl = dot (s.Normal, lightDir);

    half nh = max (0, dot (s.Normal, h));
    half spec = pow (nh, s.Specular * 128.0) * s.Gloss;

    // view dependent back contribution for translucency
    fixed backContrib = saturate(dot(viewDir, -lightDir));

    // normally translucency is more like -nl, but looks better when it's view dependent
    backContrib = lerp(saturate(-nl), backContrib, _TranslucencyViewDependency);

    fixed3 translucencyColor = backContrib * s.Translucency * _TranslucencyColor;

    // wrap-around diffuse
    nl = max(0, nl * 0.6 + 0.4);

    fixed4 c;
    /////@TODO: what is is this multiply 2x here???
    c.rgb = s.Albedo * (translucencyColor * 2 + nl);
    c.rgb = c.rgb * _LightColor0.rgb + spec;

    // For directional lights, apply less shadow attenuation
    // based on shadow strength parameter.
    #if defined(DIRECTIONAL) || defined(DIRECTIONAL_COOKIE)
    c.rgb *= lerp(1, atten, _ShadowStrength);
    #else
    c.rgb *= atten;
    #endif

    c.a = s.Alpha;

    return c;
}

// -------- Per-vertex lighting functions for "Tree Creator Leaves Fast" shaders

fixed3 ShadeTranslucentMainLight (float4 vertex, float3 normal)
{
    float3 viewDir = normalize(WorldSpaceViewDir(vertex));
    float3 lightDir = normalize(WorldSpaceLightDir(vertex));
    fixed3 lightColor = _LightColor0.rgb;

    float nl = dot (normal, lightDir);

    // view dependent back contribution for translucency
    fixed backContrib = saturate(dot(viewDir, -lightDir));

    // normally translucency is more like -nl, but looks better when it's view dependent
    backContrib = lerp(saturate(-nl), backContrib, _TranslucencyViewDependency);

    // wrap-around diffuse
    fixed diffuse = max(0, nl * 0.6 + 0.4);

    return lightColor.rgb * (diffuse + backContrib * _TranslucencyColor);
}

fixed3 ShadeTranslucentLights (float4 vertex, float3 normal)
{
    float3 viewDir = normalize(WorldSpaceViewDir(vertex));
    float3 mainLightDir = normalize(WorldSpaceLightDir(vertex));
    float3 frontlight = ShadeSH9 (float4(normal,1.0));
    float3 backlight = ShadeSH9 (float4(-normal,1.0));
    #ifdef VERTEXLIGHT_ON
    float3 worldPos = mul(unity_ObjectToWorld, vertex).xyz;
    frontlight += Shade4PointLights (
        unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
        unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
        unity_4LightAtten0, worldPos, normal);
    backlight += Shade4PointLights (
        unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
        unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
        unity_4LightAtten0, worldPos, -normal);
    #endif

    // view dependent back contribution for translucency using main light as a cue
    fixed backContrib = saturate(dot(viewDir, -mainLightDir));
    backlight = lerp(backlight, backlight * backContrib, _TranslucencyViewDependency);

    // as we integrate over whole sphere instead of normal hemi-sphere
    // lighting gets too washed out, so let's half it down
    return 0.5 * (frontlight + backlight * _TranslucencyColor);
}

void TreeVertBark (inout appdata_full v)
{
    v.vertex.xyz *= _TreeInstanceScale.xyz;
    v.vertex = AnimateVertex(v.vertex, v.normal, float4(v.color.xy, v.texcoord1.xy));

    v.vertex = Squash(v.vertex);

    v.color.rgb = _TreeInstanceColor.rgb * _Color.rgb;
    v.normal = normalize(v.normal);
    v.tangent.xyz = normalize(v.tangent.xyz);
}

void TreeVertLeaf (inout appdata_full v)
{
    ExpandBillboard (UNITY_MATRIX_IT_MV, v.vertex, v.normal, v.tangent);
    v.vertex.xyz *= _TreeInstanceScale.xyz;
    v.vertex = AnimateVertex (v.vertex,v.normal, float4(v.color.xy, v.texcoord1.xy));

    v.vertex = Squash(v.vertex);

    v.color.rgb = _TreeInstanceColor.rgb * _Color.rgb;
    v.normal = normalize(v.normal);
    v.tangent.xyz = normalize(v.tangent.xyz);
}

#endif // UNITY_BUILTIN_3X_TREE_LIBRARY_INCLUDED
