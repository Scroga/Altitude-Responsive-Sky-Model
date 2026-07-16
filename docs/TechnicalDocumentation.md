# Technical Documentation

## Introduction

This repository contains the development environment and source code for a Godot Engine addon created as part of a bachelor's thesis at Charles University.

The addon integrates the Prague Sky Model into Godot and provides physically based sky textures together with atmospheric fog and lighting support. 
This document gives a brief overview of the repository structure, implementation, and development workflow.

Detailed explanations of the model, algorithms, design decisions, and evaluation are provided in the bachelor's thesis.

## Project Structure

```text
├── doc_classes/
├── docs/
├── src/
├── test_project/
│   └── addons/
│       └── sky_model/
│           ├── src/
│           └── shaders/
├── setup.py
└── SConstruct
```

* `doc_classes` – Godot XML documentation for the C++ classes and methods exposed to GDScript.
* `docs` – Images, screenshots, and other documentation resources.
* `src` – Source code of the native C++ GDExtension.
* `test_project` – Godot project used for development, testing, and demonstration.
* `test_project/addons/sky_model/src` – GDScript source files of the addon.
* `test_project/addons/sky_model/shaders` – Sky and atmospheric fog shaders.
* `setup.py` – Script for preparing the development environment.
* `SConstruct` – SCons build configuration for compiling the extension.

## Compilation of addon

This repository uses template for developing [GDExtensions](https://docs.godotengine.org/en/stable/classes/class_gdextension.html) in C++ for [Godot Engine](https://godotengine.org/).

The installation step will be

## Requirements

* [GitHub](https://github.com/) account because we are going to be using GitHub Actions for cross platform compilation
* [Git](https://git-scm.com/downloads) installed on your machine and configured correctly so you can push changes to remote
* [Python](https://www.python.org/) latest version and ensure it's available in <b>system environment PATH</b>
* [Scons](https://scons.org/) latest version and ensure it's available in <b>system environment PATH</b>

  * Windows command: `pip install scons`
  * macOS command: `python3 -m pip install scons`
  * Linux command `python3 -m pip install scons`
* C++ compiler

  * Windows: MSVC (Microsoft Visual C++) via Visual Studio or Build Tools.
  * macOS: Clang (included with Xcode or Xcode Command Line Tools).
  * Linux: GCC or Clang (available via package managers).
* [Visual Studio Code](https://code.visualstudio.com/) or any other editor that supports C++ and the `compile_commands.json`

Here are some include directories, if you are stubbornly choosing not to use compile_commands.json or if for some reason your editor needs it for extra features (Visual Studio Code will NOT need it as long as we use the Clangd extension)

```
${workspaceFolder}/godot-cpp/gdextension/
${workspaceFolder}/godot-cpp/gen/**
${workspaceFolder}/godot-cpp/include/**
${workspaceFolder}/godot-cpp/src/**

${workspaceFolder}/src   -> usually where you write all your code  
```

## How to use

You can choose to watch this tutorial for beginners - https://www.youtube.com/watch?v=I79u5KNl34o

## Development Workflow

A typical development workflow is:

1. Clone the repository and its required submodules.
2. Run the setup script if the development environment has not yet been prepared.
3. Modify the native implementation in `src`.
4. Compile the GDExtension using SCons.
5. Copy or generate the compiled libraries in the addon directory.
6. Open `test_project` in Godot.
7. Test the addon using the included demonstration scene.
8. Update the XML class documentation when the exposed C++ API changes.

The exact output library and platform-specific build options depend on the active operating system and the project’s SCons configuration.


## Architecture Overview

The implementation is divided into three main parts:

1. **Native C++ extension**
2. **Godot integration scripts**
3. **Rendering shaders**

The C++ extension loads the Prague Sky Model dataset and generates sky textures. GDScript manages the generated textures, Godot scene objects, parameters, and runtime updates. The shaders render the sky and atmospheric fog.

## Native C++ Extension

### `SkyTextureGenerator`

`SkyTextureGenerator` is the main native class exposed to Godot.

Its primary responsibilities are:

* loading the Prague Sky Model dataset,
* reporting the parameter ranges supported by the loaded dataset,
* generating sky radiance for individual texture pixels,
* converting spectral radiance values to RGB,
* and returning the generated data as a Godot `Image`.

The class exposes the following main methods to GDScript:

```gdscript
read_dataset(path, single_visibility)
```

Loads the sky model dataset. The `single_visibility` argument can be used to load only the required visibility portion of the dataset and reduce memory consumption.

```gdscript
generate_texture(
    albedo,
    altitude,
    elevation,
    visibility,
    resolution
)
```

Generates a floating-point RGB sky texture for the supplied atmospheric parameters.

Input values are clamped to the ranges supported by the loaded dataset. The generated texture represents the upper sky hemisphere using a fisheye projection.

Texture generation is parallelized across the image to reduce processing time.

### `SkyModelUtils`

`SkyModelUtils` is an abstract utility class containing static methods available from GDScript.

It provides methods for:

* generating linearly distributed altitude samples,
* generating non-linearly distributed altitude samples,
* and estimating an appropriate sunlight color temperature.

Non-linear altitude distribution allows more textures to be generated near the ground, where visual changes caused by altitude are generally more noticeable.

## Godot Integration

### `SkyModel`

`SkyModel` is the main Godot-facing class of the addon.

It extends `WorldEnvironment` and coordinates:

* dataset loading,
* sky texture generation,
* precomputed altitude textures,
* sky shader configuration,
* atmospheric fog,
* sun direction and color,
* and runtime observer-altitude changes.

Sky textures are precomputed for several altitudes and stored in a `Texture2DArray`. During runtime, the sky shader selects and interpolates between the appropriate texture layers according to the current observer altitude.

This avoids regenerating the sky texture every frame.

### `SkyParameters`

`SkyParameters` stores the primary sky-generation configuration.

The parameters include:

* ground albedo,
* observer altitude,
* solar elevation,
* visibility,
* texture resolution,
* maximum precomputed altitude,
* number of precomputed textures,
* and altitude sample distribution.

The parameter ranges are updated after the dataset is loaded so that values remain compatible with the available data.

### `SkyDomeSettings`

`SkyDomeSettings` manages the atmospheric fog and related visual settings.

It creates the fog rendering mesh, configures its shader material, and updates shader parameters such as:

* observer altitude,
* visibility,
* atmospheric density,
* Rayleigh scattering,
* Mie scattering,
* sun direction,
* fog range,
* and color correction.

## Shaders

### Sky Shader

The sky shader renders the generated sky texture around the scene.

It uses the precomputed texture array and interpolates between altitude layers. This allows the appearance of the sky to change when the observer moves vertically through a large environment.

### Atmospheric Fog Shader

The atmospheric fog shader renders a screen-space atmospheric and distance-fog effect.

It combines configurable Rayleigh and Mie scattering approximations with information about:

* camera position,
* observer altitude,
* visibility,
* sun direction,
* terrain distance,
* and scene depth.

The fog shader is visually synchronized with the generated sky and directional sunlight.

### Shared Shader Utilities

Common shader constants and helper functions are stored in shader include files. This reduces duplication between the sky and fog shaders.

## Texture Generation Process

Sky texture generation follows these main steps:

1. The Prague Sky Model dataset is loaded.
2. The requested parameters are clamped to supported ranges.
3. Each texture pixel is converted into a sky-view direction.
4. Spectral sky radiance is evaluated for that direction.
5. The spectral result is converted through CIE XYZ to linear sRGB.
6. The generated values are stored in a floating-point RGB Godot image.
7. Multiple altitude images are combined into a `Texture2DArray`.
8. The shader interpolates between texture layers during runtime.

The generation process is performed during initialization or when parameters requiring regeneration are changed.


## Further Information

This document intentionally provides only a brief implementation overview.

For detailed information about the Prague Sky Model, spectral radiance processing, atmospheric rendering, altitude interpolation, 
performance considerations, and the design of the addon, refer to the accompanying bachelor’s thesis.
