#include "sky_texture_generator.hpp"

#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <assert.h>
#include <algorithm>
#include <array>
#include <cstring>
#include <execution>
#include <limits>
#include <string>

#include "custom_parallel_for.hpp"

#define BIND_READ_ONLY_PROPERTY(m_method, m_property, m_type)           \
	ClassDB::bind_method(D_METHOD("get_" #m_property), &m_method);      \
	ADD_PROPERTY(                                                       \
			PropertyInfo(                                               \
					m_type,                                             \
					#m_property,                                        \
					PROPERTY_HINT_NONE,                                 \
					"",                                                 \
					PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY), \
			"",                                                         \
			"get_" #m_property)

SkyTextureGenerator::SkyTextureGenerator() {
	available.albedoMin = 0.0;
	available.albedoMax = 1.0;
	available.altitudeMin = 0.0;
	available.altitudeMax = 15000.0;
	available.elevationMin = -4.2;
	available.elevationMax = 90.0;
	available.visibilityMin = 20.0;
	available.visibilityMax = 131.8;
	available.polarisation = true;
	available.channels = SPECTRUM_CHANNELS;
	available.channelStart = SPECTRUM_WAVELENGTHS[0] - 0.5 * SPECTRUM_STEP;
	available.channelWidth = SPECTRUM_STEP;
}

void SkyTextureGenerator::_bind_methods() {
	ClassDB::bind_method(
			D_METHOD(
					"generate_texture",
					"albedo",
					"altitude",
					"elevation",
					"visibility",
					"resolution"),
			&SkyTextureGenerator::generateSkyTexture);

	ClassDB::bind_method(
			D_METHOD(
					"read_dataset",
					"path",
					"single_visibility"),
			&SkyTextureGenerator::readDataset);

	BIND_READ_ONLY_PROPERTY(SkyTextureGenerator::getAlbedoMin, albedo_min, Variant::FLOAT);
	BIND_READ_ONLY_PROPERTY(SkyTextureGenerator::getAlbedoMax, albedo_max, Variant::FLOAT);

	BIND_READ_ONLY_PROPERTY(SkyTextureGenerator::getAltitudeMin, altitude_min, Variant::FLOAT);
	BIND_READ_ONLY_PROPERTY(SkyTextureGenerator::getAltitudeMax, altitude_max, Variant::FLOAT);

	BIND_READ_ONLY_PROPERTY(SkyTextureGenerator::getElevationMin, elevation_min, Variant::FLOAT);
	BIND_READ_ONLY_PROPERTY(SkyTextureGenerator::getElevationMax, elevation_max, Variant::FLOAT);

	BIND_READ_ONLY_PROPERTY(SkyTextureGenerator::getVisibilityMin, visibility_min, Variant::FLOAT);
	BIND_READ_ONLY_PROPERTY(SkyTextureGenerator::getVisibilityMax, visibility_max, Variant::FLOAT);

	BIND_READ_ONLY_PROPERTY(SkyTextureGenerator::getResolutionMin, resolution_min, Variant::INT);
	BIND_READ_ONLY_PROPERTY(SkyTextureGenerator::getResolutionMax, resolution_max, Variant::INT);

	BIND_READ_ONLY_PROPERTY(SkyTextureGenerator::isInitialized, is_initialized, Variant::BOOL);
}

SkyModel::Vector3 SkyTextureGenerator::pixelToDirection(int x, int y, int resolution) const {
	// Make circular image area in center of image.
	const double radius = double(resolution) / 2;
	const double scaledx = (x + 0.5 - radius) / radius;
	const double scaledy = (y + 0.5 - radius) / radius;
	const double denom = scaledx * scaledx + scaledy * scaledy + 1;

	if (denom > 2.0) {
		// Outside image area.
		return SkyModel::Vector3();
	} else {
		return SkyModel::Vector3(2.0 * scaledx / denom, 2.0 * scaledy / denom, -(denom - 2.0) / denom);
	}
}

SkyModel::Vector3 SkyTextureGenerator::spectrumToRGB(const Spectrum &spectrum) const {
	// Spectrum to XYZ
	SkyModel::Vector3 xyz = SkyModel::Vector3();
	for (int wl = 0; wl < SPECTRUM_CHANNELS; wl++) {
		const int responseIdx = int((SPECTRUM_WAVELENGTHS[wl] - SPECTRAL_RESPONSE_START) / SPECTRAL_RESPONSE_STEP);
		if (0 <= responseIdx && responseIdx < std::size(SPECTRAL_RESPONSE)) {
			xyz = xyz + SPECTRAL_RESPONSE[responseIdx] * spectrum[wl];
		}
	}
	xyz = xyz * SPECTRUM_STEP;

	// XYZ to sRGB
	SkyModel::Vector3 rgb = SkyModel::Vector3();
	rgb.x = 3.2404542 * xyz.x - 1.5371385 * xyz.y - 0.4985314 * xyz.z;
	rgb.y = -0.9692660 * xyz.x + 1.8760108 * xyz.y + 0.0415560 * xyz.z;
	rgb.z = 0.0556434 * xyz.x - 0.2040259 * xyz.y + 1.0572252 * xyz.z;

	return rgb;
}

SkyModel::Vector3 SkyTextureGenerator::rotateAroundZ(const SkyModel::Vector3 &v, double angle) const {
	const double c = std::cos(angle);
	const double s = std::sin(angle);
	return SkyModel::Vector3(c * v.x - s * v.y, s * v.x + c * v.y, v.z);
}

void SkyTextureGenerator::render(
		double albedo,
		double altitude,
		double elevation,
		double visibility,
		int resolution,
		std::vector<float> &outResult) {
	assert(skyModel.isInitialized());
	const unsigned int xTextureSize = resolution / 2;
	const unsigned int yTextureSize = resolution;

	// Resize the output buffer and initialize elemetes to 0.0.
	outResult.assign(size_t(xTextureSize) * yTextureSize * 3, 0.0f);

	// We are viewing the sky from 'altitude' meters above the origin.
	const SkyModel::Vector3 viewPoint = SkyModel::Vector3(0.0, 0.0, altitude);

	const double azimuth = 0.0;
	SkyModel::FrameInterpolationParameters frameIterParams = skyModel.computeFrameInterpolationParameters(
			viewPoint,
			degreesToRadians(elevation),
			degreesToRadians(azimuth),
			visibility,
			albedo);

	const std::size_t chunkSize = 8;

	//parallel_for<std::size_t>(0, xTextureSize, [&](std::size_t x) {
	parallel_for_chunks<std::size_t>(0, xTextureSize, chunkSize, [&](std::size_t x) {
		for (int y = 0; y < yTextureSize; y++) {
			// For each pixel of the rendered image get the corresponding direction in fisheye projection.
			SkyModel::Vector3 viewDir = this->pixelToDirection(x + xTextureSize, y, yTextureSize);

			viewDir = this->rotateAroundZ(viewDir, degreesToRadians(90.0));

			// If the pixel lies outside the upper hemisphere, the direction will be zero. Such a pixel is kept black.
			if (viewDir.isZero()) {
				continue;
			}

			SkyModel::PixelInterpolationParameters pixelIterParams = this->skyModel.computePixelInterpolationParameters(viewDir);

			Spectrum spectrum;
			for (int wl = 0; wl < SPECTRUM_CHANNELS; wl++) {
				spectrum[wl] = this->skyModel.skyRadiance(pixelIterParams, frameIterParams, SPECTRUM_WAVELENGTHS[wl]);
			}

			// Convert the spectral quantity to sRGB and store it at 0 in the result buffer.
			const SkyModel::Vector3 rgb = this->spectrumToRGB(spectrum);

			const size_t index = (size_t(y) * xTextureSize + x) * 3;

			outResult[index + 0] = float(rgb.x);
			outResult[index + 1] = float(rgb.y);
			outResult[index + 2] = float(rgb.z);
		}
	});
}

void SkyTextureGenerator::readDataset(const String &path, double singleVisibility) {
	try {
		skyModel.initialize(path.utf8().get_data(), singleVisibility);
		available = skyModel.getAvailableData();

		print_line("Dataset loaded.");
	} catch (const std::exception &e) {
		ERR_PRINT(String("Failed to load dataset: ") + String(e.what()));
	}
}

Ref<Image> SkyTextureGenerator::generateSkyTexture(
		double albedo,
		double altitude,
		double elevation,
		double visibility,
		int resolution) {
	if (!skyModel.isInitialized()) {
		ERR_PRINT("Sky model is not initialized. Call read_dataset() first.");
		return Ref<Image>();
	}

	if (resolution % 2 != 0)
		resolution++;

	const double clampedAlbedo = std::clamp(albedo, available.albedoMin, available.albedoMax);
	const double clampedAltitude = std::clamp(altitude, available.altitudeMin, available.altitudeMax);
	const double clampedElevation = std::clamp(elevation, available.elevationMin, available.elevationMax);
	const double clampedVisibility = std::clamp(visibility, available.visibilityMin, available.visibilityMax);
	const int clampedResolution = std::clamp(resolution, resolutionMin, resolutionMax);

	const unsigned int xTextureSize = clampedResolution / 2;
	const unsigned int yTextureSize = clampedResolution;

	std::vector<float> result;
	Ref<Image> image;

	try {
		//Render sky image according to the given configuration.
		render(
				clampedAlbedo,
				clampedAltitude,
				clampedElevation,
				clampedVisibility,
				clampedResolution,
				result);

		if (result.empty()) {
			ERR_PRINT("Render result is empty.");
			return Ref<Image>();
		}

		// Save the result buffer into an godot::Image.
		PackedByteArray bytes;
		bytes.resize(xTextureSize * yTextureSize * 3 * sizeof(float));
		memcpy(bytes.ptrw(), result.data(), bytes.size());

		image.instantiate();

		image->set_data(xTextureSize, yTextureSize, false, Image::FORMAT_RGBF, bytes);
	} catch (const std::exception &e) {
		ERR_PRINT(String("Error: ") + e.what());
		return Ref<Image>();
	}
	return image;
}
