// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef TOON_SHADING_INCLUDED
#define TOON_SHADING_INCLUDED

//-------------------------------------------------------------------------------------
// Specular workflow

// Specular Surface Sata
// - The same as SurfaceOutputStandard
struct SurfaceOutputStandardToon
{
	fixed3 Albedo;      // diffuse color
	fixed3 Specular;    // specular color
	fixed3 Normal;      // tangent space normal, if written
	half3 Emission;
	half Smoothness;    // 0=rough, 1=smooth
	half Occlusion;     // occlusion (default 1)
	fixed Alpha;        // alpha for transparencies
};

// Forward Specular Lighting Model
// - The same as LightingStandard except calls ToonBRDF expicitly
inline half4 LightingStandardToon(SurfaceOutputStandardToon s, half3 viewDir, UnityGI gi)
{
	s.Normal = normalize(s.Normal);

	// energy conservation
	half oneMinusReflectivity;
	s.Albedo = EnergyConservationBetweenDiffuseAndSpecular(s.Albedo, s.Specular, /*out*/ oneMinusReflectivity);

	// shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
	// this is necessary to handle transparency in physically correct way - only diffuse component gets affected by alpha
	half outputAlpha;
	s.Albedo = PreMultiplyAlpha(s.Albedo, s.Alpha, oneMinusReflectivity, /*out*/ outputAlpha);

	half4 c = ToonBRDF(s.Albedo, s.Specular, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect); // Call ToonBRDF expicitly
	c.a = outputAlpha;
	return c;
}

// Deferred Specular Lighting Model
// - The same as LightingStandar_Deferred except calls ToonBRDF expicitly
inline half4 LightingStandardToon_Deferred(SurfaceOutputStandardToon s, half3 viewDir, UnityGI gi, out half4 outGBuffer0, out half4 outGBuffer1, out half4 outGBuffer2)
{
	// energy conservation
	half oneMinusReflectivity;
	s.Albedo = EnergyConservationBetweenDiffuseAndSpecular(s.Albedo, s.Specular, /*out*/ oneMinusReflectivity);

	half4 c = ToonBRDF(s.Albedo, s.Specular, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect); // Call ToonBRDF expicitly

	UnityStandardData data;
	data.diffuseColor = s.Albedo;
	data.occlusion = s.Occlusion;
	data.specularColor = s.Specular;
	data.smoothness = s.Smoothness;
	data.normalWorld = s.Normal;

	UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

	half4 emission = half4(s.Emission + c.rgb, 1);
	return emission;
}

// GI Model
// - The same as LightingStandardToon_GI
inline void LightingStandardToon_GI(
	SurfaceOutputStandardToon s,
	UnityGIInput data,
	inout UnityGI gi)
{
#if defined(UNITY_PASS_DEFERRED) && UNITY_ENABLE_REFLECTION_BUFFERS
	gi = UnityGlobalIllumination(data, s.Occlusion, s.Normal);
#else
	Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(s.Smoothness, data.worldViewDir, s.Normal, s.Specular);
	gi = UnityGlobalIllumination(data, s.Occlusion, s.Normal, g);
#endif
}

//-------------------------------------------------------------------------------------
// Water workflow

// Specular Surface Sata
// - The same as SurfaceOutputStandard
struct SurfaceOutputStandardToonWater
{
	fixed3 Albedo;      // diffuse color
	fixed3 Specular;    // specular color
	fixed3 Normal;      // tangent space normal, if written
	half3 Emission;
	half Smoothness;    // 0=rough, 1=smooth
	half Occlusion;     // occlusion (default 1)
	fixed Alpha;        // alpha for transparencies
};

float4 screenUV; // Screen UVs for various passes
float _PlanarReflections; // Enable planar reflection?
sampler2D _ReflectionTex; // Reflection texture set from ToonWater.cs

// Forward Specular Lighting Model
// - The same as LightingStandard except calls ToonBRDF expicitly
inline half4 LightingStandardToonWater(SurfaceOutputStandardToonWater s, half3 viewDir, UnityGI gi)
{
	s.Normal = normalize(s.Normal);

	// energy conservation
	half oneMinusReflectivity;
	s.Albedo = EnergyConservationBetweenDiffuseAndSpecular(s.Albedo, s.Specular, /*out*/ oneMinusReflectivity);

	// shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
	// this is necessary to handle transparency in physically correct way - only diffuse component gets affected by alpha
	half outputAlpha;
	s.Albedo = PreMultiplyAlpha(s.Albedo, s.Alpha, oneMinusReflectivity, /*out*/ outputAlpha);

	half4 c = ToonBRDF(s.Albedo, s.Specular, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect);  // Call ToonBRDF expicitly
	c.a = outputAlpha;
	return c;
}

// Deferred Specular Lighting Model
// - The same as LightingStandar_Deferred except calls ToonBRDF expicitly
inline half4 LightingStandardToonWater_Deferred(SurfaceOutputStandardToonWater s, half3 viewDir, UnityGI gi, out half4 outGBuffer0, out half4 outGBuffer1, out half4 outGBuffer2)
{
	// energy conservation
	half oneMinusReflectivity;
	s.Albedo = EnergyConservationBetweenDiffuseAndSpecular(s.Albedo, s.Specular, /*out*/ oneMinusReflectivity);

	half4 c = ToonBRDF(s.Albedo, s.Specular, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect);  // Call ToonBRDF expicitly

	UnityStandardData data;
	data.diffuseColor = s.Albedo;
	data.occlusion = s.Occlusion;
	data.specularColor = s.Specular;
	data.smoothness = s.Smoothness;
	data.normalWorld = s.Normal;

	UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

	half4 emission = half4(s.Emission + c.rgb, 1);
	return emission;
}

// Modified GI Indirect Specular
// - Sample planar reflection instead of probes
inline half3 ToonWaterGI_IndirectSpecular(UnityGIInput data, half occlusion, Unity_GlossyEnvironmentData glossIn)
{
	half3 specular; // Create output
	if (_PlanarReflections == 1) // If planar reflections enabled
		specular = tex2Dproj(_ReflectionTex, UNITY_PROJ_COORD(screenUV)); // Sample planar reflection
	else
		specular = float3(0, 0, 0); // Return blank
	return specular * occlusion; // Multiply occlusion
}

// GI Function
// - The same as GlobalIllumination except calls a modified GI_Indirect function
inline UnityGI ToonWaterGlobalIllumination(UnityGIInput data, half occlusion, half3 normalWorld, Unity_GlossyEnvironmentData glossIn)
{
	UnityGI o_gi = UnityGI_Base(data, occlusion, normalWorld);
	o_gi.indirect.specular = ToonWaterGI_IndirectSpecular(data, occlusion, glossIn); // Call a modified GI_Indirect function
	return o_gi;
}

// GI Model
// - The same as LightingStandardToon_GI except calls a modified GI function
inline void LightingStandardToonWater_GI(
	SurfaceOutputStandardToonWater s,
	UnityGIInput data,
	inout UnityGI gi)
{
#if defined(UNITY_PASS_DEFERRED) && UNITY_ENABLE_REFLECTION_BUFFERS
	gi = UnityGlobalIllumination(data, s.Occlusion, s.Normal);
#else
	Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(s.Smoothness, data.worldViewDir, s.Normal, s.Specular);
	gi = ToonWaterGlobalIllumination(data, s.Occlusion, s.Normal, g); // Call a modified GI function
#endif
}

#endif // TOON_SHADING_INCLUDED
