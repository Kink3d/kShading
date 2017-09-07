using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace ToonShading
{
    [ExecuteInEditMode]
    [RequireComponent(typeof(Renderer))]
    public class ToonWater : MonoBehaviour
    {
        public enum VoronoiSampleType { SharedTexture, SeparateCalculation }
        public VoronoiSampleType voronoiSampleType = VoronoiSampleType.SharedTexture; // Switch voronoi sample type

        Renderer m_Renderer; // Reference to Renderer component
        private Dictionary<Camera, Camera> m_ReflectionCameras = new Dictionary<Camera, Camera>(); // Camera -> Camera table
        public RenderTexture m_ReflectionTexture; // Planar reflection texture
        private int m_OldReflectionTextureSize; // Track previous reflection texture size
        private Texture2D m_NoiseTexture; // Simple noise texture
        private RenderTexture m_VoronoiTex; // Voronoi noise texture
        private Material m_VoronoiMaterial; // Voronoi material

        Matrix4x4 m_Matrix;

        // Waves
        [Range(0f, 1f)] public float waveHeight = 0.5f;
        [Range(0f, 1f)] public float waveScale = 0.5f;
        [Range(0f, 1f)] public float waveCrest = 0.5f;

        // Planar Reflection
        public bool enableReflection = true;
        public LayerMask reflectLayers = -1;
        public int textureSize = 256;
        public float clipPlaneOffset = 0.07f;
        
        // Enable
        private void OnEnable()
        {
            if (Camera.main.depthTextureMode == DepthTextureMode.None) // If depth texture disabled
                Camera.main.depthTextureMode = DepthTextureMode.Depth; // Set depth mode
            m_Renderer = GetComponent<Renderer>(); // Get reference to Renderer component
        }

        // Disable
        void OnDisable()
        {
            // Reflection texture and cameras
            if (m_ReflectionTexture) // If reflection texture exists
            {
                DestroyImmediate(m_ReflectionTexture); // Destroy it
                m_ReflectionTexture = null; // Null it
            }
            foreach (var kvp in m_ReflectionCameras) // Iterate reflection cameras
                DestroyImmediate((kvp.Value).gameObject); // Destroy
            m_ReflectionCameras.Clear(); // Clear

            // Voronoi noise
            if(m_VoronoiMaterial) // If voronoi material exists
                m_VoronoiMaterial = null; // Null it
            if (m_VoronoiTex) // If voronoi texture exists
            {
                DestroyImmediate(m_VoronoiTex); // Destroy it
                m_VoronoiTex = null; // Null it
            }               

            // Simple noise
            if (m_NoiseTexture) // If noise texture exists
                m_NoiseTexture = null; // Null it (Dont destroy because asset)
        }

        // On object render
        public void OnWillRenderObject()
        {
            if (!enabled || !m_Renderer || !m_Renderer.sharedMaterial || !m_Renderer.enabled) // If rendering disabled
                return; // Return

            Camera cam = Camera.current; // Get current camera
            if (!cam) // If camera is null
                return; // Return

            m_Matrix = Camera.main.cameraToWorldMatrix; // Get camera world matrix
            m_Renderer.sharedMaterial.SetMatrix("_InverseView", m_Matrix); // Set to material

            // Voronoi noise
            if (voronoiSampleType == VoronoiSampleType.SharedTexture) // If using shared voronoi texture
            {
                if (!m_VoronoiMaterial) // If material not set
                    m_VoronoiMaterial = new Material(Shader.Find("Hidden/Voronoi")); // Create new material
                if (!m_VoronoiTex) // If texture not set
                    m_VoronoiTex = new RenderTexture(512, 512, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB); // Create new Voronoi texture
            }
            else
            {
                if (m_VoronoiMaterial) // If voronoi material exists
                    m_VoronoiMaterial = null; // Null it
                if (m_VoronoiTex) // If voronoi texture exists
                {
                    DestroyImmediate(m_VoronoiTex); // Destroy it
                    m_VoronoiTex = null; // Null iy
                }
            }

            // Simple noise
            if (!m_NoiseTexture) // If noise texture isnt loaded
                m_NoiseTexture = (Texture2D)Resources.Load("SimpleNoise"); // Load from resources

            // Planar Reflection
            if (enableReflection) // If enabled
            {
                Camera reflectionCamera; // Create camera reference
                CreateObjects(cam, out reflectionCamera);  // Create objects

                Vector3 pos = transform.position; // Get position
                Vector3 normal = transform.up; // Get normal

                UpdateCameraModes(cam, reflectionCamera); // Update camera modes

                // Reflect camera around reflection plane
                float d = -Vector3.Dot(normal, pos) - clipPlaneOffset; // Get dot product
                Vector4 reflectionPlane = new Vector4(normal.x, normal.y, normal.z, d); // Create new reflection plane

                Matrix4x4 reflection = Matrix4x4.zero; // Create reflection matrix
                CalculateReflectionMatrix(ref reflection, reflectionPlane); // Calculate reflection matrix
                Vector3 oldpos = cam.transform.position; // Get position
                Vector3 newpos = reflection.MultiplyPoint(oldpos); // Multiply point by matrix
                reflectionCamera.worldToCameraMatrix = cam.worldToCameraMatrix * reflection; // Set reflected world matrix

                // Setup oblique projection matrix so that near plane is our reflection
                // plane. This way we clip everything below/above it for free.
                Vector4 clipPlane = CameraSpacePlane(reflectionCamera, pos, normal, 1.0f); // Calculate clip plane
                reflectionCamera.projectionMatrix = cam.CalculateObliqueMatrix(clipPlane); // Calculate oblique matrix
                
                reflectionCamera.cullingMatrix = cam.projectionMatrix * cam.worldToCameraMatrix; // Set custom culling matrix from the current camera

                reflectionCamera.cullingMask = ~(1 << 4) & reflectLayers.value; // never render water layer
                reflectionCamera.targetTexture = m_ReflectionTexture; // Set target texture
                bool oldCulling = GL.invertCulling; // Get invert cull
                GL.invertCulling = !oldCulling; // Reverse
                reflectionCamera.transform.position = newpos; // Set reflection camera position
                Vector3 euler = cam.transform.eulerAngles; // Get euler from current camera
                reflectionCamera.transform.eulerAngles = new Vector3(-euler.x, euler.y, euler.z);  // Set inverse X to reflection camera
                reflectionCamera.Render(); // Render the reflection camera
                reflectionCamera.transform.position = oldpos; // Reset position
                GL.invertCulling = oldCulling; // Reset culling
                if (m_ReflectionTexture)
                    m_Renderer.sharedMaterial.SetTexture("_ReflectionTex", m_ReflectionTexture); // Set reflection texture
                m_Renderer.sharedMaterial.SetFloat("_PlanarReflections", 1); // Enable reflections
            }
            else
            {
                if (m_ReflectionTexture) // If reflection texture exists
                {
                    DestroyImmediate(m_ReflectionTexture); // Destroy it
                }
                m_Renderer.sharedMaterial.SetFloat("_PlanarReflections", 0); // Disable reflections
            }

            // Voronoi noise
            if (voronoiSampleType == VoronoiSampleType.SharedTexture && m_VoronoiTex && m_VoronoiMaterial) // If shared voronoi and objects exist
            {
                m_Renderer.sharedMaterial.SetFloat("_SeparateVoronoi", 0); // Set shared voronoi on material
                Graphics.Blit(m_VoronoiTex, m_VoronoiTex, m_VoronoiMaterial); // Create voronoi
                m_Renderer.sharedMaterial.SetTexture("_VoronoiTex", m_VoronoiTex); // Set to material
                m_VoronoiMaterial.SetFloat("_WaveScale", waveScale);
                m_VoronoiMaterial.SetFloat("_WaveHeight", waveHeight);
            }
            else
                m_Renderer.sharedMaterial.SetFloat("_SeparateVoronoi", 1); // Set separate voronoi on material

            // Set wave properties on material
            m_Renderer.sharedMaterial.SetFloat("_WaveHeight", waveHeight);
            m_Renderer.sharedMaterial.SetFloat("_WaveScale", waveScale);
            m_Renderer.sharedMaterial.SetFloat("_WaveCrest", waveCrest);

            // Simple noise
            if (m_NoiseTexture) // If loaded
                m_Renderer.sharedMaterial.SetTexture("_NoiseTex", m_NoiseTexture); // Set to material
        }
        
        // Given position/normal of the plane, calculates plane in camera space.
        Vector4 CameraSpacePlane(Camera cam, Vector3 pos, Vector3 normal, float sideSign)
        {
            Vector3 offsetPos = pos + normal * clipPlaneOffset; // Calculate offset
            Matrix4x4 m = cam.worldToCameraMatrix;
            Vector3 cpos = m.MultiplyPoint(offsetPos); // Get offset position
            Vector3 cnormal = m.MultiplyVector(normal).normalized * sideSign; // Normal
            return new Vector4(cnormal.x, cnormal.y, cnormal.z, -Vector3.Dot(cpos, cnormal)); // Return plane
        }

        // Calculates reflection matrix around the given plane
        static void CalculateReflectionMatrix(ref Matrix4x4 reflectionMatrix, Vector4 plane)
        {
            reflectionMatrix.m00 = (1F - 2F * plane[0] * plane[0]);
            reflectionMatrix.m01 = (-2F * plane[0] * plane[1]);
            reflectionMatrix.m02 = (-2F * plane[0] * plane[2]);
            reflectionMatrix.m03 = (-2F * plane[3] * plane[0]);

            reflectionMatrix.m10 = (-2F * plane[1] * plane[0]);
            reflectionMatrix.m11 = (1F - 2F * plane[1] * plane[1]);
            reflectionMatrix.m12 = (-2F * plane[1] * plane[2]);
            reflectionMatrix.m13 = (-2F * plane[3] * plane[1]);

            reflectionMatrix.m20 = (-2F * plane[2] * plane[0]);
            reflectionMatrix.m21 = (-2F * plane[2] * plane[1]);
            reflectionMatrix.m22 = (1F - 2F * plane[2] * plane[2]);
            reflectionMatrix.m23 = (-2F * plane[3] * plane[2]);

            reflectionMatrix.m30 = 0F;
            reflectionMatrix.m31 = 0F;
            reflectionMatrix.m32 = 0F;
            reflectionMatrix.m33 = 1F;
        }

        // On-demand create any objects we need for water
        void CreateObjects(Camera currentCamera, out Camera reflectionCamera)
        {
            reflectionCamera = null; // Create out

            // Reflection texture
            if (!m_ReflectionTexture || m_OldReflectionTextureSize != textureSize) // If reflection camera requires update
            {
                if (m_ReflectionTexture) // If reflection texture exists
                {
                    DestroyImmediate(m_ReflectionTexture); // Destroy it
                }
                m_ReflectionTexture = new RenderTexture(textureSize, textureSize, 16, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear); // Create new RenderTexture
                m_ReflectionTexture.name = "__WaterReflection" + GetInstanceID(); // Name texture
                m_ReflectionTexture.isPowerOfTwo = true; // Set POT
                m_ReflectionTexture.hideFlags = HideFlags.DontSave; // Set flags
                m_OldReflectionTextureSize = textureSize; // Track size
            }


            // Camera for reflection
            m_ReflectionCameras.TryGetValue(currentCamera, out reflectionCamera); // Try to get camera from dictionary
            if (!reflectionCamera) // catch both not-in-dictionary and in-dictionary-but-deleted-GO
            {
                GameObject go = new GameObject("Water Refl Camera id" + GetInstanceID() + " for " + currentCamera.GetInstanceID(), typeof(Camera), typeof(Skybox)); // Create reflection camera
                reflectionCamera = go.GetComponent<Camera>(); // Get reference to Camera component
                reflectionCamera.enabled = false; // Disable
                reflectionCamera.transform.position = transform.position; // Set position
                reflectionCamera.transform.rotation = transform.rotation; // Set rotation
                reflectionCamera.gameObject.AddComponent<FlareLayer>(); // Add component FlareLayer
                go.hideFlags = HideFlags.HideAndDontSave;  // Set flags
                m_ReflectionCameras[currentCamera] = reflectionCamera; // Set to dictionary
            }
        }

        // Update reflection camera modes to match main camera
        void UpdateCameraModes(Camera currentCamera, Camera reflectionCamera)
        {
            if (reflectionCamera == null) // If reflection camera is null
                return; // Return

            // set water camera to clear the same way as current camera
            reflectionCamera.clearFlags = currentCamera.clearFlags; // Match clear flags
            reflectionCamera.backgroundColor = currentCamera.backgroundColor; // Match background
            if (currentCamera.clearFlags == CameraClearFlags.Skybox) // If skybox
            {
                Skybox sky = currentCamera.GetComponent<Skybox>(); // Get main camera Skybox component
                Skybox mysky = reflectionCamera.GetComponent<Skybox>(); // Get reflection camera Skybox component
                if (!sky || !sky.material) // If main camera skybox isnt set
                    mysky.enabled = false; // Disable reflection camera sky
                else
                {
                    mysky.enabled = true; // Enable reflection camera sky
                    mysky.material = sky.material; // Set material
                }
            }
            reflectionCamera.farClipPlane = currentCamera.farClipPlane; // Match far clip
            reflectionCamera.nearClipPlane = currentCamera.nearClipPlane; // Match near clip
            reflectionCamera.orthographic = currentCamera.orthographic; // Match orthographic
            reflectionCamera.fieldOfView = currentCamera.fieldOfView; // Match FOV
            reflectionCamera.aspect = currentCamera.aspect; // Match aspect
            reflectionCamera.orthographicSize = currentCamera.orthographicSize; // Match orthographic size
        }

        // Request a bouyancy value from a given target object
        public float GetBouyancy(Vector3 targetPosition)
        {
            if (enabled)
            {
                Vector3 boundsCenter = m_Renderer.bounds.center; // Get bounds center
                Vector3 boundsSize = m_Renderer.bounds.size; // Get bounds size
                Vector2 boundsUV = new Vector2(boundsCenter.x, boundsCenter.y) - (new Vector2(boundsSize.x, boundsSize.y) / 2); // Convert bounds to UV space
                Vector2 positionInBounds = new Vector2((targetPosition.x - boundsUV.x) / boundsSize.x, (targetPosition.x - boundsUV.x) / boundsSize.x); // Get the targets position in the bounds
                float bouyancyValue = 0; // Define output
                switch (voronoiSampleType) // Switch based on voronoi sample type
                {
                    case VoronoiSampleType.SharedTexture: // Share one texture between C# and HLSL
                        if (m_VoronoiTex) // Check voronoi texture has been created
                        {
                            RenderTexture.active = m_VoronoiTex; // Set voronoi texture as active RenderTexture
                            Texture2D tex = new Texture2D(512, 512); // Create new Texture2D at same scale as RenderTexture
                            tex.ReadPixels(new Rect(0, 0, 512, 512), 0, 0); // Read pixels from voronoi texture
                            Color pixelColor = tex.GetPixel((int)(512 * positionInBounds.x), (int)(512 * positionInBounds.y)); // Sample pixel color at target position
                            RenderTexture.active = null; // Reset active RenderTexture
                            DestroyImmediate(tex); // Destroy the Texture2D
                            bouyancyValue = pixelColor.r; // Set bouyancy value
                        }
                        break;
                    case VoronoiSampleType.SeparateCalculation: // Calculate separately in C# and HLSL
                        bouyancyValue = Voronoi.VoronoiNoise(new Vector2((positionInBounds.x), (positionInBounds.y)), waveScale); // Sample voronoi in C#
                        break;
                }
                return bouyancyValue * waveHeight; // Return sampled value multiplied by wave height
            }
            else
                return 0;
        }
    }
}
