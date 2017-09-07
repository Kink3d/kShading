Shader "ToonStandard" 
{
	Properties 
	{
		_Mode ("", float) = 0 // Blend mode
		_Cutoff ("", range(0,1)) = 0.5 // Alpha cutoff
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_SpecGlossMap("Specular Map (RGB)", 2D) = "white" {}
		_SpecColor("Specular Color", Color) = (0,0,0,0)
		_Glossiness("Smoothness", Range(0,1)) = 0.5
		_Transmission("Transmission", Range(0,1)) = 0
		_BumpMap("Normal Map", 2D) = "bump" {}
		_BumpScale("Normal Scale", float) = 1
		_EmissionMap("Emission (RGB)", 2D) = "white" {}
		[HDR]_EmissionColor("Emission Color (RGB)", Color) = (0,0,0,0)
		[Toggle]_Fresnel ("", float) = 1 // Fresnel toggle
		_FresnelTint ("Fresnel Tint", Color) = (1,1,1,1)
		_FresnelStrength ("Fresnel Strength", Range(0, 1)) = 0.2
		_FresnelPower ("Fresnel Power", Range(0, 1)) = 0.5
		_FresnelDiffCont("Diffuse Contribution", Range(0, 1)) = 0.5
		
		_SmoothnessTextureChannel("", float) = 0 // Smoothness map channel
		[Toggle]_SpecularHighlights("", float) = 1 // Specular highlight toggle
		[Toggle]_GlossyReflections("", float) = 1 // Glossy reflection toggle
	}

	SubShader 
	{
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		// Include BRDF and shading models
		#include "CGIncludes/ToonBRDF.cginc"
		#include "CGIncludes/ToonShadingModel.cginc"
		#include "CGIncludes/ToonInput.cginc"
		// Define lighting model
		#pragma surface surf StandardToon fullforwardshadows
		#pragma target 3.0

		struct Input 
		{
			float2 uv_MainTex;
		};

		// Surface function
		// - Same as usual PBR lighting model
		void surf (Input IN, inout SurfaceOutputStandardToon o) 
		{
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Specular = tex2D(_SpecGlossMap, IN.uv_MainTex).rgb * _SpecColor;
			o.Smoothness = tex2D(_SpecGlossMap, IN.uv_MainTex).a * _Glossiness;
			o.Normal = UnpackScaleNormal(tex2D(_BumpMap, IN.uv_MainTex), _BumpScale);
			o.Emission = tex2D(_EmissionMap, IN.uv_MainTex).rgb * _EmissionColor;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse" // Define fallback
	CustomEditor "ToonShading.ToonGUI" // Define custom ShaderGUI
}
