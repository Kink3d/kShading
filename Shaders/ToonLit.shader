Shader "kShading/Toon Lit"
{
    Properties
    {
        // Surface Options
        [HideInInspector] _WorkflowMode("WorkflowMode", Float) = 1.0
        [HideInInspector] _Surface("__surface", Float) = 0.0
		[HideInInspector] _Blend("__blend", Float) = 0.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _Cull("__cull", Float) = 2.0
		[HideInInspector] _AlphaClip("__clip", Float) = 0.0
		_Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        // Default Surface Inputs
		_BaseMap("Albedo", 2D) = "white" {}
		_BaseColor("Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _MetallicGlossMap("Metallic", 2D) = "white" {}
        _SpecColor("Specular", Color) = (0.2, 0.2, 0.2)
        _SpecGlossMap("Specular", 2D) = "white" {}
		_Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}
		_BumpScale("Scale", Float) = 1.0
		_OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion", 2D) = "white" {}
        _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}

        // Anisotropy
        [ToggleOff] _EnableAnisotropy("Anisotropy", Float) = 0.0
        _AnisotropyMap("Anisotropy", 2D) = "white" {}
        _Anisotropy("Anisotropy", Range(-1.0, 1.0)) = 0.0
        _DirectionMap("Direction", 2D) = "white" {}

        // Clear Coat
        [ToggleOff] _EnableClearCoat("Clear Coat", Float) = 0.0
        _ClearCoatMap("Clear Coat", 2D) = "white" {}
        _ClearCoat("Clear Coat", Range(0.0, 1.0)) = 1.0
        _ClearCoatSmoothness("Clear Coat Smoothness", Range(0.0, 1.0)) = 0.5

        // Subsurface Scattering
        [ToggleOff] _EnableSubsurface("Enable Subsurface Scattering", Float) = 0.0
        _SubsurfaceMap("Subsurface Color", 2D) = "white" {}
        _SubsurfaceColor("Subsurface Color", Color) = (1,1,1,1)

        // Transmission
        [ToggleOff] _EnableTransmission("Enable Transmission", Float) = 0.0
        _ThicknessMap("Thickness", 2D) = "black" {}
        _Thickness("Thickness", Range(0.0, 1.0)) = 0.5

        // Stylization Options
        [ToggleOff] _EnableToonReflections("Enable Toon Reflections", Float) = 0.0
        _ReflectionSteps("Steps", Float) = 16.0

        // Advanced Options
        _ReceiveShadows("Receive Shadows", Float) = 1.0
		[ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [HideInInspector] _QueueOffset("Queue offset", Float) = 0.0
    }

    SubShader
    {
        // Universal Pipeline tag is required. If Universal render pipeline is not set in the graphics settings
        // this Subshader will fail. One can add a subshader below or fallback to Standard built-in to make this
        // material work with both Universal Render Pipeline and Builtin Unity Pipeline
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}
        LOD 300

        // ------------------------------------------------------------------
        //  Forward pass. Shades all light in a single pass. GI + emission + Fog
        Pass
        {
            // Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForwardOnly"}

            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard SRP library
            // All shaders must be compiled with HLSLcc and currently only gles is not using HLSLcc by default
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature _METALLICSPECGLOSSMAP
            #pragma shader_feature _OCCLUSIONMAP
            #pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature _SPECULAR_SETUP
            #pragma shader_feature _RECEIVE_SHADOWS_OFF

            #pragma shader_feature _ANISOTROPY
            #pragma shader_feature _ANISOTROPYMAP
            #pragma shader_feature _DIRECTIONMAP
            #pragma shader_feature _CLEARCOAT
            #pragma shader_feature _CLEARCOATMAP
            #pragma shader_feature _SUBSURFACE
            #pragma shader_feature _SUBSURFACEMAP
            #pragma shader_feature _TRANSMISSION
            #pragma shader_feature _THICKNESSMAP

            #pragma shader_feature _TOON_REFLECTIONS

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            #include "Packages/com.kink3d.shading/ShaderLibrary/ToonLitInput.hlsl"
            #include "Packages/com.kink3d.shading/ShaderLibrary/ToonLighting.hlsl"
            #include "Packages/com.kink3d.shading/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.kink3d.shading/ShaderLibrary/LitForwardPass.hlsl"
            ENDHLSL
        }

        // Used for rendering shadowmaps
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"

        // Used for depth prepass
        // If shadows cascade are enabled we need to perform a depth prepass. 
        // We also need to use a depth prepass in some cases camera require depth texture
        // (e.g, MSAA is enabled and we can't resolve with Texture2DMS
        UsePass "Universal Render Pipeline/Lit/DepthOnly"

        // Used for Baking GI. This pass is stripped from build.
        UsePass "Universal Render Pipeline/Lit/Meta"
    }
    CustomEditor "kTools.Shading.Editor.ToonLitGUI"
	FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
