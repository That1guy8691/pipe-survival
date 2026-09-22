extends SceneTree
## The pipe-ring camera rides around the leading end as the pipe advances.

const CameraRig = preload("res://scripts/camera_rig.gd")

var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var camera := CameraRig.new()
	root.add_child(camera)
	await process_frame
	camera.view = camera.View.RING
	camera.ring_angle = 0.0
	camera.initialized = false
	camera.follow({"position": Vector3.ZERO, "forward": Vector3.FORWARD, "up": Vector3.UP}, 1.0)
	var first_position := camera.global_position
	check(is_equal_approx(first_position.length(), camera.RING_RADIUS), "Camera starts at the configured distance on the pipe-tip ring")

	var next_head := Vector3(0.0, 0.0, -3.0)
	camera.ring_angle = PI * 0.5
	camera.initialized = false
	camera.follow({"position": next_head, "forward": Vector3.FORWARD, "up": Vector3.UP}, 1.0)
	var next_position := camera.global_position
	check(is_equal_approx(next_position.distance_to(next_head), camera.RING_RADIUS), "Camera stays on the same ring as its angle changes")
	check(is_equal_approx((next_position - first_position).dot(Vector3.FORWARD), 3.0), "Camera advances with the pipe while circling its tip")
	print("CAMERA RING: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
