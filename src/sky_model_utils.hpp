#ifndef SKY_MODEL_UTILS_HPP
#define SKY_MODEL_UTILS_HPP

#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/typed_array.hpp>

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
};

#endif
