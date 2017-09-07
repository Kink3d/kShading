using UnityEngine;

namespace ToonShading
{
    public enum OrbitType { Manual, Automatic }

    public class CameraOrbit : MonoBehaviour
    {
        public OrbitType orbitType = OrbitType.Automatic; // Orbit type
        public float mouseRotationSpeed = 1f; // Rotation speed when controlling with mouse
        public float constantRotationSpeed = 0.2f; // Rotation speed for automatic rotation
        public bool stopRotationOnClick = true; // Start manual rotation on click?

        Vector2 mouseStartPos; // Track initial mouse position on click

        private void Update()
        {
            if(Input.GetButtonDown("Fire1")) // If click
            {
                mouseStartPos = Input.mousePosition + new Vector3(Screen.width * 0.5f, Screen.height * 0.5f, 0); // Get mouse position in relation to center
                if (stopRotationOnClick) // If manual rotation on click
                    orbitType = OrbitType.Manual; // Start manual rotation
            }
        }

        private void LateUpdate()
        {
            if(orbitType == OrbitType.Automatic) // If automatic rotation
            {
                Vector3 euler = new Vector3(transform.eulerAngles.x, transform.eulerAngles.y + constantRotationSpeed, transform.eulerAngles.z); // Get euler rotation with constant rotation
                transform.eulerAngles = euler; // Apply roation
            }
            else // If manual rotation
            {
                if (Input.GetButton("Fire1")) // If mouse held
                {
                    Vector3 mousePos = Input.mousePosition + new Vector3(Screen.width * 0.5f, Screen.height * 0.5f, 0); // Get current mouse position
                    float rotation = ((mousePos.x - mouseStartPos.x) / Screen.width) * mouseRotationSpeed; // Get rotation speed based on current position compared to initial position
                    Vector3 euler = new Vector3(transform.eulerAngles.x, transform.eulerAngles.y + rotation, transform.eulerAngles.z); // Get euler rotation with manual rotation
                    transform.eulerAngles = euler; // Apply roation
                }
            }
        }
    }
}
