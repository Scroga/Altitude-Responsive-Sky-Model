@tool

class_name SkyModel
extends WorldEnvironment

## Emitted when the environment has changed to a new resource.
signal environment_changed

const SKY_SHADER_PATH: String = "res://addons/sky_generator/shaders/sky_material.gdshader"
const SKY_PARAMETERS_SCRIPT: Script = preload("res://addons/sky_generator/src/parameters.gd")
const SKY_DOME_SETTINGS_SCRIPT: Script = preload("res://addons/sky_generator/src/sky_dome_settings.gd")

## The Sun DirectionalLight.
var sun: DirectionalLight3D
## The Sky shader.
var sky_material: ShaderMaterial
# The sky texture generator.
var sky_texture_generator: SkyTextureGenerator
# Node that specifies the altitude at runtime.
var altitude_source: Node3D
# Parameters for sky texture generation.
var parameters: SkyParameters = SKY_PARAMETERS_SCRIPT.new()
# Sky dome for fog and sun.
var sky_dome_settings: SkyDomeSettings

#####################
## Helper
#####################
func _build_precomputed_texture_array(images: Array[Image]) -> Texture2DArray:
	if images.is_empty():
		push_error("Cannot create Texture2DArray: image array is empty.")
		return null

	var texture_array := Texture2DArray.new()
	var err: Error = texture_array.create_from_images(images)

	if err != OK:
		push_error("Failed to create Texture2DArray. Error code: " + str(err))
		return null

	return texture_array

#####################
## Texture Generation
#####################
@export_group("Dataset Loading")

@export_global_file("*.dat")
var dataset_path: String = "SkyModelDataset.dat"

@export_enum(
	"20.0 - 27.6",
	"27.6 - 40.0",
	"40.0 - 59.4",
	"59.4 - 90.0",
	"90.0 - 131.8")
var visibility_range := 0

func _read_dataset() -> void:
	if sky_texture_generator == null:
		push_error("sky_texture_generator is null")
		return

	var single_visibility := 0.0
	match visibility_range:
		0: single_visibility = 23.8
		1: single_visibility = 33.8
		2: single_visibility = 49.7
		3: single_visibility = 74.7
		4: single_visibility = 110.9
		_: single_visibility = 0.0
		
	sky_texture_generator.read_dataset(dataset_path, single_visibility)

	parameters.set_generator(sky_texture_generator)
	parameters.clamp_to_generator()
	notify_property_list_changed()

@export_tool_button("Read Dataset")
var read_dataset_button = _read_dataset

#####################
## Precomputed Data
#####################
@export_group("Precomputed Data")
@export var precomputed_textures: Array[Image] = []
@export var precomputed_altitudes: PackedFloat32Array = PackedFloat32Array()

#####################
## Runtime Altitude
#####################
@export_group("Runtime Altitude")

@export_node_path("Node3D")
var altitude_source_path: NodePath

var player_altitude: float = 0.0

@export var altitude_offset: float = 0.0

@export var altitude_scale: float = 1.0

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
		
@export var sun_visible: bool = true:
	set(value):
		sun_visible = value
		if sky_material:
			sky_material.set_shader_parameter("sun_visible", sun_visible)

@export var sky_visible: bool = true:
	set(value):
		sky_visible = value
		if sky_material:
			sky_material.set_shader_parameter("sky_visible", sky_visible)
			
@export var fog_visible: bool = true:
	set(value):
		fog_visible = value
		if sky_dome_settings:
			sky_dome_settings.fog_visible = fog_visible
			
#####################
## Sun Light
#####################
func _update_sun() -> void:
	_update_sun_rotation()
	_update_sun_temperature()
	sky_dome_settings.update_sun_coords(
		deg_to_rad(parameters.get_elevation()), 
		deg_to_rad(azimuth))

func _update_sun_rotation() -> void:
	if sun == null:
		return

	var azimuth_rad := deg_to_rad(azimuth)
	var elevation_rad := deg_to_rad(parameters.get_elevation())

	if sky_material:
		sky_material.set_shader_parameter("azimuth_rad", azimuth_rad)
		sky_material.set_shader_parameter("elevation_rad", elevation_rad)

	# Y-up Godot direction.
	var sun_direction := Vector3(
		cos(elevation_rad) * sin(azimuth_rad),
		sin(elevation_rad),
		cos(elevation_rad) * cos(azimuth_rad)
	).normalized()

	# DirectionalLight3D emits along local -Z, so it must look opposite to sun_direction.
	var look_direction := -sun_direction

	var up := Vector3.UP
	if abs(look_direction.dot(up)) > 0.999:
		up = Vector3.FORWARD
		
	if sun.is_inside_tree():
		sun.look_at(sun.global_position - sun_direction, up)
	else:
		sun.look_at_from_position(Vector3.ZERO, -sun_direction, up)

func _update_sun_temperature() -> void:
	if sun == null:
		return

	if sky_texture_generator == null:
		return

	var altitude := parameters.get_altitude()

	if altitude_source_path != null:
		altitude = player_altitude

	var temperature := SkyModelUtils.compute_sun_light_temperature(
		parameters.get_elevation(),
		altitude,
		parameters.get_visibility()
	)
	sun.light_temperature = temperature
	sun.light_color = Color.WHITE

#####################
## Fog
#####################
func _update_fog() -> void:
	sky_dome_settings.update_altitude(parameters.get_altitude())
	sky_dome_settings.update_visibility(parameters.get_visibility())
	
#####################
## Texture Generation
#####################
func _generate_textures_for_altitudes() -> void:
	if sky_texture_generator == null:
		push_error("sky_texture_generator is null")
		return

	if sky_material == null:
		push_error("sky_material is null")
		return
		
	var texture_count: int = parameters.get_precomputed_texture_count()
	var min_altitude: float = parameters.get_altitude_min()
	var max_altitude: float = parameters.get_max_precompute_altitude()
		
	#precomputed_altitudes = SkyModelUtils.generate_linear_altitudes(min_altitude, max_altitude, texture_count)
	precomputed_altitudes = SkyModelUtils.generate_non_linear_altitudes(
		min_altitude, 
		max_altitude, 
		texture_count, 
		parameters.get_altitude_density_power())
	
	precomputed_textures.clear()
	for i in range(0, texture_count):
		var altitude = precomputed_altitudes[i]
		var image: Image = sky_texture_generator.generate_texture(
			parameters.get_albedo(),
			altitude,
			parameters.get_elevation(),
			parameters.get_visibility(),
			parameters.get_resolution()
		)

		if image == null:
			push_error("Failed to generate sky texture for altitude: " + str(altitude))
			continue

		precomputed_textures.append(image)
		
	if precomputed_textures.is_empty():
		push_error("No sky texture images were generated.")
		return

	var precomputed_texture_array: Texture2DArray = _build_precomputed_texture_array(precomputed_textures);
	if (precomputed_texture_array == null): return
	
	sky_material.set_shader_parameter("precomputed_textures_array", precomputed_texture_array)
	sky_material.set_shader_parameter("precomputed_altitudes", precomputed_altitudes)
	sky_material.set_shader_parameter("precomputed_texture_count", texture_count)
	sky_material.set_shader_parameter("precomputed_altitude_min", min_altitude)
	sky_material.set_shader_parameter("precomputed_altitude_max", max_altitude)
	sky_material.set_shader_parameter("altitude", parameters.get_altitude())

	_update_sun()
	_update_fog()
	
	print("%d textures were precomputed." % texture_count)

#####################
## Setup
#####################
func _apply_precomputed_textures_runtime() -> void:
	if sky_material == null:
		return
	if precomputed_textures.is_empty():
		print("No textures where precomputed.")
		return
	if precomputed_altitudes.is_empty():
		print("No altitudes where precomputed.")
		return

	var texture_count: int = parameters.get_precomputed_texture_count()
		
	var min_altitude: float = parameters.get_altitude_min()
	var max_altitude: float = parameters.get_max_precompute_altitude()
	
	var precomputed_texture_array: Texture2DArray = _build_precomputed_texture_array(precomputed_textures);
	if (precomputed_texture_array == null): return
		
	sky_material.set_shader_parameter("precomputed_textures_array", precomputed_texture_array)
	sky_material.set_shader_parameter("precomputed_altitudes", precomputed_altitudes)
	sky_material.set_shader_parameter("precomputed_texture_count", texture_count)
	sky_material.set_shader_parameter("precomputed_altitude_min", min_altitude)
	sky_material.set_shader_parameter("precomputed_altitude_max", max_altitude)
	sky_material.set_shader_parameter("altitude", parameters.get_altitude())

	if altitude_source_path != null:
		_read_player_altitude()
	else:
		sky_material.set_shader_parameter("altitude", parameters.get_altitude())

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
		environment.sky.sky_material.shader = load(SKY_SHADER_PATH)
		
	# Set a reference to the sky material for easy access.
	sky_material = environment.sky.sky_material
		
	if sky_texture_generator != null:
		parameters.set_generator(sky_texture_generator)
	
	# Create default camera attributes
	if camera_attributes == null:
		camera_attributes = CameraAttributesPractical.new()
	
	if has_node("SkyDomeSettings"):
		sky_dome_settings = $SkyDomeSettings
		sky_dome_settings.set_sky_material(sky_material)
	elif is_inside_tree():
		sky_dome_settings = SKY_DOME_SETTINGS_SCRIPT.new()
		sky_dome_settings.set_sky_material(sky_material)
		sky_dome_settings.name = "SkyDomeSettings"
		add_child(sky_dome_settings, true)
		if get_tree().edited_scene_root:
			sky_dome_settings.owner = get_tree().edited_scene_root
	
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
	
	if sky_texture_generator != null:
		parameters.set_generator(sky_texture_generator)
	
	_update_sun()
	_update_fog()

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_apply_precomputed_textures_runtime()
		
	_update_sun()
	_update_fog()

func _read_player_altitude() -> void:
	if altitude_source_path == null:
		return
	
	if altitude_source == null:
		if altitude_source_path != NodePath():
			altitude_source = get_node_or_null(altitude_source_path) as Node3D

		if altitude_source == null:
			return

	var source_altitude: float = altitude_source.global_position.y
	var sky_altitude: float = source_altitude * altitude_scale + altitude_offset
	player_altitude = clampf(sky_altitude, parameters.get_altitude_min(), parameters.get_max_precompute_altitude())
	
	if sky_material:
		sky_material.set_shader_parameter("altitude", player_altitude)
	if sky_dome_settings:
		sky_dome_settings.update_altitude(player_altitude)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): 
		return
		
	_read_player_altitude();

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	if sky_texture_generator == null:
		return properties

	parameters.set_generator(sky_texture_generator)

	if not parameters.is_available():
		return properties
	
	
	# Sky settings
	properties.append({
		"name": "Sky Settings",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP
	})

	properties.append(_range_float_property(
		"albedo",
		parameters.get_albedo_min(),
		parameters.get_albedo_max(),
		0.001
	))

	properties.append(_range_float_property(
		"altitude",
		parameters.get_altitude_min(),
		parameters.get_altitude_max(),
		1.0,
		"suffix:m"
	))

	properties.append(_range_float_property(
		"elevation",
		parameters.get_elevation_min(),
		parameters.get_elevation_max(),
		0.1,
		"degrees"
	))

	properties.append(_range_float_property(
		"visibility",
		parameters.get_visibility_min(),
		parameters.get_visibility_max(),
		0.1,
		"suffix:km"
	))

	properties.append({
		"name": "resolution",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "%d,%d,1" % [parameters.get_resolution_min(), parameters.get_resolution_max()],
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	# Precompute settings
	properties.append({
		"name": "Precompute Settings",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP
	})
	
	properties.append(_range_float_property(
		"max_precompute_altitude",
		parameters.get_altitude_min(),
		parameters.get_altitude_max(),
		1.0,
		"suffix:m"
	))

	properties.append({
		"name": "precomputed_texture_count",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "%d,%d,1" % [
			parameters.get_texture_count_min(),
			parameters.get_texture_count_max()
		],
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append(_range_float_property(
		"altitude_density_power",
		parameters.get_altitude_density_power_min(),
		parameters.get_altitude_density_power_max(),
		0.01
	))
	
	properties.append({
		"name": "precompute_sky_textures",
		"type": TYPE_CALLABLE,
		"hint": PROPERTY_HINT_TOOL_BUTTON,
		"hint_string": "Precompute Sky Textures",
		"usage": PROPERTY_USAGE_EDITOR
	})
	
	return properties

func _property_can_revert(property: StringName) -> bool:
	match String(property):
		"albedo", \
		"altitude", \
		"elevation", \
		"visibility", \
		"resolution", \
		"max_precompute_altitude", \
		"precomputed_texture_count", \
		"altitude_density_power":
			return true

	return false

func _property_get_revert(property: StringName) -> Variant:
	match String(property):
		"albedo":
			return SkyParameters.DEFAULT_ALBEDO
		"altitude":
			return SkyParameters.DEFAULT_ALTITUDE
		"elevation":
			return SkyParameters.DEFAULT_ELEVATION
		"visibility":
			return parameters.get_visibility_min()
		"resolution":
			return SkyParameters.DEFAULT_RESOLUTION
		"max_precompute_altitude":
			return SkyParameters.MAX_ALTITUDE
		"precomputed_texture_count":
			return SkyParameters.DEFAULT_PRECOMPUTED_TEXTURE_COUNT
		"altitude_density_power":
			return SkyParameters.DEFAULT_ALTITUDE_DENSITY_POWER
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
			return parameters.get_albedo()
		"altitude":
			return parameters.get_altitude()
		"elevation":
			return parameters.get_elevation()
		"visibility":
			return parameters.get_visibility()
		"resolution":
			return parameters.get_resolution()
		"max_precompute_altitude":
			return parameters.get_max_precompute_altitude()
		"precomputed_texture_count":
			return parameters.get_precomputed_texture_count()
		"altitude_density_power":
			return parameters.get_altitude_density_power()
		"precompute_sky_textures":
			return _generate_textures_for_altitudes
	return null

func _set(property: StringName, value: Variant) -> bool:
	match String(property):
		"albedo":
			parameters.set_albedo(value)
			return true
		"altitude":
			parameters.set_altitude(value)
			if sky_material:
				sky_material.set_shader_parameter("altitude", parameters.get_altitude())
			if sky_dome_settings:
				sky_dome_settings.update_altitude(parameters.get_altitude())
				
			return true
		"elevation":
			parameters.set_elevation(value)
			return true
		"visibility":
			parameters.set_visibility(value)
			return true
		"resolution":
			parameters.set_resolution(value)
			return true
		"max_precompute_altitude":
			parameters.set_max_precompute_altitude(value)
			return true
		"precomputed_texture_count":
			parameters.set_precomputed_texture_count(value)
			return true
		"altitude_density_power":
			parameters.set_altitude_density_power(value)
			return true
		"environment":
			#sky.environment = value
			environment = value
			emit_signal("environment_changed", environment)
			return true

	return false
