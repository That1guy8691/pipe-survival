extends Node
## Opt-in in-engine smoke driver. Never active in an ordinary play session.

var game: Node
var directory := ""
var checks := 0
var failures := 0

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("SMOKE FAIL: " + message)

func key(code: Key) -> void:
	hold_key(code, true)
	hold_key(code, false)

func hold_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(directory.path_join(filename))
	require(result == OK, "Screenshot " + filename)

func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-dir="):
			directory = argument.trim_prefix("--qa-dir=")
	if directory.is_empty():
		push_error("--qa requires --qa-dir=<existing output directory>")
		get_tree().quit(1)
		return
	await wait_seconds(0.5)
	await capture("01-title.png")
	require(game.bot_count == 15 and game.sim.riders.size() == 16, "Default is fifteen bots")
	game.hud.bot_selector.select(0)
	game.hud.bot_selector.item_selected.emit(0)
	require(game.bot_count == 7 and game.sim.riders.size() == 8, "Bot selector rebuilds a seven-bot arena")
	game.hud.bot_selector.select(1)
	game.hud.bot_selector.item_selected.emit(1)
	key(KEY_ENTER)
	await get_tree().process_frame
	require(game.state == "countdown", "Enter starts a round")
	require(game.sim.occupied.size() == 16, "Start clears the title maze")
	game.countdown = 0.03
	await wait_seconds(0.45)
	key(KEY_C)
	await get_tree().process_frame
	require(game.camera.first_person, "C switches chase to first person")
	hold_key(KEY_SHIFT, true)
	await wait_seconds(0.4)
	require(game.sim.riders[0].boosting, "Shift engages the player's boost")
	require(game.sim.riders[0].pressure < 1.0, "Boost drains the displayed meter")
	require(not game.pipes.heads[0].visible and not game.pipes.markers[0].visible, "First person hides own head and label")
	await capture("02-first-person.png")
	await wait_seconds(0.35)
	require(game.sim.riders[0].orb_count >= 1, "Real movement collects a visible orb")
	require(game.sim.riders[0].score >= 25, "HUD has collectible points")
	await capture("02-orb-score.png")
	hold_key(KEY_SHIFT, false)
	await wait_seconds(0.2)
	var old_forward: Vector3i = game.sim.riders[0].forward
	key(KEY_D)
	await wait_seconds(0.4)
	require(game.motion.directions[0] != old_forward, "Steering input changes the active segment direction")
	key(KEY_W)
	await wait_seconds(0.4)
	require(game.motion.directions[0].y != 0, "Pitch input changes the active segment altitude direction")
	key(KEY_C)
	await get_tree().process_frame
	require(game.camera.overview, "C switches first person to overview")
	key(KEY_C)
	await get_tree().process_frame
	require(not game.camera.overview and not game.camera.first_person, "Camera cycle returns to chase")
	await capture("02-chase.png")
	key(KEY_C)
	key(KEY_C)
	await get_tree().process_frame
	var old_yaw: float = game.camera.yaw
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_RIGHT
	button.pressed = true
	Input.parse_input_event(button)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(90, 12)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(motion)
	button = InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_RIGHT
	button.pressed = false
	Input.parse_input_event(button)
	await get_tree().process_frame
	require(game.camera.yaw != old_yaw, "Right mouse drag orbits overview")
	var old_distance: float = game.camera.distance
	button = InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_WHEEL_UP
	button.pressed = true
	Input.parse_input_event(button)
	await get_tree().process_frame
	require(game.camera.distance < old_distance, "Mouse wheel zooms overview")
	key(KEY_ESCAPE)
	await get_tree().process_frame
	require(game.state == "paused", "Escape pauses")
	var paused_tick: int = game.sim.ticks
	var paused_score: int = game.sim.riders[0].score
	var paused_pressure: float = game.sim.riders[0].pressure
	await wait_seconds(0.35)
	require(game.sim.ticks == paused_tick, "Paused simulation stays still")
	require(game.sim.riders[0].score == paused_score and game.sim.riders[0].pressure == paused_pressure, "Pause freezes score and boost meter")
	await capture("03-paused.png")
	key(KEY_ESCAPE)
	await get_tree().process_frame
	require(game.state == "playing", "Escape resumes")
	key(KEY_R)
	await get_tree().process_frame
	require(game.state == "countdown" and game.sim.occupied.size() == 16 and game.sim.riders[0].score == 0, "R resets pipes and score")
	game.countdown = 0.01
	await wait_seconds(0.05)
	# Let an unsteered player reach a wall through the real frame loop.
	await wait_seconds(game.sim.arena_width / game.Rules.SPEED + 1.0)
	require(not game.sim.riders[0].alive, "Player can die naturally")
	require(game.camera.overview, "Death switches to spectator overview")
	key(KEY_TAB)
	await get_tree().process_frame
	require(game.sim.riders[game.watch_id].alive, "Tab selects a living spectator target")
	# Accelerate subsequent whole steps; simulation and rendering still use game methods.
	for step in range(100):
		if game.state != "playing":
			break
		game.motion.advance(game.Rules.STEP_TIME)
	await wait_seconds(2.0)
	await capture("04-overview.png")
	print("RENDER: fps=%d sections=%d" % [Engine.get_frames_per_second(), game.sim.occupied.size()])
	for step in range(250):
		if game.state != "playing":
			break
		game.motion.advance(game.Rules.STEP_TIME)
	await wait_seconds(2.0)
	await capture("06-dense-arena.png")
	print("DENSE RENDER: fps=%d sections=%d" % [Engine.get_frames_per_second(), game.sim.occupied.size()])
	for step in range(6000):
		if game.state != "playing":
			break
		game.motion.advance(game.Rules.STEP_TIME)
	require(game.state == "finished", "Complete match reaches result screen")
	await wait_seconds(0.6)
	await capture("05-result.png")
	key(KEY_ENTER)
	await get_tree().process_frame
	require(game.state == "countdown" and game.sim.alive_ids().size() == 16, "Replay from results")
	for count in [23, 31]:
		game.bot_count = count
		game.start_round(123)
		game.state = "playing"
		game.motion.autoplay = true
		game.camera.overview = true
		for step in range(240):
			if game.sim.finished:
				break
			game.motion.advance(game.Rules.STEP_TIME)
		await wait_seconds(2.0)
		await capture("07-bots-%d.png" % count)
		print("BOT BENCHMARK: bots=%d fps=%d sections=%d alive=%d" % [count, Engine.get_frames_per_second(), game.sim.occupied.size(), game.sim.alive_ids().size()])
		require(game.sim.riders.size() == count + 1, "Larger bot count runs")
	print("VISUAL SMOKE: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
