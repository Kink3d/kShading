Shader "Hidden/Voronoi"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_WaveScale("", Range(0, 1)) = 0
		_WaveHeight("", Range(0, 1)) = 0
	}

	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert_img
			#pragma fragment frag

			// Wave properties required for voronoi functions
			float _WaveScale;
			float _WaveHeight;

			// Include voronoi functions
			#include "UnityCG.cginc"
			#include "../CGIncludes/Voronoi.cginc"
			
			sampler2D _MainTex;

			fixed4 frag (v2f_img i) : SV_Target
			{
				return Voronoi(i.uv); // Return voronoi
			}
			ENDCG
		}
	}
}
