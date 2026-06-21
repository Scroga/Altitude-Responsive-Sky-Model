#ifndef SKY_TEXTURE_GENERATOR_HPP
#define SKY_TEXTURE_GENERATOR_HPP

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/wrapped.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

#include "constants.hpp"
#include "sky_model.hpp"

#include <vector>

using namespace godot;

class SkyTextureGenerator : public Node3D {
	GDCLASS(SkyTextureGenerator, Node3D)
protected:
	static void _bind_methods();

private:
	/////////////////////////////////////////////////////////////////////////////////////
	// Helpers
	/////////////////////////////////////////////////////////////////////////////////////
	SkyModel::Vector3 rotateAroundZ(const SkyModel::Vector3 &v, double angle) const;

	/// Computes direction corresponding to given pixel coordinates in up-facing projection.
	SkyModel::Vector3 pixelToDirection(int x, int y, int resolution) const;
	/// Converts given spectrum to sRGB.
	SkyModel::Vector3 spectrumToRGB(const Spectrum &spectrum) const;
	/// Renders a simple fisheye RGB image of the sky.
	void renderSingle(
			double albedo,
			double altitude,
			double elevation,
			double visibility,
			int resolution,
			std::vector<float> &outResult);

		void renderForAltitudes(
			double albedo,
			const std::vector<double>& altitudes,
			double elevation,
			double visibility,
			int resolution,
			std::vector<std::vector<float>> &outResult);

	SkyModel skyModel;
	SkyModel::AvailableData available;

	const int resolutionMin = 128;
	const int resolutionMax = 4096;

public:
	SkyTextureGenerator();

	double getAlbedoMin() const { return available.albedoMin; }
	double getAlbedoMax() const { return available.albedoMax; }

	double getAltitudeMin() const { return available.altitudeMin; }
	double getAltitudeMax() const { return available.altitudeMax; }

	double getElevationMin() const { return available.elevationMin; }
	double getElevationMax() const { return available.elevationMax; }

	double getVisibilityMin() const { return available.visibilityMin; }
	double getVisibilityMax() const { return available.visibilityMax; }

	int getResolutionMin() const { return resolutionMin; }
	int getResolutionMax() const { return resolutionMax; }

	bool isInitialized() const { return skyModel.isInitialized(); }

	void readDataset(const String &path, double singleVisibility);

	Ref<Image> generateSkyTexture(
			double albedo,
			double altitude,
			double elevation,
			double visibility,
			int resolution);

	TypedArray<Image> generateSkyTexturesForAltitudes(
			double albedo,
			const PackedFloat32Array &altitudesArray,
			double elevation,
			double visibility,
			int resolution);
};

#endif
