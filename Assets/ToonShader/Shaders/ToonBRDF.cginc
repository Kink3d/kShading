// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef TOON_BRDF_INCLUDED
#define TOON_BRDF_INCLUDED

//sampler2D unity_NHxRoughness;
//sampler1D _LightRamp;

half _Fresnel;
float3 _FresnelTint;
float _FresnelStrength;
float _FresnelPower;
float _FresnelDiffCont;

float _Test1;

half3 ToonBRDF_Fresnel(half3 diffColor, half3 viewDir, half3 normal)
{
	if (_Fresnel == 1)
	{
		half rim = 1.0 - saturate(dot(normalize(viewDir), normal));
		half3 fresnel = lerp(fixed3(.5, .5, .5), diffColor, _FresnelDiffCont) * pow(rim, 20 - (_FresnelPower * 20));
		return ((_FresnelStrength * 5) * fresnel) * _FresnelTint;
	}
	else
		return half3(0, 0, 0);
}

half3 ToonBRDF_Direct(half3 specColor, half rlPow4, half smoothness, half nl)
{
	half LUT_RANGE = 16.0; // must match range in NHxRoughness() function in GeneratedTextures.cpp
						   // Lookup texture to save instructions
	half specular = tex2D(unity_NHxRoughness, half2(rlPow4, SmoothnessToPerceptualRoughness(smoothness))).UNITY_ATTEN_CHANNEL * LUT_RANGE;
	half specularSteps = max(((1 - smoothness) * 4), 0.01);
	specular = round(specular * specularSteps) / specularSteps;
#if defined(_SPECULARHIGHLIGHTS_OFF)
	specular = 0.0;
#endif
	return specular * specColor;
}

half3 ToonBRDF_Indirect(half3 diffColor, half3 specColor, UnityIndirect indirect, half grazingTerm, half fresnelTerm)
{
	half3 c = indirect.diffuse * diffColor;
	c += indirect.specular * lerp(specColor, grazingTerm, fresnelTerm);
	return c;
}

half3 ToonBRDF_Diffuse(half3 diffColor, half3 lightDir, half3 normal, float3 lightColor)
{
	lightDir = normalize(lightDir);
	float rampCoord = dot(lightDir, normal) * 0.5 + 0.5; // Map value from [-1, 1] to [0, 1]
	float3 diffuse = step(0.1, saturate(dot(normal, lightDir)));
	//float3 diffuse = tex1D(_LightRamp, rampCoord) * lightColor;
	return diffuse;
}

// Old school, not microfacet based Modified Normalized Blinn-Phong BRDF
// Implementation uses Lookup texture for performance
//
// * Normalized BlinnPhong in RDF form
// * Implicit Visibility term
// * No Fresnel term
//
// TODO: specular is too weak in Linear rendering mode
half4 ToonBRDF(half3 diffColor, half3 specColor, half oneMinusReflectivity, half smoothness,
	half3 normal, half3 viewDir,
	UnityLight light, UnityIndirect gi)
{
	half3 reflDir = reflect(viewDir, normal);

	half nl = saturate(dot(normal, light.dir));
	half nv = saturate(dot(normal, viewDir));

	// Vectorize Pow4 to save instructions
	half2 rlPow4AndFresnelTerm = Pow4(half2(dot(reflDir, light.dir), 1 - nv));  // use R.L instead of N.H to save couple of instructions
	half rlPow4 = rlPow4AndFresnelTerm.x; // power exponent must match kHorizontalWarpExp in NHxRoughness() function in GeneratedTextures.cpp
	half fresnelTerm = rlPow4AndFresnelTerm.y;

	half3 specular = ToonBRDF_Direct(specColor, rlPow4, smoothness, nl);
	half3 diffuse = ToonBRDF_Diffuse(diffColor, light.dir, normal, light.color);
	half3 fresnel = ToonBRDF_Fresnel(diffColor, viewDir, normal);

	half grazingTerm = saturate(smoothness + (1 - oneMinusReflectivity));
	half3 indirect = ToonBRDF_Indirect(diffColor, specColor, gi, grazingTerm, fresnelTerm);

	half3 color = (diffColor + specular) * diffuse
		+ fresnel
		+ indirect;

	return half4(color, 1);
}

#endif // TOON_BRDF_INCLUDED
