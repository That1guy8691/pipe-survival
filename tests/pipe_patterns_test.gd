extends SceneTree
## Appearance survives the growing-to-batched handoff, round reset, and Endless respawn.

var failures := 0
var checks := 0
var directory := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-dir="):
			directory = argument.trim_prefix("--qa-dir=")
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func capture(filename: String) -> void:
	if directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(filename))

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	game.set_process(false)
	game.hud.set_process(false)
	game.hud.hide()
	game.bot_count = 1
	game.arena_width = 40
	game.player_color = Color("56eddf")
	for endless in [false, true]:
		game.endless_mode = endless
		for pattern in range(3):
			game.player_pattern = pattern
			game.start_round(812)
			game.state = "playing"
			game.arena.hide()
			game.orbs.hide()
			game.hud.hide()
			game.pipes.reset(2)
			for i in range(2):
				game.pipes.inlets[i].hide()
				game.pipes.heads[i].hide()
				game.pipes.markers[i].hide()
				game.pipes.active[i].hide()
			var active: ShaderMaterial = game.pipes.active_materials[0]
			for batch in game.pipes.batches[0]:
				check(batch.material_override.get_shader_parameter("pattern") == pattern,
					"Reset must apply the player pattern to both trail meshes")
				check(batch.material_override.get_shader_parameter("pipe_color") == game.player_color,
					"Reset must preserve the selected base color")
			check(game.pipes.active_materials[1].get_shader_parameter("pattern") == 0,
				"Player customization must leave bot pipes solid")
			var moves: Array[Dictionary] = [
				{"id": 0, "cell": Vector3i(10, 10, 11), "incoming": Vector3i.FORWARD, "outgoing": Vector3i.FORWARD, "died": false},
				{"id": 0, "cell": Vector3i(10, 10, 10), "incoming": Vector3i.FORWARD, "outgoing": Vector3i.RIGHT, "died": false}]
			var rider: Dictionary = game.sim.riders[0].duplicate()
			for move in moves:
				rider.cell = move.cell
				rider.forward = move.incoming
				game.pipes.begin_rider(0, rider, move.outgoing)
				game.pipes.animate_rider(0, 1.0)
				var kind := 0 if move.incoming == move.outgoing else 1
				var finished: ShaderMaterial = game.pipes.batches[0][kind].material_override
				for uniform in ["pattern", "pipe_color", "accent_color", "segment_length", "fill"]:
					check(active.get_shader_parameter(uniform) == finished.get_shader_parameter(uniform),
						"Growing and completed sections must agree on %s" % uniform)
				var segment: Array[Dictionary] = [move]
				game.pipes.commit(segment)
			check(game.pipes.counts[0] == [1, 1], "The straight and elbow both reach the trail")
			rider.cell = Vector3i(11, 10, 10)
			rider.forward = Vector3i.RIGHT
			game.pipes.begin_rider(0, rider, Vector3i.RIGHT)
			game.pipes.animate_rider(0, 0.55)
			var center: Vector3 = game.sim.world(Vector3i(10, 10, 10)) + Vector3(1, 0, 1)
			game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			game.camera.size = 6.0
			game.camera.position = center + Vector3(3.6, 6, 5)
			game.camera.look_at(center)
			if not endless:
				await capture("pipe-pattern-%d-growing.png" % pattern)
				game.pipes.animate_rider(0, 1.0)
				var final_segment: Array[Dictionary] = [{"id": 0, "cell": rider.cell, "incoming": Vector3i.RIGHT,
					"outgoing": Vector3i.RIGHT, "died": false}]
				game.pipes.commit(final_segment)
				await capture("pipe-pattern-%d-complete.png" % pattern)
			else:
				game.sim.remove_rider_trail(0)
				game.sim.riders[0].alive = false
				game.pipes.remove_rider(0)
				game.request_player_restart()
				check(game.sim.riders[0].alive and game.pipes.active[0].visible,
					"Endless restart restores the growing pipe")
				check(active.get_shader_parameter("pattern") == pattern,
					"Endless restart retains the selected pattern")
	print("PIPE PATTERNS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
