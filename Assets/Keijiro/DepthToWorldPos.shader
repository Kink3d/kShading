Shader "Hidden/DepthToWorldPos"
{
    Properties
    {
        _MainTex ("-", 2D) = ""{}
    }

    CGINCLUDE

    #include "UnityCG.cginc"

    sampler2D _MainTex;
    sampler2D_float _CameraDepthTexture;
    float4x4 _InverseView;
    half _Intensity;

    fixed4 frag (v2f_img i) : SV_Target
    {
        const float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
        const float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);
        const float isOrtho = unity_OrthoParams.w;
        const float near = _ProjectionParams.y;
        const float far = _ProjectionParams.z;

        float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
#if defined(UNITY_REVERSED_Z)
        d = 1 - d;
#endif
        float zOrtho = lerp(near, far, d);
        float zPers = near * far / lerp(far, near, d);
        float vz = lerp(zPers, zOrtho, isOrtho);

        float3 vpos = float3((i.uv * 2 - 1 - p13_31) / p11_22 * lerp(vz, 1, isOrtho), -vz);
        float4 wpos = mul(_InverseView, float4(vpos, 1));

        half4 source = tex2D(_MainTex, i.uv);
        half3 color = pow(abs(cos(wpos.xyz * UNITY_PI * 4)), 20);
		return color.y;
        return half4(lerp(source.rgb, color, _Intensity), source.a);
    }

    ENDCG

    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag
            ENDCG
        }
    }
}
