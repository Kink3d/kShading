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
		[HideInInspector] _ReflectionTex("Internal Reflection", 2D) = "" {}
		[Header(Refraction)]
		_RefractStrength("Strength", Range(0, 1)) = 0.5
		_RefractPower("Power", Range(0, 1)) = 0.1
		_RefractAmp("Amplifcation", Range(0, 3)) = 1
		_RefractDepth("Depth", Range(0, 1)) = 0.1
		[Header(Waves)]
		_WaveHeight("Height", Range(0, 1)) = 0
		_WaveDensity("Density", Range(0, 1)) = 0.5
		[HideInInspector] _NoiseTex("Noise Texture", 2D) = "" {}
		[Header(Test)]
		_Test1("Test 1", float) = 0.5
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
		#include "ToonBRDF.cginc"
		#include "ToonShadingModel.cginc"
		#include "ToonInput.cginc"
		//#define UNITY_BRDF_PBS ToonBRDF
		#pragma surface surf StandardToonWater vertex:vert fullforwardshadows
		#pragma target 3.0

		float2 random2(float2 p)
		{
			return frac(sin(float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3))))*43758.5453);
		}

		float _WaveHeight;
		float _WaveDensity;

		float Voronoi(float2 uv)
		{
			float2 st = uv;// gl_FragCoord.xy / u_resolution.xy;
			//st.x *= u_resolution.x / u_resolution.y;

			// Scale 
			st *= 10 - _WaveDensity * 10;

			// Tile the space
			float2 i_st = floor(st);
			float2 f_st = frac(st);

			float m_dist = 10.;  // minimun distance
			float2 m_point;        // minimum point

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
			float4 grabUV;
			float4 screenUV;
		};

		float4 grabUV;

		void vert(inout appdata_full v, out Input o) 
		{
			float4 hpos = UnityObjectToClipPos(v.vertex);
			o.uv_MainTex = v.texcoord1;
			o.grabUV = ComputeGrabScreenPos(hpos);
			
			float voronoi = Voronoi(v.texcoord1);
			v.vertex.y += voronoi * _WaveHeight;
			o.screenUV = ComputeNonStereoScreenPos(UnityObjectToClipPos(v.vertex));
		}

		sampler2D _GrabTex;
		sampler2D _NoiseTex;
		sampler2D _CameraDepthTexture;
		float _RefractStrength;
		float _RefractAmp;
		float _RefractPower;

		// Refract projection UVs
		float4 Refraction(float4 uv)
		{
			fixed4 projUV = UNITY_PROJ_COORD(uv);
			projUV.xy = projUV.xy + (_RefractPower * .5) * sin((1 - projUV.y) * _SinTime.y + (_RefractAmp * .1));
			//projUV.xy = projUV.xy + (_RefractPower * .1) * sin((1 - projUV.y) * (_Time.w * _RefractAmp * .1));
			return projUV;
		}

		float4x4 _InverseView;

		float3 DepthToWorld(float2 uv)
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

			half3 color = pow(abs(cos(wpos.xyz * UNITY_PI * 4)), 20);
			return color;
		}

		void surf (Input IN, inout SurfaceOutputStandardToonWater o) 
		{
			float3 refraction = tex2Dproj(_GrabTex, Refraction(IN.grabUV));
			float voronoi = Voronoi(IN.uv_MainTex);
			
			// Set screenUV for specular calculation from Planar in BRDF
			screenUV = IN.screenUV;

			// Calculate world position from Depth texture
			float3 worldDepth = DepthToWorld((screenUV.xy / screenUV.w));
			worldDepth = step(_Test1, worldDepth);

			// Calculate noise
			float noise = tex2D(_NoiseTex, IN.uv_MainTex * 1.5 + _Time.x).r;
			//noise += tex2D(_NoiseTex, IN.uv_MainTex * 2 - _Time.x).r * 0.5;

			// Calculate crest
			float crest = max(pow(voronoi * 1.5, 10) * (_WaveHeight * 10) - noise * 20, 0);
			crest = step(0.9, crest);
			//crest += max(worldDepth * (_WaveHeight * 100) - noise * 15, 0);
			crest = min(crest, 1);

			// Main
			fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = worldDepth.y;// lerp(c.rgb, c.rgb * refraction, _RefractStrength) + (crest * 0.3);
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
