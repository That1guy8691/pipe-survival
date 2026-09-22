extends SceneTree

const Rules = preload("res://scripts/simulation.gd")
const Renderer = preload("res://scripts/pipe_renderer.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func configure_two_riders(sim) -> void:
	sim.endless_mode = true
	sim.reset(804, 1, 40)
	for i in range(2, sim.riders.size()):
		sim.riders[i].alive = false
	sim.occupied.clear()
	var player: Dictionary = sim.riders[0]
	player.cell = Vector3i(7, 5, 5)
	player.forward = Vector3i.RIGHT
	player.up = Vector3i.UP
	player.score = 432
	player.survival_time = 18.5
	player.orb_count = 3
	player.eliminations = 2
	player.length = 11
	var bot: Dictionary = sim.riders[1]
	bot.cell = Vector3i(8, 5, 5)
	bot.forward = Vector3i.UP
	bot.up = Vector3i.RIGHT
	bot.score = 70
	bot.length = 9
	for cell in [Vector3i(5, 5, 5), Vector3i(6, 5, 5), player.cell]:
		sim.occupied[cell] = 0
	for cell in [Vector3i(8, 4, 5), bot.cell]:
		sim.occupied[cell] = 1
	sim.scoring.orbs.clear()
	sim.finished = false
	sim.winner = -1

func run() -> void:
	var sim := Rules.new()
	configure_two_riders(sim)
	var directions: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.UP]
	var moves: Array[Dictionary] = sim.advance(directions, [0, 1], 0.0)
	var player_cells_remain := false
	for owner in sim.occupied.values():
		player_cells_remain = player_cells_remain or int(owner) == 0
	check(not sim.riders[0].alive and not player_cells_remain,
		"Endless death clears every occupied cell owned by that rider")
	check(sim.riders[0].score == 0 and sim.riders[0].orb_count == 0 and sim.riders[0].eliminations == 0
		and is_zero_approx(sim.riders[0].survival_time),
		"Death resets the rider's score and life statistics immediately")
	check(sim.riders[1].score == 170, "The surviving rider keeps its score and earns elimination credit")
	check(sim.riders[1].alive and sim.riders[1].cell == Vector3i(8, 6, 5)
		and sim.occupied.get(Vector3i(8, 4, 5), -1) == 1,
		"The other rider and its older trail continue unchanged")
	check(not sim.finished and sim.alive_ids().size() == 1 and sim.winner == -1,
		"Endless remains active with only one surviving rider")
	var bot_cell_before: Vector3i = sim.riders[1].cell
	check(sim.respawn_rider(0), "A dead rider respawns when a safe wall inlet is open")
	var player: Dictionary = sim.riders[0]
	var spawn_forward: Vector3i = sim.inlet_direction(player.source_cell)
	check(player.alive and sim.occupied.get(player.cell, -1) == 0
		and spawn_forward != Vector3i.ZERO and player.forward == spawn_forward
		and sim.is_open(player.cell + player.forward),
		"Respawn occupies a unique finite wall cell with a clear inward step")
	check(player.score == 0 and player.orb_count == 0 and player.eliminations == 0
		and player.length == 0 and is_zero_approx(player.survival_time),
		"Respawn starts a fresh life with zero score and statistics")
	check(sim.riders[1].cell == bot_cell_before and sim.occupied.get(Vector3i(8, 4, 5), -1) == 1,
		"Respawning the player leaves the survivor and its trail intact")

	player.alive = false
	sim.remove_rider_trail(0)
	sim.occupied.clear()
	for a in range(1, sim.cell_count - 1):
		for b in range(1, sim.cell_count - 1):
			for side in [0, sim.cell_count - 1]:
				sim.occupied[Vector3i(side, a, b)] = 1
				sim.occupied[Vector3i(a, side, b)] = 1
				sim.occupied[Vector3i(a, b, side)] = 1
	check(not sim.respawn_rider(0) and not player.alive,
		"A rider waits when every safe wall spawn is occupied")

	await test_renderer_cleanup()
	await test_title_mode_and_live_restart()
	await test_auto_respawn()
	print("ENDLESS MODE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_renderer_cleanup() -> void:
	var sim := Rules.new()
	configure_two_riders(sim)
	var renderer := Renderer.new()
	renderer.model = sim
	root.add_child(renderer)
	await process_frame
	renderer.reset(2)
	var moves: Array[Dictionary] = [
		{"id": 0, "cell": Vector3i(5, 5, 5), "incoming": Vector3i.RIGHT, "outgoing": Vector3i.RIGHT, "died": false},
		{"id": 1, "cell": Vector3i(8, 4, 5), "incoming": Vector3i.UP, "outgoing": Vector3i.UP, "died": false}]
	renderer.commit(moves)
	check(renderer.batches[0][0].multimesh.visible_instance_count == 1
		and renderer.batches[1][0].multimesh.visible_instance_count == 1,
		"Both riders have visible renderer batches before a death")
	sim.endless_mode = false
	renderer.commit([{"id": 0, "cell": Vector3i(6, 5, 5), "incoming": Vector3i.RIGHT,
		"outgoing": Vector3i.RIGHT, "died": true}])
	check(renderer.batches[0][0].multimesh.visible_instance_count == 2,
		"Survival continues to retain eliminated trails")
	sim.endless_mode = true
	renderer.reset(2)
	renderer.commit(moves)
	renderer.commit([{"id": 0, "cell": Vector3i(6, 5, 5), "incoming": Vector3i.RIGHT,
		"outgoing": Vector3i.RIGHT, "died": true}])
	check(renderer.batches[0][0].multimesh.visible_instance_count == 0
		and renderer.batches[1][0].multimesh.visible_instance_count == 1,
		"Removing a dead pipe clears only its own visible renderer batches")
	check(not renderer.inlets[0].visible and renderer.inlets[1].visible,
		"Only the dead rider's wall inlet is hidden")
	root.remove_child(renderer)
	renderer.queue_free()

func test_title_mode_and_live_restart() -> void:
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await process_frame
	game.bot_count = 1
	game.arena_width = 40
	game.player_name = "MATRIX"
	game.player_color = Color("ff6e91")
	game.hud._process(0.0)
	check(game.hud.mode_toggle.visible and not game.endless_mode,
		"The title exposes Survival as the default mode")
	game.hud.mode_toggle.emit_signal("toggled", true)
	game.hud._process(0.0)
	check(game.endless_mode and game.hud.mode_toggle.button_pressed
		and game.bot_count == 1 and game.arena_width == 40
		and game.player_name == "MATRIX" and game.player_color == Color("ff6e91"),
		"Selecting Endless preserves arena, bot, and player options")
	game.start_round(902)
	game.state = "playing"
	var sim = game.sim
	# Make the bot hit the outer wall while the player continues in open space.
	sim.occupied.clear()
	for i in range(2, sim.riders.size()):
		sim.riders[i].alive = false
	sim.riders[0].cell = Vector3i(6, 6, 6)
	sim.riders[0].forward = Vector3i.RIGHT
	sim.riders[0].up = Vector3i.UP
	sim.riders[1].cell = Vector3i(0, 10, 10)
	sim.riders[1].forward = Vector3i.LEFT
	sim.riders[1].up = Vector3i.UP
	sim.occupied[sim.riders[0].cell] = 0
	sim.occupied[sim.riders[1].cell] = 1
	sim.occupied[Vector3i(1, 10, 10)] = 1
	game.pipes.reset(2)
	game.motion.reset()
	game.motion.directions[0] = Vector3i.RIGHT
	game.motion.directions[1] = Vector3i.LEFT
	game.pipes.begin_step(sim.riders, game.motion.directions)
	var bot_movers: Array[int] = [1]
	var bot_death: Array[Dictionary] = sim.advance(game.motion.directions, bot_movers, 0.0)
	game.on_completed(bot_death)
	check(not sim.riders[1].alive and game.respawn_timers[1] == game.BOT_RESPAWN_DELAY,
		"A dead bot gets a short automatic respawn timer")
	for x in range(sim.cell_count):
		for y in range(sim.cell_count):
			for z in range(sim.cell_count):
				if x == 0 or y == 0 or z == 0 or x == sim.cell_count - 1 or y == sim.cell_count - 1 or z == sim.cell_count - 1:
					sim.occupied[Vector3i(x, y, z)] = 0
	game.advance_endless_respawns(game.BOT_RESPAWN_DELAY)
	check(not sim.riders[1].alive and game.respawn_timers[1] == game.RESPAWN_RETRY_DELAY,
		"A bot waits and retries when no wall spawn is available")
	sim.occupied.clear()
	sim.occupied[sim.riders[0].cell] = 0
	game.advance_endless_respawns(game.RESPAWN_RETRY_DELAY)
	var bot: Dictionary = sim.riders[1]
	check(bot.alive and sim.occupied.get(bot.cell, -1) == 1
		and sim.is_open(bot.cell + bot.forward) and game.pipes.inlets[1].visible,
		"The bot returns at a safe spawn with its renderer restored")

	# Put the player directly against the bot's trail to exercise the quick restart.
	sim.remove_rider_trail(0)
	sim.remove_rider_trail(1)
	sim.riders[0].alive = true
	sim.riders[0].cell = Vector3i(7, 7, 7)
	sim.riders[0].forward = Vector3i.RIGHT
	sim.riders[0].up = Vector3i.UP
	sim.riders[0].score = 432
	sim.riders[0].survival_time = 16.0
	sim.riders[0].orb_count = 3
	sim.riders[0].eliminations = 2
	sim.riders[0].length = 12
	sim.riders[1].alive = true
	sim.riders[1].cell = Vector3i(8, 7, 7)
	sim.riders[1].forward = Vector3i.UP
	sim.riders[1].up = Vector3i.RIGHT
	sim.occupied[Vector3i(5, 7, 7)] = 0
	sim.occupied[Vector3i(6, 7, 7)] = 0
	sim.occupied[sim.riders[0].cell] = 0
	sim.occupied[Vector3i(8, 6, 7)] = 1
	sim.occupied[sim.riders[1].cell] = 1
	game.pipes.reset(2)
	game.motion.reset()
	game.motion.directions[0] = Vector3i.RIGHT
	game.motion.directions[1] = Vector3i.UP
	game.pipes.begin_step(sim.riders, game.motion.directions)
	sim.elapsed_time = 81.0
	var player_movers: Array[int] = [0]
	var player_death: Array[Dictionary] = sim.advance(game.motion.directions, player_movers, 0.0)
	game.on_completed(player_death)
	game.hud._process(0.0)
	check(not sim.riders[0].alive and game.state == "playing" and not sim.finished
		and game.hud.quick_restart.visible,
		"Player death keeps Endless running and reveals Quick Restart")
	var bot_cell: Vector3i = sim.riders[1].cell
	var bot_trail_cell := Vector3i(8, 6, 7)
	check(sim.riders[0].score == 0, "Player death clears the displayed score before restarting")
	var arena_before: Node3D = game.arena
	game.hud.quick_restart.emit_signal("pressed")
	game.hud._process(0.0)
	check(sim.riders[0].alive and sim.riders[0].score == 0
		and is_zero_approx(sim.riders[0].survival_time),
		"Quick Restart restores only the player's pipe with a fresh score")
	check(sim.riders[1].cell == bot_cell and sim.occupied.get(bot_cell, -1) == 1
		and sim.occupied.get(bot_trail_cell, -1) == 1 and sim.elapsed_time == 81.0
		and game.arena_width == 40 and game.arena == arena_before and game.state == "playing",
		"Player restart preserves the live bot, trails, session clock, and selected cube")
	game.queue_free()
	await process_frame

func test_auto_respawn() -> void:
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	game.set_process(false)
	game.bot_count = 1
	game.arena_width = 40
	game.endless_mode = true
	game.set_auto_mode(true)
	game.start_round(903)
	game.state = "playing"
	var sim = game.sim
	# Both riders die in the same step, leaving no survivor for the camera to follow.
	sim.occupied.clear()
	for i in range(2):
		sim.riders[i].cell = Vector3i(0 if i == 0 else 19, 5 + i, 5)
		sim.riders[i].forward = Vector3i.LEFT if i == 0 else Vector3i.RIGHT
		sim.riders[i].up = Vector3i.UP
		sim.riders[i].score = 300 + i
		sim.riders[i].orb_count = 4
		sim.riders[i].eliminations = 2
		sim.occupied[sim.riders[i].cell] = i
	game.motion.reset()
	var directions: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT]
	var movers: Array[int] = [0, 1]
	game.pipes.begin_step(sim.riders, directions)
	game.on_completed(sim.advance(directions, movers, 0.0))
	check(sim.alive_ids().is_empty() and not sim.finished and game.player_respawn_pending
		and game.respawn_timers[0] == game.BOT_RESPAWN_DELAY,
		"Auto Mode schedules the player's restart even when every rider dies")
	check(sim.riders[0].score == 0 and sim.riders[1].score == 0
		and sim.riders[1].orb_count == 0 and sim.riders[1].eliminations == 0,
		"Both player and bot scores reset on death")
	game.toggle_pause()
	game._process(1.0)
	check(game.respawn_timers[0] == game.BOT_RESPAWN_DELAY and sim.alive_ids().is_empty(),
		"Pausing freezes automatic respawn timers")
	game.toggle_pause()
	game.advance_endless_respawns(1.0)
	check(sim.alive_ids().is_empty(), "Automatic respawns respect the delay")
	# Keep all wall inlets occupied through the first attempt, then free them.
	for a in range(1, sim.cell_count - 1):
		for b in range(1, sim.cell_count - 1):
			for side in [0, sim.cell_count - 1]:
				sim.occupied[Vector3i(side, a, b)] = 1
				sim.occupied[Vector3i(a, side, b)] = 1
				sim.occupied[Vector3i(a, b, side)] = 1
	game.advance_endless_respawns(game.BOT_RESPAWN_DELAY)
	check(game.player_respawn_pending and not sim.riders[0].alive
		and game.respawn_timers[0] == game.RESPAWN_RETRY_DELAY,
		"Auto Mode keeps retrying the player's restart when every inlet is blocked")
	sim.occupied.clear()
	game.advance_endless_respawns(game.RESPAWN_RETRY_DELAY)
	check(sim.alive_ids().size() == 2 and not game.player_respawn_pending and game.state == "playing"
		and game.pipes.active[0].visible and game.pipes.active[1].visible,
		"Both riders resume automatically once safe inlets reopen")
	# Enabling Auto Mode after a manual crash must also recover the player's pipe.
	game.set_auto_mode(false)
	sim.riders[0].alive = false
	sim.remove_rider_trail(0)
	game.pipes.remove_rider(0)
	game.toggle_pause()
	game.set_auto_mode(true)
	check(game.player_respawn_pending and game.respawn_timers[0] == game.BOT_RESPAWN_DELAY,
		"Enabling Auto Mode from the pause menu while dead schedules a restart")
	game.toggle_pause()
	game.set_auto_mode(false)
	game.advance_endless_respawns(game.BOT_RESPAWN_DELAY)
	check(not sim.riders[0].alive and not game.player_respawn_pending,
		"Returning to manual control leaves restart under the player's control")
	game.set_auto_mode(true)
	game.advance_endless_respawns(game.BOT_RESPAWN_DELAY)
	check(sim.riders[0].alive, "Re-enabling Auto Mode restarts the player's pipe")
	game.queue_free()
	await process_frame
