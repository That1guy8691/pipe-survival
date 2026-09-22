extends "res://tests/menu_click_test.gd"
## Rendered input checks plus deterministic autonomous-round progression.

func key(code: Key) -> void:
	hold_key(code, true)
	hold_key(code, false)

func hold_key(code: Key, pressed: bool) -> void:
	# Send through viewport input immediately, avoiding OS event buffering in assertions.
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	game.bot_count = 7
	game.arena_width = 40
	game.show_title()
	await create_timer(0.2).timeout
	check(not game.auto_mode, "Manual play remains the default")
	await click(game.hud.auto_toggle)
	check(game.auto_mode and game.hud.auto_toggle.button_pressed, "Mouse turns Auto Mode on across rendered frames")
	await capture("auto-title.png")
	await click(game.hud.primary)
	check(game.state == "countdown" and game.motion.autoplay, "Start launches a fully autonomous round")
	check(game.camera.overview, "Auto rounds start with an overview")
	game.countdown = 0.01
	await create_timer(0.5).timeout
	check(game.state == "playing" and game.sim.riders[0].length > 0, "Cyan pipe advances without player input")
	var original_fov: float = game.camera.base_fov
	key(KEY_Q)
	check(is_equal_approx(game.camera.base_fov, original_fov - 2.0) and game.fov_message_time > 0.0,
		"Q decreases live FOV and displays the new value")
	key(KEY_E)
	check(is_equal_approx(game.camera.base_fov, original_fov), "E increases live FOV back to its previous value")
	key(KEY_W)
	check(game.turn_queue.is_empty(), "Manual steering cannot interfere with Auto Mode")
	var overview_yaw: float = game.camera.yaw
	key(KEY_LEFT)
	check(game.camera.yaw < overview_yaw, "Arrow keys orbit the overview camera")
	key(KEY_SHIFT)
	check(not game.boost_held, "Auto Mode controls boost independently of Shift")
	key(KEY_TAB)
	check(game.watch_id != 0 and game.sim.riders[game.watch_id].alive, "Tab follows another living pipe while cyan is alive")
	key(KEY_C)
	check(game.camera.view == game.camera.View.RING and game.watch_id != 0, "C selects the pipe-ring camera without losing the followed pipe")
	var ring_angle: float = game.camera.ring_angle
	var ring_position: Vector3 = game.camera.global_position
	hold_key(KEY_RIGHT, true)
	await create_timer(0.18).timeout
	hold_key(KEY_RIGHT, false)
	check(game.camera.ring_angle < ring_angle and game.camera.global_position.distance_to(ring_position) > 0.05,
		"Holding Right moves the camera around the advancing pipe tip")
	key(KEY_C)
	check(game.camera.view == game.camera.View.CHASE, "The existing orbiting chase view remains available")
	key(KEY_C)
	await process_frame
	await RenderingServer.frame_post_draw
	check(game.camera.first_person and game.watch_id != 0, "First person works on a selected bot")
	check(not game.pipes.heads[game.watch_id].visible, "Selected bot head does not obstruct first person")
	await capture("auto-follow-first-person.png")
	var first_person_pitch: float = game.camera.first_person_pitch
	key(KEY_UP)
	check(game.camera.first_person_pitch > first_person_pitch, "Arrow keys look around in first person")
	var previous := InputEventKey.new()
	previous.physical_keycode = KEY_TAB
	previous.shift_pressed = true
	previous.pressed = true
	root.push_input(previous)
	previous = InputEventKey.new()
	previous.physical_keycode = KEY_TAB
	root.push_input(previous)
	check(game.watch_id == 0, "Shift+Tab cycles backward")
	key(KEY_ESCAPE)
	check(game.state == "paused", "Escape pauses Auto Mode")
	var paused_time: float = game.sim.elapsed_time
	await create_timer(0.15).timeout
	check(game.sim.elapsed_time == paused_time, "Pause freezes autonomous movement")
	await click(game.hud.auto_toggle)
	check(not game.auto_mode and not game.motion.autoplay, "Pause-menu toggle returns to manual control")
	await click(game.hud.primary)
	check(game.state == "playing" and game.watch_id == 0, "Resume returns to the cyan pipe (state=%s, watch=%d, paused_from=%s)" % [game.state, game.watch_id, game.paused_from])
	game.camera.view = game.camera.View.CHASE
	game.camera.initialized = false
	await process_frame
	var chase_camera_position: Vector3 = game.camera.global_position
	var chase_yaw: float = game.camera.chase_yaw
	key(KEY_LEFT)
	await process_frame
	check(game.camera.chase_yaw < chase_yaw and game.camera.global_position.distance_to(chase_camera_position) > 0.05
		and game.turn_queue.is_empty(), "Arrow keys orbit chase view without steering")
	key(KEY_D)
	check(not game.turn_queue.is_empty(), "Manual steering is restored (state=%s, alive=%s, auto=%s)" % [game.state, game.sim.riders[0].alive, game.auto_mode])
	var segment_time: float = game.motion.elapsed[0]
	key(KEY_F)
	check(game.auto_mode and game.turn_queue.is_empty(), "F enables auto and discards queued manual turns")
	check(game.motion.elapsed[0] == segment_time, "Switching drivers does not restart a segment")
	game.automated = false
	root.focus_exited.emit()
	check(game.state == "playing", "Auto Mode keeps running when the window loses focus")
	key(KEY_F)
	root.focus_exited.emit()
	check(game.state == "paused", "Manual play still pauses when focus is lost")
	game.automated = true
	key(KEY_F)
	await click(game.hud.secondary)
	check(game.state == "ready" and game.auto_mode, "Returning to title preserves Auto Mode")
	check(game.arena_width == 40 and game.bot_count == 7, "Auto Mode preserves map and bot choices")
	game.set_auto_mode(false)
	game.start_round(822)
	check(game.camera.view == game.camera.View.CHASE, "Manual rounds start with the familiar chase camera")
	game.set_auto_mode(true)

	# A real AI round, advanced without wall-clock waits or altered rules.
	game.set_process(false)
	game.start_round(821)
	game.state = "playing"
	game.camera.view = game.camera.View.FIRST_PERSON
	game.watch_id = 1
	# Force the watched pipe to hit a solid cell, exercising the real death callback.
	var victim: int = game.watch_id
	game.sim.occupied[game.sim.riders[victim].cell + game.motion.directions[victim]] = 0
	game.motion.advance(game.Rules.STEP_TIME)
	check(not game.sim.riders[victim].alive and game.watch_id != victim and game.sim.riders[game.watch_id].alive,
		"A crashed followed pipe is replaced by a living pipe")
	check(game.camera.first_person, "Automatic survivor switching preserves camera mode")
	game.start_round(821)
	game.state = "playing"
	game.camera.view = game.camera.View.FIRST_PERSON
	var turned := false
	var boosted := false
	var last_direction: Vector3i = game.sim.riders[0].forward
	for tick in range(6000):
		if game.sim.finished:
			break
		boosted = boosted or game.sim.riders[0].boosting
		game.motion.advance(game.Rules.STEP_TIME)
		turned = turned or game.sim.riders[0].forward != last_direction
		last_direction = game.sim.riders[0].forward
		if tick % 90 == 0:
			await process_frame
	check(turned and boosted, "Cyan AI turns and uses boost during a real round")
	check(game.sim.finished and game.state == "finished", "Autonomous survival reaches a result")
	await capture("auto-result.png")
	key(KEY_ESCAPE)
	var restart_before: float = game.auto_restart_left
	game._process(1.0)
	check(game.state == "paused" and game.auto_restart_left == restart_before, "Escape also pauses the next-round timer")
	key(KEY_ESCAPE)
	game._process(4.8)
	check(game.state == "finished", "Result stays visible for five seconds")
	game._process(0.3)
	check(game.state == "countdown" and game.sim.ticks == 0, "Next round starts automatically and clears the maze")
	check(game.camera.first_person and game.motion.autoplay, "Automatic restart preserves view and Auto Mode")
	check(game.sim.arena_width == 40 and game.sim.riders.size() == 8, "Automatic restart keeps arena and bot settings")
	game._process(3.1)
	game._process(0.1)
	check(game.state == "playing" and game.sim.elapsed_time > 0, "The next round actually plays without input")
	game.state = "finished"
	game.auto_restart_left = 0.1
	key(KEY_F)
	game._process(6.0)
	check(game.state == "finished", "Turning auto off cancels automatic replay")

	root.size = Vector2i(960, 600)
	game.show_title()
	game.set_process(true)
	await create_timer(0.15).timeout
	await click(game.hud.auto_toggle)
	check(game.auto_mode, "Auto toggle works at minimum window size")
	await capture("auto-title-small.png")
	await click(game.hud.primary)
	check(game.state == "countdown", "Auto start button works at minimum window size")
	print("AUTO MODE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
