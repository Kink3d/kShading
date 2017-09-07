using UnityEditor;
using UnityEngine;
using System.Collections.Generic;

namespace ToonShading
{
    [CustomEditor(typeof(ToonWater))]
    public class ToonWaterEditor : Editor
    {
        SerializedProperty m_WaveHeight;

        public override void OnInspectorGUI()
        {
            ToonWater myTarget = (ToonWater)target; // Get target

            EditorGUILayout.LabelField("Mode", EditorStyles.boldLabel);
            myTarget.voronoiSampleType = (ToonWater.VoronoiSampleType)EditorGUILayout.EnumPopup("Voronoi Sample Type", myTarget.voronoiSampleType); // Draw Orbit Type enum

            EditorGUILayout.Space();
            EditorGUILayout.LabelField("Waves", EditorStyles.boldLabel);
            myTarget.waveHeight = EditorGUILayout.Slider("Wave Height", myTarget.waveHeight, 0, 1);
            myTarget.waveScale = EditorGUILayout.Slider("Wave Scale", myTarget.waveScale, 0, 1);
            myTarget.waveCrest = EditorGUILayout.Slider("Wave Crest", myTarget.waveCrest, 0, 1);

            EditorGUILayout.Space();
            EditorGUILayout.LabelField("Reflection", EditorStyles.boldLabel);
            myTarget.enableReflection = EditorGUILayout.Toggle("Enable Reflection", myTarget.enableReflection);
            if (myTarget.enableReflection)
            {
                EditorGUI.indentLevel++;
                myTarget.reflectLayers = LayerMaskField("Reflect Layers", myTarget.reflectLayers);
                myTarget.textureSize = EditorGUILayout.IntSlider("Texture Size", myTarget.textureSize, 16, 1024);
                myTarget.clipPlaneOffset = EditorGUILayout.Slider("Clip Plane Offset", myTarget.clipPlaneOffset, 0f, 1f);
                EditorGUI.indentLevel--;
            }
        }

        LayerMask LayerMaskField(string label, LayerMask layerMask)
        {
            List<string> layers = new List<string>();
            List<int> layerNumbers = new List<int>();

            for (int i = 0; i < 32; i++)
            {
                string layerName = LayerMask.LayerToName(i);
                if (layerName != "")
                {
                    layers.Add(layerName);
                    layerNumbers.Add(i);
                }
            }
            int maskWithoutEmpty = 0;
            for (int i = 0; i < layerNumbers.Count; i++)
            {
                if (((1 << layerNumbers[i]) & layerMask.value) > 0)
                    maskWithoutEmpty |= (1 << i);
            }
            maskWithoutEmpty = EditorGUILayout.MaskField(label, maskWithoutEmpty, layers.ToArray());
            int mask = 0;
            for (int i = 0; i < layerNumbers.Count; i++)
            {
                if ((maskWithoutEmpty & (1 << i)) > 0)
                    mask |= (1 << layerNumbers[i]);
            }
            layerMask.value = mask;
            return layerMask;
        }
    }
}