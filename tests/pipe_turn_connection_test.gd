extends "res://tests/pipe_cutaway_visual_test.gd"
## The elbow behind the followed head must stay intact on sideways turns.

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	game.set_process(false)
	game.hud.set_process(false)
	game.bot_count = 1
	game.pipes.pattern_rng.seed = 821
	game.player_pattern = game.PipeRenderer.Appearance.Pattern.CHECKER
	game.start_round(821)
	game.state = "playing"
	game.hud.hide()
	game.orbs.hide()
	game.arena.set_labels_visible(false)
	game.camera.view = game.camera.View.CHASE
	for command in ["left", "right", "down"]:
		game.pipes.reset(2)
		for i in range(2):
			game.pipes.inlets[i].hide()
			game.pipes.heads[i].hide()
			game.pipes.markers[i].hide()
			game.pipes.active[i].hide()
		for z in range(25, 15, -1):
			section(0, Vector3i(15, 15, z), Vector3i.FORWARD, Vector3i.FORWARD)
		var rider: Dictionary = game.sim.riders[0]
		rider.cell = Vector3i(15, 15, 15)
		rider.forward = Vector3i.FORWARD
		rider.up = Vector3i.UP
		game.pipes.heads[0].show()
		game.pipes.markers[0].show()
		game.camera.initialized = false
		game.pipes.begin_rider(0, rider, rider.forward)
		game.camera.follow(game.pipes.pose(0, 0.0), 0.0)
		var outgoing: Vector3i = game.Rules.turn(rider, command)
		game.pipes.begin_rider(0, rider, outgoing)
		for frame in range(21):
			var phase := frame / 20.0
			game.pipes.animate_rider(0, phase)
			game.camera.follow(game.pipes.pose(0, phase), game.Rules.STEP_TIME / 20.0)
			if frame in [10, 15, 20]:
				await check_connection("%s-turn-%02d" % [command, frame])
		var next_up: Vector3i = game.Rules.next_up(rider, outgoing)
		section(0, rider.cell, rider.forward, outgoing)
		rider.cell += outgoing
		rider.forward = outgoing
		rider.up = next_up
		game.pipes.begin_rider(0, rider, outgoing)
		for frame in range(21):
			var phase := frame / 20.0
			game.pipes.animate_rider(0, phase)
			game.camera.follow(game.pipes.pose(0, phase), game.Rules.STEP_TIME / 20.0)
			if frame in [0, 10, 20]:
				await check_connection("%s-exit-%02d" % [command, frame])
	print("TURN CONNECTION: %d failures" % failures)
	quit(1 if failures else 0)

func check_connection(label: String) -> void:
	cutaway(false)
	var plain := await capture(label + "-off.png")
	cutaway(true)
	var filtered := await capture(label + "-on.png")
	var changed := differences(plain, filtered)
	print("%s changed_pixels=%d" % [label, changed])
	check(changed < 10, label + " removes an unobstructing part of the connected tail")
