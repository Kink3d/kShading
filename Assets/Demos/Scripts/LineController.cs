using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace ToonShading
{
    [RequireComponent(typeof(LineRenderer))]
    public class LineController : MonoBehaviour
    {
        private LineRenderer renderer;

        public Transform[] points;

        private void Start()
        {
            renderer = GetComponent<LineRenderer>();
            renderer.positionCount = points.Length;
            StartCoroutine(EnableLine());
        }

        private void Update()
        {
            if(renderer)
            {
                for (int i = 0; i < points.Length; i++)
                    renderer.SetPosition(i, points[i].position);
            }
        }

        IEnumerator EnableLine()
        {
            yield return new WaitForEndOfFrame();
            renderer.enabled = true;
        }
    }
}
