# kShading
### Shading models for Unity’s Universal Render Pipeline.

![alt text](https://github.com/Kink3d/kShading/wiki/Images/Home00.png?raw=true)
*An example of a scene using Lit Toon shading.*

kShading is a package of shaders for Unity's Universal Render Pipeline. It includes:
- **Lit:** A physically based shader that supports all default Universal surface properties as well as anisotropy, clear coat, sub-surface scattering and transmission.
- **Toon Lit:** A cel style shader that supports all features of the **Lit** shader but uses a stepped physical approximation BSDF.

Refer to the [Wiki](https://github.com/Kink3d/kShading/wiki/Home) for more information.

## Instructions
- Open your project manifest file (`MyProject/Packages/manifest.json`).
- Add `"com.kink3d.shading": "https://github.com/Kink3d/kShading.git"` to the `dependencies` list.
- Open or focus on Unity Editor to resolve packages.

## Requirements
- Unity 2019.3.0f3 or higher.