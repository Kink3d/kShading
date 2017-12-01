#ifndef TOON_BRDF_INCLUDED
#define TOON_BRDF_INCLUDED

// Fresnel
half _Fresnel;
float3 _FresnelTint;
float _FresnelStrength;
float _FresnelPower;
float _FresnelDiffCont;

// Transmission
float _Transmission;

// Calculate an extra rimlight / fresnel effect for stylization
half3 ToonBRDF_Fresnel(half3 diffColor, half3 viewDir, half3 normal)
{
	if (_Fresnel == 1) // If fresnel is enabled
	{
		half rim = 1.0 - saturate(dot(normalize(viewDir), normal)); // Rim is one minus NdotL
		half3 fresnelColor = lerp(fixed3(.5, .5, .5), diffColor, _FresnelDiffCont); // Calculate fresnel color based on diffuse contribution
		half fresnelPower = pow(rim, 20 - (_FresnelPower * 20)); // Calculate fresnel power based on user property and rim
		half3 fresnel = fresnelColor * fresnelPower; // Multiply color by power
		return ((_FresnelStrength * 5) * fresnel) * _FresnelTint; // Return tinted and faded fresnel
	}
	else
		return half3(0, 0, 0); // Return zero
}

// Calculate direct lighting
half3 ToonBRDF_Direct(half3 specColor, half rlPow4, half smoothness, half nl)
{
	half LUT_RANGE = 16.0; // must match range in NHxRoughness() function in GeneratedTextures.cpp
						   // Lookup texture to save instructions
	half specular = tex2D(unity_NHxRoughness, half2(rlPow4, SmoothnessToPerceptualRoughness(smoothness))).UNITY_ATTEN_CHANNEL * LUT_RANGE; // Specular function the same as Unity_BRDF3
	half specularSteps = max(((1 - smoothness) * 4), 0.01); // Calculate specular step count based on roughness
	specular = round(specular * specularSteps) / specularSteps; // Step the specular term
#if defined(_SPECULARHIGHLIGHTS_OFF) // If specular highlights disabled
	specular = 0.0; // Set to zero
#endif
	return specular * nl * specColor; // Return colored specular multiplied by NdotL 
}

// Calculate indirect lighting
half3 ToonBRDF_Indirect(half3 diffColor, half3 specColor, UnityIndirect indirect, half grazingTerm, half fresnelTerm)
{
	half3 c = indirect.diffuse * diffColor; // Calculate indirect diffuse color
	c += indirect.specular * lerp(specColor, grazingTerm, fresnelTerm); // Add specular multiplied by fresnel
	return c; // Return
}

// Calculate classic wrapped diffuse
// - TODO: Stepped transmission is not energy conservative
half3 ToonBRDF_Diffuse(half3 diffColor, half3 lightDir, half3 normal, float3 lightColor)
{
	lightDir = normalize(lightDir); // Normalize light direction
	float3 diffuse = saturate((dot(normal, lightDir) + _Transmission) / ((1 + _Transmission) * (1 + _Transmission))); // Wrap diffuse based on transmission
	diffuse = min((round(diffuse * 2) / 2) + _Transmission, 1);
	//diffuse = min(step(0.01, diffuse) + (_Transmission), 1); // Step the diffuse term and rebalance zero area to simulate transmission
	return diffuse * lightColor; // Return diffuse multiplied by light color
}

// Main BRDF
// - Based on the same not microfacet based Modified Normalized Blinn-Phong BRDF as Unity_BRDF3
// - Implementation uses Lookup texture for performance
// - Normalized BlinnPhong in RDF form
// - Implicit Visibility term
half4 ToonBRDF(half3 diffColor, half3 specColor, half oneMinusReflectivity, half smoothness,
	half3 normal, half3 viewDir,
	UnityLight light, UnityIndirect gi)
{
	half3 reflDir = reflect(viewDir, normal); // Calculate reflection vector
	half nl = saturate(dot(normal, light.dir)); // Calculate nDotL
	half nv = saturate(dot(normal, viewDir)); // Calculate NdotV

	// Vectorize Pow4 to save instructions
	half2 rlPow4AndFresnelTerm = Pow4(half2(dot(reflDir, light.dir), 1 - nv));  // use R.L instead of N.H to save couple of instructions
	half rlPow4 = rlPow4AndFresnelTerm.x; // power exponent must match kHorizontalWarpExp in NHxRoughness() function in GeneratedTextures.cpp
	half fresnelTerm = rlPow4AndFresnelTerm.y;

	half3 specular = ToonBRDF_Direct(specColor, rlPow4, smoothness, nl); // Calculate specular
	half3 diffuse = ToonBRDF_Diffuse(diffColor, light.dir, normal, light.color); // Calculate diffuse
	half3 fresnel = ToonBRDF_Fresnel(diffColor, viewDir, normal); // Calculate fresnel/rimlight

	half grazingTerm = saturate(smoothness + (1 - oneMinusReflectivity)); // Calculate grazing term
	half3 indirect = ToonBRDF_Indirect(diffColor, specColor, gi, grazingTerm, fresnelTerm); // Calculate indirect

	// Compose output
	half3 color = (diffColor + specular) * diffuse
		+ fresnel
		+ indirect;

	return half4(color, 1); // Return
}

#endif // TOON_BRDF_INCLUDED
