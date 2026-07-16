# User Documentation

## Overview

The **Sky Model addon** provides a physically based sky, sunlight, and atmospheric fog system for Godot. Sky textures are generated from the **Prague Sky Model dataset** and can be precomputed for multiple observer altitudes.

The addon is intended primarily for large outdoor environments, including terrain visualizations and scenes in which the observer can move significantly above ground level.

This repository also contains a `test_project` demonstrating the addon together with [Terrain3D](https://github.com/TokisanGames/Terrain3D).

For information about the development environment, source code, and compiling the GDExtension, see [technical documentation](TechnicalDocumentation.md).


## Requirements

* **Godot Engine 4.5**
* A compatible Prague Sky Model dataset
* Sufficient memory and storage for the selected dataset
* A renderer and GPU capable of displaying floating-point sky textures

## Installation

1. Open the repository's **Releases** page.
2. Download the addon archive for your operating system.
3. Extract the archive.
4. Copy the addon folder into your Godot project.
5. Open the project in Godot.
6. Go to:

```text
Project → Project Settings → Plugins
```

7. Find **Sky Texture Generator Tool** and set its status to **Enabled**.
8. Restart the editor if Godot requests it or if the addon's custom nodes do not appear immediately.

## Downloading a Dataset

The addon requires a Prague Sky Model dataset file.

Three dataset variants are currently available.

### Full dataset

[Download the full dataset — 2.2 GB](https://drive.google.com/file/d/1IShL7T3umxGOEFvyYGQpHKMTneXEvyTM/view?usp=sharing)

This version contains:

* The full range of atmospheric visibilities
* The full range of solar elevations
* Multiple observer altitudes
* The full range of ground albedos
* Polarization data
* 11 wavelength channels from 320 to 760 nm

This is the recommended dataset when the observer altitude changes at runtime.

### Ground-level dataset

[Download the ground-level dataset — 103 MB](https://drive.google.com/file/d/1IflyFZTJxC_N298yXq_2GK4ycIsVJZk6/view?usp=sharing)

This smaller version contains:

* The full range of atmospheric visibilities
* The full range of solar elevations
* A single observer altitude of 0 m
* The full range of ground albedos
* No polarization data
* 11 wavelength channels from 320 to 760 nm

Use this version for scenes viewed approximately from ground level. Because it contains only one observer altitude, it is not suitable for altitude-dependent sky transitions.

### SWIR dataset

[Download the SWIR dataset — 547 MB](https://drive.google.com/file/d/1ZOizQCN6tH39JEwyX8KvAj7WEdX-EqJl/view?usp=sharing)

This version contains:

* The full range of atmospheric visibilities
* The full range of solar elevations
* A single observer altitude of 0 m
* The full range of ground albedos
* Polarization data
* 55 wavelength channels from 280 to 2480 nm

The SWIR dataset provides a wider spectral range but contains only one observer altitude.

### Dataset comparison

| Property                 |    Full    | Ground-level |     SWIR    |
| ------------------------ | :--------: | :----------: | :---------: |
| Atmospheric visibilities |     All    |      All     |     All     |
| Solar elevations         |     All    |      All     |     All     |
| Observer altitudes       |     All    |   0 m only   |   0 m only  |
| Ground albedos           |     All    |      All     |     All     |
| Wavelength channels      |     11     |      11      |      55     |
| Spectral range           | 320–760 nm |  320–760 nm  | 280–2480 nm |
| Transmittance            |     Yes    |      Yes     |     Yes     |
| Polarization             |     Yes    |      No      |     Yes     |

Place the downloaded `.dat` file somewhere accessible to the Godot project. 

## Basic Setup

### 1. Add the SkyModel node

Open the scene that should contain the sky.

Add a new **SkyModel** node to the scene tree. The node acts as the scene’s `WorldEnvironment` and automatically creates the supporting sky, fog, sunlight, and texture-generator nodes.

A typical scene tree will look similar to:

```text
SkyModel
├── SkyDomeSettings
├── SkyTextureGenerator
└── SunLight
```

These child nodes are normally created and configured automatically.

Only one active `WorldEnvironment` should control the scene at a time. Remove or disable another `WorldEnvironment` if it conflicts with `SkyModel`.

### 2. Select and load the dataset

Select the `SkyModel` node and find the **Dataset Loading** section in the Inspector.

1. Set **Dataset Path** to the downloaded `.dat` file.
2. Select the required **Visibility Range**.
3. Click **Read Dataset**.

The available sky and precomputation settings appear after the dataset has loaded successfully.

The visibility range determines which part of the dataset is loaded into memory. Selecting a smaller range reduces memory consumption.

Choose a range that contains the visibility value you intend to use:

| Visibility range | Typical interpretation     |
| ---------------- | -------------------------- |
| 20.0–27.6 km     | Hazy atmosphere            |
| 27.6–40.0 km     | Moderate haze              |
| 40.0–59.4 km     | Clear conditions           |
| 59.4–90.0 km     | Very clear conditions      |
| 90.0–131.8 km    | Extremely clear atmosphere |

After changing the dataset path or visibility range, click **Read Dataset** again.

## Configuring the Sky

After the dataset is loaded, configure the parameters in the **Sky Settings** section.

### Albedo

Controls the reflectivity of the ground.

* `0.0` represents a very dark surface.
* `1.0` represents a highly reflective surface.

Typical values include:

* Dark soil or forest: `0.05–0.20`
* Grass or mixed terrain: `0.15–0.30`
* Sand: `0.30–0.50`
* Snow: `0.70–0.95`

### Altitude

Sets the observer altitude in meters when no runtime altitude source is assigned.

This value is also used while editing the scene and when generating a static sky setup.

### Elevation

Sets the sun's elevation above the horizon in degrees.

* Negative values place the sun below the horizon.
* `0°` places it on the horizon.
* `90°` places it directly overhead.

### Visibility

Sets atmospheric visibility in kilometers.

Lower values produce a hazier atmosphere. Higher values produce a clearer atmosphere.

The value must remain within the visibility range loaded from the dataset.

## Configuring Runtime Altitude

The addon can change the sky according to the observer’s altitude while the application is running.

Find the **Runtime Altitude** section on the `SkyModel` node.

### Altitude Source Path

Assign a `Node3D` whose vertical position represents the observer altitude. This is usually the player, camera rig, aircraft, or another moving scene object.

The addon reads the node's global Y coordinate.

Set **Altitude Source Path** to `Player` or `Player/Camera3D`, depending on which node contains the required world-space height.

### Altitude Scale

Multiplies the source node's global Y coordinate:

```text
sky altitude = source Y × altitude scale + altitude offset
```

Change this value when the scene uses a different world scale. For example, when one Godot unit represents ten meters, use an appropriate conversion factor.

### Altitude Offset

Adds a fixed value to the measured altitude.

This is useful when:

* The scene origin does not represent sea level.
* Terrain coordinates use a local height reference.
* The dataset altitude should begin above or below the Godot world origin.


Runtime altitude is limited to the altitude range for which sky textures were precomputed.

## Precomputing Sky Textures

The addon generates several sky textures and interpolates between them as the observer altitude changes.

Find the **Precompute Settings** section on the `SkyModel` node.

### Texture Resolution

Controls the resolution of each generated sky texture.

Higher resolutions improve detail but require more generation time, memory, and GPU resources.

A value of `512` is a suitable starting point for most scenes.

### Maximum Precompute Altitude

Sets the highest observer altitude for which a sky texture will be generated.

Set this value according to the expected movement range of the player or camera.

Examples:

* Ground-based scene: `1000 m`
* Mountain environment: `5000 m`
* Aircraft scene: `15000 m`

Avoid generating textures for altitudes that the application will never use.

### Precomputed Texture Count

Sets the number of altitude samples generated between the dataset's minimum altitude and **Maximum Precompute Altitude**.

A value between `8` and `16` is a reasonable starting point. The maximum supported value is `32`.

### Altitude Density Power

Controls the distribution of altitude samples.

Higher values place more samples near ground level, where atmospheric appearance often changes more noticeably.

Use a lower value for a more uniform altitude distribution. Use a higher value when visual quality near the ground is more important.

### Generate the textures

After configuring all sky and precomputation parameters, click **Precompute Sky Textures**.

Texture generation may temporarily make the Godot editor less responsive, especially when using:

* A high texture resolution
* A large texture count
* A large dataset
* A wide precomputed altitude range

When generation finishes, the textures and their corresponding altitude values are stored on the `SkyModel` node.

Recompute the textures whenever you change parameters that affect the physical sky, including:

* Albedo
* Solar elevation
* Visibility
* Texture resolution
* Maximum precompute altitude
* Texture count
* Altitude density power

Changing display-only settings such as exposure or azimuth does not normally require texture regeneration.

## Display Settings

The **Display** section controls how the generated sky is presented.

### Exposure

Adjusts the brightness of the sky.

The generated textures contain high-dynamic-range values, so a negative exposure may be required depending on the scene’s tone-mapping and lighting configuration.

### Azimuth

Rotates the sun horizontally around the scene.

This changes the direction of:

* The visible sun
* The generated directional light
* Atmospheric lighting around the sun

Azimuth does not change the physical sky texture itself and therefore does not require precomputation.

### Sun Visible

Shows or hides the rendered sun disc.

### Sky Visible

Shows or hides the sky background.

### Fog Visible

Enables or disables the addon’s atmospheric fog pass.

## Atmospheric Fog Settings

Select the automatically created `SkyDomeSettings` child node to configure atmospheric fog and horizon blending.

The available parameters include:

* Atmospheric wavelengths
* Atmospheric darkness
* Sun intensity
* Daytime tint
* Atmospheric thickness
* Mie scattering
* Turbidity
* Sun Mie tint
* Sun Mie intensity
* Mie anisotropy
* Fog density
* Fog start and end distances
* Fog falloff
* Sea level
* Rayleigh and Mie depth settings

The default settings provide a starting point, but they should be adjusted to match the scale, lighting, and terrain of the scene.

## Camera Configuration

The addon is designed for large environments. The camera’s visibility range must be configured accordingly.

## Terrain3D Integration

To reproduce an environment similar to the preview scene, install [Terrain3D](https://github.com/TokisanGames/Terrain3D).

The test project contains a customized Terrain3D shader that simulates the curvature of the Earth. The curvature effect lowers distant terrain and helps its horizon align with the horizon produced by the sky model.

To use it:

1. Install and enable Terrain3D.
2. Create or import a Terrain3D terrain.
3. Apply the custom terrain shader supplied with the project.
4. Increase the camera’s far clipping distance.

The custom terrain shader is optional. The Sky Model addon can be used without Terrain3D, but flat terrain extending over very large distances may not align naturally with the atmospheric horizon.
