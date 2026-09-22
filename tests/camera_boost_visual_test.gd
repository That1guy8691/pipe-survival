extends SceneTree
## Rendered regression: overview framing stays fixed when the followed pipe boosts.

var directory := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-dir="):
			directory = argument.trim_prefix("--qa-dir=")
	call_deferred("run")

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(filename))

func run() -> void:
	if directory.is_empty():
		push_error("Provide --qa-dir=<existing folder>")
		quit(1)
		return
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	game.set_process(false)
	game.set_auto_mode(true)
	game.start_round(821)
	game.state = "playing"
	game.camera.view = game.camera.View.OVERVIEW
	game.camera.initialized = false
	game.sim.riders[game.watch_id].boosting = false
	game._process(0.0)
	var normal_fov: float = game.camera.fov
	await capture("overview-follow-normal.png")
	game.sim.riders[game.watch_id].boosting = true
	game._process(0.0)
	var boost_fov: float = game.camera.fov
	await capture("overview-follow-boost.png")
	if not is_equal_approx(normal_fov, boost_fov):
		push_error("Rendered overview FOV changed from %.3f to %.3f" % [normal_fov, boost_fov])
		quit(1)
		return
	print("CAMERA BOOST VISUAL: overview framing stable at %.3f degrees" % normal_fov)
	quit(0)
