#ifndef SKY_MODEL_UTILS_HPP
#define SKY_MODEL_UTILS_HPP

#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/typed_array.hpp>

#include <algorithm>

#include "constants.hpp"

using namespace godot;

class SkyModelUtils : public Node3D {
	GDCLASS(SkyModelUtils, Node3D)
protected:
	static void _bind_methods() {
		ClassDB::bind_static_method(
				"SkyModelUtils",
				D_METHOD("generate_linear_altitudes", "min_altitude", "max_altitude", "count"),
				&SkyModelUtils::generateLinearAltitudes);

		ClassDB::bind_static_method(
				"SkyModelUtils",
				D_METHOD("generate_non_linear_altitudes", "min_altitude", "max_altitude", "count", "exponent"),
				&SkyModelUtils::generateNonLinearAltitudes);

		ClassDB::bind_static_method(
				"SkyModelUtils",
				D_METHOD("compute_sun_light_temperature", "elevation", "altitude", "visibility"),
				&SkyModelUtils::computeSunLightTemperature);
	}

public:
	/// Generates evenly spaced altitude values between minAltitude and maxAltitude.
	///
	/// Returns an empty array if count is less than or equal to 0. If count is 1,
	/// the returned array contains only minAltitude.
	static PackedFloat32Array generateLinearAltitudes(
			double minAltitude,
			double maxAltitude,
			int count) {
		PackedFloat32Array altitudes;

		if (count <= 0) {
			return altitudes;
		}
		altitudes.resize(count);

		if (count == 1) {
			altitudes.set(0, minAltitude);
			return altitudes;
		}

		if (minAltitude >= maxAltitude) {
			ERR_PRINT("Invalid altitude range.");
		}

		double rangeSize = maxAltitude - minAltitude;
		double step = rangeSize / double(count - 1);

		for (int i = 0; i < count; i++) {
			double altitude = minAltitude + step * i;
			altitudes.set(i, altitude);
		}

		return altitudes;
	}

	/// Generates non-linearly spaced altitude values between minAltitude and maxAltitude.
	///
	/// The exponent controls the distribution of samples. Values greater than 1.0 place
	/// more samples near minAltitude. Returns an empty array if count is less than or
	/// equal to 0. If count is 1, the returned array contains only minAltitude.
	static PackedFloat32Array generateNonLinearAltitudes(
			double minAltitude,
			double maxAltitude,
			int count,
			double exponent = 2.0) {
		PackedFloat32Array altitudes;

		if (count <= 0) {
			return altitudes;
		}
		altitudes.resize(count);

		if (count == 1) {
			altitudes.set(0, minAltitude);
			return altitudes;
		}

		if (minAltitude >= maxAltitude) {
			ERR_PRINT("Invalid altitude range.");
		}

		if (exponent <= 0.0) {
			exponent = 1.0;
		}

		double rangeSize = maxAltitude - minAltitude;

		for (int i = 0; i < count; i++) {
			const double t = double(i) / double(count - 1);

			// exponent > 1.0 means more samples near minAltitude.
			const double nonlinearT = std::pow(t, exponent);

			const double altitude = minAltitude + nonlinearT * rangeSize;
			altitudes.set(i, float(altitude));
		}

		return altitudes;
	}

	/// Estimates direct sunlight color temperature from sun elevation.
	///
	/// Returns a warm value near the horizon and a neutral daylight value when the sun is high.
	/// Visibility and altitude slightly affect the result, but this is only an artistic approximation
	/// intended for Godot's light_temperature property.
	static double computeSunLightTemperature(double elevation, double altitude, double visibility) {
		if (elevation <= 0.0) {
			return SUN_CCT_MIN;
		}

		// Normalize sun elevation from horizon to zenith.
		const double elevationFactor = std::clamp(
			elevation / MAX_SUN_ELEVATION_DEG,
			0.0,
			1.0);

		// Low sun = warm orange, high sun = daylight white.
		double cct = SUN_CCT_MIN +
				std::pow(elevationFactor, SUN_CCT_ELEVATION_EXPONENT) *
						(SUN_CCT_MAX - SUN_CCT_MIN);

		// Lower visibility means more haze, which makes direct sunlight warmer.
		if (visibility > 0.0) {
			const double hazeFactor = std::clamp(
					(VISIBILITY_HAZE_START_KM - visibility) / VISIBILITY_HAZE_RANGE_KM,
					0.0,
					1.0);

			cct -= hazeFactor * VISIBILITY_HAZE_CCT_REDUCTION;
		}

		// Higher altitude means less atmosphere, so direct sunlight becomes slightly less warm.
		const double altitudeKm = std::clamp(
				altitude / METERS_PER_KILOMETER,
				0.0,
				MAX_ALTITUDE_KM);

		cct += altitudeKm * ALTITUDE_CCT_INCREASE_PER_KM;

		return std::clamp(cct, SUN_CCT_CLAMP_MIN, SUN_CCT_CLAMP_MAX);
	}
};

#endif
