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
// Disabled by default for options and model previews.
uniform bool cutaway_enabled = false;
uniform float cutaway_depth = 0.0;
uniform float cutaway_radius = 0.28;
uniform float cutaway_feather = 0.045;
uniform bool preserve_focus_segment = false;
uniform vec3 cutaway_forward = vec3(0.0, 0.0, -1.0);
uniform vec3 cutaway_head_view = vec3(0.0);
varying float instance_rainbow_phase;
varying float instance_is_focus_segment;
varying float tail_alignment;
varying vec3 tube_center_view;
varying float camera_intersection;

float distance_to_tube_path(vec3 point) {
	if (segment_length >= 1.9) {
		vec3 closest = vec3(0.0, 0.0, clamp(point.z, 1.0 - fill * 2.0, 1.0));
		return distance(point, closest);
	}
	float end_angle = fill * PI * 0.5;
	vec3 end = vec3(1.0 - cos(end_angle), 0.0, 1.0 - sin(end_angle));
	float closest = min(distance(point, vec3(0.0, 0.0, 1.0)), distance(point, end));
	float angle = atan(1.0 - point.z, 1.0 - point.x);
	if (angle >= 0.0 && angle <= end_angle) {
		closest = min(closest, distance(point, vec3(1.0 - cos(angle), 0.0, 1.0 - sin(angle))));
	}
	return closest;
}

void vertex() {
	instance_rainbow_phase = INSTANCE_CUSTOM.x;
	instance_is_focus_segment = INSTANCE_CUSTOM.y;
	vec3 tangent = vec3(0.0, 0.0, -1.0);
	vec3 centerline = vec3(0.0, 0.0, 1.0 - UV.y * 2.0);
	if (segment_length < 1.9) {
		float angle = UV.y * PI * 0.5;
		tangent = vec3(sin(angle), 0.0, -cos(angle));
		centerline = vec3(1.0 - cos(angle), 0.0, 1.0 - sin(angle));
	}
	tube_center_view = (MODELVIEW_MATRIX * vec4(centerline, 1.0)).xyz;
	tail_alignment = dot(normalize((MODEL_MATRIX * vec4(tangent, 0.0)).xyz), cutaway_forward);
	camera_intersection = 0.0;
	if (cutaway_enabled && preserve_focus_segment) {
		vec3 local_camera = (inverse(MODELVIEW_MATRIX) * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		// Tube radius is at most 0.645; include the camera's 0.12 near plane.
		camera_intersection = 1.0 - smoothstep(0.7, 0.8, distance_to_tube_path(local_camera));
	}
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
	float cutaway_ghost = 0.0;
	if (cutaway_enabled && !IN_SHADOW_PASS) {
		vec2 centered = (SCREEN_UV - vec2(0.5)) * VIEWPORT_SIZE;
		float radius = length(centered) / min(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y);
		float circle = 1.0 - smoothstep(cutaway_radius - cutaway_feather, cutaway_radius, radius);
		// Preserve the connected tail, including the current growing section.
		float recent_segment = 0.0;
		if (preserve_focus_segment) {
			recent_segment = instance_is_focus_segment;
			// The non-instanced growing segment stays joined to the followed head.
			if (!use_instance_phase) {
				recent_segment = 1.0;
			}
		}
		// A turn can swing the recent tail across the camera-to-head line.
		float aligned = smoothstep(0.8, 0.95, tail_alignment);
		// Use the tube's centerline, not its surface: the sides of a connected
		// elbow must not dissolve just because they overlap the cutaway circle.
		vec2 head_projection = cutaway_head_view.xy / max(cutaway_depth, 0.001);
		vec2 tube_projection = tube_center_view.xy / max(-tube_center_view.z, 0.001);
		vec2 toward_route = -head_projection / max(length(head_projection), 0.001);
		float crosses_view = step(0.0, dot(tube_projection - head_projection, toward_route));
		// Centerline projection is unreliable inside a tube. Never preserve its
		// near wall across the opening just because it projects behind the head.
		float crossing_tail = recent_segment * max((1.0 - aligned) * crosses_view, camera_intersection);
		float protected_segment = recent_segment - crossing_tail;
		// Keep the usual clearance around hazards. A crossing part of our own tail
		// must clear right up to the head, or it still hides the view on the turn exit.
		float depth_limit = cutaway_depth - mix(1.2, 0.1, crossing_tail);
		float depth_feather = mix(0.8, 0.15, crossing_tail);
		float foreground = 1.0 - smoothstep(depth_limit - depth_feather, depth_limit, -VERTEX.z);
		cutaway_ghost = circle * foreground * (1.0 - protected_segment);
		// Screen-locked dithering softens the circle without transparent-pipe sorting.
		vec2 pixel = floor(FRAGCOORD.xy);
		float threshold = fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
		if (cutaway_ghost > threshold) discard;
	}
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
