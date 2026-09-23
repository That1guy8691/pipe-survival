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
	var chase_normal := settle(camera, false, camera.View.CHASE)
	var chase_boost := settle(camera, true, camera.View.CHASE)
	check(is_equal_approx(chase_normal, chase_boost), "Chase FOV is stable while the followed pipe boosts")
	var first_normal := settle(camera, false, camera.View.FIRST_PERSON)
	var first_boost := settle(camera, true, camera.View.FIRST_PERSON)
	check(first_boost > first_normal, "First-person boost FOV remains an intentional speed cue")
	camera.set_base_fov(96.0)
	var selected_fov := settle(camera, false, camera.View.CHASE)
	check(is_equal_approx(selected_fov, 96.0), "Selected base FOV applies to the chase view")
	var selected_first_person_fov := settle(camera, false, camera.View.FIRST_PERSON)
	check(is_equal_approx(selected_first_person_fov, 102.0), "Selected FOV preserves the first-person speed cue")
	camera.set_base_fov(500.0)
	check(is_equal_approx(camera.base_fov, camera.MAX_FOV), "FOV cannot exceed its maximum")
	camera.set_base_fov(0.0)
	check(is_equal_approx(camera.base_fov, camera.MIN_FOV), "FOV cannot go below its minimum")
	print("CAMERA BOOST VIEW: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
