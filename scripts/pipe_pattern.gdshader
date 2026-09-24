shader_type spatial;
render_mode cull_disabled;

uniform vec4 pipe_color : source_color;
uniform vec4 accent_color : source_color;
uniform vec4 detail_color : source_color;
uniform bool custom_accent = false;
uniform bool custom_detail = false;
uniform float glow_scale = 1.0;
uniform int pattern = 0;
uniform int finish = 0;
// 0 keeps raised, plain collars; 1 smooths them and carries the pattern through.
uniform int joint_style = 0;
uniform float segment_length = 2.0;
uniform float fill = 1.0;
uniform float display_brightness = 1.0;
uniform float rainbow_phase = 0.0;
uniform bool use_instance_phase = false;
varying float instance_rainbow_phase;

void vertex() {
	instance_rainbow_phase = INSTANCE_CUSTOM.x;
	if (joint_style == 1 && (UV.y < 0.07 || UV.y > 0.93)) {
		VERTEX -= NORMAL * 0.045;
	}
}

vec3 hsv_to_rgb(vec3 hsv) {
	vec3 rgb = clamp(abs(mod(hsv.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0,
		0.0, 1.0);
	return hsv.z * mix(vec3(1.0), rgb, hsv.y);
}

void fragment() {
	if (UV.y > fill) discard;
	float phase = rainbow_phase;
	if (use_instance_phase) {
		phase = instance_rainbow_phase;
	}
	float around = fract(UV.x + phase);
	float marking = 0.0;
	vec3 color;
	if (pattern == 1) {
		float band = abs(fract(UV.y * 2.0) - 0.5);
		float edge = max(fwidth(UV.y * 2.0), 0.001);
		marking = 1.0 - smoothstep(0.12 - edge, 0.12 + edge, band);
	} else if (pattern == 2) {
		// Six repeats close around the circumference; arc length keeps dots round.
		float axial = (UV.y - 0.5) * segment_length / 0.628 + 0.5;
		if (joint_style == 1) {
			// Whole rows leave matching, uncut dot spacing at both segment ends.
			axial = UV.y * floor(segment_length / 0.628 + 0.5);
		}
		vec2 grid = vec2(around * 6.0, axial);
		float dot_distance = length(fract(grid) - 0.5);
		float edge = max(length(fwidth(grid)), 0.001);
		marking = 1.0 - smoothstep(0.25 - edge, 0.25 + edge, dot_distance);
	} else if (pattern == 4) {
		float helix = fract(around * 3.0 + UV.y);
		float edge = max(fwidth(helix), 0.001);
		marking = 1.0 - smoothstep(0.3 - edge, 0.3 + edge, abs(helix - 0.5));
	} else if (pattern == 5) {
		vec2 grid = vec2(around * 8.0, UV.y * 6.0);
		marking = mod(floor(grid.x) + floor(grid.y), 2.0);
	} else if (pattern == 6) {
		float diagonal_a = abs(fract(around * 8.0 + UV.y * 6.0) - 0.5);
		float diagonal_b = abs(fract(around * 8.0 - UV.y * 6.0) - 0.5);
		float edge = max(length(fwidth(vec2(around, UV.y)) * 8.0), 0.001);
		float line_a = 1.0 - smoothstep(0.08 - edge, 0.08 + edge, diagonal_a);
		float line_b = 1.0 - smoothstep(0.08 - edge, 0.08 + edge, diagonal_b);
		marking = max(line_a, line_b);
	} else if (pattern == 7) {
		float rib = abs(fract(UV.y * 10.0) - 0.5);
		float edge = max(fwidth(UV.y * 10.0), 0.001);
		marking = 1.0 - smoothstep(0.07 - edge, 0.07 + edge, rib);
	} else if (pattern == 8) {
		float highlight = pow(max(cos((around - 0.28) * TAU), 0.0), 16.0);
		float dark_reflection = pow(max(cos((around - 0.78) * TAU), 0.0), 7.0);
		vec3 chrome_shadow = pipe_color.rgb * 0.42;
		vec3 chrome_reflection = mix(pipe_color.rgb, vec3(1.0), 0.2 + highlight * 0.65);
		color = mix(chrome_shadow, chrome_reflection, 0.3 + highlight * 0.7);
		color *= 1.0 - dark_reflection * 0.4;
		if (custom_accent) {
			color = mix(color, accent_color.rgb, highlight * 0.38);
		}
	}
	float collar = smoothstep(0.125, 0.145, UV.y) * (1.0 - smoothstep(0.855, 0.875, UV.y));
	if (pattern == 3) {
		// Keep the stripe phase aligned to the rider's up frame at every elbow.
		color = hsv_to_rgb(vec3(around, 0.9, 1.0));
		if (custom_accent) {
			color = mix(color, accent_color.rgb, 0.22);
		}
	} else if (pattern != 8) {
		if (joint_style == 0) {
			// The collared style leaves each raised joint plain.
			marking *= collar;
		}
		color = mix(pipe_color.rgb, accent_color.rgb, marking);
	}
	if (custom_detail && joint_style == 0 && (UV.y < 0.07 || UV.y > 0.93)) {
		color = detail_color.rgb;
	}
	color *= display_brightness;
	ALBEDO = color;
	float metallic = 0.62;
	float roughness = 0.28;
	if (finish == 1) {
		metallic = 0.88;
		roughness = 0.42;
	} else if (finish == 2) {
		metallic = 0.08;
		roughness = 0.2;
	} else if (finish == 3) {
		metallic = 0.0;
		roughness = 0.34;
	} else if (finish == 4) {
		metallic = 0.0;
		roughness = 0.84;
	}
	if (pattern == 8) {
		metallic = 0.5;
		roughness = 0.09;
	}
	if (glow_scale < 1.0) {
		roughness = max(roughness, 0.48);
	}
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = 0.72 * min(glow_scale, 1.0);
	float emission_strength = 0.13;
	if (finish == 2) {
		emission_strength = 0.08;
	} else if (finish == 3) {
		emission_strength = 0.06;
	} else if (finish == 4) {
		emission_strength = 0.03;
	}
	if (pattern == 8) {
		emission_strength = 0.22;
		SPECULAR = min(glow_scale, 1.0);
	}
	EMISSION = color * emission_strength * glow_scale;
}
