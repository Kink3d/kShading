using UnityEngine;
using UnityEditor;

namespace kTools.Shading.Editor
{
    sealed class LitGUI : BaseGUI
    {
#region Structs
        struct Labels
        {
            public static readonly GUIContent Color = new GUIContent("Color",
                "Specifies the base map and color of the surface. Alpha values are used for transparency.");

            public static readonly GUIContent Specular = new GUIContent("Specular", 
                "Sets and configures the map and color for the Specular workflow.");

            public static readonly GUIContent Metallic = new GUIContent("Metallic", 
                "Sets and configures the map for the Metallic workflow.");

            public static readonly GUIContent Smoothness = new GUIContent("Smoothness",
                "Controls the spread of highlights and reflections on the surface.");

            public static readonly GUIContent Normal = new GUIContent("Normal", 
                "Assigns a tangent-space normal map.");

            public static readonly GUIContent Occlusion = new GUIContent("Occlusion",
                "Sets an occlusion map to simulate shadowing from ambient lighting.");

            public static readonly GUIContent Emission = new GUIContent("Emission",
                "Sets a map and color to use for emission. Colors are multiplied over the Texture.");

            public static readonly GUIContent EnableClearCoat = new GUIContent("Clear Coat",
                "Enable Clear Coat layer for the surface");
            
            public static readonly GUIContent ClearCoat = new GUIContent("Clear Coat", 
                "Sets and configures the map for Clear Coat. Red channel defines Clear Coat strength. Green channel defines Smoothness for the Clear Coat layer");
            
            public static readonly GUIContent ClearCoatSmoothness = new GUIContent("Smoothness", 
                "Controls the spread of highlights and reflections for the Clear Coat layer");
        }

        struct PropertyNames
        {
            public static readonly string BaseMap = "_BaseMap";
            public static readonly string BaseColor = "_BaseColor";
            public static readonly string Metallic = "_Metallic";
            public static readonly string SpecColor = "_SpecColor";
            public static readonly string MetallicGlossMap = "_MetallicGlossMap";
            public static readonly string SpecGlossMap = "_SpecGlossMap";
            public static readonly string Smoothness = "_Smoothness";
            public static readonly string BumpMap = "_BumpMap";
            public static readonly string BumpScale = "_BumpScale";
            public static readonly string OcclusionMap = "_OcclusionMap";
            public static readonly string OcclusionStrength = "_OcclusionStrength";
            public static readonly string EmissionMap = "_EmissionMap";
            public static readonly string EmissionColor = "_EmissionColor";
            public static readonly string EnableClearCoat = "_EnableClearCoat";
            public static readonly string ClearCoatMap = "_ClearCoatMap";
            public static readonly string ClearCoat = "_ClearCoat";
            public static readonly string ClearCoatSmoothness = "_ClearCoatSmoothness";
        }
#endregion

#region Fields
        MaterialProperty m_BaseMapProp;
        MaterialProperty m_BaseColorProp;
        MaterialProperty m_MetallicProp;
        MaterialProperty m_SpecColorProp;
        MaterialProperty m_MetallicGlossMapProp;
        MaterialProperty m_SpecGlossMapProp;
        MaterialProperty m_SmoothnessProp;
        MaterialProperty m_BumpMapProp;
        MaterialProperty m_BumpScaleProp;
        MaterialProperty m_OcclusionMapProp;
        MaterialProperty m_OcclusionStrengthProp;
        MaterialProperty m_EmissionMapProp;
        MaterialProperty m_EmissionColorProp;
        MaterialProperty m_EnableClearCoatProp;
        MaterialProperty m_ClearCoatMapProp;
        MaterialProperty m_ClearCoatProp;
        MaterialProperty m_ClearCoatSmoothnessProp;
#endregion

#region GUI
        public override void GetProperties(MaterialProperty[] properties)
        {
            // Find properties
            m_BaseMapProp = FindProperty(PropertyNames.BaseMap, properties, false);
            m_BaseColorProp = FindProperty(PropertyNames.BaseColor, properties, false);
            m_MetallicProp = FindProperty(PropertyNames.Metallic, properties);
            m_SpecColorProp = FindProperty(PropertyNames.SpecColor, properties, false);
            m_MetallicGlossMapProp = FindProperty(PropertyNames.MetallicGlossMap, properties);
            m_SpecGlossMapProp = FindProperty(PropertyNames.SpecGlossMap, properties, false);
            m_SmoothnessProp = FindProperty(PropertyNames.Smoothness, properties, false);
            m_BumpMapProp = FindProperty(PropertyNames.BumpMap, properties, false);
            m_BumpScaleProp = FindProperty(PropertyNames.BumpScale, properties, false);
            m_OcclusionMapProp = FindProperty(PropertyNames.OcclusionMap, properties, false);
            m_OcclusionStrengthProp = FindProperty(PropertyNames.OcclusionStrength, properties, false);
            m_EmissionMapProp = FindProperty(PropertyNames.EmissionMap, properties, false);
            m_EmissionColorProp = FindProperty(PropertyNames.EmissionColor, properties, false);
            m_EnableClearCoatProp = FindProperty(PropertyNames.EnableClearCoat, properties, false);
            m_ClearCoatMapProp = FindProperty(PropertyNames.ClearCoatMap, properties, false);
            m_ClearCoatProp = FindProperty(PropertyNames.ClearCoat, properties, false);
            m_ClearCoatSmoothnessProp = FindProperty(PropertyNames.ClearCoatSmoothness, properties, false);
        }

        public override void DrawSurfaceInputs(MaterialEditor materialEditor)
        {
            // Get Material
            var material = materialEditor.target as Material;

            // Color
            materialEditor.TexturePropertySingleLine(Labels.Color, m_BaseMapProp, m_BaseColorProp);

            // MetallicSpecular
            bool hasGlossMap = false;
            if (material.IsSpecularWorkflow())
            {
                hasGlossMap = m_SpecGlossMapProp.textureValue != null;
                materialEditor.TexturePropertySingleLine(Labels.Specular, m_SpecGlossMapProp, hasGlossMap ? null : m_SpecColorProp);
            }
            else
            {
                hasGlossMap = m_MetallicGlossMapProp.textureValue != null;
                materialEditor.TexturePropertySingleLine(Labels.Metallic, m_MetallicGlossMapProp, hasGlossMap ? null : m_MetallicProp);
            }

            // Smoothness
            EditorGUI.BeginChangeCheck();
            EditorGUI.indentLevel += 2;
            var smoothness = EditorGUILayout.Slider(Labels.Smoothness, m_SmoothnessProp.floatValue, 0f, 1f);
            EditorGUI.indentLevel -= 2;
            if (EditorGUI.EndChangeCheck())
            {
                m_SmoothnessProp.floatValue = smoothness;
            }

            // Normal
            materialEditor.TexturePropertySingleLine(Labels.Normal, m_BumpMapProp, m_BumpScaleProp);

            // Occlusion
            materialEditor.TexturePropertySingleLine(Labels.Occlusion, m_OcclusionMapProp, 
                m_OcclusionMapProp.textureValue != null ? m_OcclusionStrengthProp : null);

            // Emission
            var hadEmissionTexture = m_EmissionMapProp.textureValue != null;
            materialEditor.TexturePropertyWithHDRColor(Labels.Emission, m_EmissionMapProp,
                m_EmissionColorProp, false);

            // If texture was assigned and color was black set color to white
            var brightness = m_EmissionColorProp.colorValue.maxColorComponent;
            if (m_EmissionMapProp.textureValue != null && !hadEmissionTexture && brightness <= 0f)
                m_EmissionColorProp.colorValue = Color.white;

            // Clear Coat
            materialEditor.ShaderProperty(m_EnableClearCoatProp, Labels.EnableClearCoat);
            if (m_EnableClearCoatProp.floatValue == 1.0)
            {
                materialEditor.TexturePropertySingleLine(Labels.ClearCoat, m_ClearCoatMapProp, m_ClearCoatMapProp.textureValue == null ? m_ClearCoatProp : null);
                EditorGUI.indentLevel += 2;
                materialEditor.ShaderProperty(m_ClearCoatSmoothnessProp, Labels.ClearCoatSmoothness);
                EditorGUI.indentLevel -= 2;
            }
        }
#endregion

#region Keywords
        public override void SetMaterialKeywords(Material material)
        {
            // Metallic Specular
            var isSpecularWorkFlow = (WorkflowMode) material.GetFloat("_WorkflowMode") == WorkflowMode.Specular;
            var hasGlossMap = false;
            if (isSpecularWorkFlow)
                hasGlossMap = material.GetTexture(PropertyNames.SpecGlossMap) != null;
            else
                hasGlossMap = material.GetTexture(PropertyNames.MetallicGlossMap) != null;
            material.SetKeyword("_METALLICSPECGLOSSMAP", hasGlossMap);

            // Normal
            material.SetKeyword("_NORMALMAP", material.GetTexture(PropertyNames.BumpMap) != null);

            // Emission
            bool hasEmissionMap = material.GetTexture(PropertyNames.EmissionMap) != null;
            Color emissionColor = material.GetColor(PropertyNames.EmissionColor);
            material.SetKeyword("_EMISSION", hasEmissionMap || emissionColor != Color.black);

            // Clear Coat
            material.SetKeyword("_CLEARCOAT", material.GetFloat(PropertyNames.EnableClearCoat) == 1.0f);
            material.SetKeyword("_CLEARCOATMAP", material.GetTexture(PropertyNames.ClearCoatMap) != null);
        }
#endregion
    }
}
