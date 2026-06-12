shader_type sky;
render_mode use_debanding;

group_uniforms general;
uniform sampler2D sky_texture : source_color;
uniform bool sky_visible = true;
uniform bool sun_visible = true;
uniform float horizon_offset = 0.0;
uniform float azimuth_rad = 0.0;
uniform float elevation_rad = 0.0;
uniform float altitude = 0.0;

group_uniforms postprocessing;
uniform float exposure = -5.0;

group_uniforms sun;
uniform vec4 sun_disk_color: source_color = vec4(0.996, 0.541, 0.14, 1.0);
uniform float sun_disk_intensity = 2.0;
uniform float sun_disk_size = 0.015;
uniform float sun_aureole_size = 135.0;
uniform float soft_glow_size = 0.09;
uniform float soft_glow_intensity = 0.03;

uniform float sun_horizon_fade_width = 0.03;

vec3 rotate_y(vec3 v, float angle) {
	float s = sin(angle);
	float c = cos(angle);

	return vec3(
		c * v.x - s * v.z,
		v.y,
		s * v.x + c * v.z
	);
}

// Creates binary mask for the sun disk.
float calc_disk_mask(vec3 view_dir, vec3 sun_dir, lowp float radius) {
	float dist = length(view_dir - sun_dir);
	return 1.0 - step(radius, dist);
}

vec3 apply_exposure_gamma(vec3 rgb) {
	float exp_mult = exp2(exposure);
	rgb = max(rgb * exp_mult, vec3(0.0));
	rgb = pow(rgb, vec3(1.0 / 2.2));
	return clamp(rgb, vec3(0.0), vec3(1.0));
}

// Compute sun direction based on azimuth and elevation of the sun.
vec3 compute_sun_direction(float azimuth, float elevation) {
	return normalize(vec3(
		cos(elevation) * sin(azimuth),
		sin(elevation),
		cos(elevation) * cos(azimuth)
	));
}

vec3 compute_sky_color(vec3 view_dir) {
	vec3 color = vec3(0.0);

	vec3 sky_dir = normalize(rotate_y(view_dir, azimuth_rad));

	if (sky_dir.y < 0.005) {
		sky_dir.y = 0.005;
	}

	vec2 texture_dir = sky_dir.xz / (1.0 + sky_dir.y);

	vec2 uv = vec2(
		0.5 + 0.5 * texture_dir.x,
		0.5 - 0.5 * texture_dir.y
	);

	if (distance(uv, vec2(0.5)) <= 0.5) {
		vec2 sample_uv = uv;
		float texel_x = 1.0 / float(textureSize(sky_texture, 0).x);
		sample_uv.x = abs(2.0 * uv.x - 1.0);
		sample_uv.x = clamp(sample_uv.x, texel_x * 0.5, 1.0 - texel_x * 0.5);

		color = texture(sky_texture, sample_uv).rgb;
	}
	return apply_exposure_gamma(color);
}

vec3 compute_sun_color(vec3 view_dir) {
	vec3 color = vec3(0.0);

	vec3 sun_dir = compute_sun_direction(azimuth_rad, elevation_rad);

	float horizon_mask = smoothstep(0.0, sun_horizon_fade_width, view_dir.y + horizon_offset);

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
	vec3 low_sun_color = vec3(1.0, 0.45, 0.05) * 1.5;
	vec3 high_sun_color = vec3(1.0);
	vec3 glow_tint = mix(low_sun_color, high_sun_color, sun_height);

	vec3 glow_color = glow_tint * glow * soft_glow_intensity;


	return (sun_disk + glow_color + core_color) * horizon_mask;
}

void sky() {
	vec3 sky = vec3(0.0);
	vec3 sun = vec3(0.0);

	vec3 view_dir = EYEDIR;

	if (sky_visible)
		sky = compute_sky_color(view_dir);
	if (sun_visible)
		sun = compute_sun_color(view_dir);

	vec3 color = sky+ sun;
	COLOR = color.rgb;
}
