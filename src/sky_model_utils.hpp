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

private:
public:
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

	static double computeSunLightTemperature(double elevation, double altitude, double visibility) {
		if (elevation <= 0.0) {
			return 1900.0;
		}
		const double elevationRad = degreesToRadians(elevation);

		const double zenithDeg = 90.0 - elevation;
		const double airMass = 1.0 / (std::cos(degreesToRadians(zenithDeg)) + 0.50572 * std::pow(96.07995 - zenithDeg, -1.6364));

		// Atmosphere scale heights.
		// Rayleigh molecules extend higher; aerosols are concentrated near ground.
		const double altitudeKm = altitude / 1000.0;
		const double rayleighHeightScaleKm = 8.0;
		const double aerosolHeightScaleKm = 1.2;

		const double rayleighAltitudeFactor = std::exp(-altitudeKm / rayleighHeightScaleKm);
		const double aerosolAltitudeFactor = std::exp(-altitudeKm / aerosolHeightScaleKm);

		// Visibility is meteorological range in km.
		// Koschmieder relation: beta_extinction ~= 3.912 / visibility.
		// This gives horizontal extinction at 550 nm.
		const double betaAerosol550 = 3.912 / visibility;

		// Convert horizontal extinction to approximate vertical aerosol optical depth.
		const double aerosolTau550 = betaAerosol550 * aerosolHeightScaleKm * aerosolAltitudeFactor;

		// Angstrom exponent.
		// Higher = smaller particles, stronger blue attenuation.
		// This is a reasonable clear/hazy atmosphere approximation.
		const double angstromAlpha = 1.3;

		double X = 0.0;
		double Y = 0.0;
		double Z = 0.0;

		for (int wl = 0; wl < SPECTRUM_CHANNELS; wl++) {
			const double wavelengthNm = SPECTRUM_WAVELENGTHS[wl];
			const double wavelengthUm = wavelengthNm / 1000.0;

			// Relative extraterrestrial solar spectrum approximated as 5778 K blackbody.
			// Constants are not needed because only chromaticity matters.
			const double c2 = 1.438776877e-2; // m*K
			const double wavelengthM = wavelengthNm * 1.0e-9;
			const double solarTemperature = 5778.0;

			const double solar = 1.0 / (std::pow(wavelengthM, 5.0) * (std::exp(c2 / (wavelengthM * solarTemperature)) - 1.0));

			// Rayleigh vertical optical depth at sea level.
			// Common compact approximation around visible wavelengths.
			const double rayleighTau = 0.008735 * std::pow(wavelengthUm, -4.08) * rayleighAltitudeFactor;

			// Aerosol optical depth from visibility.
			const double aerosolTau = aerosolTau550 * std::pow(wavelengthUm / 0.55, -angstromAlpha);

			const double transmittance = std::exp(-airMass * (rayleighTau + aerosolTau));

			const double spectrum = solar * transmittance;

			const int responseIdx = int(
					(SPECTRUM_WAVELENGTHS[wl] - SPECTRAL_RESPONSE_START) /
					SPECTRAL_RESPONSE_STEP);

			if (0 <= responseIdx && responseIdx < std::size(SPECTRAL_RESPONSE)) {
				X += SPECTRAL_RESPONSE[responseIdx].x * spectrum;
				Y += SPECTRAL_RESPONSE[responseIdx].y * spectrum;
				Z += SPECTRAL_RESPONSE[responseIdx].z * spectrum;
			}
		}

		X *= SPECTRUM_STEP;
		Y *= SPECTRUM_STEP;
		Z *= SPECTRUM_STEP;

		const double sum = X + Y + Z;
		if (sum <= 0.0) {
			return 1900.0;
		}

		const double x = X / sum;
		const double y = Y / sum;

		// McCamy CCT approximation from xy chromaticity.
		// Good enough for driving Godot light_temperature.
		const double n = (x - 0.3320) / (0.1858 - y);
		double cct =
				449.0 * n * n * n +
				3525.0 * n * n +
				6823.3 * n +
				5520.33;

		// Godot light temperature is useful in a practical range.
		// Direct sunlight usually stays roughly inside this range.
		cct = std::clamp(cct, 1500.0, 6500.0);

		return cct;
	}
};

#endif
