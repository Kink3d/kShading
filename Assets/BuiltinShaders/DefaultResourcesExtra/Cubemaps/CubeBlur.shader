// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

﻿Shader "Hidden/CubeBlur" {
	Properties {
		_MainTex ("Main", CUBE) = "" {}
		_Texel ("Texel", Float) = 0.0078125
		_Level ("Level", Float) = 0.
		_Scale ("Scale", Float) = 1.
	}

	CGINCLUDE
	#pragma vertex vert
	#pragma fragment frag
	#include "UnityCG.cginc"
	#include "HLSLSupport.cginc"

	struct v2f {
		half4 pos : SV_POSITION;
		half4 uvw : TEXCOORD0;
	};

	v2f vert(appdata_base v)
	{
		v2f o;
		o.pos = UnityObjectToClipPos(v.vertex);
		o.uvw = v.texcoord;
		return o;
	}

	UNITY_DECLARE_TEXCUBE(_MainTex);

	#define UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(tex, dir,  lod) max(half4(0.0, 0.0, 0.0, 0.0), UNITY_SAMPLE_TEXCUBE_LOD(tex, dir, lod))

	half _Texel;
	half _Radius;
	half _Level;
	half _Scale;

	#define zero	half3(0., 0., 0.)
	#define one		half3(1., 1., 1.)
	#define two		half3(2., 2., 2.)

	half3 fold(half3 st, half3 face)
	{
		half3 c = min(max(st, -one), one);
		half3 f = abs(st - c);
		half m = max(max(f.x, f.y), f.z);
		return c - m*face;
	}

	half3 gauss(half d)
	{
		// compute coefficients for positions .5*d/.5, 1.5*d/.5 and 2.5*d/.5
		// this assumes a sigma of .5 for a density of 1.
		half3 v = half3(d, 3.*d, 5.*d)*_Scale;
		return exp(-v*v);
	}

	half4 frag(v2f  i) : SV_Target
	{
		#if (SHADER_TARGET < 30 || SHADER_API_GLES)
			return UNITY_SAMPLE_TEXCUBE_LOD(_MainTex, i.uvw.xyz, _Level);
		#else
			half3 st;

			half3 face = lerp(zero, i.uvw.xyz, abs(i.uvw.xyz)==one);
			half3 u = face.zxy*_Texel;
			half3 v = face.yzx*_Texel;
			half4 s = half4(i.uvw.xyz*(one - abs(face)), 0.);

			// modulate coefficients based on position (texel density on projected sphere)
			half w = 1. / sqrt(1. + dot(s.xyz, s.xyz));
			half3 C = gauss(w*w*w);

			half4 s1, s2, s3;
			half3 c;

			half3 up1 = fold(i.uvw.xyz + 1.5*u, face);
			half3 um1 = fold(i.uvw.xyz - 1.5*u, face);
			half3 up2 = fold(i.uvw.xyz + 2.5*u, face);
			half3 um2 = fold(i.uvw.xyz - 2.5*u, face);

			half3 vp1 = fold(i.uvw.xyz + 1.5*v, face);
			half3 vm1 = fold(i.uvw.xyz - 1.5*v, face);
			half3 vp2 = fold(i.uvw.xyz + 2.5*v, face);
			half3 vm2 = fold(i.uvw.xyz - 2.5*v, face);

			s = 0.;
			w = 0.;

			// first row

			c = C.xyz*C.zzz;

			st = i.uvw.xyz - 2.5*u - 2.5*v;
			st = fold(st, face);
			s3 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = i.uvw.xyz - 1.5*u - 2.5*v;
			st = fold(st, face);
			s2 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = vm2 - .5*u;
			s1 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = vm2 + .5*u;
			s1 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = i.uvw.xyz + 1.5*u - 2.5*v;
			st = fold(st, face);
			s2 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = i.uvw.xyz + 2.5*u - 2.5*v;
			st = fold(st, face);
			s3 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			w += dot(c, two);
			s1 = c.x*s1 + c.y*s2;
			s += c.z*s3;
			s += s1;

			// second row

			c = C.xyz*C.yyy;

			st = i.uvw.xyz + 2.5*u - 1.5*v;
			st = fold(st, face);
			s3 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = i.uvw.xyz + 1.5*u - 1.5*v;
			st = fold(st, face);
			s2 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = vm1 + .5*u;
			s1 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = vm1 - .5*u;
			s1 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = i.uvw.xyz - 1.5*u - 1.5*v;
			st = fold(st, face);
			s2 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = i.uvw.xyz - 2.5*u - 1.5*v;
			st = fold(st, face);
			s3 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			w += dot(c, two);
			s1 = c.x*s1 + c.y*s2;
			s += c.z*s3;
			s += s1;

			// third row

			c = C.xyz*C.xxx;

			st = um2 - .5*v;
			s3 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = um1 - .5*v;
			s2 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = i.uvw.xyz - .5*u - .5*v;
			s1 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = i.uvw.xyz + .5*u - .5*v;
			s1 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = up1 - .5*v;
			s2 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = up2 - .5*v;
			s3 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			w += dot(c, two);
			s1 = c.x*s1 + c.y*s2;
			s += c.z*s3;
			s += s1;

			// fourth row

			c = C.xyz*C.xxx;

			st = up2 + .5*v;
			s3 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = up1 + .5*v;
			s2 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = i.uvw.xyz + .5*u + .5*v;
			s1 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = i.uvw.xyz - .5*u + .5*v;
			s1 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = um1 + .5*v;
			s2 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = um2 + .5*v;
			s3 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			w += dot(c, two);
			s1 = c.x*s1 + c.y*s2;
			s += c.z*s3;
			s += s1;

			// fifth row

			c = C.xyz*C.yyy;

			st = i.uvw.xyz - 2.5*u + 1.5*v;
			st = fold(st, face);
			s3 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = i.uvw.xyz - 1.5*u + 1.5*v;
			st = fold(st, face);
			s2 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = vp1 - .5*u;
			s1 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = vp1 + .5*u;
			s1 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = i.uvw.xyz + 1.5*u + 1.5*v;
			st = fold(st, face);
			s2 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = i.uvw.xyz + 2.5*u + 1.5*v;
			st = fold(st, face);
			s3 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			w += dot(c, two);
			s1 = c.x*s1 + c.y*s2;
			s += c.z*s3;
			s += s1;

			// sixth row

			c = C.xyz*C.zzz;

			st = i.uvw.xyz + 2.5*u + 2.5*v;
			st = fold(st, face);
			s3 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = i.uvw.xyz + 1.5*u + 2.5*v;
			st = fold(st, face);
			s2 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = vp2 + .5*u;
			s1 = UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = vp2 - .5*u;
			s1 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = i.uvw.xyz - 1.5*u + 2.5*v;
			st = fold(st, face);
			s2 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			st = i.uvw.xyz - 2.5*u + 2.5*v;
			st = fold(st, face);
			s3 += UNITY_SAMPLE_TEXCUBE_LOD_CLAMPED(_MainTex, st, _Level);

			w += dot(c, two);
			s1 = c.x*s1 + c.y*s2;
			s += c.z*s3;
			s += s1;

			return s/w;

		#endif		
	}
	ENDCG

	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		Pass {
			ZTest Always
			Blend Off
			AlphaTest off
			Cull Off
			ZWrite Off
			Fog { Mode off }
			CGPROGRAM
			#pragma target 3.0
			ENDCG
		}
	}

	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		Pass {
			ZTest Always
			Blend Off
			AlphaTest off
			Cull Off
			ZWrite Off
			Fog { Mode off }
			CGPROGRAM
			#pragma target 2.0
			ENDCG
		}
	}
}
