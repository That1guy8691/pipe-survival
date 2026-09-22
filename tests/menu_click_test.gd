extends SceneTree
## Pointer events pass through viewport GUI hit-testing, with real frame gaps.
var game
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", message])
	if not condition:
		failures += 1

func pointer(button: Control, pressed: bool) -> void:
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	root.push_input(move, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event, true)

func click(button: Control) -> void:
	await RenderingServer.frame_post_draw
	pointer(button, true)
	await create_timer(0.15).timeout
	pointer(button, false)
	await process_frame

func popup_pointer(popup: PopupMenu, index: int, pressed: bool) -> void:
	var point := Vector2(popup.size.x * 0.5, popup.size.y * (index + 0.5) / popup.item_count)
	# Embedded popup positions are relative to the parent viewport, not a native window.
	if popup.is_embedded():
		point += Vector2(popup.position)
	var move := InputEventMouseMotion.new()
	move.window_id = popup.get_window_id()
	move.position = point
	move.global_position = point
	if popup.is_embedded():
		root.push_input(move, true)
	else:
		Input.parse_input_event(move)
	var event := InputEventMouseButton.new()
	event.window_id = popup.get_window_id()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	if popup.is_embedded():
		root.push_input(event, true)
	else:
		Input.parse_input_event(event)

func choose(selector: OptionButton, index: int) -> void:
	await click(selector)
	var popup := selector.get_popup()
	check(popup.visible, "Dropdown remains open")
	if not popup.visible:
		return
	popup_pointer(popup, index, true)
	await create_timer(0.15).timeout
	popup_pointer(popup, index, false)
	await create_timer(0.15).timeout
	check(not popup.visible, "Clicking a popup item commits and closes the dropdown")

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)

func capture(filename: String) -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-dir="):
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(argument.trim_prefix("--qa-dir=").path_join(filename))

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	await create_timer(0.3).timeout
	var button: Button = game.hud.primary
	pointer(button, true)
	check(root.gui_get_hovered_control() == button, "Pointer hits the visible Start button")
	check(button.is_pressed(), "Start receives mouse-down")
	await create_timer(0.15).timeout
	check(button.is_pressed(), "Start remains pressed across rendered frames")
	pointer(button, false)
	await process_frame
	check(game.state == "countdown", "Mouse release starts the round")
	game.show_title()
	await process_frame
	check(not game.hud.bot_selector.visible and not game.hud.size_selector.visible, "Round setup controls are hidden on the main title page")
	await click(game.hud.options_button)
	await process_frame
	check(game.hud.options_open and game.hud.bot_selector.visible and game.hud.size_selector.visible, "Game Options reveals bot and arena selectors")
	await capture("menu-options.png")
	await choose(game.hud.bot_selector, 0)
	check(game.bot_count == 7, "Mouse selects seven bots")
	for index in [0, 2, 3, 1]:
		await choose(game.hud.size_selector, index)
		var width: int = [40, 60, 80, 100][index]
		check(game.arena_width == width and game.sim.arena_width == width, "Mouse selects %d-unit arena" % width)
		check(game.arena.width == width and game.camera.arena_width == width, "Geometry and camera use selected width")
		await capture("menu-size-%d.png" % width)
	await click(game.hud.options_back)
	await process_frame
	check(not game.hud.options_open and not game.hud.bot_selector.visible, "Done returns to the uncluttered title page")
	await capture("menu-main.png")
	await click(game.hud.primary)
	check(game.state == "countdown", "Mouse starts the selected 60-unit arena")
	game.countdown = 0.01
	await create_timer(0.1).timeout
	game.motion.autoplay = true
	for step in range(60):
		game.motion.advance(game.Rules.STEP_TIME)
	key(KEY_C)
	key(KEY_C)
	await create_timer(0.5).timeout
	await capture("arena-60-play.png")
	key(KEY_ESCAPE)
	await process_frame
	await click(game.hud.secondary)
	check(game.state == "ready" and game.arena_width == 60, "Back to Title keeps the selected arena setting")
	root.size = Vector2i(960, 600)
	await create_timer(0.25).timeout
	await click(game.hud.primary)
	check(game.state == "countdown", "Start click works at a smaller window size")
	game.countdown = 0.01
	await create_timer(0.1).timeout
	key(KEY_ESCAPE)
	await process_frame
	check(game.state == "paused", "Pause menu opens")
	await capture("pause-controls.png")
	await click(game.hud.primary)
	check(game.state == "playing", "Mouse Resume button works")
	key(KEY_ESCAPE)
	await process_frame
	await click(game.hud.secondary)
	check(game.state == "ready", "Mouse Back to Title button works")
	check(game.arena_width == 60 and game.bot_count == 7, "Settings survive returning to title")
	await capture("menu-small-window.png")
	print("MENU POINTER CHECKS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
