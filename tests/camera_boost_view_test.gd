extends SceneTree
## Regression: boosting a followed pipe must not zoom chase or overview views.

const CameraRig = preload("res://scripts/camera_rig.gd")

var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle(camera: CameraRig, boosting: bool, view: CameraRig.View) -> float:
	camera.view = view
	camera.initialized = false
	camera.boosting = boosting
	camera.follow({"position": Vector3.ZERO, "forward": Vector3.FORWARD, "up": Vector3.UP}, 1.0)
	return camera.fov

func _initialize() -> void:
	var camera := CameraRig.new()
	root.add_child(camera)
	await process_frame
	var overview_normal := settle(camera, false, camera.View.OVERVIEW)
	var overview_boost := settle(camera, true, camera.View.OVERVIEW)
	check(is_equal_approx(overview_normal, overview_boost), "Overview FOV is stable while the followed pipe boosts")
	var ring_normal := settle(camera, false, camera.View.RING)
	var ring_boost := settle(camera, true, camera.View.RING)
	check(is_equal_approx(ring_normal, ring_boost), "Pipe-ring FOV is stable while the followed pipe boosts")
	var chase_normal := settle(camera, false, camera.View.CHASE)
	var chase_boost := settle(camera, true, camera.View.CHASE)
	check(is_equal_approx(chase_normal, chase_boost), "Chase FOV is stable while the followed pipe boosts")
	var first_normal := settle(camera, false, camera.View.FIRST_PERSON)
	var first_boost := settle(camera, true, camera.View.FIRST_PERSON)
	check(first_boost > first_normal, "First-person boost FOV remains an intentional speed cue")
	print("CAMERA BOOST VIEW: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
