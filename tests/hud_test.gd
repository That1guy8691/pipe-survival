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

func click_at(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event, true)

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
	await capture("retro-title.png")
	var exhibition_time: float = game.sim.elapsed_time
	await create_timer(0.25).timeout
	check(game.title_exhibition and game.motion.autoplay and game.sim.elapsed_time > exhibition_time,
		"The title background runs a continuous all-bot match")
	game.camera.view = game.camera.View.OVERVIEW
	game.title_camera_time = 0.0
	game.advance_title_preview(0.0)
	await create_timer(0.45).timeout
	check(game.camera.view == game.camera.View.CHASE and game.sim.riders[game.watch_id].alive,
		"The title camera cuts to a living pipe chase view")
	await capture("retro-title-chase.png")
	check(game.hud_enabled, "HUD is on by default")
	# The title's display slot is Full Screen; HUD controls live in the pause menu.
	game.start_round(821)
	game.toggle_pause()
	await settle()
	await click(game.hud.hud_toggle)
	check(not game.hud_enabled and game.hud.visible, "Pause toggle disables gameplay HUD while leaving menus accessible")
	game.show_title()
	await settle()
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
	var paused_time: float = game.sim.elapsed_time
	await click(game.hud.options_menu_button)
	await settle()
	check(game.state == "paused" and game.hud.options_open, "Options opens without leaving the paused round")
	await click(game.hud.options_back)
	await settle()
	check(game.state == "paused" and is_equal_approx(game.sim.elapsed_time, paused_time),
		"Closing paused Options preserves the current round")
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
	game.hud.fit_menu(game.hud.overlay_panel_height())
	await capture("retro-gameplay.png")
	var right_offset := Vector2(game.hud.retro_wide_offset, 0)
	await click_at(game.hud.retro_origin + (Vector2(1280, 379) + right_offset) * game.hud.retro_root_scale)
	check(game.camera.first_person, "Clicking First Person in the gameplay camera group changes the view")
	await click_at(game.hud.retro_origin + (Vector2(1280, 417) + right_offset) * game.hud.retro_root_scale)
	check(game.camera.overview, "Clicking Overview in the gameplay camera group changes the view")
	await click_at(game.hud.retro_origin + (Vector2(1280, 341) + right_offset) * game.hud.retro_root_scale)
	check(game.camera.view == game.camera.View.CHASE, "Clicking Chase in the gameplay camera group changes the view")
	await click_at(game.hud.retro_origin + (Vector2(1280, 417) + right_offset) * game.hud.retro_root_scale)
	await capture("retro-gameplay-controls.png")
	var roster: Array = game.hud.retro_roster_ids(game.watch_id)
	var target_id := -1
	for rider_id_value in roster:
		var rider_id: int = rider_id_value
		if rider_id != game.watch_id and game.sim.riders[rider_id].alive:
			target_id = rider_id
			break
	if target_id >= 0:
		var row := roster.find(target_id)
		var local_point := Vector2(1100, 546 + row * 29)
		await click_at(game.hud.retro_origin + (local_point + right_offset) * game.hud.retro_root_scale)
		check(game.watch_id == target_id and game.overview_focus_id == target_id,
			"Clicking a live spectator roster row changes the followed pipe and overview highlight")
	else:
		check(false, "A second live pipe is available to select from the spectator roster")
	var previous_scroll: int = game.hud.retro_roster_scroll
	await click_at(game.hud.retro_origin + (Vector2(1380, 726) + right_offset) * game.hud.retro_root_scale)
	check(game.hud.retro_roster_scroll > previous_scroll,
		"The spectator roster scrollbar reaches pipes outside the first seven rows")
	key(KEY_TAB)
	game._process(0.0)
	var selected: int = game.watch_id
	var lists: Array = game.hud.leaderboard_ids(selected)
	check(lists[1].size() == 3 and selected in lists[1], "Auto leaderboard stays compact and always includes the followed pipe")
	await capture("hud-auto.png")
	key(KEY_H)
	game._process(0.0)
	if game.collision_feedback_time > 0.0:
		check(game.hud.visible and not game.collision_feedback_label.is_empty(),
			"Collision feedback stays visible even when the HUD is hidden")
		game.collision_feedback_time = 0.0
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
	game.start_round(821)
	game.toggle_pause()
	await settle()
	await click(game.hud.hud_toggle)
	check(not game.hud_enabled, "HUD toggle is clickable at minimum window size")
	await click(game.hud.hud_toggle)
	check(game.hud_enabled, "HUD menu toggle can restore the setting")
	print("HUD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
