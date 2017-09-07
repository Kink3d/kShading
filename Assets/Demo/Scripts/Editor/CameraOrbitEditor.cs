using UnityEngine;
using System.Collections;
using UnityEditor;

namespace ToonShading
{
    [CustomEditor(typeof(CameraOrbit))]
    public class CameraOrbitEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            CameraOrbit myTarget = (CameraOrbit)target; // Get target
            myTarget.orbitType = (OrbitType)EditorGUILayout.EnumPopup("Orbit Type", myTarget.orbitType); // Draw Orbit Type enum
            switch (myTarget.orbitType) // Draw different UI based on Orbit Type
            {
                case OrbitType.Manual: // Manual Orbit
                    myTarget.mouseRotationSpeed = EditorGUILayout.FloatField("Mouse Rotation Speed", myTarget.mouseRotationSpeed);
                    break;
                case OrbitType.Automatic: // Automatic Orbit
                    myTarget.constantRotationSpeed = EditorGUILayout.FloatField("Constant Rotation Speed", myTarget.constantRotationSpeed);
                    myTarget.stopRotationOnClick = EditorGUILayout.Toggle("Stop Rotation On Click", myTarget.stopRotationOnClick);
                    if(myTarget.stopRotationOnClick) // If stop rotation on click
                        myTarget.mouseRotationSpeed = EditorGUILayout.FloatField("Mouse Rotation Speed", myTarget.mouseRotationSpeed);
                    break;
            }
        }
    }
}
