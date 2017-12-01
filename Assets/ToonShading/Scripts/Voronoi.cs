using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace ToonShading
{
    public static class Voronoi
    {
        // HLSL Frac
        static float Frac(float value)
        {
            return value - Mathf.Floor(value);
        }

        // Get random Vector2
        static Vector2 random2(Vector2 p)
        {
            Vector2 x = new Vector2(Vector2.Dot(p, new Vector2(127.1f, 311.7f)), Vector2.Dot(p, new Vector2(269.5f, 183.3f)));
            return new Vector2(Frac(Mathf.Sin(x.x) * 43758.5453f), Frac(Mathf.Sin(x.y) * 43758.5453f));
        }

        // Calculate voronoi noise
        static public float VoronoiNoise(Vector2 uv, float scale)
        {
            Vector2 st = uv; // UV
            st *= 10 - scale * 10; // Scale 

            // Tile the space
            Vector2 i_st = new Vector2(Mathf.Floor(st.x), Mathf.Floor(st.y));
            Vector2 f_st = new Vector2(Frac(st.x), Frac(st.y));

            float m_dist = 10f; // minimun distance

            for (int j = -1; j <= 1; j++) // Iterate Y neightbours
            {
                for (int i = -1; i <= 1; i++) // Iterate X neightbours
                {
                    Vector2 neighbor = new Vector2(i, j); // Sample neighbours
                    Vector2 p = random2(i_st + neighbor);
                    p = new Vector2(0.5f, 0.5f) + 0.5f * new Vector2(Mathf.Sin(Time.time + 6.2831f * p.x), Mathf.Sin(Time.time + 6.2831f * p.y));
                    Vector2 diff = neighbor + p - f_st;
                    float dist = diff.magnitude;

                    if (dist < m_dist) // If nearer than previous iterations
                    {
                        m_dist = dist; // Save distance
                    }
                }
            }
            return m_dist;
        }
    }
}
