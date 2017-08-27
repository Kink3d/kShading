// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "ToonWater" 
{
	Properties 
	{
		_Mode("", float) = 0
		_Cutoff("", range(0,1)) = 0.5
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_SpecGlossMap("Specular Map (RGB)", 2D) = "white" {}
		_SpecColor("Specular Color", Color) = (0,0,0,0)
		_Glossiness("Smoothness", Range(0,1)) = 0.5
		_Transmission("Transmission", Range(0, 1)) = 0.5
		_BumpMap("Normal Map", 2D) = "bump" {}
		_BumpScale("Normal Scale", float) = 1
		_EmissionMap("Emission (RGB)", 2D) = "white" {}
		[HDR]_EmissionColor("Emission Color (RGB)", Color) = (0,0,0,0)
		[Toggle]_Fresnel("", float) = 1
		_FresnelTint ("Fresnel Tint", Color) = (1,1,1,1)
		_FresnelStrength ("Fresnel Strength", Range(0, 1)) = 0.2
		_FresnelPower ("Fresnel Power", Range(0, 1)) = 0.5
		_FresnelDiffCont("Diffuse Contribution", Range(0, 1)) = 0.5

		_SmoothnessTextureChannel("", float) = 0
		[Toggle]_SpecularHighlights("", float) = 1
		[Toggle]_GlossyReflections("", float) = 1

		_WaveHeight("Height", Range(0, 1)) = 0
		_WaveScale("Scale", Range(0, 1)) = 0.5
		_WaveCrest("Crest", Range(0, 1)) = 0.5
		[HideInInspector] _ReflectionTex("Internal Reflection", 2D) = "" {}
		[HideInInspector] _NoiseTex("Noise Texture", 2D) = "" {}
		
	}

	SubShader 
	{
		

		Tags { "Queue"="Transparent" "RenderType"="Transparent" }
		LOD 200
		ZWrite Off

		GrabPass
		{
			"_GrabTex"
		}
		
		CGPROGRAM
		#include "CGIncludes/ToonBRDF.cginc"
		#include "CGIncludes/ToonShadingModel.cginc"
		#include "CGIncludes/ToonInput.cginc"
		//#define UNITY_BRDF_PBS ToonBRDF
		#pragma surface surf StandardToonWater vertex:vert fullforwardshadows
		#pragma target 3.0

		float2 random2(float2 p)
		{
			return frac(sin(float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3))))*43758.5453);
		}

		float _WaveHeight;
		float _WaveScale;
		float _WaveCrest;

		float Voronoi(float2 uv)
		{
			float2 st = uv;

			// Scale 
			st *= 10 - _WaveScale * 10;

			// Tile the space
			float2 i_st = floor(st);
			float2 f_st = frac(st);

			float m_dist = 10.;	// minimun distance
			float2 m_point;     // minimum point

			for (int j = -1; j <= 1; j++) {
				for (int i = -1; i <= 1; i++) {
					float2 neighbor = float2(float(i), float(j));
					float2 p = random2(i_st + neighbor);
					p = 0.5 + 0.5*sin(_Time.y + 6.2831*p);
					float2 diff = neighbor + p - f_st;
					float dist = length(diff);

					if (dist < m_dist) {
						m_dist = dist;
						m_point = p;
					}
				}
			}
			return m_dist;
		}

		struct Input 
		{
			float2 uv_MainTex;
			float3 position;
			float4 screenUV;
		};

		void vert(inout appdata_full v, out Input o) 
		{
			float voronoi = Voronoi(v.texcoord1);
			v.vertex.y += voronoi * _WaveHeight; // Move vertex y for voronoi
			o.uv_MainTex = v.texcoord;
			o.position = v.vertex;
			o.screenUV = ComputeNonStereoScreenPos(UnityObjectToClipPos(v.vertex));
		}

		sampler2D _GrabTex;
		sampler2D _NoiseTex;
		sampler2D _CameraDepthTexture;

		// Refract projection UVs
		float2 Refraction(float2 uv)
		{
			uv.x += 0.1 * sin((1 - uv.xy) * .25 * _WaveHeight * (_SinTime.w) * sin(uv.y * 50));
			return uv;
		}

		float4x4 _InverseView; // Cameras world matrix (from C#)

		// Convert depth map to world space
		float3 DepthToWorld(float2 uv, float vHeight)
		{
			const float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
			const float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);
			const float isOrtho = unity_OrthoParams.w;
			const float near = _ProjectionParams.y;
			const float far = _ProjectionParams.z;

			float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
			#if defined(UNITY_REVERSED_Z)
			d = 1 - d;
			#endif
			float zOrtho = lerp(near, far, d);
			float zPers = near * far / lerp(far, near, d);
			float vz = lerp(zPers, zOrtho, isOrtho);

			float3 vpos = float3((uv * 2 - 1 - p13_31) / p11_22 * lerp(vz, 1, isOrtho), -vz);
			float4 wpos = mul(_InverseView, float4(vpos, 1));

			wpos = mul(unity_WorldToObject, wpos); // Back to local object space, can go straight to this?
			wpos.y += vHeight;

			return wpos;
		}

		void surf (Input IN, inout SurfaceOutputStandardToonWater o) 
		{
			// Voronoi noise
			float voronoi = Voronoi(IN.uv_MainTex);
			// Set screenUV for specular calculation from Planar in BRDF
			screenUV = IN.screenUV;
			// Refract UVs
			float2 refractedWSUV = Refraction(screenUV.xy / screenUV.w);
			// Calculate world position from Depth texture (with refraction)
			float3 refractedWorldPos = DepthToWorld(refractedWSUV, IN.position.y);
			// Simple noise
			float noise = tex2D(_NoiseTex, IN.uv_MainTex * 1.5 + _Time.x).r;
			// Crest
			float crest = max(pow(voronoi * 1.5, 10) * (_WaveHeight * 10) - noise * 20, 0); // Wave peaks
			crest += max((refractedWorldPos.y * 1.5) * (_WaveHeight * 1000) - noise * (100 * _WaveHeight), 0); // Intersections
			crest = min(step(0.9, crest), 1) * _WaveCrest; // Step
			// Depth visibility
			float visibility = max(pow(_Transmission, max(-refractedWorldPos.y, 0)) - (1 - _Transmission), 0);
			// Refraction
			float3 refraction = tex2D(_GrabTex, refractedWSUV);
			float3 underwater = lerp(_Color, (refraction * _Color), visibility);

			// Main
			//fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = underwater + crest;
			o.Specular = tex2D(_SpecGlossMap, IN.uv_MainTex).rgb * _SpecColor;
			o.Smoothness = tex2D(_SpecGlossMap, IN.uv_MainTex).a * _Glossiness;
			o.Normal = UnpackScaleNormal(tex2D(_BumpMap, IN.uv_MainTex), _BumpScale);
			o.Emission = tex2D(_EmissionMap, IN.uv_MainTex).rgb * _EmissionColor;
			//o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
	CustomEditor "ToonShading.ToonGUI"
}
