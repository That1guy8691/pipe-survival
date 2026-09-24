extends SceneTree
## Pointer events pass through viewport GUI hit-testing, with real frame gaps.
const Appearance = preload("res://scripts/pipe_appearance.gd")
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
	await process_frame
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

func scroll_options_to_fov() -> void:
	var scale: float = game.hud.menu_canvas.scale.x
	var point: Vector2 = game.hud.menu_canvas.position \
		+ game.hud.options_content.position * scale + Vector2(280, 180) * scale
	for _step in range(2):
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = true
		root.push_input(event, true)
		event.pressed = false
		root.push_input(event, true)
		await process_frame

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
	check(not game.hud.bot_selector.visible and not game.hud.size_selector.visible
		and game.hud.mode_toggle.visible and game.hud.mode_toggle.text == "MODE / SURVIVAL",
		"The main title keeps round setup tucked away and shows Survival as the selected mode")
	check(game.hud.controls_button.visible, "Controls and views are discoverable on the title")
	await click(game.hud.controls_button)
	await process_frame
	check(game.hud.controls_open and game.hud.options_back.visible and not game.hud.primary.visible
		and not game.hud.options_button.visible, "Controls page opens from the title")
	await capture("menu-controls.png")
	await click(game.hud.options_back)
	await process_frame
	check(not game.hud.controls_open and game.hud.primary.visible,
		"Controls page returns to the title without starting a round")
	await click(game.hud.mode_toggle)
	await capture("menu-endless-title.png")
	check(game.endless_mode and game.arena_width == 60 and game.bot_count == 15,
		"The title mode button selects Endless without changing the existing round options")
	await click(game.hud.mode_toggle)
	check(not game.endless_mode, "The title mode button switches back to Survival")
	await click(game.hud.options_button)
	await process_frame
	check(game.hud.options_open and game.hud.bot_selector.visible and game.hud.size_selector.visible
		and game.hud.player_name_entry.visible and game.hud.player_color_picker.visible and game.hud.fov_slider.visible,
		"Game Options reveals round setup, player identity, and FOV controls")
	await capture("menu-options.png")
	check(game.hud.pattern_selector.visible and game.hud.pipe_preview.visible,
		"Game Options shows the pipe pattern selector and live preview")
	check(game.hud.joint_selector.visible and game.player_joint_style == Appearance.JointStyle.COLLARED,
		"Joint styles are available with collars selected by default")
	await choose(game.hud.pattern_selector, Appearance.Pattern.CHECKER)
	await capture("menu-joints-collared.png")
	await choose(game.hud.joint_selector, Appearance.JointStyle.SEAMLESS)
	for _frame in range(4):
		if game.hud.pipe_preview.current_joint_style == Appearance.JointStyle.SEAMLESS:
			break
		await process_frame
	check(game.hud.pipe_preview.current_joint_style == Appearance.JointStyle.SEAMLESS
		and game.hud.pipe_preview.materials[0].get_shader_parameter("joint_style") == Appearance.JointStyle.SEAMLESS,
		"Seamless joint selection updates the live preview")
	await RenderingServer.frame_post_draw
	await capture("menu-joints-seamless.png")
	for pattern in [1, 2, 3, 0, 2]:
		await choose(game.hud.pattern_selector, pattern)
		for _frame in range(4):
			if game.hud.pipe_preview.current_pattern == pattern:
				break
			await process_frame
		check(game.player_pattern == pattern and game.hud.pipe_preview.current_pattern == pattern,
			"Mouse selects pattern %d and updates the live preview" % pattern)
		await capture("menu-pattern-%d.png" % pattern)
	await choose(game.hud.pattern_selector, 8)
	await capture("menu-chrome-cyan.png")
	var chrome_color := Color("ee5f83")
	game.hud.player_color_picker.color = chrome_color
	game.hud.player_color_picker.emit_signal("color_changed", chrome_color)
	for _frame in range(4):
		if game.hud.pipe_preview.current_color == chrome_color:
			break
		await process_frame
	check(game.hud.pipe_preview.current_color == chrome_color
		and game.hud.pipe_preview.materials[0].get_shader_parameter("pipe_color") == chrome_color,
		"Changing pipe color updates the Chrome preview material")
	await capture("menu-chrome-coral.png")
	await choose(game.hud.pattern_selector, 2)
	root.size = Vector2i(960, 600)
	await create_timer(0.25).timeout
	await capture("menu-options-small.png")
	await click(game.hud.player_color_picker)
	var color_picker: ColorPicker = game.hud.player_color_picker.get_picker()
	check(color_picker.is_visible_in_tree(), "Player color control opens its picker")
	root.size = Vector2i(1280, 800)
	await create_timer(0.25).timeout
	await capture("menu-color-picker-resized.png")
	# The open color popup covers the left column; use an unobscured control first.
	await choose(game.hud.size_selector, 1)
	check(not color_picker.is_visible_in_tree(), "Selecting another option closes the color picker")
	await choose(game.hud.bot_selector, 0)
	check(game.bot_count == 7, "Mouse selects seven bots")
	for index in [0, 2, 3, 1]:
		await choose(game.hud.size_selector, index)
		var width: int = [40, 60, 80, 100][index]
		check(game.arena_width == width and game.sim.arena_width == width, "Mouse selects %d-unit arena" % width)
		check(game.arena.width == width and game.camera.arena_width == width, "Geometry and camera use selected width")
		await capture("menu-size-%d.png" % width)
	var player_color := Color("ee5f83")
	game.hud.player_name_entry.grab_focus()
	game.hud.player_name_entry.text = "MATRIX"
	game.hud.player_name_entry.emit_signal("text_changed", "MATRIX")
	game.hud.player_color_picker.color = player_color
	game.hud.player_color_picker.emit_signal("color_changed", player_color)
	await scroll_options_to_fov()
	check(is_equal_approx(game.hud.options_scroll_offset, 76.0),
		"Scrolling Game Options reveals the camera settings")
	await capture("menu-options-scrolled.png")
	var original_fov: float = game.camera.base_fov
	await click(game.hud.fov_slider)
	var selected_fov: float = game.camera.base_fov
	check(not is_equal_approx(selected_fov, original_fov) and is_equal_approx(game.hud.fov_slider.value, selected_fov),
		"Mouse adjusts the FOV slider and camera setting together")
	await click(game.hud.options_back)
	await process_frame
	check(not game.hud.options_open and not game.hud.bot_selector.visible, "Done returns to the uncluttered title page")
	check(game.sim.rider_name(0) == "MATRIX" and game.sim.rider_color(0) == player_color
		and is_equal_approx(game.camera.base_fov, selected_fov),
		"Done applies player identity and retains the selected FOV")
	check(game.pipes.markers[0].text == "MATRIX" and game.pipes.markers[0].modulate == player_color,
		"Pipe marker reflects the selected player identity")
	var player_pipe_material := game.pipes.batches[0][0].material_override as ShaderMaterial
	check(player_pipe_material.get_shader_parameter("pipe_color") == player_color
		and game.pipes.inlet_materials[0].albedo_color == player_color,
		"Selected color reaches the pipe trail and wall inlet")
	check(player_pipe_material.get_shader_parameter("pattern") == 2
		and game.pipes.active_materials[0].get_shader_parameter("pattern") == 2,
		"Selected spots reach completed and growing player pipes")
	check(player_pipe_material.get_shader_parameter("joint_style") == Appearance.JointStyle.SEAMLESS
		and game.pipes.active_materials[0].get_shader_parameter("joint_style") == Appearance.JointStyle.SEAMLESS,
		"Selected joint style reaches completed and growing player pipes")
	await capture("menu-main.png")
	await click(game.hud.primary)
	check(game.state == "countdown", "Mouse starts the selected 60-unit arena")
	check(game.player_pattern == 2 and game.pipes.active_materials[0].get_shader_parameter("pattern") == 2
		and not game.hud.pipe_preview.visible, "Starting a round keeps the pattern and hides the preview")
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
	check(game.arena_width == 60 and game.bot_count == 7 and game.sim.rider_name(0) == "MATRIX"
		and game.sim.rider_color(0) == player_color and is_equal_approx(game.camera.base_fov, selected_fov),
		"Settings, identity, and FOV survive returning to title")
	root.size = Vector2i(390, 844)
	await create_timer(0.25).timeout
	game.hud.touch_ui_enabled = false
	game.primary_action()
	await process_frame
	var touch_event := InputEventScreenTouch.new()
	touch_event.index = 7
	touch_event.position = Vector2(195, 422)
	touch_event.pressed = true
	root.push_input(touch_event, true)
	await process_frame
	check(game.hud.touch_ui_enabled and game.hud.touch_boost.visible
		and game.hud.touch_view.visible and game.hud.touch_pause.visible,
		"A first screen touch reveals mobile controls if platform detection misses")
	await capture("mobile-touch-controls.png")
	touch_event.pressed = false
	root.push_input(touch_event, true)
	await capture("menu-small-window.png")
	game.show_title()
	await process_frame
	await capture("menu-main-touch.png")
	await click(game.hud.controls_button)
	await process_frame
	check(game.hud.controls_open and game.hud.options_back.visible
		and game.hud.options_back.position.y + game.hud.options_back.size.y <= 560.0,
		"Controls and views fit and remain accessible on a touch-sized screen")
	await capture("menu-controls-touch.png")
	await click(game.hud.options_back)
	await process_frame
	await click(game.hud.options_button)
	await process_frame
	check(game.hud.joint_selector.visible, "Joint styles remain available on a touch-sized screen")
	await capture("menu-options-joints-touch.png")
	await scroll_options_to_fov()
	await process_frame
	check(game.hud.fov_slider.position.y >= 0.0
		and game.hud.fov_slider.position.y + game.hud.fov_slider.size.y <= game.hud.options_content.size.y + 1.0,
		"Touch options scroll keeps the FOV slider inside the panel")
	await capture("menu-options-fov-touch.png")
	print("MENU POINTER CHECKS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
