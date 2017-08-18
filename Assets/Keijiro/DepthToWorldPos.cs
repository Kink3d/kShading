using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class DepthToWorldPos : MonoBehaviour
{
    [Range(0, 1)] public float _intensity = 0.5f;

    [SerializeField] Shader _shader;

    Material _material;

    void Update()
    {
        GetComponent<Camera>().depthTextureMode = DepthTextureMode.Depth;
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (_material == null) {
            _material = new Material(_shader);
            _material.hideFlags = HideFlags.DontSave;
        }

        var matrix = GetComponent<Camera>().cameraToWorldMatrix;
        _material.SetMatrix("_InverseView", matrix);
        _material.SetFloat("_Intensity", _intensity);

        Graphics.Blit(source, destination, _material);
    }
}
