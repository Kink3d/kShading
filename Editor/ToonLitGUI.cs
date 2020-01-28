using UnityEngine;
using UnityEditor;

namespace kTools.Shading.Editor
{
    sealed class ToonLitGUI : BaseGUI
    {
#region Structs
        struct Labels
        {
            // Foldouts
            public static readonly GUIContent StylizationOptions = new GUIContent("Stylization Options");

            // Properties
            public static readonly GUIContent EnableToonReflections = new GUIContent("Toon Reflections",
                "Enable toon shading posterization for environment reflections");

            public static readonly GUIContent Steps = new GUIContent("Steps",
                "Specifies the amount of steps for posterization");
        }

        struct PropertyNames
        {
            public static readonly string EnableToonReflections = "_EnableToonReflections";
            public static readonly string ReflectionSteps = "_ReflectionSteps";
        }
#endregion

#region Fields
        const string kEditorPrefKey = "kShading:ToonLitGUI:";
        LitGUI m_LitGui;

        // Foldouts
        bool m_StylizationOptionsFoldout;

        // Properties
        MaterialProperty m_EnableToonReflectionsProp;
        MaterialProperty m_ReflectionStepsProp;
#endregion

#region GUI
        public override void GetProperties(MaterialProperty[] properties)
        {
            // Generate a LitGUI instance
            // This is sealed but shares most properties
            m_LitGui = new LitGUI();
            m_LitGui.GetProperties(properties);

            // Get foldouts from EditorPrefs
            m_StylizationOptionsFoldout = GetFoldoutState("StylizationOptions");

            // Find properties
            m_EnableToonReflectionsProp = FindProperty(PropertyNames.EnableToonReflections, properties, false);
            m_ReflectionStepsProp = FindProperty(PropertyNames.ReflectionSteps, properties, false);
        }

        public override void DrawSurfaceInputs(MaterialEditor materialEditor)
        {
            // Draw LitGUI SurfaceInputs
            // These are the same
            m_LitGui.DrawSurfaceInputs(materialEditor);
        }

        public override void DrawCustom(MaterialEditor materialEditor)
        {
            // Stylization Options
            var stylizationOptions = EditorGUILayout.BeginFoldoutHeaderGroup(m_StylizationOptionsFoldout, Labels.StylizationOptions);
            if(stylizationOptions)
            {
                // Toon Reflections
                materialEditor.ShaderProperty(m_EnableToonReflectionsProp, Labels.EnableToonReflections);
                if (m_EnableToonReflectionsProp.floatValue == 1.0)
                {
                    EditorGUI.BeginChangeCheck();
                    EditorGUI.indentLevel++;
                    var reflectionSteps = EditorGUILayout.IntSlider(Labels.Steps, (int)m_ReflectionStepsProp.floatValue, 2, 128);
                    EditorGUI.indentLevel--;
                    if(EditorGUI.EndChangeCheck())
                    {
                        m_ReflectionStepsProp.floatValue = reflectionSteps;
                    }
                }
            }
            SetFoldoutState("StylizationOptions", m_StylizationOptionsFoldout, stylizationOptions);
            EditorGUILayout.EndFoldoutHeaderGroup();
        }
#endregion

#region Keywords
        public override void SetMaterialKeywords(Material material)
        {
            // Set LitGUI keywords
            // These are mostly the same
            m_LitGui.SetMaterialKeywords(material);

            // Toon Reflections
            material.SetKeyword("_TOON_REFLECTIONS", material.GetFloat(PropertyNames.EnableToonReflections) == 1.0f);
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
}
