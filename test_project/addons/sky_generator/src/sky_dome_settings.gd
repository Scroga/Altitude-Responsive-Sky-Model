@tool
class_name SkyDomeSettings
extends Node

const FOG_SHADER: String = "res://addons/sky_generator/shaders/atm_fog.gdshader"

var is_scene_built: bool = false
var fog_mesh: MeshInstance3D
var fog_material: ShaderMaterial

var _sun_direction: Vector3 = Vector3.UP

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
	fog_material.shader = load(FOG_SHADER)
	fog_material.render_priority = fog_render_priority

	fog_mesh.material_override = fog_material
	fog_mesh.transform.origin = Vector3.ZERO
	fog_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fog_mesh.custom_aabb = AABB(
		Vector3(-1e31, -1e31, -1e31),
		Vector3(2e31, 2e31, 2e31)
	)

	add_child(fog_mesh)

	is_scene_built = true
	_apply_all_parameters()


func _apply_all_parameters() -> void:
	if not is_scene_built:
		return

	fog_mesh.visible = fog_visible
	fog_mesh.layers = fog_layers

	fog_material.render_priority = fog_render_priority

	_update_color_correction()
	#_update_sun_coords()
	_update_beta_ray()
	_update_beta_mie()

	fog_material.set_shader_parameter("atm_darkness", atm_darkness)
	fog_material.set_shader_parameter("atm_sun_intensity", atm_sun_intensity)
	fog_material.set_shader_parameter("atm_day_tint", atm_day_tint)
	fog_material.set_shader_parameter("atm_horizon_light_tint", atm_horizon_light_tint)
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

func _spherical_to_cartesian(altitude: float, azimuth: float) -> Vector3:
	var cos_alt := cos(altitude)
	return Vector3(
		sin(azimuth) * cos_alt,
		sin(altitude),
		cos(azimuth) * cos_alt
	).normalized()


func _update_color_correction() -> void:
	if is_scene_built:
		fog_material.set_shader_parameter("color_correction", Vector2(tonemap_level, exposure))


func update_sun_coords(altitude: float, azimuth: float) -> void:
	if not is_scene_built:
		return

	_sun_direction = _spherical_to_cartesian(altitude, azimuth)
	fog_material.set_shader_parameter("sun_direction", _sun_direction)


func _update_beta_ray() -> void:
	if not is_scene_built:
		return

	var wll: Vector3 = ScatterLib.compute_wavelenghts_lambda(atm_wavelengths)
	var wls: Vector3 = ScatterLib.compute_wavelenghts(wll)
	var beta_ray: Vector3 = ScatterLib.compute_beta_ray(wls)

	fog_material.set_shader_parameter("atm_beta_ray", beta_ray)


func _update_beta_mie() -> void:
	if is_scene_built:
		var beta_mie: Vector3 = ScatterLib.compute_beta_mie(atm_mie, atm_turbidity)
		fog_material.set_shader_parameter("atm_beta_mie", beta_mie)


func _update_sun_partial_mie_phase() -> void:
	if is_scene_built:
		var partial: Vector3 = ScatterLib.get_partial_mie_phase(atm_sun_mie_anisotropy)
		fog_material.set_shader_parameter("atm_sun_partial_mie_phase", partial)

# ------------------------------------------------------------
# General color correction
# ------------------------------------------------------------

@export_group("General")

@export_range(0.0, 1.0, 0.001) var tonemap_level: float = 0.0:
	set(value):
		tonemap_level = value
		_update_color_correction()


@export var exposure: float = 1.0:
	set(value):
		exposure = value
		_update_color_correction()

# -----------------------------------------------------------
# Atmosphere parameters used by fog shader
# ------------------------------------------------------------

@export_group("Atmosphere")

@export var atm_wavelengths := Vector3(680.0, 550.0, 440.0):
	set(value):
		atm_wavelengths = value
		_update_beta_ray()


@export_range(0.0, 1.0, 0.01) var atm_darkness: float = 0.5:
	set(value):
		atm_darkness = value
		if is_scene_built:
			fog_material.set_shader_parameter("atm_darkness", atm_darkness)


@export var atm_sun_intensity: float = 18.0:
	set(value):
		atm_sun_intensity = value
		if is_scene_built:
			fog_material.set_shader_parameter("atm_sun_intensity", atm_sun_intensity)


@export var atm_day_tint := Color(0.807843, 0.909804, 1.0):
	set(value):
		atm_day_tint = value
		if is_scene_built:
			fog_material.set_shader_parameter("atm_day_tint", atm_day_tint)


@export var atm_horizon_light_tint := Color(0.980392, 0.635294, 0.462745, 1.0):
	set(value):
		atm_horizon_light_tint = value
		if is_scene_built:
			fog_material.set_shader_parameter("atm_horizon_light_tint", atm_horizon_light_tint)


@export_range(0.0, 100.0, 0.01) var atm_thickness: float = 1.0:
	set(value):
		atm_thickness = value
		if is_scene_built:
			fog_material.set_shader_parameter("atm_thickness", atm_thickness)


@export var atm_mie: float = 0.07:
	set(value):
		atm_mie = value
		_update_beta_mie()


@export var atm_turbidity: float = 0.001:
	set(value):
		atm_turbidity = value
		_update_beta_mie()


@export var atm_sun_mie_tint := Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		atm_sun_mie_tint = value
		if is_scene_built:
			fog_material.set_shader_parameter("atm_sun_mie_tint", atm_sun_mie_tint)


@export var atm_sun_mie_intensity: float = 1.0:
	set(value):
		atm_sun_mie_intensity = value
		if is_scene_built:
			fog_material.set_shader_parameter("atm_sun_mie_intensity", atm_sun_mie_intensity)


@export_range(0.0, 0.9999999, 0.0000001) var atm_sun_mie_anisotropy: float = 0.8:
	set(value):
		atm_sun_mie_anisotropy = value
		_update_sun_partial_mie_phase()

@export var atm_level_params := Vector3(1.0, 0.0, 0.0):
	set(value):
		atm_level_params = value
		if is_scene_built:
			fog_material.set_shader_parameter(
				"atm_level_params",
				atm_level_params + fog_atm_level_params_offset
			)


# ------------------------------------------------------------
# Fog
# ------------------------------------------------------------

@export_group("Fog")

@export var fog_visible: bool = true:
	set(value):
		fog_visible = value
		if is_scene_built:
			fog_mesh.visible = fog_visible


@export_exp_easing() var fog_density: float = 0.0007:
	set(value):
		fog_density = value
		if is_scene_built:
			fog_material.set_shader_parameter("fog_density", fog_density)


@export_range(0.0, 5000.0) var fog_start: float = 0.0:
	set(value):
		fog_start = value
		if is_scene_built:
			fog_material.set_shader_parameter("fog_start", fog_start)


@export_range(0.0, 5000.0) var fog_end: float = 1000.0:
	set(value):
		fog_end = value
		if is_scene_built:
			fog_material.set_shader_parameter("fog_end", fog_end)


@export_range(-2048.0, 2048.0) var fog_sea_level: float = 0.0:
	set(value):
		fog_sea_level = value
		if is_scene_built:
			fog_material.set_shader_parameter("sea_level", fog_sea_level)


@export_range(0.0, 50.0, 0.01, "or_greater") var fog_falloff: float = 3.0:
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
		if is_scene_built:
			fog_material.set_shader_parameter("fog_mie_depth", fog_mie_depth)


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
