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
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert_img
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			sampler2D _MainTex;

			float2 random2(float2 p)
			{
				return frac(sin(float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3))))*43758.5453);
			}

			float _WaveScale;
			float _WaveHeight;

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

			fixed4 frag (v2f_img i) : SV_Target
			{
				fixed col = Voronoi(i.uv) * _WaveHeight;
				return col;
			}
			ENDCG
		}
	}
}
