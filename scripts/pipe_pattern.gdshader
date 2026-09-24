shader_type spatial;
render_mode cull_disabled;

uniform vec4 pipe_color : source_color;
uniform vec4 accent_color : source_color;
uniform int pattern = 0;
uniform float segment_length = 2.0;
uniform float fill = 1.0;
uniform float display_brightness = 1.0;
uniform float rainbow_phase = 0.0;
uniform bool use_instance_phase = false;
varying float instance_rainbow_phase;

void vertex() {
	instance_rainbow_phase = INSTANCE_CUSTOM.x;
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
	if (pattern == 1) {
		float band = abs(fract(UV.y * 2.0) - 0.5);
		float edge = max(fwidth(UV.y * 2.0), 0.001);
		marking = 1.0 - smoothstep(0.12 - edge, 0.12 + edge, band);
	} else if (pattern == 2) {
		// Six repeats close around the circumference; arc length keeps dots round.
		vec2 grid = vec2(around * 6.0, (UV.y - 0.5) * segment_length / 0.628 + 0.5);
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
	}
	float collar = smoothstep(0.125, 0.145, UV.y) * (1.0 - smoothstep(0.855, 0.875, UV.y));
	vec3 color;
	if (pattern == 3) {
		// Keep the stripe phase aligned to the rider's up frame at every elbow.
		color = hsv_to_rgb(vec3(around, 0.9, 1.0));
	} else {
		// Unpainted collars separate pieces whose local UV frames change at turns.
		marking *= collar;
		color = mix(pipe_color.rgb, accent_color.rgb, marking);
	}
	color *= display_brightness;
	ALBEDO = color;
	METALLIC = 0.62;
	ROUGHNESS = 0.28;
	EMISSION = color * 0.13;
}
