extends Camera3D

const Rules = preload("res://scripts/simulation.gd")
const MIN_FOV := 60.0
const MAX_FOV := 110.0

enum View { CHASE, FIRST_PERSON, OVERVIEW }
var view: View = View.CHASE
var overview: bool:
	get: return view == View.OVERVIEW
	set(value): view = View.OVERVIEW if value else View.CHASE
var first_person: bool:
	get: return view == View.FIRST_PERSON
var boosting := false
var base_fov := 78.0
var yaw := 0.67
var pitch := 0.43
var chase_yaw := 0.0
var chase_pitch := 0.407
var first_person_yaw := 0.0
var first_person_pitch := 0.0
var arena_width := Rules.DEFAULT_WIDTH
var distance := arena_width * 1.7
var initialized := false
var impact_time := 0.0
var impact_duration := 0.28
var impact_strength := 0.0

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

func set_base_fov(value: float) -> void:
	base_fov = clampf(value, MIN_FOV, MAX_FOV)

func toggle() -> void:
	view = (view + 1) % View.size() as View
	initialized = false

func view_name() -> String:
	return ["CHASE CAMERA", "FIRST PERSON", "OVERVIEW"][view]

func orbit(relative: Vector2) -> void:
	if overview:
		yaw = wrapf(yaw - relative.x * 0.006, -PI, PI)
		pitch = clampf(pitch + relative.y * 0.006, -0.8, 1.25)
	elif first_person:
		first_person_yaw = wrapf(first_person_yaw - relative.x * 0.006, -PI, PI)
		first_person_pitch = clampf(first_person_pitch + relative.y * 0.006, -0.8, 0.8)
	else:
		chase_yaw = wrapf(chase_yaw - relative.x * 0.006, -PI, PI)
		chase_pitch = clampf(chase_pitch + relative.y * 0.006, -0.35, 1.1)

func orbit_step(horizontal: float, vertical: float) -> void:
	# One arrow-key press moves the camera by roughly eight degrees.
	orbit(Vector2(-horizontal * 24.0, -vertical * 24.0))

func zoom(amount: float) -> void:
	distance = clampf(distance + amount, arena_width, arena_width * 2.375)

func trigger_impact(strength: float = 1.0) -> void:
	impact_time = impact_duration
	impact_strength = clampf(strength, 0.0, 1.0)

func clear_impact() -> void:
	impact_time = 0.0
	impact_strength = 0.0

func focus_point(point: Vector3, delta: float, focus_distance: float = 12.0) -> void:
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * focus_distance
	var target_position := point + offset
	var target_basis := Basis.looking_at((point - target_position).normalized(), Vector3.UP)
	var weight := 1.0 if not initialized else 1.0 - exp(-delta * 10.0)
	position = position.lerp(target_position, weight)
	quaternion = quaternion.slerp(target_basis.get_rotation_quaternion(), weight)
	fov = lerpf(fov, base_fov, weight)
	apply_impact(delta, target_basis)
	initialized = true

func follow(pose: Dictionary, delta: float, force_overview: bool = false) -> void:
	var target_position: Vector3
	var target_basis: Basis
	if overview or force_overview:
		var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
		var focus: Vector3 = pose.position * 0.12
		target_position = focus + offset
		target_basis = Basis.looking_at((focus - target_position).normalized(), Vector3.UP)
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
	var target_fov := base_fov
	if first_person:
		target_fov += 6.0 + (8.0 if boosting else 0.0)
	target_fov = minf(target_fov, 120.0)
	fov = lerpf(fov, target_fov, weight)
	apply_impact(delta, target_basis)
	initialized = true

func apply_impact(delta: float, target_basis: Basis) -> void:
	if impact_time <= 0.0:
		return
	var elapsed := impact_duration - impact_time
	var envelope := impact_time / impact_duration
	var shake := sin(elapsed * 68.0) * envelope * impact_strength
	position += target_basis.x * shake * 0.32 + target_basis.y * cos(elapsed * 52.0) * envelope * impact_strength * 0.16
	fov += envelope * impact_strength * 2.5
	impact_time = maxf(0.0, impact_time - delta)
