// Copyright (c) 2026 Ilia Riabko
// Copyright (c) 2023-2025 Cory Petkovsek and Contributors
// Copyright (c) 2021 J. Cuellar
//
// Modified as part of a bachelor's thesis at Charles University, Prague.
//
// SPDX-License-Identifier: MIT

shader_type spatial;
render_mode blend_mix, cull_front, unshaded, fog_disabled;

group_uniforms general;
uniform float tonemap_level : hint_range(0.0, 1.0) = 1.0;
uniform float fog_exposure = 1.0;
uniform float sea_level: hint_range(-2048,2048,.001) = 0.0;
uniform vec3 sun_direction = vec3(0.25, -0.25, 0.25);

uniform float viewer_altitude = 0.0;
uniform float high_altitude_start = 1000.0;
uniform float high_altitude_end = 8000.0;
uniform float altitude_max = 15000.0;
uniform float high_altitude_sunset_tint = 0.15;

uniform float falloff_at_max_altitude = 50.0;
uniform float falloff_altitude_curve : hint_range(0.25, 8.0) = 4.0;

uniform float falloff_low_visibility = 4.0;
uniform float falloff_high_visibility = 6.0;

uniform float visibility = 0.0;
uniform float visibility_min = 23.0;
uniform float visibility_max = 131.0;

uniform float planet_radius = 6371000.0; // Earth radius in meters
uniform float horizon_roundness : hint_range(0.0, 1.0) = 0.6;
uniform float horizon_curve_strength : hint_range(0.0, 8.0) = 0.5;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

varying vec4 v_angle_mult;

group_uniforms fog;
uniform float fog_density = 0.0001;
uniform float fog_rayleigh_depth = 0.115;
uniform float fog_mie_depth = 0.0;
uniform float fog_falloff = 3.0;
uniform float fog_start = 0.0;
uniform float fog_end = 1000.;

group_uniforms atmosphere;
uniform float atm_darkness = 0.5;
uniform float atm_sun_intensity = 10.0;
uniform vec4 atm_day_tint: source_color = vec4(0.78, 0.85, 0.98, 1.0);
uniform vec4 atm_horizon_light_tint: source_color = vec4(0.98, 0.73, 0.49, 1.0);
uniform vec4 atm_night_tint: source_color = vec4(0.16, 0.2, 0.25, 1.0);
uniform vec3 atm_level_params = vec3(1.0, 0.0, 0.0);
uniform float atm_thickness = 0.5;

uniform vec3 atm_beta_ray;
uniform vec3 atm_beta_mie;

uniform vec3 atm_sun_partial_mie_phase = vec3(0.0, 0.0, 0.0);
uniform vec4 atm_sun_mie_tint: source_color = vec4(1.);
uniform float atm_sun_mie_intensity = 1.;

#include "utils.gdshaderinc"

// Atmosphere
vec3 calc_atmospheric_scatter(float sr, float sm, float sun_mu, vec3 mult, float depth, float altitude_sun_factor) {
	vec3 beta_mie = atm_beta_mie;
	vec3 beta_ray = atm_beta_ray * atm_thickness;

	vec3 extc_factor = clamp_rgb_to_unit(exp(-(beta_ray * sr + beta_mie * sm)));

	float extc_ff = mix(clamp_to_unit(atm_thickness * 0.5), 1.0, mult.x);
	vec3 final_extc_factor = mix(1.0 - extc_factor, (1.0 - extc_factor) * extc_factor, extc_ff);

	float rayleigh_phase = calc_rayleigh_phase(sun_mu);
	vec3 BRT = beta_ray * rayleigh_phase * clamp_to_unit(depth * fog_rayleigh_depth);
	vec3 BMT = beta_mie * calc_mie_phase(sun_mu, atm_sun_partial_mie_phase);
	BMT *= atm_sun_mie_intensity * atm_sun_mie_tint.rgb * clamp_to_unit(depth * fog_mie_depth);

	vec3 BRMT = (BRT + BMT) / (beta_ray + beta_mie);
	vec3 scatter = atm_sun_intensity * (BRMT * final_extc_factor) * atm_day_tint.rgb * mult.y;
	scatter = mix(scatter, scatter * (1.0 - extc_factor), atm_darkness);

	// reduce the sunset/horizon tint at high altitude
	float horizon_tint_amount = mult.x * altitude_sun_factor;
	vec3 lcol = mix(atm_day_tint.rgb, max(atm_horizon_light_tint.rgb, vec3(0.15)), horizon_tint_amount);
	vec3 nscatter = (1.0 - extc_factor) * atm_night_tint.rgb * clamp_to_unit(depth * fog_rayleigh_depth);
	return (scatter * lcol) + nscatter;
}

float calc_fog_distance(float depth) {
	float d = depth;
	d = (fog_end - d) / (fog_end - fog_start);
	return clamp_to_unit(1.0 - d);
}

float calc_spherical_horizon_mu(float altitude, float radius) {
	float r = max(radius, 1.0);
	float h = max(altitude, 0.0);

	// Camera distance from planet center.
	float camera_r = r + h;

	// Horizon/tangent view direction in terms of dot(ray, up).
	// At sea level this is 0.0.
	// At altitude it becomes negative, meaning the visible horizon dips below flat level.
	float ratio = clamp(r / camera_r, 0.0, 1.0);
	float horizon_mu = -sqrt(max(0.0, 1.0 - ratio * ratio));

	return horizon_mu;
}

float calc_ray_distance(vec3 ray_direction, vec3 camera_pos, float original_distance) {
	float dy = sea_level - camera_pos.y;
	// Distance along ray to sea_level plane
	float plane_distance = dy / (ray_direction.y + 1e-6 * sign(ray_direction.y));  // avoid divide by zero
	float plane_hit = float(ray_direction.y < 0.) *
					  float(plane_distance > 0.) *
					  float(plane_distance < original_distance);

	float ray_distance = mix(original_distance, plane_distance, plane_hit);
	return ray_distance;
}

float calc_fog_density() {
	float visibility_factor = clamp((visibility_min * 2.0) / visibility, 0.15, 7.5);
	return fog_density * visibility_factor;
}

float calc_fog_falloff() {
	float visibility_range = max(visibility_max - visibility_min, 0.0001);
	float visibility_t = clamp((visibility - visibility_min) / visibility_range, 0.0,1.0);

	float sea_level_falloff = mix(falloff_low_visibility, falloff_high_visibility, visibility_t);

	float altitude_t = clamp(viewer_altitude / max(altitude_max, 0.0001), 0.0, 1.0 );
	altitude_t = pow(altitude_t, falloff_altitude_curve);

	return mix(sea_level_falloff, falloff_at_max_altitude, altitude_t);
}

float calc_fog_factor(vec3 ray_direction, float ray_distance) {
	// Calculate fog exponent.
	float fog_factor = 1.0 - clamp_to_unit(exp2(-ray_distance * calc_fog_density()));

	float horizon_mu = calc_spherical_horizon_mu(viewer_altitude, planet_radius);
	// Blend between flat horizon and spherical horizon.
	float curved_mu = mix(ray_direction.y, ray_direction.y - horizon_mu, horizon_roundness);
	// Extra shaping so curvature becomes more visible with altitude.
	curved_mu *= horizon_curve_strength;

	fog_factor *= clamp_to_unit(exp(-(curved_mu) * calc_fog_falloff()));

	fog_factor *= calc_fog_distance(ray_distance);

	return fog_factor;
}

// Main
void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
	v_angle_mult = vec4(
		clamp_to_unit(1.0 - sun_direction.y),
		clamp_to_unit(sun_direction.y + 0.45),
		clamp_to_unit(-sun_direction.y + 0.30),
		clamp_to_unit(-sun_direction.y + 0.60));
}

void fragment() {
	// Calculate world pixel position from depth
	float depth_raw = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	depth_raw = depth_raw * 2.0 - 1.0;

	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 clip_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 view_pos = clip_pos.xyz / clip_pos.w;
	vec4 world_pos_hom = INV_VIEW_MATRIX * vec4(view_pos, 1.0);
	vec3 world_position = world_pos_hom.xyz / world_pos_hom.w;

	// Ray from camera to world intersection point
	vec3 intersection_ray = world_position - CAMERA_POSITION_WORLD;
	// Unit ray direction
	vec3 ray_direction = normalize(intersection_ray);

	float original_distance = length(intersection_ray);

	float ray_distance = calc_ray_distance(ray_direction, CAMERA_POSITION_WORLD, original_distance);

	float fog_factor = calc_fog_factor(ray_direction, ray_distance);

	float sun_mu = dot(sun_direction, ray_direction);

	float high_altitude_factor = smoothstep(high_altitude_start, high_altitude_end, viewer_altitude);
	float altitude_sun_factor = mix(1.0, high_altitude_sunset_tint, high_altitude_factor);

	float sr, sm;
	calc_simple_optical_depth(ray_direction.y + atm_level_params.z, sr, sm, atm_level_params.xy);
	vec3 scatter = calc_atmospheric_scatter(sr, sm, sun_mu, v_angle_mult.xyz, ray_distance, altitude_sun_factor);

	vec4 fog_color = vec4(scatter, fog_factor);
	fog_color.a = clamp(fog_color.a, 0.0, 1.0);
	fog_color.rgb = apply_photo_tonemap(fog_color.rgb, fog_exposure, tonemap_level);

	ALBEDO = fog_color.rgb;
	ALPHA = fog_color.a;

	// View depth map
	//ALPHA = 1.;
	//ALBEDO = vec3(ray_distance*.0001);
}