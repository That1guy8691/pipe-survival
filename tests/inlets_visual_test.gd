extends SceneTree
## Opt-in captures of real inlet geometry, initial cameras, and later arena coverage.

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
		push_error("Provide --qa-dir=<existing folder> for captures")
		quit(1)
		return
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	game.set_process(false)
	game.start_round(821)
	game._process(0.0)
	await capture("inlets-start-chase.png")
	game.camera.view = game.camera.View.FIRST_PERSON
	game.camera.initialized = false
	game._process(0.0)
	await capture("inlets-start-first-person.png")
	game.state = "playing"
	game.motion.advance(1.0)
	game._process(0.0)
	game.hud.visible = false
	var rider: Dictionary = game.sim.riders[0]
	var origin: Vector3 = game.pipes.inlets[0].position
	var forward := Vector3(rider.source_forward)
	var right := forward.cross(Vector3(rider.up))
	game.camera.position = origin + forward * 6.0 + Vector3(rider.up) * 2.8 + right * 4.0
	game.camera.look_at(origin + forward, Vector3(rider.up))
	game.camera.fov = 60.0
	await capture("inlet-closeup.png")
	game.hud.visible = true
	game.motion.autoplay = true
	for step in range(360):
		if game.sim.finished:
			break
		game.motion.advance(game.Rules.STEP_TIME)
		if step % 30 == 0:
			await process_frame
	game.camera.view = game.camera.View.OVERVIEW
	game.camera.initialized = false
	game.camera.distance = game.sim.arena_width * 1.4
	game.state = "playing"
	game._process(0.0)
	await capture("inlets-dense-arena.png")
	print("INLETS VISUAL: captured initial chase, first person, wall fitting, and 120-second arena")
	quit(0)
