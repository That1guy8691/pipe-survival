extends Camera3D

const Rules = preload("res://scripts/simulation.gd")

enum View { RING, CHASE, FIRST_PERSON, OVERVIEW }
var view: View = View.RING
var overview: bool:
	get: return view == View.OVERVIEW
	set(value): view = View.OVERVIEW if value else View.RING
var first_person: bool:
	get: return view == View.FIRST_PERSON
var boosting := false
var yaw := 0.67
var pitch := 0.43
var ring_angle := PI * 0.5
var ring_look_pitch := 0.0
const RING_RADIUS := 5.4
var chase_yaw := 0.0
var chase_pitch := 0.407
var first_person_yaw := 0.0
var first_person_pitch := 0.0
var arena_width := Rules.DEFAULT_WIDTH
var distance := arena_width * 1.7
var initialized := false

func _ready() -> void:
	current = true
	fov = 78.0
	near = 0.12
	far = arena_width * 5.5

func set_arena_size(width: float) -> void:
	arena_width = width
	distance = width * 1.7
	far = width * 5.5
	initialized = false

func toggle() -> void:
	view = (view + 1) % 4 as View
	initialized = false

func view_name() -> String:
	return ["PIPE RING", "CHASE CAMERA", "FIRST PERSON", "OVERVIEW"][view]

func orbit(relative: Vector2) -> void:
	if overview:
		yaw = wrapf(yaw - relative.x * 0.006, -PI, PI)
		pitch = clampf(pitch + relative.y * 0.006, -0.8, 1.25)
	elif first_person:
		first_person_yaw = wrapf(first_person_yaw - relative.x * 0.006, -PI, PI)
		first_person_pitch = clampf(first_person_pitch + relative.y * 0.006, -0.8, 0.8)
	elif view == View.RING:
		ring_angle = wrapf(ring_angle - relative.x * 0.006, -PI, PI)
		ring_look_pitch = clampf(ring_look_pitch + relative.y * 0.006, -0.8, 0.8)
	else:
		chase_yaw = wrapf(chase_yaw - relative.x * 0.006, -PI, PI)
		chase_pitch = clampf(chase_pitch + relative.y * 0.006, -0.35, 1.1)

func orbit_step(horizontal: float, vertical: float) -> void:
	# One arrow-key press moves the camera by roughly eight degrees.
	orbit(Vector2(-horizontal * 24.0, -vertical * 24.0))

func zoom(amount: float) -> void:
	distance = clampf(distance + amount, arena_width, arena_width * 2.375)

func follow(pose: Dictionary, delta: float, force_overview: bool = false) -> void:
	var target_position: Vector3
	var target_basis: Basis
	if overview or force_overview:
		var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
		var focus: Vector3 = pose.position * 0.12
		target_position = focus + offset
		target_basis = Basis.looking_at((focus - target_position).normalized(), Vector3.UP)
	elif view == View.RING and not force_overview:
		var forward: Vector3 = pose.forward.normalized()
		var up: Vector3 = pose.up.normalized()
		var right := forward.cross(up).normalized()
		var radial := right * cos(ring_angle) + up * sin(ring_angle)
		target_position = pose.position + radial * RING_RADIUS
		var camera_limit := arena_width * 0.5 - 0.6
		target_position = target_position.clamp(Vector3.ONE * -camera_limit, Vector3.ONE * camera_limit)
		var focus_forward := forward.rotated(right, ring_look_pitch).normalized()
		var focus: Vector3 = pose.position + focus_forward * 4.5
		target_basis = Basis.looking_at((focus - target_position).normalized(), up)
	elif first_person:
		target_position = pose.position + pose.forward * 0.3
		var view_forward: Vector3 = pose.forward.rotated(pose.up, first_person_yaw)
		var view_right := view_forward.cross(pose.up).normalized()
		view_forward = view_forward.rotated(view_right, first_person_pitch).normalized()
		target_basis = Basis.looking_at(view_forward, pose.up)
	else:
		var forward: Vector3 = pose.forward
		var up: Vector3 = pose.up
		var right := forward.cross(up).normalized()
		var offset_direction := -forward * cos(chase_yaw) * cos(chase_pitch)
		offset_direction += right * sin(chase_yaw) * cos(chase_pitch) + up * sin(chase_pitch)
		target_position = pose.position + offset_direction * 6.315
		var camera_limit := arena_width * 0.5 - 0.6
		target_position = target_position.clamp(Vector3.ONE * -camera_limit, Vector3.ONE * camera_limit)
		var focus: Vector3 = pose.position + forward * 4.5
		target_basis = Basis.looking_at((focus - target_position).normalized(), up)
	var weight := 1.0 if not initialized else 1.0 - exp(-delta * 10.0)
	position = target_position if first_person and not force_overview else position.lerp(target_position, weight)
	quaternion = target_basis.get_rotation_quaternion() if first_person and not force_overview else quaternion.slerp(target_basis.get_rotation_quaternion(), weight)
	# Boost can widen first-person FOV as a speed cue, but must never zoom the
	# arena while following a pipe from chase or overview.
	var target_fov := (92.0 if boosting else 84.0) if first_person else 78.0
	fov = lerpf(fov, target_fov, weight)
	initialized = true
