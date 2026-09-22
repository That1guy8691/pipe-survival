shader_type spatial;
render_mode cull_disabled;

uniform vec4 pipe_color : source_color;
uniform vec4 accent_color : source_color;
uniform int pattern = 0;
uniform float segment_length = 2.0;
uniform float fill = 1.0;

void fragment() {
	if (UV.y > fill) discard;
	float marking = 0.0;
	if (pattern == 1) {
		float band = abs(fract(UV.y * 2.0) - 0.5);
		float edge = max(fwidth(UV.y * 2.0), 0.001);
		marking = 1.0 - smoothstep(0.12 - edge, 0.12 + edge, band);
	} else if (pattern == 2) {
		// Six repeats close around the circumference; arc length keeps dots round.
		vec2 grid = vec2(UV.x * 6.0, (UV.y - 0.5) * segment_length / 0.628 + 0.5);
		float dot_distance = length(fract(grid) - 0.5);
		float edge = max(length(fwidth(grid)), 0.001);
		marking = 1.0 - smoothstep(0.25 - edge, 0.25 + edge, dot_distance);
	}
	// Unpainted collars separate pieces whose local UV frames change at turns.
	marking *= smoothstep(0.125, 0.145, UV.y) * (1.0 - smoothstep(0.855, 0.875, UV.y));
	vec3 color = mix(pipe_color.rgb, accent_color.rgb, marking);
	ALBEDO = color;
	METALLIC = 0.62;
	ROUGHNESS = 0.28;
	EMISSION = color * 0.13;
}
