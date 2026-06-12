@tool

class_name SkyModel
extends WorldEnvironment

## Emitted when the environment has changed to a new resource.
signal environment_changed

const SKY_SHADER: String = "res://addons/sky_generator/shaders/sky_material.gdshader"

## The Sun DirectionalLight.
var sun: DirectionalLight3D
## The Sky shader.
var sky_material: ShaderMaterial
# The sky texture generator
var sky_texture_generator: SkyTextureGenerator

const DEFAULT_ALBEDO := 0.5
const DEFAULT_ALTITUDE := 0.0
const DEFAULT_ELEVATION := 0.0
const DEFAULT_VISIBILITY := 59.4
const DEFAULT_RESOLUTION := 512

#####################
## Helpers
#####################
func _get_albedo_min() -> float:
	return sky_texture_generator.albedo_min if sky_texture_generator != null else 0.0
func _get_albedo_max() -> float:
	return sky_texture_generator.albedo_max if sky_texture_generator != null else 1.0
func _get_altitude_min() -> float:
	return sky_texture_generator.altitude_min if sky_texture_generator != null else 0.0
func _get_altitude_max() -> float:
	return sky_texture_generator.altitude_max if sky_texture_generator != null else 15000.0
func _get_elevation_min() -> float:
	return sky_texture_generator.elevation_min if sky_texture_generator != null else -4.2
func _get_elevation_max() -> float:
	return sky_texture_generator.elevation_max if sky_texture_generator != null else 90.0
func _get_visibility_min() -> float:
	return sky_texture_generator.visibility_min if sky_texture_generator != null else 20.0
func _get_visibility_max() -> float:
	return sky_texture_generator.visibility_max if sky_texture_generator != null else 131.8
func _get_resolution_min() -> int:
	return sky_texture_generator.resolution_min if sky_texture_generator != null else 128
func _get_resolution_max() -> int:
	return sky_texture_generator.resolution_max if sky_texture_generator != null else 4096

func _clamp_sky_parameters() -> void:
	_albedo = clampf(_albedo, _get_albedo_min(), _get_albedo_max())
	_altitude = clampf(_altitude, _get_altitude_min(), _get_altitude_max())
	_elevation = clampf(_elevation, _get_elevation_min(), _get_elevation_max())
	_visibility = clampf(_visibility, _get_visibility_min(), _get_visibility_max())
	_resolution = clampi(_resolution, _get_resolution_min(), _get_resolution_max())

func _visibility_range_to_value(index: int) -> float:
	match index:
		0: return 23.8
		1: return 33.8
		2: return 49.7
		3: return 74.7
		4: return 110.9
		_: return 0.0

#####################
## Texture Generation
#####################
@export_group("Texture Generation")

@export_global_file("*.dat")
var dataset_path: String = "SkyModelDataset.dat"

@export_enum(
	"20.0 - 27.6",
	"27.6 - 40.0",
	"40.0 - 59.4",
	"59.4 - 90.0",
	"90.0 - 131.8")
var visibility_range := 0

# Backing fields for dynamic inspector properties.
var _albedo: float = 0.5
var _altitude: float = 0.0
var _elevation: float = 0.0
var _visibility: float = 59.4
var _resolution: int = 512

func _read_dataset() -> void:
	if sky_texture_generator == null:
		push_error("sky_texture_generator is null")
		return

	var single_visibility := _visibility_range_to_value(visibility_range)

	sky_texture_generator.read_dataset(dataset_path, single_visibility)

	_clamp_sky_parameters()
	notify_property_list_changed()

func _generate_texture() -> void:
	if sky_texture_generator == null:
		push_error("sky_texture_generator is null")
		return

	if sky_material == null:
		push_error("sky_material is null")
		return

	var image: Image = sky_texture_generator.generate(
		_albedo,
		_altitude,
		_elevation,
		_visibility,
		_resolution
	)

	if image == null:
		push_error("Sky image generation failed.")
		return

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	
	sky_material.set_shader_parameter("sky_texture", texture)
	sky_material.set_shader_parameter("altitude", _altitude)
	
	_update_sun()

@export_tool_button("Read Dataset")
var read_dataset_button = _read_dataset

#####################
## Display
#####################
@export_group("Display")

@export_range(-10.0, 10.0, 0.1)
var exposure: float = -5.0:
	set(value):
		exposure = value
		if sky_material:
			sky_material.set_shader_parameter("exposure", exposure)
			
@export_range(0.0, 360.0, 0.1, "degrees")
var azimuth: float = 0.0:
	set(value):
		azimuth = value
		_update_sun()

#####################
## Sun Light
#####################

func _update_sun() -> void:
	_update_sun_rotation()

func _update_sun_rotation() -> void:
	if sun == null:
		return

	var azimuth_rad := deg_to_rad(azimuth)
	var elevation_rad := deg_to_rad(_elevation)

	if sky_material:
		sky_material.set_shader_parameter("azimuth_rad", azimuth_rad)
		sky_material.set_shader_parameter("elevation_rad", elevation_rad)

	# Y-up Godot direction.
	var sun_direction := Vector3(
		cos(elevation_rad) * sin(azimuth_rad),
		sin(elevation_rad),
		cos(elevation_rad) * cos(azimuth_rad)
	).normalized()

# DirectionalLight3D emits along local -Z.
	if sun.is_inside_tree():
		sun.look_at(sun.global_position - sun_direction, Vector3.UP)
	else:
		sun.look_at_from_position(Vector3.ZERO, -sun_direction, Vector3.UP)

#####################
## Setup
#####################

func _notification(what: int) -> void:
	# Must be after _init and before _enter_tree to properly set vars like 'sky' for setters
	if what in [ NOTIFICATION_SCENE_INSTANTIATED, NOTIFICATION_ENTER_TREE ]:
		_initialize()

func _initialize() -> void:
	# Create default environment
	if environment == null:
		environment = Environment.new()
		environment.background_mode = Environment.BG_SKY
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		environment.ambient_light_sky_contribution = 0.7
		environment.ambient_light_energy = 1.0
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		environment.tonemap_mode = Environment.TONE_MAPPER_ACES
		environment.tonemap_white = 6
		emit_signal("environment_changed", environment)
		
	# Setup Sky material & Upgrade old
	if environment.sky == null or environment.sky.sky_material is PhysicalSkyMaterial:
		environment.sky = Sky.new()
		environment.sky.sky_material = ShaderMaterial.new()
		environment.sky.sky_material.shader = load(SKY_SHADER)
		
	# Set a reference to the sky material for easy access.
	sky_material = environment.sky.sky_material
		
	# Create default camera attributes
	if camera_attributes == null:
		camera_attributes = CameraAttributesPractical.new()
	
	if has_node("SkyTextureGenerator"):
		sky_texture_generator = $SkyTextureGenerator
	elif is_inside_tree():
		sky_texture_generator = SkyTextureGenerator.new()
		add_child(sky_texture_generator, true)
		sky_texture_generator.owner = get_tree().edited_scene_root
		
	if has_node("SunLight"):
		sun = $SunLight
	elif is_inside_tree():
		sun = DirectionalLight3D.new()
		sun.name = "SunLight"
		add_child(sun, true)
		sun.owner = get_tree().edited_scene_root
		sun.shadow_enabled = true
	_update_sun()

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	if sky_texture_generator == null:
		return properties

	if not sky_texture_generator.is_initialized:
		return properties
		
	properties.append({
		"name": "Sky Parameters",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP
	})

	properties.append(_range_float_property(
		"albedo",
		_get_albedo_min(),
		_get_albedo_max(),
		0.001
	))

	properties.append(_range_float_property(
		"altitude",
		_get_altitude_min(),
		_get_altitude_max(),
		1.0,
		"suffix:m"
	))

	properties.append(_range_float_property(
		"elevation",
		_get_elevation_min(),
		_get_elevation_max(),
		0.1,
		"degrees"
	))

	properties.append(_range_float_property(
		"visibility",
		_get_visibility_min(),
		_get_visibility_max(),
		0.1,
		"suffix:km"
	))

	properties.append({
		"name": "resolution",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "%d,%d,1" % [_get_resolution_min(), _get_resolution_max()],
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "generate_sky_texture",
		"type": TYPE_CALLABLE,
		"hint": PROPERTY_HINT_TOOL_BUTTON,
		"hint_string": "Generate Sky Texture",
		"usage": PROPERTY_USAGE_EDITOR
	})

	
	return properties

func _property_can_revert(property: StringName) -> bool:
	match String(property):
		"albedo", "altitude", "elevation", "visibility", "resolution":
			return true

	return false


func _property_get_revert(property: StringName) -> Variant:
	match String(property):
		"albedo":
			return DEFAULT_ALBEDO
		"altitude":
			return DEFAULT_ALTITUDE
		"elevation":
			return DEFAULT_ELEVATION
		"visibility":
			return (_get_visibility_max() + _get_visibility_min()) / 2
		"resolution":
			return DEFAULT_RESOLUTION

	return null

func _range_float_property(
		property_name: String,
		min_value: float,
		max_value: float,
		step: float,
		extra_hint := "") -> Dictionary:
	var hint_string := "%f,%f,%f" % [min_value, max_value, step]

	if extra_hint != "":
		hint_string += "," + extra_hint

	return {
		"name": property_name,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": hint_string,
		"usage": PROPERTY_USAGE_DEFAULT
	}

func _get(property: StringName) -> Variant:
	match String(property):
		"albedo":
			return _albedo
		"altitude":
			return _altitude
		"elevation":
			return _elevation
		"visibility":
			return _visibility
		"resolution":
			return _resolution
		"generate_sky_texture":
			return _generate_texture
	return null

func _set(property: StringName, value: Variant) -> bool:
	match String(property):
		"albedo":
			_albedo = clampf(value, _get_albedo_min(), _get_albedo_max())
			return true

		"altitude":
			_altitude = clampf(value, _get_altitude_min(), _get_altitude_max())
			return true

		"elevation":
			_elevation = clampf(value, _get_elevation_min(), _get_elevation_max())
			return true

		"visibility":
			_visibility = clampf(value, _get_visibility_min(), _get_visibility_max())
			return true

		"resolution":
			_resolution = clampi(value, _get_resolution_min(), _get_resolution_max())
			return true
		"environment":
			#sky.environment = value
			environment = value
			emit_signal("environment_changed", environment)
			return true

	return false
