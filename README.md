# Toon Shading
![alt text][logo]

[logo]: https://cdna.artstation.com/p/assets/images/images/007/124/644/large/matt-dean-screenshot01.jpg?1503872324 "Demo Scene"

A collection of "Toon" shaders based on a stepped PBR approximation.

Toon Standard Shader:
- Custom "Toon" cel style BRDF
- Specular / Smoothness 
- Energy conservation approximation 
- Wrap based transmission approximation 
- Custom ShaderGUI

Toon Water Shader: 
- Uses same BRDF as above 
- Voronoi based procedural waves 
- Depth buffer to world position intersection for wave crests 
- Approximated transmission and refraction 
- Planar reflection 
- Buoyancy calculation

Contains:
- Toon Standard shader
- Toon Water shader
- Buoyancy controller
- Demo scene
- Source assets
