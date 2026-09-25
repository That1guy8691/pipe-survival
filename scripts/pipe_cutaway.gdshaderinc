// A finite camera-to-head cone in view space, measured in world units.
// Both render passes use the tube CENTERLINE so its near and far walls fade
// together. Surface-depth cutoffs can expose an opaque hollow interior.
uniform bool cutaway_enabled = false;
uniform vec3 cutaway_head_view = vec3(0.0);
uniform vec3 cutaway_target_view = vec3(0.0, 0.0, -6.0);
uniform float cutaway_camera_radius = 1.15;
uniform float cutaway_tip_radius = 0.15;
uniform float cutaway_softness = 0.28;

float cone_fade(vec3 center) {
	float cone_length = max(length(cutaway_target_view), 0.001);
	vec3 axis = cutaway_target_view / cone_length;
	float along = dot(center, axis);
	float fraction = clamp(along / cone_length, 0.0, 1.0);
	float radius = mix(cutaway_camera_radius, cutaway_tip_radius, fraction);
	float radial_distance = length(center - axis * along);
	float corridor = 1.0 - smoothstep(radius, radius + cutaway_softness, radial_distance);
	float end_cap = 1.0 - smoothstep(cone_length - 0.35, cone_length, along);
	// Keep the head's collar and the space ahead solid. A spherical exclusion
	// also protects REAR blockers when a wall pushes the camera close to the head.
	vec3 forward = normalize(cutaway_target_view - cutaway_head_view);
	float behind_head = dot(center - cutaway_head_view, forward);
	float head_clearance = 1.0 - smoothstep(-0.9, -0.35, behind_head);
	// Preserve the immediate connection through bends, but shrink this collar
	// with camera clearance so it cannot engulf a nearby camera or rear blocker.
	float camera_clearance = length(cutaway_head_view);
	float collar_radius = min(1.3, camera_clearance * 0.3);
	float collar_feather = min(0.8, camera_clearance * 0.13);
	float collar_clearance = smoothstep(collar_radius,
		collar_radius + max(collar_feather, 0.001), distance(center, cutaway_head_view));
	return corridor * end_cap * head_clearance * collar_clearance;
}
