extends "res://tests/pipe_cutaway_visual_test.gd"
## A camera intersecting a followed survivor's pipe must still see through it.

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	game.set_process(false)
	game.hud.set_process(false)
	game.bot_count = 1
	game.pipes.pattern_rng.seed = 821
	game.start_round(821)
	game.state = "playing"
	game.sim.riders[0].alive = false
	game.watch_id = 1
	game.hud.hide()
	game.orbs.hide()
	game.arena.set_labels_visible(false)
	for i in range(2):
		game.pipes.inlets[i].hide()
		game.pipes.heads[i].hide()
		game.pipes.markers[i].hide()
		game.pipes.active[i].hide()
	var rider: Dictionary = game.sim.riders[1]
	rider.cell = Vector3i(15, 15, 15)
	rider.forward = Vector3i.FORWARD
	rider.up = Vector3i.UP
	section(1, Vector3i(15, 15, 16), rider.forward, rider.forward)
	section(1, Vector3i(15, 15, 17), rider.forward, Vector3i.UP)
	game.pipes.begin_rider(1, rider, rider.forward)
	game.pipes.animate_rider(1, 0.5)
	game.pipes.heads[1].show()
	game.pipes.markers[1].show()
	game.camera.view = game.camera.View.CHASE
	game.camera.initialized = false
	game.camera.follow(game.pipes.pose(1, 0.5), 0.0)
	for batch: MultiMeshInstance3D in game.pipes.batches[1]:
		batch.hide()
	cutaway(true)
	var reference := await capture("spectator-reference.png")
	# The camera can pass through a section while smoothing around a turn or
	# switching the followed survivor, regardless of when the trail was created.
	for kind in range(2):
		var batch: MultiMeshInstance3D = game.pipes.batches[1][kind]
		batch.show()
		for offset in [0.0, 0.4, 0.55]:
			var orientation: Basis = game.camera.global_basis * Basis(Vector3.RIGHT, PI * 0.5)
			var origin: Vector3 = game.camera.to_global(Vector3(offset, 0.0, -0.15))
			if kind == 1:
				var middle: Vector3 = game.PipeRenderer.Geometry.centerline(true, 0.5)
				origin = game.camera.global_position - orientation * (middle + Vector3.UP * offset)
			batch.multimesh.set_instance_transform(0, Transform3D(orientation, origin))
			cutaway(false)
			var blocked := await capture("spectator-%d-%s-off.png" % [kind, offset])
			cutaway(true)
			var cleared := await capture("spectator-%d-%s-on.png" % [kind, offset])
			var head_pixel: Vector2 = game.camera.unproject_position(game.pipes.heads[1].global_position)
			check(region_differences(blocked, reference, head_pixel, 20.0) > 100,
				"Close camera fixture must obscure the survivor")
			check_revealed("SPECTATOR kind=%d offset=%.2f" % [kind, offset], blocked, cleared,
				reference, head_pixel, 20.0)
		batch.hide()
	print("CLOSE CAMERA CUTAWAY: %d failures" % failures)
	quit(1 if failures else 0)
