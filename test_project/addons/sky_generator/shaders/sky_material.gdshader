shader_type sky;
render_mode use_debanding;

const int MAX_TEXTURES_COUNT = 32;

group_uniforms textures;
uniform sampler2D sky_texture;
uniform sampler2D precomputed_textures[MAX_TEXTURES_COUNT];
uniform float precomputed_altitudes[MAX_TEXTURES_COUNT];
uniform int precomputed_texture_count;
uniform bool use_precomputed_textures = false;

group_uniforms general;
uniform bool sky_visible = true;
uniform bool sun_visible = true;
uniform float azimuth_rad = 0.0;
uniform float elevation_rad = 0.0;
uniform float precomputed_altitude_min = 0.001;
uniform float precomputed_altitude_max = 15000.0;
uniform float altitude = 0.0;

group_uniforms postprocessing;
uniform float exposure = -5.0;

group_uniforms sun;
uniform vec4 sun_disk_color: source_color = vec4(0.996, 0.541, 0.14, 1.0);
uniform vec4 horizon_light_tint: source_color = vec4(1.0, 0.45, 0.05, 1.0);
uniform float sun_disk_intensity = 2.0;
uniform float sun_disk_size = 0.015;
uniform float sun_aureole_size = 135.0;
uniform float soft_glow_size = 0.09;
uniform float soft_glow_intensity = 0.03;

uniform float sun_horizon_fade_width = 0.03;

const float SKY_DIRECTION_Y_OFFSET_MIN = 0.01;
const float SKY_DIRECTION_Y_OFFSET_MAX = 0.08;

const bool clamp_sky_to_horizon = true;

#include "utils.gdshaderinc"

vec3 apply_exposure_gamma(vec3 rgb) {
	float exp_mult = exp2(exposure);
	rgb = max(rgb * exp_mult, vec3(0.0));
	rgb = pow(rgb, vec3(1.0 / 2.2));
	return clamp(rgb, vec3(0.0), vec3(1.0));
}

void find_altitude_indices(float current_altitude, out int lower_index, out int upper_index) {
	lower_index = 0;
	upper_index = 0;

	if (precomputed_texture_count <= 1) {
		return;
	}

	// Below first altitude.
	if (current_altitude <= precomputed_altitudes[0]) {
		return;
	}

	int last_index = precomputed_texture_count - 1;

	// Above last altitude.
	if (current_altitude >= precomputed_altitudes[last_index]) {
		lower_index = last_index;
		upper_index = last_index;
		return;
	}

	for (int i = 0; i < precomputed_texture_count - 1; i++) {
		float a0 = precomputed_altitudes[i];
		float a1 = precomputed_altitudes[i + 1];

		if (current_altitude >= a0 && current_altitude <= a1) {
			lower_index = i;
			upper_index = i + 1;
			return;
		}
	}
}

vec3 sample_single_sky_texture(vec2 uv) {
	vec2 sample_uv = uv;

	ivec2 tex_size = textureSize(sky_texture, 0);

	float texel_x = 1.0 / float(tex_size.x);

	sample_uv.x = abs(2.0 * uv.x - 1.0);
	sample_uv.x = clamp(sample_uv.x, texel_x * 0.5, 1.0 - texel_x * 0.5);

	return texture(sky_texture, sample_uv).rgb;
}

vec3 sample_precomputed_sky_textures(vec2 uv) {
	vec2 sample_uv = uv;

	int i = 0;

	ivec2 tex_size = textureSize(precomputed_textures[i], 0);

	float texel_x = 1.0 / float(tex_size.x);

	sample_uv.x = abs(2.0 * uv.x - 1.0);
	sample_uv.x = clamp(sample_uv.x, texel_x * 0.5, 1.0 - texel_x * 0.5);

	int lower_index = 0;
	int upper_index = 0;
	find_altitude_indices(altitude, lower_index, upper_index);
	float lower_altitude = precomputed_altitudes[lower_index];
	float upper_altitude =  precomputed_altitudes[upper_index];
	float blend = 0.0;
	float range = upper_altitude - lower_altitude;
	if (range > 0.0) {
		blend = (altitude - lower_altitude) / range;
	}

	vec3 lower_color = texture(precomputed_textures[lower_index], sample_uv).rgb;
	vec3 upper_color = texture(precomputed_textures[upper_index], sample_uv).rgb;

	return mix(lower_color, upper_color, blend);
}

vec3 interpolate_sky_texture(vec2 uv) {
	vec3 sky_color = vec3(1.0, 0.0, 0.0); // red
	if (use_precomputed_textures) {
		sky_color = sample_precomputed_sky_textures(uv);
	}
	else {
		sky_color = sample_single_sky_texture(uv);
	}
	return sky_color;
}

vec3 calc_sky_color(vec3 view_dir) {
	vec3 color = vec3(0.0);

	vec3 sky_dir = normalize(rotate_y(view_dir, azimuth_rad));

	if (clamp_sky_to_horizon && sky_dir.y < 0.005) {
		sky_dir.y = 0.005;
	}

	vec2 texture_dir = sky_dir.xz / (1.0 + sky_dir.y);

	vec2 uv = vec2(
		0.5 + 0.5 * texture_dir.x,
		0.5 - 0.5 * texture_dir.y
	);

	if (distance(uv, vec2(0.5)) <= 0.5) {
		color = interpolate_sky_texture(uv);
	}
	return apply_exposure_gamma(color);
}

vec3 calc_sun_color(vec3 view_dir, float normalized_altitude) {
	vec3 color = vec3(0.0);

	vec3 sun_dir = calc_sun_direction(azimuth_rad, elevation_rad);

	float altitude_horizon_fade_offset  = normalized_altitude * (SKY_DIRECTION_Y_OFFSET_MAX - SKY_DIRECTION_Y_OFFSET_MIN);
	float horizon_mask = smoothstep(0.0, sun_horizon_fade_width, view_dir.y + altitude_horizon_fade_offset);

	float close_to_sun = max(dot(view_dir, sun_dir), 0.0);

	// Compute solar disk.
	float sun_mask = calc_disk_mask(view_dir, sun_dir, sun_disk_size);
	vec3 sun_disk = sun_mask * sun_disk_color.rgb * sun_disk_intensity;

	// Compute small smooth areol around the sun.
	float sun_core = pow(close_to_sun, sun_aureole_size / sun_disk_size);
	sun_core *= sun_disk_intensity;
	sun_core = clamp(sun_core, 0.0, 1.0);
	vec3 core_color = sun_disk_color.rgb * sun_core;

	// Compute smooth glow around the sun.
	float glow_size = pow(2.0, 1.0 / soft_glow_size);
	float glow = pow(close_to_sun, glow_size);

	// Make glow stronger near the horizon.
	float horizon_factor = clamp(1.0 - abs(view_dir.y), 0.0, 1.0);
	glow *= mix(0.35, 1.4, horizon_factor);

	// When sun is low, make glow more orange.
	float sun_height = clamp(sun_dir.y, 0.0, 1.0);
	vec3 low_sun_color = horizon_light_tint.xyz * 1.5;
	vec3 high_sun_color = vec3(1.0);
	vec3 glow_tint = mix(low_sun_color, high_sun_color, sun_height);

	vec3 glow_color = glow_tint * glow * soft_glow_intensity;


	return (sun_disk + glow_color + core_color) * horizon_mask;
}

vec3 calc_sky_coords(vec3 view_dir, float altitude_t) {
	view_dir.y += mix(
		SKY_DIRECTION_Y_OFFSET_MIN,
		SKY_DIRECTION_Y_OFFSET_MAX,
		altitude_t
	);

	return normalize(view_dir);
}

vec3 calc_sun_coords(vec3 view_dir, float normalized_altitude) {
	view_dir.y += SKY_DIRECTION_Y_OFFSET_MIN;

	return normalize(view_dir);
}

void sky() {
	vec3 sky = vec3(0.0);
	vec3 sun = vec3(0.0);

	float normalized_altitude = clamp(
		(altitude - precomputed_altitude_min) /
		max(precomputed_altitude_max - precomputed_altitude_min, 0.0001),
		0.0,
		1.0
	);

	vec3 view_dir = EYEDIR;

	vec3 sun_coords = calc_sun_coords(view_dir, normalized_altitude);
	vec3 sky_coords = calc_sky_coords(view_dir, normalized_altitude);

	if (sky_visible)
		sky = calc_sky_color(sky_coords);
	if (sun_visible)
		sun = calc_sun_color(sun_coords, normalized_altitude);

	vec3 color = sky+ sun;
	COLOR = color.rgb;
}
