class_name SkyParameters
extends RefCounted

const DEFAULT_ALBEDO := 0.5
const DEFAULT_ALTITUDE := 0.0
const DEFAULT_ELEVATION := 0.0
const DEFAULT_VISIBILITY := 59.4
const DEFAULT_RESOLUTION := 512

const MAX_ALTITUDE := 15000.0
const MAX_TEXTURES_COUNT = 32
const DEFAULT_PRECOMPUTED_TEXTURE_COUNT := 5
const DEFAULT_ALTITUDE_DENSITY_POWER := 2.0

var _generator: SkyTextureGenerator = null

var _albedo: float = DEFAULT_ALBEDO
var _altitude: float = DEFAULT_ALTITUDE
var _elevation: float = DEFAULT_ELEVATION
var _visibility: float = DEFAULT_VISIBILITY
var _resolution: int = DEFAULT_RESOLUTION

var _max_precompute_altitude: float = MAX_ALTITUDE
var _precomputed_texture_count: int = DEFAULT_PRECOMPUTED_TEXTURE_COUNT
var _altitude_density_power: float = DEFAULT_ALTITUDE_DENSITY_POWER

func set_generator(generator: SkyTextureGenerator) -> void:
	_generator = generator
	clamp_to_generator()

func has_generator() -> bool:
	return _generator != null

func is_available() -> bool:
	return _generator != null and _generator.is_initialized

func clamp_to_generator(generator: SkyTextureGenerator = null) -> void:
	if generator != null:
		_generator = generator

	if _generator == null:
		return

	_albedo = clampf(_albedo, get_albedo_min(), get_albedo_max())
	_altitude = clampf(_altitude, get_altitude_min(), get_altitude_max())
	_elevation = clampf(_elevation, get_elevation_min(), get_elevation_max())
	_visibility = clampf(_visibility, get_visibility_min(), get_visibility_max())
	_resolution = clampi(_resolution, get_resolution_min(), get_resolution_max())

#####################
## Sky Parameters
#####################
func set_albedo(value: float) -> void:
	_albedo = clampf(value, get_albedo_min(), get_albedo_max())

func get_albedo() -> float:
	return _albedo

func set_altitude(value: float) -> void:
	_altitude = clampf(value, get_altitude_min(), get_altitude_max())

func get_altitude() -> float:
	return _altitude

func set_elevation(value: float) -> void:
	_elevation = clampf(value, get_elevation_min(), get_elevation_max())

func get_elevation() -> float:
	return _elevation

func set_visibility(value: float) -> void:
	_visibility = clampf(value, get_visibility_min(), get_visibility_max())

func get_visibility() -> float:
	return _visibility

func set_resolution(value: int) -> void:
	_resolution = clampi(value, get_resolution_min(), get_resolution_max())

func get_resolution() -> int:
	return _resolution

#####################
## Precompute Parameters
#####################
func set_max_precompute_altitude(value: float) -> void:
	_max_precompute_altitude = clampf(value, get_altitude_min(), get_altitude_max())

func get_max_precompute_altitude() -> float:
	return _max_precompute_altitude
	
func set_precomputed_texture_count(value: int) -> void:
	_precomputed_texture_count = clampi(value, get_texture_count_min(), get_texture_count_max())

func get_precomputed_texture_count() -> int:
	return _precomputed_texture_count
	
func set_altitude_density_power(value: float) -> void:
	_altitude_density_power = clampf(value, get_altitude_density_power_min(), get_altitude_density_power_max())

func get_altitude_density_power() -> float:
	return _altitude_density_power
#####################
## Parameter Limits
#####################
func get_albedo_min() -> float:
	return _generator.albedo_min if _generator != null else 0.0

func get_albedo_max() -> float:
	return _generator.albedo_max if _generator != null else 1.0

func get_altitude_min() -> float:
	return _generator.altitude_min if _generator != null else 0.0

func get_altitude_max() -> float:
	return _generator.altitude_max if _generator != null else MAX_ALTITUDE

func get_elevation_min() -> float:
	return _generator.elevation_min if _generator != null else -4.2

func get_elevation_max() -> float:
	return _generator.elevation_max if _generator != null else 90.0

func get_visibility_min() -> float:
	return _generator.visibility_min if _generator != null else 20.0

func get_visibility_max() -> float:
	return _generator.visibility_max if _generator != null else 131.8

func get_resolution_min() -> int:
	return _generator.resolution_min if _generator != null else 128

func get_resolution_max() -> int:
	return _generator.resolution_max if _generator != null else 4096

func get_texture_count_min() -> int:
	return 1

func get_texture_count_max() -> int:
	return MAX_TEXTURES_COUNT
	
func get_altitude_density_power_min() -> float:
	return 0.0
	
func get_altitude_density_power_max() -> float:
	return 4.0
