@tool
class_name SkyDomeSettings
extends Node

const FOG_SHADER_PATH: String = "res://addons/sky_generator/shaders/atm_fog.gdshader"

var is_scene_built: bool = false
var fog_mesh: MeshInstance3D
var fog_material: ShaderMaterial
var sky_material: ShaderMaterial

var altitude: float = 0.0
var visibility: float = 23.0

const MAX_FOG_FALLOFF = 40;

func update_sun_coords(altitude: float, azimuth: float) -> void:
	if not is_scene_built:
		return
	var sun_direction = _spherical_to_cartesian(altitude, azimuth)
	fog_material.set_shader_parameter("sun_direction", sun_direction)

func update_visibility(visibility_param: float) -> void:
	visibility = visibility_param
	_update_fog_from_atmosphere()

func update_altitude(altitude_param: float) -> void:
	altitude = altitude_param
	_update_fog_from_atmosphere()

func set_sky_material(material: ShaderMaterial) -> void:
	sky_material = material

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_build_scene()

func _build_scene() -> void:
	if is_scene_built:
		return

	fog_mesh = MeshInstance3D.new()
	fog_mesh.name = "_FogMesh"

	var fog_screen_quad := QuadMesh.new()
	fog_screen_quad.size = Vector2(2.0, 2.0)
	fog_mesh.mesh = fog_screen_quad

	fog_material = ShaderMaterial.new()
	fog_material.shader = load(FOG_SHADER_PATH)
	fog_material.render_priority = fog_render_priority

	fog_mesh.material_override = fog_material
	fog_mesh.transform.origin = Vector3.ZERO
	fog_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fog_mesh.custom_aabb = AABB(Vector3(-1e31, -1e31, -1e31), Vector3(2e31, 2e31, 2e31))

	add_child(fog_mesh)

	is_scene_built = true
	_apply_all_parameters()

func _update_fog_from_atmosphere() -> void:
	if not is_scene_built:
		return
		
	var visibility_km: float = max(visibility, 0.1)
	var visibility_factor: float = clamp(23.0 / visibility_km, 0.15, 8.0)

	var altitude_m: float = max(altitude, 0.0)
	var altitude_factor: float = exp(-altitude_m / 2500.0)
	
	var effective_density: float = fog_density * visibility_factor
	var effective_end: float = fog_end / max(visibility_factor, 0.001)
	var effective_rayleigh_depth: float = fog_rayleigh_depth * visibility_factor * altitude_factor
	var effective_mie_depth: float = fog_mie_depth * visibility_factor * altitude_factor
	
	var altitude_t := clamp(altitude / 15000.0, 0.0, 1.0)
	var effective_fog_falloff := lerp(fog_falloff, 50.0, altitude_t)

	fog_material.set_shader_parameter("fog_density", effective_density)
	fog_material.set_shader_parameter("fog_end", effective_end)
	fog_material.set_shader_parameter("fog_rayleigh_depth", effective_rayleigh_depth)
	fog_material.set_shader_parameter("fog_mie_depth", effective_mie_depth)
	fog_material.set_shader_parameter("fog_falloff", effective_fog_falloff)

func _apply_all_parameters() -> void:
	if not is_scene_built:
		return

	fog_mesh.visible = fog_visible
	fog_mesh.layers = fog_layers

	fog_material.render_priority = fog_render_priority

	_update_color_correction(0.0, 1.0)
	
	_update_beta_ray()
	_update_beta_mie()
	_update_sun_mie_phase()

	fog_material.set_shader_parameter("atm_darkness", atm_darkness)
	fog_material.set_shader_parameter("atm_sun_intensity", atm_sun_intensity)
	fog_material.set_shader_parameter("atm_day_tint", atm_day_tint)
	fog_material.set_shader_parameter("atm_horizon_light_tint", horizon_light_tint)
	fog_material.set_shader_parameter("atm_thickness", atm_thickness)
	fog_material.set_shader_parameter("atm_sun_mie_tint", atm_sun_mie_tint)
	fog_material.set_shader_parameter("atm_sun_mie_intensity", atm_sun_mie_intensity)
	fog_material.set_shader_parameter("atm_level_params", atm_level_params + fog_atm_level_params_offset)
	
	fog_material.set_shader_parameter("fog_density", fog_density)
	fog_material.set_shader_parameter("fog_start", fog_start)
	fog_material.set_shader_parameter("fog_end", fog_end)
	fog_material.set_shader_parameter("sea_level", fog_sea_level)
	fog_material.set_shader_parameter("fog_falloff", fog_falloff)
	fog_material.set_shader_parameter("fog_rayleigh_depth", fog_rayleigh_depth)
	fog_material.set_shader_parameter("fog_mie_depth", fog_mie_depth)
	
	_update_fog_from_atmosphere()

func _spherical_to_cartesian(altitude: float, azimuth: float) -> Vector3:
	var cos_alt := cos(altitude)
	return Vector3(
		sin(azimuth) * cos_alt,
		sin(altitude),
		cos(azimuth) * cos_alt
	).normalized()

func _update_color_correction(tonemap_level: float, exposure: float) -> void:
	if is_scene_built:
		fog_material.set_shader_parameter("color_correction", Vector2(tonemap_level, exposure))

#####################
## Atmosphere
#####################
@export_group("Atmosphere")

## Affects the overall color of the sky and fog.
@export var atm_wavelengths := Vector3(680.0, 550.0, 440.0) :
	set(value):
		atm_wavelengths = value
		if is_scene_built:
			_update_beta_ray()

## Higher values darken the atmosphere.
@export_range(0.0, 1.0, 0.01) var atm_darkness: float = 0.5 :
	set(value):
		atm_darkness = value
		if is_scene_built:
			fog_material.set_shader_parameter("atm_darkness", atm_darkness)

## Higher values increase the sun's contribution to the atmosphere.
@export var atm_sun_intensity: float = 18.0 :
	set(value):
		atm_sun_intensity = value
		if is_scene_built:
			fog_material.set_shader_parameter("atm_sun_intensity", atm_sun_intensity)

## Color tint applied to the daytime sky atmosphere.
@export var atm_day_tint := Color(0.807843, 0.909804, 1.0) :
	set(value):
		atm_day_tint = value
		if is_scene_built:
			fog_material.set_shader_parameter("atm_day_tint", atm_day_tint)

@export_range(0.0, 100.0, 0.01) var atm_thickness: float = 0.5:
	set(value):
		atm_thickness = value
		if is_scene_built:
			fog_material.set_shader_parameter("atm_thickness", atm_thickness)

## Sets the Mie scattering: the haze and white light diffusion around the sun.
@export var atm_mie: float = 0.07 :
	set(value):
		atm_mie = value
		_update_beta_mie()

## Sets the multiplier for [member atm_mie].
@export var atm_turbidity: float = 0.001 :
	set(value):
		atm_turbidity = value
		_update_beta_mie()

## Color tint of the Mie scattering around the sun.
@export var atm_sun_mie_tint := Color(1.0, 1.0, 1.0, 1.0) :
	set(value):
		atm_sun_mie_tint = value
		if is_scene_built:
			fog_material.set_shader_parameter("atm_sun_mie_tint", atm_sun_mie_tint)

## Sets the intensity of the Mie scattering around the sun.
@export var atm_sun_mie_intensity: float = 1.0 :
	set(value):
		atm_sun_mie_intensity = value
		if is_scene_built:
			fog_material.set_shader_parameter("atm_sun_mie_intensity", atm_sun_mie_intensity)
			
## Controls the directional bias (shape) of the Mie scattering around the sun.
@export_range(0.0, 0.9999999, 0.0000001) var atm_sun_mie_anisotropy: float = 0.8 :
	set(value):
		atm_sun_mie_anisotropy = value
		if is_scene_built:
			_update_sun_mie_phase()

## These parameters fine-tune the vertical distribution of atmospheric scattering in the shader.
## X scales the height of Mie scattering layers (haze closer to the ground)
## Y scales Rayleigh scattering layers (bluer sky higher up)
## Z acts as a ground-level offset to adjust where the atmosphere "starts" relative to the horizon.
@export var atm_level_params := Vector3(1.0, 0.0, 0.0) :
	set(value):
		atm_level_params = value
		if is_scene_built:
			fog_material.set_shader_parameter("atm_level_params", atm_level_params + fog_atm_level_params_offset)
			
func _update_beta_mie() -> void:
	if is_scene_built:
		var bm: Vector3 = ScatterLib.compute_beta_mie(atm_mie, atm_turbidity)
		fog_material.set_shader_parameter("atm_beta_mie", bm)

func _update_beta_ray() -> void:
	if not is_scene_built:
		return

	var wll: Vector3 = ScatterLib.compute_wavelenghts_lambda(atm_wavelengths)
	var wls: Vector3 = ScatterLib.compute_wavelenghts(wll)
	var beta_ray: Vector3 = ScatterLib.compute_beta_ray(wls)

	fog_material.set_shader_parameter("atm_beta_ray", beta_ray)
	
func _update_sun_mie_phase() -> void:
	if not is_scene_built:
		return

	var partial: Vector3 = ScatterLib.get_partial_mie_phase(atm_sun_mie_anisotropy)
	fog_material.set_shader_parameter("atm_sun_partial_mie_phase", partial)
	
#####################
## Sun
#####################
@export_group("Sun")

## Size of the visible sun disk in the sky shader.
@export_range(0.0, 0.5, 0.001)
var sun_disk_size: float = 0.015:
	set(value):
		sun_disk_size = value
		if sky_material:
			sky_material.set_shader_parameter("sun_disk_size", sun_disk_size)

## Color of the visible sun disk.
@export var sun_disk_color: Color = Color(0.996, 0.541, 0.14, 1.0):
	set(value):
		sun_disk_color = value
		if sky_material:
			sky_material.set_shader_parameter("sun_disk_color", sun_disk_color)

## Color tint applied to atmosphere during sunrise and sunset.
@export var horizon_light_tint: Color = Color(1.0, 0.45, 0.05, 1.0):
	set(value):
		horizon_light_tint = value
		if sky_material:
			sky_material.set_shader_parameter("horizon_light_tint", horizon_light_tint)

		if is_scene_built:
			fog_material.set_shader_parameter("atm_horizon_light_tint", horizon_light_tint)

## Brightness multiplier of the visible sun disk.
@export_range(0.0, 100.0, 0.01)
var sun_disk_intensity: float = 2.0:
	set(value):
		sun_disk_intensity = value
		if sky_material:
			sky_material.set_shader_parameter("sun_disk_intensity", sun_disk_intensity)

## Controls the sharp bright aureole around the sun.
## Higher values make the aureole smaller/sharper.
@export_range(1.0, 300.0, 0.1)
var sun_aureole_size: float = 135.0:
	set(value):
		sun_aureole_size = value
		if sky_material:
			sky_material.set_shader_parameter("sun_aureole_size", sun_aureole_size)

## Size of the larger soft glow around the sun.
@export_range(0.0, 1.0, 0.001)
var soft_glow_size: float = 0.09:
	set(value):
		soft_glow_size = value
		if sky_material:
			sky_material.set_shader_parameter("soft_glow_size", soft_glow_size)

## Intensity of the larger soft glow around the sun.
@export_range(0.0, 10.0, 0.001)
var soft_glow_intensity: float = 0.03:
	set(value):
		soft_glow_intensity = value
		if sky_material:
			sky_material.set_shader_parameter("soft_glow_intensity", soft_glow_intensity)

## Width of the fade when the sun approaches the horizon.
@export_range(0.0, 1.0, 0.001)
var sun_horizon_fade_width: float = 0.03:
	set(value):
		sun_horizon_fade_width = value
		if sky_material:
			sky_material.set_shader_parameter("sun_horizon_fade_width", sun_horizon_fade_width)

#####################
## Fog
#####################
@export_group("Fog")

@export var fog_visible: bool = true:
	set(value):
		fog_visible = value
		if is_scene_built:
			fog_mesh.visible = fog_visible

@export_exp_easing() var fog_density: float = 0.0007:
	set(value):
		fog_density = value
		_update_fog_from_atmosphere()

@export_range(0.0, 5000.0) var fog_start: float = 0.0:
	set(value):
		fog_start = value
		_update_fog_from_atmosphere()

@export_range(0.0, 5000.0) var fog_end: float = 1000.0:
	set(value):
		fog_end = value
		_update_fog_from_atmosphere()

@export_range(-2048.0, 2048.0) var fog_sea_level: float = 0.0:
	set(value):
		fog_sea_level = value
		if is_scene_built:
			fog_material.set_shader_parameter("sea_level", fog_sea_level)

@export_range(0.0, 50, 0.01, "or_greater") var fog_falloff: float = 3.0:
	set(value):
		fog_falloff = value
		if is_scene_built:
			fog_material.set_shader_parameter("fog_falloff", fog_falloff)

@export_exp_easing() var fog_rayleigh_depth: float = 0.115:
	set(value):
		fog_rayleigh_depth = value
		if is_scene_built:
			fog_material.set_shader_parameter("fog_rayleigh_depth", fog_rayleigh_depth)

@export_exp_easing() var fog_mie_depth: float = 0.0001:
	set(value):
		fog_mie_depth = value
		_update_fog_from_atmosphere()

@export var fog_atm_level_params_offset := Vector3(0.0, 0.0, -1.0):
	set(value):
		fog_atm_level_params_offset = value
		if is_scene_built:
			fog_material.set_shader_parameter(
				"atm_level_params",
				atm_level_params + fog_atm_level_params_offset
			)

@export_flags_3d_render var fog_layers: int = 524288:
	set(value):
		fog_layers = value
		if is_scene_built:
			fog_mesh.layers = fog_layers

@export var fog_render_priority: int = 100:
	set(value):
		fog_render_priority = value
		if is_scene_built:
			fog_material.render_priority = fog_render_priority
