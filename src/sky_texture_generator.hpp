// Copyright 2022 Charles University
// SPDX-License-Identifier: Apache-2.0
#pragma once

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/wrapped.hpp>

#include "sky_model.hpp"

using namespace godot;

class SkyTextureGenerator : public Node {
	GDCLASS(SkyTextureGenerator, Node)
protected:
	static void _bind_methods();

private:

	/// <summary>
	/// An example of using Realtime Sky Model for rendering a simple fisheye RGB image of the sky.
	/// </summary>
	/// <param name="model">Reference to the sky model object.</param>
	/// <param name="albedo">Ground albedo, value in range [0, 1].</param>
	/// <param name="altitude">Altitude of view point in meters, value in range [0, 15000].</param>
	/// <param name="azimuth">Sun azimuth at view point in degrees, value in range [0, 360].</param>
	/// <param name="elevation">Sun elevation at view point in degrees, value in range [-4.2, 90].</param>
	/// <param name="mode">Rendered quantity: sky radiance, sun radiance, polarisation, or transmittance.</param>
	/// <param name="resolution">Length of resulting square image size in pixels.</param>
	/// <param name="view">Rendered view: up-facing fisheye or side-facing fisheye.</param>
	/// <param name="visibility">Horizontal visibility (meteorological range) at ground level in kilometers, value in range [20, 131.8].</param>
	/// <param name="outResult">Buffer for storing the resulting images (index 0 = sRGB, index 1 - <# of channels in the dataset> = individual channels).</param>
	void render(
			SkyModel &model,
			const double albedo,
			const double altitude,
			const double azimuth,
			const double elevation,
			const int resolution,
			const double visibility,
			std::vector<std::vector<float>> &outResult) const;

public:
	void generate() const;
};
