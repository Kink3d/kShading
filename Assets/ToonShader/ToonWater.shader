// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "ToonWater" 
{
	Properties 
	{
		[Header(Basic)]
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_SpecGlossMap("Specular Map (RGB)", 2D) = "white" {}
		_SpecColor("Specular Color", Color) = (0,0,0,0)
		_Glossiness("Smoothness", Range(0,1)) = 0.5
		_BumpMap("Normal Map", 2D) = "bump" {}
		_BumpScale("Normal Scale", float) = 1
		_EmissionMap("Emission (RGB)", 2D) = "white" {}
		[HDR]_EmissionColor("Emission Color (RGB)", Color) = (0,0,0,0)
		[Header(Lighting)]
		_LightRamp ("Lighting Ramp (RGB)", 2D) = "white" {}
		[Header(Fresnel)]
		_FresnelTint ("Fresnel Tint", Color) = (1,1,1,1)
		_FresnelStrength ("Fresnel Strength", Range(0, 1)) = 0.2
		_FresnelPower ("Fresnel Power", Range(0, 1)) = 0.5
		_FresnelDiffCont("Diffuse Contribution", Range(0, 1)) = 0.5
		[Header(Reflection)]
		_ReflectStrength("Strength", Range(0, 1)) = 0.5
		[HideInInspector] _ReflectionTex("Internal Reflection", 2D) = "" {}
		[Header(Refraction)]
		_RefractStrength("Strength", Range(0, 1)) = 0.5
		_RefractPower("Power", Range(0, 1)) = 0.1
		_RefractAmp("Amplifcation", Range(0, 3)) = 1
		_RefractDepth("Depth", Range(0, 1)) = 0.1
		[Header(Test)]
		_Test1("Test 1", float) = 0.5
	}

	SubShader 
	{
		

		Tags { "Queue"="Transparent" "RenderType"="Transparent" }
		LOD 200

		GrabPass
		{
			"_GrabTex"
		}
		
		CGPROGRAM
		#include "ToonBRDF.cginc"
		#include "ToonShadingModel.cginc"
		#include "ToonInput.cginc"
		//#define UNITY_BRDF_PBS ToonBRDF
		#pragma surface surf StandardToon vertex:vert fullforwardshadows alpha:blend
		#pragma target 3.0

		struct Input 
		{
			float2 uv_MainTex;
			float4 grabUV;
			float4 ssUV;
		};

		void vert(inout appdata_full v, out Input o) 
		{
			float4 hpos = UnityObjectToClipPos(v.vertex);
			o.uv_MainTex = v.texcoord1;
			o.grabUV = ComputeGrabScreenPos(hpos);
			o.ssUV = ComputeNonStereoScreenPos(UnityObjectToClipPos(v.vertex));
		}

		sampler2D _ReflectionTex;
		float _ReflectStrength;

		sampler2D _GrabTex;
		float _RefractStrength;
		float _RefractAmp;
		float _RefractPower;

		float4 Refraction(float4 uv)
		{
			fixed4 projUV = UNITY_PROJ_COORD(uv);
			//projUV.xy = projUV.xy + (_RefractPower * .5) * sin((1 - projUV.y) * _SinTime.y + (_RefractAmp * .1));
			projUV.xy = projUV.xy + (_RefractPower * .1) * sin((1 - projUV.y) * (_Time.w * _RefractAmp * .1));
			return projUV;
		}

		float4 Refraction2(float4 uv)
		{
			fixed4 projUV = UNITY_PROJ_COORD(uv);
			//projUV.xy = projUV.xy + (_RefractPower * .5) * sin((1 - projUV.y) * _SinTime.y + (_RefractAmp * .1));
			projUV.xy = projUV.xy + (_RefractPower * .05) * sin((1 - projUV.y) * (_Time.w * _RefractAmp * .05));
			return projUV;
		}

		void surf (Input IN, inout SurfaceOutputStandardToon o) 
		{
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;

			float3 refraction = tex2Dproj(_GrabTex, Refraction(IN.grabUV));
			
			float3 reflection = tex2Dproj(_ReflectionTex, Refraction2(IN.ssUV));
			//float3 reflection = tex2Dproj(_ReflectionTex, UNITY_PROJ_COORD(IN.ssUV));

			o.Albedo = c.rgb * (_RefractStrength * refraction) + (_ReflectStrength * reflection);
			o.Specular = tex2D(_SpecGlossMap, IN.uv_MainTex).rgb * _SpecColor;
			o.Smoothness = tex2D(_SpecGlossMap, IN.uv_MainTex).a * _Glossiness;
			o.Normal = UnpackScaleNormal(tex2D(_BumpMap, IN.uv_MainTex), _BumpScale);
			o.Emission = tex2D(_EmissionMap, IN.uv_MainTex).rgb * _EmissionColor;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
