extends "res://tests/menu_click_test.gd"
## Visible HUD, pointer toggles, and clean-view behavior through real viewport input.

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)

func settle() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func no_world_labels() -> bool:
	for marker in game.pipes.markers:
		if marker.visible:
			return false
	for label in game.arena.labels:
		if label.visible:
			return false
	return true

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await settle()
	check(game.hud_enabled, "HUD is on by default")
	await click(game.hud.hud_toggle)
	check(not game.hud_enabled and game.hud.visible, "Menu toggle disables gameplay HUD while leaving Start accessible")
	await capture("hud-menu.png")
	await click(game.hud.primary)
	await settle()
	check(game.state == "countdown" and not game.hud.visible, "Hidden HUD includes the start countdown")
	check(no_world_labels(), "Clean view hides all pipe names and wall labels")
	check(not game.hud.primary.is_visible_in_tree(), "Hidden interface leaves no visible menu buttons")
	game.countdown = 0.01
	await create_timer(0.15).timeout
	key(KEY_D)
	check(not game.turn_queue.is_empty(), "Hidden HUD still accepts gameplay input")
	key(KEY_ESCAPE)
	await settle()
	check(game.state == "paused" and game.hud.visible, "Escape opens the pause menu from a clean view")
	check(not game.hud_enabled and no_world_labels(), "Pause retains the hidden-HUD preference")
	await capture("hud-hidden-pause.png")
	await click(game.hud.primary)
	await settle()
	check(game.state == "playing" and not game.hud.visible, "Mouse Resume returns to the clean view")
	key(KEY_H)
	await settle()
	check(game.hud_enabled and game.hud.visible, "H restores the HUD")
	check(game.arena.labels[0].visible, "Restoring HUD restores orientation labels")
	game.set_process(false)
	game.start_round(821)
	game.state = "playing"
	game.sim.riders[0].pressure = 0.42
	game._process(0.0)
	check(game.hud.boost_status(game.sim.riders[0]) == "RECHARGING", "Partial meter reads Recharging")
	await capture("hud-manual.png")
	game.sim.riders[0].pressure = 1.0
	check(game.hud.boost_status(game.sim.riders[0]) == "READY", "Full meter reads Ready")
	game.sim.riders[0].boosting = true
	check(game.hud.boost_status(game.sim.riders[0]) == "BOOSTING 2x", "Active boost reads Boosting 2x")
	game.sim.riders[0].boosting = false
	game.sim.riders[0].boost_locked = true
	game.boost_held = true
	check(game.hud.boost_status(game.sim.riders[0]) == "RELEASE SHIFT", "Exhaustion tells the player how to unlock boost")
	game.set_auto_mode(true)
	game.start_round(821)
	game.state = "playing"
	for tick in range(100):
		game.motion.advance(game.Rules.STEP_TIME)
	game._process(0.0)
	key(KEY_TAB)
	game._process(0.0)
	var selected: int = game.watch_id
	var lists: Array = game.hud.leaderboard_ids(selected)
	check(lists[1].size() == 3 and selected in lists[1], "Auto leaderboard stays compact and always includes the followed pipe")
	await capture("hud-auto.png")
	key(KEY_H)
	game._process(0.0)
	check(not game.hud.visible and no_world_labels(), "Auto Mode can show just the arena with no interface or labels")
	await capture("hud-hidden-auto.png")
	key(KEY_TAB)
	check(game.watch_id != selected, "Pipe switching still works with HUD hidden")
	key(KEY_C)
	key(KEY_C)
	game._process(0.0)
	check(game.camera.first_person and not game.pipes.heads[game.watch_id].visible, "Hidden HUD preserves first-person head occlusion")
	await capture("hud-hidden-first-person.png")
	game.state = "finished"
	game.auto_restart_left = 0.05
	game._process(0.02)
	check(not game.hud.visible, "Automatic result screen stays hidden in clean view")
	game._process(0.04)
	check(game.state == "countdown" and not game.hud_enabled and not game.hud.visible, "Automatic replay preserves hidden HUD")
	check(no_world_labels(), "New round cannot reintroduce floating labels")
	key(KEY_H)
	game._process(0.0)
	check(game.hud.visible, "H restores the interface after automatic replay")
	root.size = Vector2i(960, 600)
	game.state = "playing"
	game._process(0.0)
	await capture("hud-auto-small.png")
	game.show_title()
	game.set_process(true)
	await settle()
	await click(game.hud.hud_toggle)
	check(not game.hud_enabled, "HUD toggle is clickable at minimum window size")
	await click(game.hud.hud_toggle)
	check(game.hud_enabled, "HUD menu toggle can restore the setting")
	print("HUD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
