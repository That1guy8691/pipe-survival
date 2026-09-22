extends Camera3D

const Rules = preload("res://scripts/simulation.gd")

enum View { CHASE, FIRST_PERSON, OVERVIEW }
var view: View = View.CHASE
var overview: bool:
	get: return view == View.OVERVIEW
	set(value): view = View.OVERVIEW if value else View.CHASE
var first_person: bool:
	get: return view == View.FIRST_PERSON
var boosting := false
var yaw := 0.67
var pitch := 0.43
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
	view = (view + 1) % 3 as View
	initialized = false

func view_name() -> String:
	return ["CHASE CAMERA", "FIRST PERSON", "OVERVIEW"][view]

func orbit(relative: Vector2) -> void:
	yaw -= relative.x * 0.006
	pitch = clampf(pitch + relative.y * 0.006, -0.8, 1.25)

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
	elif first_person:
		target_position = pose.position + pose.forward * 0.3
		target_basis = Basis.looking_at(pose.forward, pose.up)
	else:
		var forward: Vector3 = pose.forward
		var up: Vector3 = pose.up
		target_position = pose.position - forward * 5.8 + up * 2.5
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
