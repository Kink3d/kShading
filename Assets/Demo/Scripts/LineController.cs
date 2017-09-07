using System.Collections;
using UnityEngine;

namespace ToonShading
{
    [RequireComponent(typeof(LineRenderer))]
    public class LineController : MonoBehaviour
    {
        private LineRenderer line; // Reference to LineRenderer component
        public Transform[] points; // Array of points for the LineRenderer

        private void Start()
        {
            line = GetComponent<LineRenderer>(); // Get the LineRenderer
            line.positionCount = points.Length; // Set position count
            StartCoroutine(EnableLine()); // Enable the LineRenderer
        }

        private void Update()
        {
            if(line) // If LineRenderer exits
            {
                for (int i = 0; i < points.Length; i++) // Iterate points
                    line.SetPosition(i, points[i].position); // Set positions to points array
            }
        }

        // Have to enable LineRenderer manually to avoid "teleporting"
        IEnumerator EnableLine()
        {
            yield return new WaitForEndOfFrame(); // Wait one frame
            line.enabled = true; // Enable LineRenderer
        }
    }
}
