// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef TOON_INPUT_INCLUDED
#define TOON_INPUT_INCLUDED

half4       _Color;
//half      _Cutoff;

sampler2D   _MainTex;
//float4    _MainTex_ST;

sampler2D   _BumpMap;
half        _BumpScale;

sampler2D   _SpecGlossMap;
half        _Glossiness;
//half      _GlossMapScale;

//sampler2D _OcclusionMap;
//half      _OcclusionStrength;

half4       _EmissionColor;
sampler2D   _EmissionMap;

half _SmoothnessTextureChannel;
half _SpecularHighlights;
half _GlossyReflections;

// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
// #pragma instancing_options assumeuniformscaling
UNITY_INSTANCING_CBUFFER_START(Props)
	// put more per-instance properties here
UNITY_INSTANCING_CBUFFER_END

#endif // TOON_INPUT_INCLUDED
