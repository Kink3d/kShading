Shader "ToonWater" 
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
		_WaveHeight("Height", Range(0, 1)) = 0
		_WaveScale("Scale", Range(0, 1)) = 0.5
		_WaveCrest("Crest", Range(0, 1)) = 0.5

		[Toggle]_SeparateVoronoi("", float) = 0 // Separate voronoi toggle
		_SmoothnessTextureChannel("", float) = 0 // Smoothness map channel
		[Toggle]_SpecularHighlights("", float) = 1 // Specular highlight toggle
		[Toggle]_PlanarReflection("", float) = 1 // Planar reflection toggle
		[HideInInspector] _VoronoiTex("Internal Voronoi", 2D) = "" {} // Voronoi noise texture. Set from ToonWater.cs
		[HideInInspector] _ReflectionTex("Internal Reflection", 2D) = "black" {} // Planar reflection texture. Set from ToonWater.cs
		[HideInInspector] _NoiseTex("Noise Texture", 2D) = "" {} // Noise texture. Set from ToonWater.cs
	}

	SubShader 
	{
		Tags { "Queue"="Transparent" "RenderType"="Transparent" }
		LOD 200
		ZWrite Off

		// Enable grab pass
		GrabPass
		{
			"_GrabTex"
		}
		
		CGPROGRAM

		// Wave properties required for voronoi functions
		float _WaveHeight;
		float _WaveScale;
		float _WaveCrest;

		// Include input, BRDF, shading models and voronoi
		#include "CGIncludes/ToonBRDF.cginc"
		#include "CGIncludes/ToonShadingModel.cginc"
		#include "CGIncludes/ToonInput.cginc"
		#include "CGIncludes/Voronoi.cginc"
		// Define lighting model and vertex function
		#pragma surface surf StandardToonWater vertex:vert fullforwardshadows
		#pragma target 3.0

		// Texture samples
		float _SeparateVoronoi;
		sampler2D _VoronoiTex;
		sampler2D _GrabTex;
		sampler2D _NoiseTex;
		sampler2D _CameraDepthTexture;

		struct Input 
		{
			float2 uv_MainTex;
			float3 position;
			float4 screenUV;
		};

		// Vertex shader
		void vert(inout appdata_full v, out Input o) 
		{
			float voronoi = 0; // Define voronoi
			if(_SeparateVoronoi == 1) // If separate voronoi enabled
				voronoi = Voronoi(v.texcoord1); // Calculate voronoi for this vertex
			else
				voronoi = tex2Dlod(_VoronoiTex, v.texcoord).r; // Sample voronoi texture at this vertex
			v.vertex.y += voronoi * _WaveHeight; // Move vertex for waves
			o.uv_MainTex = v.texcoord; // Output UV
			o.position = v.vertex; // Output vertex position
			o.screenUV = ComputeNonStereoScreenPos(UnityObjectToClipPos(v.vertex)); // Compute screen position
		}

		// Refract projection UVs
		// - Use to refract water transmission/visibility and crests
		float2 Refraction(float2 uv)
		{
			uv.x += 0.1 * sin((1 - uv.xy) * .25 * _WaveHeight * (_SinTime.w) * sin(uv.y * 50)); // Calculate sine refraction
			return uv; // Return
		}

		float4x4 _InverseView; // Cameras world matrix. Set from ToonWater.cs

		// Convert depth map to world space
		float3 DepthToWorld(float2 uv, float vHeight)
		{
			// Get projections
			const float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
			const float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);
			const float isOrtho = unity_OrthoParams.w; // Is orthographic
			const float near = _ProjectionParams.y; // Near clip
			const float far = _ProjectionParams.z; // Far clip

			float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv); // Sample depth
			#if defined(UNITY_REVERSED_Z) // If reverse Z
				d = 1 - d; // Reverse
			#endif
			float zOrtho = lerp(near, far, d); // Orthographics projection
			float zPers = near * far / lerp(far, near, d); // Perspective projection
			float vz = lerp(zPers, zOrtho, isOrtho); // Select projection

			float3 vpos = float3((uv * 2 - 1 - p13_31) / p11_22 * lerp(vz, 1, isOrtho), -vz); // Calculate vpos
			float4 wpos = mul(_InverseView, float4(vpos, 1)); // Multiply by camera matrix for world space
			wpos.y += vHeight; // Add vertex height for waves 

			return wpos; // Return
		}

		void surf (Input IN, inout SurfaceOutputStandardToonWater o) 
		{
			// Voronoi noise
			float voronoi = 0; // Define voronoi
			if (_SeparateVoronoi == 1) // If separate voronoi enabled
				voronoi = Voronoi(IN.uv_MainTex); // Calculate voronoi for this fragment
			else 
				voronoi = tex2D(_VoronoiTex, IN.uv_MainTex); // Sample voronoi texture at this fragment

			screenUV = IN.screenUV; // Set screen-space UVs for specular calculation from Planar in BRDF
			float2 refractedWSUV = Refraction(screenUV.xy / screenUV.w); // Refract screen-space UVs
			float3 refractedWorldPos = DepthToWorld(refractedWSUV, IN.position.y); // Calculate world position from Depth texture (with refracted UVs)			

			// Calculate crest
			float noise = tex2D(_NoiseTex, IN.uv_MainTex * 1.5 + _Time.x).r; // Sample simple noise
			float crest = max(pow(voronoi * 1.5, 10) * (_WaveHeight * 10) - noise * 20, 0); // Calculate wave peaks
			crest += max((refractedWorldPos.y * 1.5) * (_WaveHeight * 1000) - noise * (100 * _WaveHeight), 0); // Calculate intersections
			crest = min(step(0.9, crest), 1) * _WaveCrest; // Step the crest and blend

			// Calculate visibility
			float visibility = max(pow(_Transmission, max(-refractedWorldPos.y, 0)) - (1 - _Transmission), 0); // Calculate depth visibility
			float3 grabTex = tex2D(_GrabTex, refractedWSUV); // Sample grab texture
			float3 finalWater = lerp(_Color, (grabTex * _Color), visibility); // Blend between color and colored grab texture based on visibility

			// Main
			o.Albedo = finalWater + crest; // Albedo is water color plus crests
			o.Specular = tex2D(_SpecGlossMap, IN.uv_MainTex).rgb * _SpecColor;
			o.Smoothness = tex2D(_SpecGlossMap, IN.uv_MainTex).a * _Glossiness;
			o.Normal = UnpackScaleNormal(tex2D(_BumpMap, IN.uv_MainTex), _BumpScale);
			o.Emission = tex2D(_EmissionMap, IN.uv_MainTex).rgb * _EmissionColor;
			//o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse" // Define fallback
	CustomEditor "ToonShading.ToonGUI" // Define custom ShaderGUI
}
