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
		_TessellationPower("Tessellation", Range(0, 10)) = 1
		[HideInInspector] _NoiseTex("Noise Texture", 2D) = "" {}
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
		#pragma surface surf StandardToonWater vertex:vert /*tessellate:tessFixed*/ fullforwardshadows alpha:blend
		#pragma target 3.0

		float2 random2(float2 p)
		{
			return frac(sin(float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3))))*43758.5453);
		}

		float _WaveHeight;
		float _WaveDensity;
		float _TessellationPower;

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

		struct appdata_water 
		{
			float4 vertex : POSITION;
			float4 tangent : TANGENT;
			float3 normal : NORMAL;
			float4 texcoord : TEXCOORD0;
			float4 texcoord1 : TEXCOORD1;
			fixed4 color : COLOR;
			//#if defined(SHADER_API_XBOX360)
			half4 texcoord2 : TEXCOORD2;
			half4 texcoord3 : TEXCOORD3;
			half4 texcoord4 : TEXCOORD4;
			half4 texcoord5 : TEXCOORD5;
			//#endif
		};

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
			o.screenUV = ComputeNonStereoScreenPos(UnityObjectToClipPos(v.vertex));
			float voronoi = Voronoi(v.texcoord1);
			v.vertex.y += voronoi * _WaveHeight;
		}

		sampler2D _GrabTex;
		sampler2D _NoiseTex;
		sampler2D _CameraDepthTexture;
		float _RefractStrength;
		float _RefractAmp;
		float _RefractPower;

		float4 tessFixed()
		{
			return float4(_TessellationPower, _TessellationPower, _TessellationPower, _TessellationPower);
		}

		// Refract projection UVs
		float4 Refraction(float4 uv)
		{
			fixed4 projUV = UNITY_PROJ_COORD(uv);
			projUV.xy = projUV.xy + (_RefractPower * .5) * sin((1 - projUV.y) * _SinTime.y + (_RefractAmp * .1));
			//projUV.xy = projUV.xy + (_RefractPower * .1) * sin((1 - projUV.y) * (_Time.w * _RefractAmp * .1));
			return projUV;
		}

		void surf (Input IN, inout SurfaceOutputStandardToonWater o) 
		{
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;

			float3 refraction = tex2Dproj(_GrabTex, Refraction(IN.grabUV));
			float voronoi = Voronoi(IN.uv_MainTex);
			
			// Set screenUV for specular calculation from Planar in BRDF
			screenUV = IN.screenUV; 
			
			// Depth intersection
			float sceneZ = LinearEyeDepth (tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(screenUV)).r);
			float fragZ = screenUV.z;
			float factor = step(0.1, abs(fragZ - sceneZ)); //If the two are similar, then there is an object intersecting with our object

			float crest = step(0.5, smoothstep(.4, 1, (voronoi)));
			//float crest = min((step(0.6, voronoi)), 1);
			//float crest = (step(0.5, voronoi) * tex2D(_NoiseTex, IN.uv_MainTex + _Time.x).r + step(0.6, voronoi));

			o.Albedo = lerp(c.rgb, c.rgb * refraction, _RefractStrength) + crest * 0.3;
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
