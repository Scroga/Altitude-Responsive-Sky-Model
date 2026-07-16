# User Documentation

## Introduction

This repository is a development environment used to create output addon. 
This readme file contains user documentation where the installation and usage of 
this addon. More detail about the development environment and how to compile 
addon itself will be found in file (docs/TechnicalDocumentation.md).

The repository contains test_project where the terrain3D https://github.com/TokisanGames/Terrain3D addon is setup

# Notes
The addon is designed for large scenes environments, to produce results as shown on screenshots it is 
needed to adjust the camera visibility range.

## Requirements
Godot engine version 4.5

## Installation
1. Go to release and download file.
2. Unzip it.
3. Move folder "sky_model" into Godot project directory
4. Go to Project->Project Settings->Plugins->Enable Sky Texture Generator Tool
5. Download prague sky model dataset dataset
    - the model is flexible and can work with various versions of the dataset
    - currently available:
        - [Full version (2.2 GB)](https://drive.google.com/file/d/1IShL7T3umxGOEFvyYGQpHKMTneXEvyTM/view?usp=sharing)
            - a full version of the dataset as presented in the first paper, contains the entire range of visibilities, solar elevations, observer altitudes, and ground albedos, includes polarisation
        - [Ground-level version (103 MB)](https://drive.google.com/file/d/1IflyFZTJxC_N298yXq_2GK4ycIsVJZk6/view?usp=sharing)
            - a smaller version of the dataset, contains only a single (zero) observer altitude, does not include polarisation
        - [SWIR version (547 MB)](https://drive.google.com/file/d/1ZOizQCN6tH39JEwyX8KvAj7WEdX-EqJl/view?usp=sharing)
            - a wide spectral range version of the dataset as presented in the second paper, contains 55 (instead of 11) wavelength channels, but only a single (zero) observer altitude, includes polarisation

            |                         | Full               | Ground-level       | SWIR                |
            | ----------------------- |:------------------:|:------------------:|:-------------------:|
            | **visibilities**        | all                | all                | all                 |
            | **solar elevations**    | all                | all                | all                 |
            | **observer altitudes**  | all                | just one (0 m)     | just one (0 m)      |
            | **ground albedos**      | all                | all                | all                 |
            | **wavelength channels** | 11 (320 - 760 nm)  | 11 (320 - 760 nm)  | 55 (280 - 2480 nm)  |
            | **transmittance**       | yes                | yes                | yes                 |

## Usage
1. Create SkyModel node in the scene
2. Choose data set and visiblity range in inspector-> press read dataset button
3. Set source of altitude in Reuntime Altitude secton in inspector of SkyModel node
4. Adjust atmospheric which are stored in the child node SkyDomeSettings
5. Choose sky parameters and press precompute button

To add terrain as in preview scene download terrain3D https://github.com/TokisanGames/Terrain3D.
The current the project contains custom terrain shader, the terrain will simulate the curvature of the earth if
the shader is applied which produces the match of horizon line with sky model.
