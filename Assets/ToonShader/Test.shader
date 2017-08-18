Shader "Custom/Test" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard vertex:vert fullforwardshadows

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex;

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;

		struct Input
		{
			float2 uv_MainTex;
			float4 screenUV;
		};

		void vert(inout appdata_full v, out Input o)
		{
			o.uv_MainTex = v.texcoord1;
			o.screenUV = ComputeNonStereoScreenPos(UnityObjectToClipPos(v.vertex));
		}

		sampler2D _CameraDepthTexture;
		float4x4 _InverseView;

		float3 DepthToWorld(float4 uv)
		{
			const float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
			const float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);
			const float isOrtho = unity_OrthoParams.w;
			const float near = _ProjectionParams.y;
			const float far = _ProjectionParams.z;

			float d = LinearEyeDepth(tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(uv))).r;
			//float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv.xy);
#if defined(UNITY_REVERSED_Z)
			d = 1 - d;
#endif
			float zOrtho = lerp(near, far, d);
			float zPers = near * far / lerp(far, near, d);
			float vz = lerp(zPers, zOrtho, isOrtho);

			float3 vpos = float3((uv * 2 - 1 - p13_31) / p11_22 * lerp(vz, 1, isOrtho), -vz);
			float4 wpos = mul(_InverseView, float4(vpos, 1));
			half3 color = pow(abs(cos(wpos.xyz * UNITY_PI * 4)), 3);
			return color;// half(wpos.y);
		}

		void surf (Input IN, inout SurfaceOutputStandard o) {
			// Albedo comes from a texture tinted by color
			fixed4 c = DepthToWorld(IN.screenUV).y;
			o.Albedo = c.rgb;
			// Metallic and smoothness come from slider variables
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
