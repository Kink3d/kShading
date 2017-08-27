using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace ToonShading
{
    public class CameraOrbit : MonoBehaviour
    {
        public float orbitSpeed = 1f;

        Vector2 mouseStartPos;

        private void Update()
        {
            if(Input.GetButtonDown("Fire1"))
            {
                mouseStartPos = Input.mousePosition + new Vector3(Screen.width * 0.5f, Screen.height * 0.5f, 0);
            }
        }

        private void LateUpdate()
        {
            if(Input.GetButton("Fire1"))
            {
                Vector3 mousePos = Input.mousePosition + new Vector3(Screen.width * 0.5f, Screen.height * 0.5f, 0);
                float rotation = ((mousePos.x - mouseStartPos.x) / Screen.width) * orbitSpeed;
                Vector3 euler = new Vector3(transform.eulerAngles.x , transform.eulerAngles.y + rotation, transform.eulerAngles.z);
                transform.eulerAngles = euler;
            }
        }
    }
}
