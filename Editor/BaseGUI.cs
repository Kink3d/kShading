using System;
using UnityEngine;
using UnityEditor;

namespace kTools.Shading.Editor
{
    /// <summary>
    /// Base ShaderGUI class for shaders.
    /// </summary>
    public abstract class BaseGUI : ShaderGUI
    {
#region Structs
        struct Styles
        {
            // Foldouts
            public static readonly GUIContent SurfaceOptions = new GUIContent("Surface Options");
            public static readonly GUIContent SurfaceInputs = new GUIContent("Surface Inputs");
            public static readonly GUIContent AdvancedOptions = new GUIContent("Advanced Options");

            // Properies
            public static readonly GUIContent WorkflowMode = new GUIContent("Workflow Mode",
                "Select a workflow that fits your textures. Choose between Metallic or Specular.");

            public static readonly GUIContent SurfaceType = new GUIContent("Surface Type",
                "Select a surface type for your texture. Choose between Opaque or Transparent.");
            
            public static readonly GUIContent BlendingMode = new GUIContent("Blending Mode",
                "Controls how the color of the Transparent surface blends with the Material color in the background.");

            public static readonly GUIContent RenderFace = new GUIContent("Render Face",
                "Specifies which faces to cull from your geometry. Front culls front faces. Back culls backfaces. None means that both sides are rendered.");

            public static readonly GUIContent AlphaClipping = new GUIContent("Alpha Clipping",
                "Makes your Material act like a Cutout shader. Use this to create a transparent effect with hard edges between opaque and transparent areas.");

            public static readonly GUIContent AlphaClippingThreshold = new GUIContent("Threshold",
                "Sets where the Alpha Clipping starts. The higher the value is, the brighter the  effect is when clipping starts.");

            public static readonly GUIContent ReceiveShadows = new GUIContent("Receive Shadows",
                "When enabled, other GameObjects can cast shadows onto this GameObject.");
            
            public static readonly GUIContent SpecularHighlights = new GUIContent("Specular Highlights",
                "When enabled, the Material reflects the shine from direct lighting.");

            public static readonly GUIContent EnvironmentReflections = new GUIContent("Environment Reflections",
                "When enabled, the Material samples reflections from the nearest Reflection Probes or Lighting Probe.");

            public static readonly GUIContent Priority = new GUIContent("Priority",
                "Determines the chronological rendering order for a Material. High values are rendered first.");
        }

        struct PropertyNames
        {
            public static readonly string WorkflowMode = "_WorkflowMode";
            public static readonly string SurfaceType = "_Surface";
            public static readonly string Blend = "_Blend";
            public static readonly string ZWrite = "_ZWrite";
            public static readonly string Cull = "_Cull";
            public static readonly string AlphaClip = "_AlphaClip";
            public static readonly string Cutoff = "_Cutoff";
            public static readonly string ReceiveShadows = "_ReceiveShadows";
            public static readonly string SpecularHighlights = "_SpecularHighlights";
            public static readonly string EnvironmentReflections = "_EnvironmentReflections";
            public static readonly string QueueOffset = "_QueueOffset";
        }
#endregion

#region Enumerations
        /// <summary>
        /// Blend mode enumeration for shaders.
        /// </summary>
        public enum BlendMode
        {
            Alpha,
            Premultiply,
            Additive,
            Multiply,
        }

        /// <summary>
        /// Surface Type enumeration for shaders.
        /// </summary>
        public enum SurfaceType
        {
            Opaque,
            Transparent
        }

        /// <summary>
        /// Workflow mode (specular/metallic) enumeration for shaders.
        /// </summary>
        public enum WorkflowMode
        {
            Specular,
            Metallic,
        }

        /// <summary>
        /// Culling enumeration for shaders.
        /// </summary>
        public enum RenderFace
        {
            Front = 2,
            Back = 1,
            Both = 0
        }
#endregion

#region Fields
        const string kEditorPrefKey = "kShading:BaseGUI:";
        const int kQueueOffsetRange = 50;

        // Foldouts
        bool m_SurfaceOptionsFoldout;
        bool m_SurfaceInputsFoldout;
        bool m_AdvancedOptionsFoldout;

        // Properties
        MaterialProperty m_WorkflowModeProp;
        MaterialProperty m_SurfaceTypeProp;
        MaterialProperty m_BlendProp;
        MaterialProperty m_CullProp;
        MaterialProperty m_AlphaClipProp;
        MaterialProperty m_CutoffProp;
        MaterialProperty m_ReceiveShadowsProp;
        MaterialProperty m_SpecularHighlightsProp;
        MaterialProperty m_EnvironmentReflectionsProp;
        MaterialProperty m_QueueOffsetProp;
#endregion

#region GUI
        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
        {
            // Get foldouts from EditorPrefs
            m_SurfaceOptionsFoldout = GetFoldoutState("SurfaceOptions");
            m_SurfaceInputsFoldout = GetFoldoutState("SurfaceInputs");
            m_AdvancedOptionsFoldout =  GetFoldoutState("AdvancedOptions");

            // Base properties
            m_WorkflowModeProp = FindProperty(PropertyNames.WorkflowMode, properties, false);
            m_SurfaceTypeProp = FindProperty(PropertyNames.SurfaceType, properties, false);
            m_BlendProp = FindProperty(PropertyNames.Blend, properties, false);
            m_CullProp = FindProperty(PropertyNames.Cull, properties, false);
            m_AlphaClipProp = FindProperty(PropertyNames.AlphaClip, properties, false);
            m_CutoffProp = FindProperty(PropertyNames.Cutoff, properties, false);
            m_ReceiveShadowsProp = FindProperty(PropertyNames.ReceiveShadows, properties, false);
            m_SpecularHighlightsProp = FindProperty(PropertyNames.SpecularHighlights, properties, false);
            m_EnvironmentReflectionsProp = FindProperty(PropertyNames.EnvironmentReflections, properties, false);
            m_QueueOffsetProp = FindProperty(PropertyNames.QueueOffset, properties, false);

            // Leaf properties
            GetProperties(properties);

            // Draw properties
            EditorGUI.BeginChangeCheck();
            DrawProperties(materialEditor);
            if (EditorGUI.EndChangeCheck())
            {
                SetBaseMaterialKeywords(materialEditor.target as Material);
            }
        }
#endregion

#region Properties
        /// <summary>
        /// Get MaterialProperty fields during OnGUI call.
        /// </summary>
        /// <param name="properties">MaterialProperty array to access.</param>  
        public abstract void GetProperties(MaterialProperty[] properties);

        /// <summary>
        /// Draw MaterialProperty fields within the `Surface Inputs` foldout.
        /// </summary>
        /// <param name="materialEditor">MaterialEditor currently drawing.</param>  
        public abstract void DrawSurfaceInputs(MaterialEditor materialEditor);

        void DrawProperties(MaterialEditor materialEditor)
        {
            // Surface Options
            var surfaceOptions = EditorGUILayout.BeginFoldoutHeaderGroup(m_SurfaceOptionsFoldout, Styles.SurfaceOptions);
            if(surfaceOptions)
            {
                DrawSurfaceProperies(materialEditor);
                EditorGUILayout.Space();
            }
            SetFoldoutState("SurfaceOptions", m_SurfaceOptionsFoldout, surfaceOptions);
            EditorGUILayout.EndFoldoutHeaderGroup();

            // Surface Inputs
            var surfaceInputs = EditorGUILayout.BeginFoldoutHeaderGroup(m_SurfaceInputsFoldout, Styles.SurfaceInputs);
            if(surfaceInputs)
            {
                DrawSurfaceInputs(materialEditor);
                EditorGUILayout.Space();
            }
            SetFoldoutState("SurfaceInputs", m_SurfaceInputsFoldout, surfaceInputs);
            EditorGUILayout.EndFoldoutHeaderGroup();

            // Advanced Options
            var advancedOptions = EditorGUILayout.BeginFoldoutHeaderGroup(m_AdvancedOptionsFoldout, Styles.AdvancedOptions);
            if(advancedOptions)
            {
                DrawAdvancedOptions(materialEditor);
                EditorGUILayout.Space();
            }
            SetFoldoutState("AdvancedOptions", m_AdvancedOptionsFoldout, advancedOptions);
            EditorGUILayout.EndFoldoutHeaderGroup();
        }

        void DrawSurfaceProperies(MaterialEditor materialEditor)
        {
            // Get Material
            var material = materialEditor.target as Material;

            // Workflow Mode
            if(material.HasProperty(PropertyNames.WorkflowMode))
            {
                EditorGUI.BeginChangeCheck();
                var workflowMode = EditorGUILayout.Popup(Styles.WorkflowMode, (int)m_WorkflowModeProp.floatValue, Enum.GetNames(typeof(WorkflowMode)));
                if (EditorGUI.EndChangeCheck())
                {
                    materialEditor.RegisterPropertyChangeUndo(Styles.WorkflowMode.text);
                    m_WorkflowModeProp.floatValue = workflowMode;
                }
            }

            // SurfaceType
            SurfaceType surfaceType = SurfaceType.Opaque;
            if(material.HasProperty(PropertyNames.SurfaceType))
            {
                EditorGUI.BeginChangeCheck();
                surfaceType = (SurfaceType)EditorGUILayout.Popup(Styles.SurfaceType, (int)m_SurfaceTypeProp.floatValue, Enum.GetNames(typeof(SurfaceType)));
                if (EditorGUI.EndChangeCheck())
                {
                    materialEditor.RegisterPropertyChangeUndo(Styles.SurfaceType.text);
                    m_SurfaceTypeProp.floatValue = (int)surfaceType;
                }
            }

            // Blend Mode
            if(material.HasProperty(PropertyNames.Blend))
            {
                if(surfaceType == SurfaceType.Transparent)
                {
                    EditorGUI.BeginChangeCheck();
                    var blend = EditorGUILayout.Popup(Styles.BlendingMode, (int)m_BlendProp.floatValue, Enum.GetNames(typeof(BlendMode)));
                    if (EditorGUI.EndChangeCheck())
                    {
                        materialEditor.RegisterPropertyChangeUndo(Styles.BlendingMode.text);
                        m_BlendProp.floatValue = blend;
                    }
                }
            }

            // Render Face
            if(material.HasProperty(PropertyNames.Cull))
            {
                EditorGUI.BeginChangeCheck();
                var renderFace = EditorGUILayout.Popup(Styles.RenderFace, (int)m_CullProp.floatValue, Enum.GetNames(typeof(RenderFace)));
                if (EditorGUI.EndChangeCheck())
                {
                    materialEditor.RegisterPropertyChangeUndo(Styles.RenderFace.text);
                    m_CullProp.floatValue = renderFace;
                }
            }

            // AlphaClip Enabled
            if(material.HasProperty(PropertyNames.AlphaClip) && material.HasProperty(PropertyNames.Cutoff))
            {
                EditorGUI.BeginChangeCheck();
                var alphaClip = EditorGUILayout.Toggle(Styles.AlphaClipping, m_AlphaClipProp.floatValue == 1);
                if (EditorGUI.EndChangeCheck())
                {
                    m_AlphaClipProp.floatValue = alphaClip ? 1 : 0;
                }

                // Alpha Clip
                if (m_AlphaClipProp.floatValue == 1)
                {
                    materialEditor.ShaderProperty(m_CutoffProp, Styles.AlphaClippingThreshold, 1);
                }
            }
        }

        void DrawAdvancedOptions(MaterialEditor materialEditor)
        {
            // Get Material
            var material = materialEditor.target as Material;

            // Receive Shadows
            if(material.HasProperty(PropertyNames.ReceiveShadows))
            {
                EditorGUI.BeginChangeCheck();
                var receiveShadows = EditorGUILayout.Toggle(Styles.ReceiveShadows, m_ReceiveShadowsProp.floatValue == 1.0f);
                if (EditorGUI.EndChangeCheck())
                {
                    materialEditor.RegisterPropertyChangeUndo(Styles.ReceiveShadows.text);
                    m_ReceiveShadowsProp.floatValue = receiveShadows ? 1.0f : 0.0f;
                }
            }

            // Highlights
            if(material.HasProperty(PropertyNames.SpecularHighlights))
            {
                materialEditor.ShaderProperty(m_SpecularHighlightsProp, Styles.SpecularHighlights);
            }

            // Reflections
            if(material.HasProperty(PropertyNames.EnvironmentReflections))
            {
                materialEditor.ShaderProperty(m_EnvironmentReflectionsProp, Styles.EnvironmentReflections);
            }
            
            // QueueOffset
            if(material.HasProperty(PropertyNames.QueueOffset))
            {
                EditorGUI.BeginChangeCheck();
                var queueOffset = EditorGUILayout.IntSlider(Styles.Priority, (int)m_QueueOffsetProp.floatValue, -kQueueOffsetRange, kQueueOffsetRange);
                if (EditorGUI.EndChangeCheck())
                {
                    m_QueueOffsetProp.floatValue = queueOffset;
                }
            }
        }
#endregion

#region Keywords
        /// <summary>
        /// Set Material keywords when changes are made during OnGUI call.
        /// </summary>
        /// <param name="material">Material target of current MaterialEditor.</param>
        public virtual void SetMaterialKeywords(Material material) {}

        void SetBaseMaterialKeywords(Material material)
        {
            // Reset
            material.shaderKeywords = null;

            // Custom Keywords
            SetMaterialKeywords(material);

            // WorkflowMode
            if(material.HasProperty(PropertyNames.WorkflowMode))
            {
                material.SetKeyword("_SPECULAR_SETUP", material.IsSpecularWorkflow());
            }

            // RenderQueue
            var queueOffset = 0;
            if(material.HasProperty("_QueueOffset"))
            {
                queueOffset = kQueueOffsetRange - (int) material.GetFloat("_QueueOffset");
            }

            // SurfaceType
            SurfaceType surfaceType = SurfaceType.Opaque;
            if(material.HasProperty(PropertyNames.SurfaceType))
            {
                surfaceType = (SurfaceType)material.GetFloat("_Surface");
            }

            // AlphaClip
            bool alphaClip = false;
            if(material.HasProperty(PropertyNames.AlphaClip))
            {
                alphaClip = material.GetFloat(PropertyNames.AlphaClip) == 1;
                material.SetKeyword("_ALPHATEST_ON", alphaClip);
            }

            // Receive Shadows
            if(material.HasProperty(PropertyNames.ReceiveShadows))
            {
                material.SetKeyword("_RECEIVE_SHADOWS_OFF", material.GetFloat(PropertyNames.ReceiveShadows) == 0.0f);
            }

            // Opaque
            if (surfaceType == SurfaceType.Opaque)
            {
                if (alphaClip)
                {
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.AlphaTest;
                    material.SetOverrideTag("RenderType", "TransparentCutout");
                }
                else
                {
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Geometry;
                    material.SetOverrideTag("RenderType", "Opaque");
                }
                material.renderQueue += queueOffset;
                material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
                material.SetInt("_ZWrite", 1);
                material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                material.SetShaderPassEnabled("ShadowCaster", true);
            }
            // Transparent
            else
            {
                // Blend Mode
                BlendMode blend = BlendMode.Alpha;
                if(material.HasProperty(PropertyNames.Blend))
                {
                    blend = (BlendMode)material.GetFloat(m_BlendProp.name);   
                }

                switch (blend)
                {
                    case BlendMode.Alpha:
                        material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                        material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                        material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                        break;
                    case BlendMode.Premultiply:
                        material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                        material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                        material.EnableKeyword("_ALPHAPREMULTIPLY_ON");
                        break;
                    case BlendMode.Additive:
                        material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                        material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.One);
                        material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                        break;
                    case BlendMode.Multiply:
                        material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.DstColor);
                        material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
                        material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                        material.EnableKeyword("_ALPHAMODULATE_ON");
                        break;
                }

                material.SetOverrideTag("RenderType", "Transparent");
                material.SetInt("_ZWrite", 0);
                var queue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
                material.renderQueue = queue + queueOffset;
                material.SetShaderPassEnabled("ShadowCaster", false);
            }
            
            // Highlights
            if(material.HasProperty(PropertyNames.SpecularHighlights))
            {
                material.SetKeyword("_SPECULARHIGHLIGHTS_OFF", material.GetFloat(m_SpecularHighlightsProp.name) == 0.0f);
            }

            // Reflections
            if(material.HasProperty(PropertyNames.EnvironmentReflections))
            {
                material.SetKeyword("_ENVIRONMENTREFLECTIONS_OFF", material.GetFloat(m_EnvironmentReflectionsProp.name) == 0.0f);
            }
        }        
#endregion

#region EditorPrefs
        bool GetFoldoutState(string name)
        {
            // Get value from EditorPrefs
            return EditorPrefs.GetBool($"{kEditorPrefKey}.{name}");
        }

        void SetFoldoutState(string name, bool field, bool value)
        {
            if(field == value)
                return;

            // Set value to EditorPrefs and field
            EditorPrefs.SetBool($"{kEditorPrefKey}.{name}", value);
            field = value;
        }
#endregion
    }

    public static class ShaderGUIExtensions
    {
#region Workflow
        /// <summary>
        /// Determine if current material is using specular `WorkflowMode`.
        /// </summary>
        /// <returns>True if specular `WorkflowMode`. Default is false.</returns>
        public static bool IsSpecularWorkflow(this Material material)
        {
            if(!material.HasProperty("_WorkflowMode"))
                return false;
            
            return (BaseGUI.WorkflowMode)material.GetFloat("_WorkflowMode") == BaseGUI.WorkflowMode.Specular;
        }
#endregion

#region Keywords
        /// <summary>
        /// Sets `keyword` on current Material to `value`.
        /// </summary>
        /// <param name="keyword">Keyword string to set.</param>
        /// <param name="value">Value to set keyword.</param>
        public static void SetKeyword(this Material material, string keyword, bool value)
        {
            if (value)
            {
                material.EnableKeyword(keyword);
            }
            else
            {
                material.DisableKeyword(keyword);
            }
        }
#endregion
    }
}
