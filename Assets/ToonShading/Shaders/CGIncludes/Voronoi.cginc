#ifndef VORONOI_INCLUDED
#define VORONOI_INCLUDED

// Get random Vector2
float2 random2(float2 p)
{
	return frac(sin(float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3))))*43758.5453);
}

// Calculate voronoi noise
float Voronoi(float2 uv)
{
	float2 st = uv; // UV
	st *= 10 - _WaveScale * 10; // Scale 

	// Tile the space
	float2 i_st = floor(st);
	float2 f_st = frac(st);

	float m_dist = 10.;	// minimun distance
	float2 m_point;     // minimum point

	for (int j = -1; j <= 1; j++) // Iterate Y neightbours
	{
		for (int i = -1; i <= 1; i++) // Iterate X neightbours
		{
			float2 neighbor = float2(float(i), float(j)); // Sample neighbours
			float2 p = random2(i_st + neighbor);
			p = 0.5 + 0.5*sin(_Time.y + 6.2831*p);
			float2 diff = neighbor + p - f_st;
			float dist = length(diff);

			if (dist < m_dist) // If nearer than previous iterations
			{
				m_dist = dist; // Save distance
				m_point = p; // Save point
			}
		}
	}
	return m_dist;
}

#endif // VORONOI_INCLUDED
