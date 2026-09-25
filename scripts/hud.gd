extends Control

signal primary_clicked
signal secondary_clicked
signal quick_restart_clicked
signal touch_turn_requested(command: String)
signal touch_boost_changed(held: bool)
signal touch_view_requested
signal touch_overview_style_requested
signal touch_overview_focus_requested
signal touch_pause_requested
signal touch_camera_orbit_requested(relative: Vector2)
signal touch_camera_zoom_requested(distance_change: float)
const INK := Color("e8f2f5")
const MUTED := Color("8da4b8")
const ACCENT := Color("56eddf")
const PLAYER_COLOR := Color("56eddf")
const RETRO_GRAY := Color("c0c0c0")
const RETRO_LIGHT := Color("dfdfdf")
const RETRO_BLUE := Color("000080")
const RETRO_BLACK := Color("101010")
const RETRO_SHELL_SIZE := Vector2(1392, 868)
const RETRO_DARK := Color("404040")
const RETRO_RIGHT_ORIGIN := Vector2(862, 110)
const RETRO_RIGHT_SIZE := Vector2(554, 736)
const OPTIONS_VIEW_TOP := 168.0
const OPTIONS_VIEW_INSET := 38.0
const OPTIONS_VIEW_HEIGHT := 500.0
const Appearance = preload("res://scripts/pipe_appearance.gd")
const BotStyle = preload("res://scripts/bot_style.gd")
const PipePreview = preload("res://scripts/pipe_preview.gd")
const Scoring = preload("res://scripts/scoring.gd")
const Rules = preload("res://scripts/simulation.gd")
const TouchControls = preload("res://scripts/hud_touch_controls.gd")
var touch_controls := TouchControls.new()
var game: Node
var font := SystemFont.new()
var mono := SystemFont.new()
var primary := Button.new()
var secondary := Button.new()
var options_button := Button.new()
var bot_looks_button := Button.new()
var online_button := Button.new()
var controls_button := Button.new()
var exit_button := Button.new()
var game_menu_button := Button.new()
var view_menu_button := Button.new()
var options_menu_button := Button.new()
var help_menu_button := Button.new()
var minimize_window_button := Button.new()
var maximize_window_button := Button.new()
var close_window_button := Button.new()
var pause_game_button := Button.new()
var restart_game_button := Button.new()
var options_back := Button.new()
var online_back := Button.new()
var online_join := Button.new()
var online_quick_match := Button.new()
var online_host_public := Button.new()
var online_private_join := Button.new()
var bot_selector := OptionButton.new()
var size_selector := OptionButton.new()
var fov_slider := HSlider.new()
var player_name_entry := LineEdit.new()
var online_server_entry := LineEdit.new()
var online_room_entry := LineEdit.new()
var player_color_picker := ColorPickerButton.new()
var player_color_label := Label.new()
var secondary_color_picker := ColorPickerButton.new()
var detail_color_picker := ColorPickerButton.new()
var secondary_auto := Button.new()
var detail_auto := Button.new()
var pattern_selector := OptionButton.new()
var material_selector := OptionButton.new()
var joint_selector := OptionButton.new()
var bot_palette_selector := OptionButton.new()
var bot_mix_selector := OptionButton.new()
var bot_saturation_slider := HSlider.new()
var bot_brightness_slider := HSlider.new()
var bot_pattern_checks: Array[CheckBox] = []
var reduced_glow_toggle := CheckButton.new()
var pipe_preview := PipePreview.new()
var auto_toggle := Button.new()
var hud_toggle := Button.new()
var full_screen_toggle := Button.new()
var mode_toggle := Button.new()
var quick_restart := Button.new()
var menu_canvas := Control.new()
var options_content := Control.new()
var options_open := false
var online_open := false
var controls_open := false
var bot_looks_focus := false
var touch_ui_enabled := false
var overlay_draw_active := false
var touch_draw_active := false
var applied_menu_screen_scale := -1.0
var menu_screen_scale := 1.0
var options_scroll_offset := 0.0
var options_drag_index := -1
var options_drag_start := Vector2.ZERO
var options_drag_start_scroll := 0.0
var retro_layout_active := false
var retro_viewport_draw_active := false
var retro_origin := Vector2.ZERO
var retro_root_scale := 1.0
var retro_wide_offset := 0.0
var return_to_pause_after_page := false
var retro_roster_scroll := 0

func _ready() -> void:
	font.font_names = PackedStringArray(["Tahoma", "MS Sans Serif", "Microsoft Sans Serif", "Arial", "Segoe UI"])
	font.font_weight = 400
	mono.font_names = PackedStringArray(["Consolas", "Courier New", "Courier"])
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_ui_enabled = DisplayServer.is_touchscreen_available()
	add_child(menu_canvas)
	menu_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_canvas.add_child(options_content)
	options_content.position = Vector2(0, OPTIONS_VIEW_TOP)
	options_content.size = Vector2(560, OPTIONS_VIEW_HEIGHT)
	options_content.clip_contents = true
	for button in [primary, secondary, options_button, bot_looks_button, online_button, controls_button, exit_button,
			game_menu_button, view_menu_button, options_menu_button, help_menu_button,
			minimize_window_button, maximize_window_button, close_window_button, pause_game_button,
			restart_game_button, options_back,
			online_back, online_join, online_quick_match, online_host_public, online_private_join,
			auto_toggle, hud_toggle, full_screen_toggle, mode_toggle]:
		menu_canvas.add_child(button)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", RETRO_BLACK)
		button.add_theme_stylebox_override("normal", classic_button_box(RETRO_GRAY, false))
		button.add_theme_stylebox_override("hover", classic_button_box(RETRO_LIGHT, false))
		button.add_theme_stylebox_override("pressed", classic_button_box(Color("a0a0a0"), true))
	add_child(quick_restart)
	quick_restart.focus_mode = Control.FOCUS_NONE
	quick_restart.add_theme_font_override("font", font)
	quick_restart.add_theme_font_size_override("font_size", 20)
	quick_restart.add_theme_color_override("font_color", RETRO_BLACK)
	quick_restart.add_theme_stylebox_override("normal", classic_button_box(RETRO_GRAY, false))
	quick_restart.add_theme_stylebox_override("hover", classic_button_box(RETRO_LIGHT, false))
	quick_restart.add_theme_stylebox_override("pressed", classic_button_box(Color("a0a0a0"), true))
	primary.pressed.connect(func(): primary_clicked.emit())
	secondary.pressed.connect(func(): secondary_clicked.emit())
	quick_restart.pressed.connect(func(): quick_restart_clicked.emit())
	for button in [secondary, options_button, bot_looks_button, online_button, controls_button, exit_button,
			options_back, online_back]:
		button.add_theme_color_override("font_color", RETRO_BLACK)
		button.add_theme_stylebox_override("normal", classic_button_box(RETRO_GRAY, false))
		button.add_theme_stylebox_override("hover", classic_button_box(RETRO_LIGHT, false))
		button.add_theme_stylebox_override("pressed", classic_button_box(Color("a0a0a0"), true))
	for button in [game_menu_button, view_menu_button, options_menu_button, help_menu_button]:
		button.add_theme_color_override("font_color", RETRO_BLACK)
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", classic_button_box(RETRO_LIGHT, false))
		button.add_theme_stylebox_override("pressed", classic_button_box(Color("a0a0a0"), true))
	for button in [minimize_window_button, maximize_window_button, close_window_button]:
		button.add_theme_stylebox_override("normal", classic_button_box(RETRO_GRAY, false))
		button.add_theme_stylebox_override("hover", classic_button_box(RETRO_LIGHT, false))
		button.add_theme_stylebox_override("pressed", classic_button_box(Color("a0a0a0"), true))
		button.add_theme_font_size_override("font_size", 17)
	game_menu_button.text = "Game"
	view_menu_button.text = "View"
	view_menu_button.tooltip_text = "Change camera view; press F11 for Full Screen"
	options_menu_button.text = "Options"
	help_menu_button.text = "Help"
	exit_button.text = "EXIT"
	minimize_window_button.text = "_"
	maximize_window_button.text = "[]"
	close_window_button.text = "X"
	pause_game_button.text = "PAUSE"
	restart_game_button.text = "RESTART"
	game_menu_button.add_theme_font_size_override("font_size", 17)
	view_menu_button.add_theme_font_size_override("font_size", 17)
	options_menu_button.add_theme_font_size_override("font_size", 17)
	help_menu_button.add_theme_font_size_override("font_size", 17)
	exit_button.pressed.connect(func(): get_tree().quit())
	game_menu_button.pressed.connect(func():
		options_open = false
		online_open = false
		controls_open = false
		if game.state != "ready":
			game.toggle_pause()
		else:
			game.show_title())
	view_menu_button.pressed.connect(func(): game.swap_camera_view())
	options_menu_button.pressed.connect(func():
		open_retro_page("options"))
	help_menu_button.pressed.connect(func():
		open_retro_page("help"))
	minimize_window_button.pressed.connect(func():
		if not OS.has_feature("web"):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	maximize_window_button.pressed.connect(func():
		if OS.has_feature("web"):
			return
		var mode := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED
			if mode == DisplayServer.WINDOW_MODE_MAXIMIZED else DisplayServer.WINDOW_MODE_MAXIMIZED))
	close_window_button.pressed.connect(func(): get_tree().quit())
	pause_game_button.pressed.connect(func(): touch_pause_requested.emit())
	restart_game_button.pressed.connect(func():
		if not game.online_mode:
			game.start_round())
	options_button.text = "OPTIONS..."
	options_button.pressed.connect(func():
		open_retro_page("options"))
	bot_looks_button.text = "BOT LOOKS"
	bot_looks_button.tooltip_text = "Set local bot colors and patterns"
	bot_looks_button.pressed.connect(func():
		open_retro_page("bot_looks")
		options_open = true
		bot_looks_focus = true
		var bot_field_y: float = options_layout().bot_field_y
		options_scroll_offset = clampf(bot_field_y - OPTIONS_VIEW_INSET - 24.0,
			0.0, options_max_scroll()))
	online_button.text = "ONLINE"
	online_button.pressed.connect(func():
		open_retro_page("online"))
	controls_button.text = "HOW TO PLAY"
	controls_button.pressed.connect(func():
		open_retro_page("help"))
	options_back.text = "DONE"
	options_back.pressed.connect(close_menu_page)
	online_back.text = "BACK TO TITLE"
	online_back.pressed.connect(func(): online_open = false)
	online_join.text = "CONNECT TO ROOM"
	online_join.pressed.connect(func():
		if game.online_connected:
			game.disconnect_online()
		else:
			game.connect_online(online_server_entry.text, online_room_entry.text))
	online_quick_match.text = "QUICK MATCH"
	online_quick_match.pressed.connect(func():
		online_room_entry.text = "PUBLIC"
		game.connect_online(game.online_server_url, "PUBLIC"))
	online_host_public.text = "HOST PUBLIC"
	online_host_public.pressed.connect(func():
		online_room_entry.text = "PUBLIC"
		game.connect_online(game.online_server_url, "PUBLIC"))
	online_private_join.text = "JOIN PRIVATE"
	online_private_join.pressed.connect(func():
		if online_room_entry.text.strip_edges().is_empty() or online_room_entry.text.strip_edges().to_upper() == "PUBLIC":
			online_room_entry.text = make_private_code()
		game.connect_online(game.online_server_url, online_room_entry.text))
	auto_toggle.toggle_mode = true
	auto_toggle.add_theme_color_override("font_color", RETRO_BLACK)
	auto_toggle.add_theme_color_override("font_pressed_color", RETRO_BLACK)
	auto_toggle.add_theme_stylebox_override("normal", classic_button_box(RETRO_GRAY, false))
	auto_toggle.add_theme_stylebox_override("hover", classic_button_box(RETRO_LIGHT, false))
	auto_toggle.add_theme_stylebox_override("pressed", classic_button_box(Color("a0a0a0"), true))
	auto_toggle.toggled.connect(func(enabled: bool): game.set_auto_mode(enabled))
	hud_toggle.toggle_mode = true
	hud_toggle.add_theme_color_override("font_color", RETRO_BLACK)
	hud_toggle.add_theme_color_override("font_pressed_color", RETRO_BLACK)
	hud_toggle.add_theme_stylebox_override("normal", classic_button_box(RETRO_GRAY, false))
	hud_toggle.add_theme_stylebox_override("hover", classic_button_box(RETRO_LIGHT, false))
	hud_toggle.add_theme_stylebox_override("pressed", classic_button_box(Color("a0a0a0"), true))
	hud_toggle.toggled.connect(func(enabled: bool): game.set_hud_enabled(enabled))
	full_screen_toggle.toggle_mode = true
	full_screen_toggle.add_theme_color_override("font_color", RETRO_BLACK)
	full_screen_toggle.add_theme_color_override("font_pressed_color", RETRO_BLACK)
	full_screen_toggle.add_theme_stylebox_override("normal", classic_button_box(RETRO_GRAY, false))
	full_screen_toggle.add_theme_stylebox_override("hover", classic_button_box(RETRO_LIGHT, false))
	full_screen_toggle.add_theme_stylebox_override("pressed", classic_button_box(Color("a0a0a0"), true))
	full_screen_toggle.add_theme_font_size_override("font_size", 15)
	full_screen_toggle.toggled.connect(func(enabled: bool): game.set_fullscreen(enabled))
	for toggle in [auto_toggle, hud_toggle]:
		toggle.add_theme_font_size_override("font_size", 18)
	mode_toggle.toggle_mode = true
	mode_toggle.add_theme_font_size_override("font_size", 15)
	mode_toggle.add_theme_color_override("font_color", RETRO_BLACK)
	mode_toggle.add_theme_color_override("font_pressed_color", RETRO_BLACK)
	mode_toggle.add_theme_stylebox_override("normal", classic_button_box(RETRO_GRAY, false))
	mode_toggle.add_theme_stylebox_override("hover", classic_button_box(RETRO_LIGHT, false))
	mode_toggle.add_theme_stylebox_override("pressed", classic_button_box(Color("a0a0a0"), true))
	mode_toggle.toggled.connect(func(enabled: bool): game.set_endless_mode(enabled))
	quick_restart.text = "RESTART PIPE"
	quick_restart.add_theme_font_size_override("font_size", 17)
	options_content.add_child(bot_selector)
	for count in range(Rules.MAX_BOTS + 1):
		var label := "SOLO RUN" if count == 0 else ("1 BOT" if count == 1 else "%d BOTS" % count)
		bot_selector.add_item(label, count)
	bot_selector.select(bot_selector.get_item_index(Rules.DEFAULT_BOTS))
	# Keep the long list below its opener; the popup scrolls to the remaining counts.
	bot_selector.get_popup().max_size = Vector2i(480, 320)
	bot_selector.focus_mode = Control.FOCUS_NONE
	bot_selector.add_theme_font_override("font", font)
	bot_selector.add_theme_font_size_override("font_size", 18)
	var selector_normal := classic_input_box()
	selector_normal.content_margin_left = 12
	selector_normal.content_margin_right = 10
	var selector_hover := classic_input_box(RETRO_LIGHT)
	selector_hover.content_margin_left = 12
	selector_hover.content_margin_right = 10
	bot_selector.add_theme_stylebox_override("normal", selector_normal)
	bot_selector.add_theme_stylebox_override("hover", selector_hover)
	bot_selector.add_theme_color_override("font_color", RETRO_BLACK)
	bot_selector.item_selected.connect(func(index: int):
		game.bot_count = bot_selector.get_item_id(index)
		refresh_title_preview())
	options_content.add_child(size_selector)
	for width in [40, 60, 80, 100]:
		size_selector.add_item("%d x %d x %d" % [width, width, width], width)
	size_selector.select(1)
	size_selector.focus_mode = Control.FOCUS_NONE
	size_selector.add_theme_font_override("font", font)
	size_selector.add_theme_font_size_override("font_size", 18)
	size_selector.add_theme_stylebox_override("normal", selector_normal)
	size_selector.add_theme_stylebox_override("hover", selector_hover)
	size_selector.add_theme_color_override("font_color", RETRO_BLACK)
	size_selector.item_selected.connect(func(index: int):
		game.arena_width = size_selector.get_item_id(index)
		refresh_title_preview())
	options_content.add_child(fov_slider)
	fov_slider.min_value = 60.0
	fov_slider.max_value = 110.0
	fov_slider.step = 1.0
	fov_slider.value = 78.0
	fov_slider.focus_mode = Control.FOCUS_NONE
	fov_slider.tooltip_text = "Adjust the camera field of view"
	fov_slider.add_theme_stylebox_override("slider", StyleBoxEmpty.new())
	fov_slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
	fov_slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	fov_slider.value_changed.connect(func(value: float): game.camera.set_base_fov(value))
	options_content.add_child(player_name_entry)
	player_name_entry.max_length = 18
	player_name_entry.placeholder_text = "Enter a name"
	player_name_entry.add_theme_font_override("font", font)
	player_name_entry.add_theme_font_size_override("font_size", 18)
	player_name_entry.add_theme_color_override("font_color", RETRO_BLACK)
	player_name_entry.add_theme_color_override("font_placeholder_color", RETRO_DARK)
	player_name_entry.add_theme_stylebox_override("normal", classic_input_box())
	player_name_entry.add_theme_stylebox_override("focus", classic_input_box(RETRO_LIGHT))
	player_name_entry.text = "YOU"
	player_name_entry.text_changed.connect(func(value: String): game.player_name = clean_player_name(value))
	menu_canvas.add_child(online_server_entry)
	online_server_entry.placeholder_text = "WebSocket server URL"
	online_server_entry.text = "wss://pipe-survival.onrender.com"
	online_server_entry.max_length = 160
	online_server_entry.add_theme_font_override("font", font)
	online_server_entry.add_theme_font_size_override("font_size", 18)
	online_server_entry.add_theme_color_override("font_color", RETRO_BLACK)
	online_server_entry.add_theme_color_override("font_placeholder_color", RETRO_DARK)
	online_server_entry.add_theme_stylebox_override("normal", classic_input_box())
	online_server_entry.add_theme_stylebox_override("focus", classic_input_box(RETRO_LIGHT))
	menu_canvas.add_child(online_room_entry)
	online_room_entry.placeholder_text = "PUBLIC or private room code"
	online_room_entry.text = "PUBLIC"
	online_room_entry.max_length = 12
	online_room_entry.add_theme_font_override("font", font)
	online_room_entry.add_theme_font_size_override("font_size", 18)
	online_room_entry.add_theme_color_override("font_color", RETRO_BLACK)
	online_room_entry.add_theme_color_override("font_placeholder_color", RETRO_DARK)
	online_room_entry.add_theme_stylebox_override("normal", classic_input_box())
	online_room_entry.add_theme_stylebox_override("focus", classic_input_box(RETRO_LIGHT))
	options_content.add_child(player_color_picker)
	player_color_picker.color = PLAYER_COLOR
	player_color_picker.edit_alpha = false
	player_color_picker.tooltip_text = "Choose the color for your pipe"
	player_color_picker.focus_mode = Control.FOCUS_NONE
	player_color_picker.add_theme_stylebox_override("normal", box(PLAYER_COLOR, 7))
	player_color_picker.add_theme_stylebox_override("hover", box(PLAYER_COLOR.lightened(0.2), 7))
	player_color_picker.color_changed.connect(func(value: Color): game.player_color = value)
	options_content.add_child(player_color_label)
	player_color_label.text = "EDIT COLOR"
	player_color_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_color_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player_color_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_color_label.add_theme_font_override("font", font)
	player_color_label.add_theme_font_size_override("font_size", 16)
	for picker in [secondary_color_picker, detail_color_picker]:
		options_content.add_child(picker)
		picker.edit_alpha = false
		picker.focus_mode = Control.FOCUS_NONE
		picker.add_theme_stylebox_override("normal", classic_input_box())
		picker.add_theme_stylebox_override("hover", classic_input_box(RETRO_LIGHT))
	secondary_color_picker.tooltip_text = "Color for pattern markings; AUTO derives it from the primary color"
	detail_color_picker.tooltip_text = "Color for collars, pipe heads, and wall inlets"
	secondary_color_picker.color_changed.connect(func(value: Color): game.player_secondary_color = value)
	detail_color_picker.color_changed.connect(func(value: Color): game.player_detail_color = value)
	for button in [secondary_auto, detail_auto]:
		options_content.add_child(button)
		button.text = "AUTO"
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_color_override("font_color", RETRO_BLACK)
		button.add_theme_stylebox_override("normal", classic_button_box(RETRO_GRAY, false))
		button.add_theme_stylebox_override("hover", classic_button_box(RETRO_LIGHT, false))
		button.add_theme_stylebox_override("pressed", classic_button_box(Color("a0a0a0"), true))
	secondary_auto.pressed.connect(func(): game.player_secondary_color = Color.TRANSPARENT)
	detail_auto.pressed.connect(func(): game.player_detail_color = Color.TRANSPARENT)
	options_content.add_child(pattern_selector)
	for i in range(Appearance.NAMES.size()):
		pattern_selector.add_item(Appearance.NAMES[i], i)
	pattern_selector.focus_mode = Control.FOCUS_NONE
	pattern_selector.tooltip_text = "Choose the pattern for your pipe"
	pattern_selector.add_theme_font_override("font", font)
	pattern_selector.add_theme_font_size_override("font_size", 18)
	pattern_selector.add_theme_stylebox_override("normal", selector_normal)
	pattern_selector.add_theme_stylebox_override("hover", selector_hover)
	pattern_selector.add_theme_color_override("font_color", RETRO_BLACK)
	pattern_selector.add_theme_color_override("font_disabled_color", RETRO_DARK)
	pattern_selector.item_selected.connect(func(index: int): game.player_pattern = pattern_selector.get_item_id(index))
	options_content.add_child(material_selector)
	for i in range(Appearance.FINISH_NAMES.size()):
		material_selector.add_item(Appearance.FINISH_NAMES[i], i)
	material_selector.focus_mode = Control.FOCUS_NONE
	material_selector.tooltip_text = "Choose the surface finish for your pipe"
	material_selector.add_theme_font_override("font", font)
	material_selector.add_theme_font_size_override("font_size", 18)
	material_selector.add_theme_stylebox_override("normal", selector_normal)
	material_selector.add_theme_stylebox_override("hover", selector_hover)
	material_selector.add_theme_color_override("font_color", RETRO_BLACK)
	material_selector.add_theme_color_override("font_disabled_color", RETRO_DARK)
	material_selector.item_selected.connect(func(index: int):
		game.player_material = material_selector.get_item_id(index))
	options_content.add_child(joint_selector)
	for i in range(Appearance.JOINT_NAMES.size()):
		joint_selector.add_item(Appearance.JOINT_NAMES[i], i)
	joint_selector.focus_mode = Control.FOCUS_NONE
	joint_selector.tooltip_text = "Choose visible collars or uninterrupted pipe patterns"
	joint_selector.add_theme_font_override("font", font)
	joint_selector.add_theme_font_size_override("font_size", 18)
	joint_selector.add_theme_stylebox_override("normal", selector_normal)
	joint_selector.add_theme_stylebox_override("hover", selector_hover)
	joint_selector.add_theme_color_override("font_color", RETRO_BLACK)
	joint_selector.add_theme_color_override("font_disabled_color", RETRO_DARK)
	joint_selector.item_selected.connect(func(index: int):
		game.player_joint_style = joint_selector.get_item_id(index))
	for selector in [bot_palette_selector, bot_mix_selector]:
		options_content.add_child(selector)
		selector.focus_mode = Control.FOCUS_NONE
		selector.add_theme_font_override("font", font)
		selector.add_theme_font_size_override("font_size", 18)
		selector.add_theme_stylebox_override("normal", selector_normal)
		selector.add_theme_stylebox_override("hover", selector_hover)
		selector.add_theme_color_override("font_color", RETRO_BLACK)
	for i in range(BotStyle.PALETTE_NAMES.size()):
		bot_palette_selector.add_item(BotStyle.PALETTE_NAMES[i], i)
	for i in range(BotStyle.MIX_NAMES.size()):
		bot_mix_selector.add_item(BotStyle.MIX_NAMES[i], i)
	bot_palette_selector.item_selected.connect(func(index: int):
		game.bot_palette = bot_palette_selector.get_item_id(index)
		refresh_title_preview())
	bot_mix_selector.item_selected.connect(func(index: int):
		game.bot_pattern_mix = bot_mix_selector.get_item_id(index)
		refresh_title_preview())
	for slider in [bot_saturation_slider, bot_brightness_slider]:
		options_content.add_child(slider)
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.focus_mode = Control.FOCUS_NONE
	bot_brightness_slider.min_value = 0.35
	bot_saturation_slider.value_changed.connect(func(value: float):
		game.bot_custom_saturation = value
		if game.bot_palette == BotStyle.Palette.CUSTOM:
			refresh_title_preview())
	bot_brightness_slider.value_changed.connect(func(value: float):
		game.bot_custom_brightness = value
		if game.bot_palette == BotStyle.Palette.CUSTOM:
			refresh_title_preview())
	for i in range(Appearance.NAMES.size()):
		var check := CheckBox.new()
		check.text = Appearance.NAMES[i]
		check.button_pressed = true
		check.focus_mode = Control.FOCUS_NONE
		check.add_theme_font_override("font", font)
		check.add_theme_font_size_override("font_size", 15)
		check.add_theme_color_override("font_color", RETRO_BLACK)
		options_content.add_child(check)
		bot_pattern_checks.append(check)
		check.toggled.connect(func(enabled: bool): set_custom_bot_pattern(i, enabled))
	options_content.add_child(reduced_glow_toggle)
	reduced_glow_toggle.text = "REDUCED GLOW"
	reduced_glow_toggle.focus_mode = Control.FOCUS_NONE
	reduced_glow_toggle.add_theme_font_override("font", font)
	reduced_glow_toggle.add_theme_font_size_override("font_size", 17)
	reduced_glow_toggle.add_theme_color_override("font_color", RETRO_BLACK)
	reduced_glow_toggle.toggled.connect(func(enabled: bool):
		game.reduced_glow = enabled
		refresh_title_preview())
	pipe_preview.visible = false
	options_content.add_child(pipe_preview)
	touch_controls.font = font
	touch_controls.touch_turn_requested.connect(func(command: String): touch_turn_requested.emit(command))
	touch_controls.touch_boost_changed.connect(func(held: bool): touch_boost_changed.emit(held))
	touch_controls.touch_view_requested.connect(func(): touch_view_requested.emit())
	touch_controls.touch_overview_style_requested.connect(func(): touch_overview_style_requested.emit())
	touch_controls.touch_overview_focus_requested.connect(func(): touch_overview_focus_requested.emit())
	touch_controls.touch_pause_requested.connect(func(): touch_pause_requested.emit())
	touch_controls.touch_camera_orbit_requested.connect(func(relative: Vector2): touch_camera_orbit_requested.emit(relative))
	touch_controls.touch_camera_zoom_requested.connect(func(change: float): touch_camera_zoom_requested.emit(change))
	add_child(touch_controls)
	touch_controls.refresh(game, touch_ui_enabled, ui_scale_factor())

static func box(color: Color, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style

static func classic_button_box(color: Color, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(0)
	style.set_border_width_all(2)
	style.border_color = Color("808080")
	style.shadow_color = Color("404040")
	style.shadow_size = 1
	style.shadow_offset = Vector2(1, 1)
	style.content_margin_left = 8 if not pressed else 9
	style.content_margin_top = 4 if not pressed else 5
	style.content_margin_right = 8
	style.content_margin_bottom = 4
	return style

static func classic_input_box(color: Color = Color("ffffff")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(0)
	style.set_border_width_all(2)
	style.border_color = Color("808080")
	style.content_margin_left = 8
	style.content_margin_top = 5
	style.content_margin_right = 8
	style.content_margin_bottom = 5
	return style

func ui_scale_factor() -> float:
	if not touch_ui_enabled:
		return 1.0
	var canvas_scale := get_viewport().get_stretch_transform().get_scale().x
	var display_scale := maxf(DisplayServer.screen_get_scale(), 1.0)
	return display_scale / maxf(canvas_scale, 0.01)

func screen_size() -> Vector2:
	return size / ui_scale_factor()

func cancel_touch_input() -> void:
	touch_controls.cancel_gestures()

func fit_menu(panel_height: float) -> void:
	if not touch_ui_enabled:
		retro_layout_active = true
		retro_root_scale = minf(size.x / RETRO_SHELL_SIZE.x, size.y / RETRO_SHELL_SIZE.y)
		retro_root_scale = maxf(retro_root_scale, 0.45)
		retro_wide_offset = maxf(0.0, size.x / retro_root_scale - RETRO_SHELL_SIZE.x)
		var fitted_canvas := Vector2(RETRO_SHELL_SIZE.x + retro_wide_offset, RETRO_SHELL_SIZE.y)
		retro_origin = Vector2(-24.0 * retro_root_scale,
			(size.y - RETRO_SHELL_SIZE.y * retro_root_scale) / 2.0 - 16.0 * retro_root_scale)
		menu_canvas.position = retro_origin
		menu_canvas.scale = Vector2.ONE * retro_root_scale
		menu_canvas.size = fitted_canvas
		options_content.position = Vector2(RETRO_RIGHT_ORIGIN.x + retro_wide_offset,
			RETRO_RIGHT_ORIGIN.y + OPTIONS_VIEW_TOP)
		options_content.size = Vector2(560, OPTIONS_VIEW_HEIGHT)
		game_menu_button.position = Vector2(46, 66)
		game_menu_button.size = Vector2(94, 37)
		view_menu_button.position = Vector2(143, 66)
		view_menu_button.size = Vector2(84, 37)
		options_menu_button.position = Vector2(230, 66)
		options_menu_button.size = Vector2(125, 37)
		help_menu_button.position = Vector2(359, 66)
		help_menu_button.size = Vector2(88, 37)
		minimize_window_button.position = Vector2(1280 + retro_wide_offset, 24)
		maximize_window_button.position = Vector2(1322 + retro_wide_offset, 24)
		close_window_button.position = Vector2(1364 + retro_wide_offset, 24)
		for button in [minimize_window_button, maximize_window_button, close_window_button]:
			button.size = Vector2(36, 32)
		var right_origin := RETRO_RIGHT_ORIGIN + Vector2(retro_wide_offset, 0)
		pause_game_button.position = right_origin + Vector2(38, 674)
		pause_game_button.size = Vector2(231, 42)
		restart_game_button.position = right_origin + Vector2(291, 674)
		restart_game_button.size = Vector2(231, 42)
		var quick_restart_pos := right_origin + Vector2(291, 674)
		quick_restart.position = retro_origin + quick_restart_pos * retro_root_scale
		quick_restart.size = Vector2(231, 42) * retro_root_scale
		update_menu_control_scale()
		return
	retro_layout_active = false
	var available := screen_size()
	var screen_scale := minf(1.0, minf((available.x - 32.0) / 560.0, (available.y - 24.0) / panel_height))
	screen_scale = clampf(screen_scale, 0.45, 1.0)
	menu_screen_scale = screen_scale
	var canvas_scale := screen_scale * ui_scale_factor()
	menu_canvas.scale = Vector2.ONE * canvas_scale
	menu_canvas.position = Vector2((size.x - 560.0 * canvas_scale) / 2.0,
		(size.y - panel_height * canvas_scale) / 2.0)
	update_menu_control_scale()

func overlay_panel_height() -> float:
	if game.state == "ready" and options_open:
		return 790.0 if touch_ui_enabled else 760.0
	return 680.0 if touch_ui_enabled else 556.0

func menu_target_height(base_height: float) -> float:
	if not touch_ui_enabled:
		return base_height
	return maxf(base_height, 44.0 / maxf(menu_screen_scale, 0.01))

func menu_control_font_size(base_size: int) -> int:
	if not touch_ui_enabled:
		return base_size
	return maxi(base_size, roundi(float(base_size) / maxf(menu_screen_scale, 0.01)))

func update_menu_control_scale() -> void:
	if is_equal_approx(applied_menu_screen_scale, menu_screen_scale):
		return
	applied_menu_screen_scale = menu_screen_scale
	for button in [primary, secondary, options_button, online_button, controls_button, options_back, online_back, online_join]:
		button.add_theme_font_size_override("font_size", menu_control_font_size(20))
	for button in [options_button, bot_looks_button, online_button, controls_button]:
		button.add_theme_font_size_override("font_size", menu_control_font_size(13))
	for button in [auto_toggle, hud_toggle]:
		button.add_theme_font_size_override("font_size", menu_control_font_size(18))
	full_screen_toggle.add_theme_font_size_override("font_size", menu_control_font_size(15))
	mode_toggle.add_theme_font_size_override("font_size", menu_control_font_size(15))
	bot_selector.add_theme_font_size_override("font_size", menu_control_font_size(18))
	size_selector.add_theme_font_size_override("font_size", menu_control_font_size(18))
	player_name_entry.add_theme_font_size_override("font_size", menu_control_font_size(18))
	online_server_entry.add_theme_font_size_override("font_size", menu_control_font_size(18))
	online_room_entry.add_theme_font_size_override("font_size", menu_control_font_size(18))
	player_color_label.add_theme_font_size_override("font_size", menu_control_font_size(16))
	for button in [secondary_auto, detail_auto]:
		button.add_theme_font_size_override("font_size", menu_control_font_size(13))
	pattern_selector.add_theme_font_size_override("font_size", menu_control_font_size(18))
	material_selector.add_theme_font_size_override("font_size", menu_control_font_size(18))
	joint_selector.add_theme_font_size_override("font_size", menu_control_font_size(18))
	for selector in [bot_palette_selector, bot_mix_selector]:
		selector.add_theme_font_size_override("font_size", menu_control_font_size(18))
	for check in bot_pattern_checks:
		check.add_theme_font_size_override("font_size", menu_control_font_size(15))
	reduced_glow_toggle.add_theme_font_size_override("font_size", menu_control_font_size(17))

func options_max_scroll() -> float:
	var fov_slider_y: float = options_layout().fov_slider_y
	var max_scroll := maxf(0.0, fov_slider_y - OPTIONS_VIEW_INSET + menu_target_height(22.0)
		- options_content.size.y + 20.0)
	if bot_looks_focus:
		var bot_start: float = options_layout().bot_field_y - OPTIONS_VIEW_INSET - 24.0
		max_scroll = maxf(max_scroll, bot_start)
	return max_scroll

func options_layout() -> Dictionary:
	var row_gap := menu_target_height(46.0) + 32.0 if touch_ui_enabled else 75.0
	var preview_y := (269.0 if touch_ui_enabled else 219.0) + row_gap * 3.0 - 18.0
	var preview_height := 90.0 if touch_ui_enabled else 96.0
	var bot_field_y := preview_y + preview_height + 40.0
	var custom_label_y := bot_field_y + menu_target_height(46.0) + 16.0
	var custom_slider_y := custom_label_y + 14.0
	var pattern_label_y := custom_slider_y + menu_target_height(30.0) + 28.0
	var checks_y := pattern_label_y + 13.0
	var check_step := menu_target_height(33.0) + 6.0
	var reduced_y := checks_y + check_step * 3.0 + 4.0
	var fov_label_y := reduced_y + menu_target_height(46.0) + 16.0
	return {"row_gap": row_gap, "preview_y": preview_y, "preview_height": preview_height,
		"bot_field_y": bot_field_y, "custom_label_y": custom_label_y,
		"custom_slider_y": custom_slider_y, "pattern_label_y": pattern_label_y,
		"checks_y": checks_y, "check_step": check_step, "reduced_y": reduced_y,
		"fov_label_y": fov_label_y, "fov_slider_y": fov_label_y + 14.0}

func menu_text_font_size(text: String, base_size: int, max_width: float, numeric: bool) -> int:
	if not overlay_draw_active or (not touch_ui_enabled and not retro_layout_active):
		return base_size
	var draw_font := mono if numeric else font
	var font_size := base_size if retro_layout_active else menu_control_font_size(base_size)
	var text_width := draw_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if max_width > 0.0 and text_width > max_width:
		font_size = maxi(1, floori(float(font_size) * max_width / text_width))
	return font_size

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not touch_ui_enabled:
		touch_ui_enabled = true
		if game != null:
			game.update_hud_visibility()
		queue_redraw()
	touch_controls.refresh(game, touch_ui_enabled, ui_scale_factor())
	if touch_controls.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var camera_view := retro_camera_view_at(event.position)
		if camera_view >= 0:
			game.select_camera_view(camera_view)
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and can_select_spectator_pipe():
		var canvas_position: Vector2 = (event.position - retro_origin) / maxf(retro_root_scale, 0.01) \
			- Vector2(retro_wide_offset, 0)
		var roster_rect := Rect2(884, 533, 510, 207)
		if roster_rect.has_point(canvas_position):
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				var step: int = -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
				retro_roster_scroll = clampi(retro_roster_scroll + step, 0, retro_roster_max_scroll())
				queue_redraw()
				get_viewport().set_input_as_handled()
				return
			if event.button_index == MOUSE_BUTTON_LEFT:
				if Rect2(1368, 533, 26, 26).has_point(canvas_position):
					retro_roster_scroll = maxi(0, retro_roster_scroll - 1)
					queue_redraw()
					get_viewport().set_input_as_handled()
					return
				if Rect2(1368, 714, 26, 26).has_point(canvas_position):
					retro_roster_scroll = mini(retro_roster_max_scroll(), retro_roster_scroll + 1)
					queue_redraw()
					get_viewport().set_input_as_handled()
					return
				var rider_id: int = retro_roster_rider_at(event.position)
				if rider_id >= 0:
					game.select_spectator_rider(rider_id)
					get_viewport().set_input_as_handled()
					return
	if not options_open or game == null or game.state not in ["ready", "paused"]:
		return
	var scale := maxf(menu_canvas.scale.x, 0.01)
	var viewport_position := menu_canvas.position + options_content.position * scale
	var viewport_rect := Rect2(viewport_position, options_content.size * scale)
	if event is InputEventScreenTouch:
		if event.pressed and viewport_rect.has_point(event.position):
			options_drag_index = event.index
			options_drag_start = event.position
			options_drag_start_scroll = options_scroll_offset
		elif not event.pressed and event.index == options_drag_index:
			options_drag_index = -1
	elif event is InputEventScreenDrag and event.index == options_drag_index:
		var drag_distance: float = options_drag_start.y - event.position.y
		if absf(drag_distance) > 6.0:
			options_scroll_offset = clampf(options_drag_start_scroll + drag_distance / scale, 0.0, options_max_scroll())
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and viewport_rect.has_point(event.position):
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				options_drag_index = -2
				options_drag_start = event.position
				options_drag_start_scroll = options_scroll_offset
			elif options_drag_index == -2:
				options_drag_index = -1
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			options_scroll_offset = maxf(0.0, options_scroll_offset - 48.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			options_scroll_offset = minf(options_max_scroll(), options_scroll_offset + 48.0)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and options_drag_index == -2:
		options_drag_index = -1
	elif event is InputEventMouseMotion and options_drag_index == -2 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var drag_distance: float = options_drag_start.y - event.position.y
		if absf(drag_distance) > 6.0:
			options_scroll_offset = clampf(options_drag_start_scroll + drag_distance / scale, 0.0, options_max_scroll())
			get_viewport().set_input_as_handled()

static func clean_player_name(value: String) -> String:
	var cleaned := value.strip_edges().left(18)
	return "YOU" if cleaned.is_empty() else cleaned

func refresh_title_preview() -> void:
	if game != null and game.state == "ready":
		game.show_title()

func finish_options() -> void:
	if game == null:
		options_open = false
		bot_looks_focus = false
		return
	game.player_name = clean_player_name(player_name_entry.text)
	game.player_color = player_color_picker.color
	game.player_pattern = pattern_selector.get_selected_id()
	game.player_material = material_selector.get_selected_id()
	game.player_joint_style = joint_selector.get_selected_id()
	player_name_entry.release_focus()
	options_open = false
	bot_looks_focus = false
	options_scroll_offset = 0.0
	if game.state == "paused":
		return_to_pause_after_page = false
		return
	game.show_title()

func set_custom_bot_pattern(index: int, enabled: bool) -> void:
	var bit := 1 << index
	var mask: int = game.bot_custom_pattern_mask
	mask = mask | bit if enabled else mask & ~bit
	if mask == 0:
		bot_pattern_checks[index].set_pressed_no_signal(true)
		return
	game.bot_custom_pattern_mask = mask
	if game.bot_pattern_mix == BotStyle.PatternMix.CUSTOM:
		refresh_title_preview()

func sync_color_picker(picker: ColorPickerButton, color: Color) -> void:
	if picker.color == color:
		return
	picker.set_block_signals(true)
	picker.color = color
	picker.set_block_signals(false)

func close_menu_page() -> void:
	if controls_open:
		controls_open = false
		if game.state == "paused":
			return_to_pause_after_page = false
			return
	else:
		finish_options()

func open_retro_page(page: String) -> void:
	if game == null:
		return
	return_to_pause_after_page = game.state not in ["ready", "paused"]
	if return_to_pause_after_page:
		game.toggle_pause()
	options_open = page in ["options", "bot_looks"]
	bot_looks_focus = page == "bot_looks"
	online_open = page == "online"
	controls_open = page == "help"
	options_scroll_offset = 0.0
	if bot_looks_focus:
		var bot_field_y: float = options_layout().bot_field_y
		options_scroll_offset = clampf(bot_field_y - OPTIONS_VIEW_INSET - 24.0, 0.0, options_max_scroll())
	queue_redraw()

func label_at(text: String, location: Vector2, size_value: int = 18, color: Color = INK, numeric: bool = false) -> void:
	var max_width := -1.0
	if overlay_draw_active:
		max_width = RETRO_RIGHT_ORIGIN.x + retro_wide_offset + RETRO_RIGHT_SIZE.x - location.x - 20.0 if retro_layout_active \
			else 560.0 - location.x - 20.0
	var draw_size := menu_text_font_size(text, size_value, max_width, numeric)
	draw_string(mono if numeric else font, location, text, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size,
		retro_text_color(color))

func centered(text: String, y: float, size_value: int, color: Color = INK) -> void:
	var max_width := 512.0 if retro_layout_active and overlay_draw_active else 780.0
	var draw_size := menu_text_font_size(text, size_value, max_width, false)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size).x
	var anchor_x := size.x / 2.0
	if retro_viewport_draw_active:
		anchor_x = 443.0
	elif overlay_draw_active and retro_layout_active:
		anchor_x = RETRO_RIGHT_ORIGIN.x + retro_wide_offset + RETRO_RIGHT_SIZE.x / 2.0
	elif overlay_draw_active:
		anchor_x = 280.0
	elif touch_draw_active:
		anchor_x = screen_size().x / 2.0
	draw_string(font, Vector2(anchor_x - width / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		draw_size, retro_text_color(color))

func retro_world_rect() -> Rect2:
	return Rect2(retro_origin + Vector2(36, 114) * retro_root_scale,
		Vector2(814 + retro_wide_offset, 726) * retro_root_scale)

func viewport_centered(text: String, relative_y: float, size_value: int, color: Color = INK) -> void:
	var rect := retro_world_rect()
	var draw_size := maxi(10, roundi(size_value * retro_root_scale))
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size).x
	draw_string(font, Vector2(rect.position.x + (rect.size.x - width) / 2.0,
		rect.position.y + rect.size.y * relative_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		draw_size, color)

func retro_text_color(color: Color) -> Color:
	if not retro_layout_active or not overlay_draw_active:
		return color
	if color == INK:
		return RETRO_BLACK
	if color == MUTED:
		return RETRO_DARK
	if color == ACCENT:
		return RETRO_BLUE
	return color

func can_select_spectator_pipe() -> bool:
	return game != null and retro_layout_active and game.state in ["countdown", "playing"] \
		and (game.auto_mode or not game.sim.riders[game.player_rider_id()].alive)

func retro_camera_view_at(position: Vector2) -> int:
	if game == null or not visible or not retro_layout_active \
			or game.state not in ["countdown", "playing"] or retro_root_scale <= 0.0:
		return -1
	var canvas_position := (position - retro_origin) / retro_root_scale - Vector2(retro_wide_offset, 0)
	for view_id in range(3):
		if Rect2(1196, 327 + view_id * 38, 190, 31).has_point(canvas_position):
			return view_id
	return -1

func retro_roster_rider_at(position: Vector2) -> int:
	if retro_root_scale <= 0.0:
		return -1
	var canvas_position := (position - retro_origin) / retro_root_scale - Vector2(retro_wide_offset, 0)
	if not Rect2(Vector2(884, 533), Vector2(480, 207)).has_point(canvas_position):
		return -1
	var player_id: int = game.player_rider_id()
	var focus_id: int = game.watch_id if game.auto_mode or not game.sim.riders[player_id].alive else player_id
	var shown := retro_roster_ids(focus_id)
	for row in range(shown.size()):
		var row_rect := Rect2(Vector2(884, 532 + row * 29), Vector2(480, 28))
		if row_rect.has_point(canvas_position):
			return shown[row]
	return -1

func panel(rect: Rect2, color: Color = Color(0.025, 0.055, 0.095, 0.9)) -> void:
	draw_style_box(box(color), rect)

func _process(_delta: float) -> void:
	if game != null:
		touch_controls.refresh(game, touch_ui_enabled, ui_scale_factor())
		if game.state not in ["ready", "paused"]:
			options_open = false
			online_open = false
			controls_open = false
			bot_looks_focus = false
		options_content.size = Vector2(560, 530.0 if touch_ui_enabled else OPTIONS_VIEW_HEIGHT)
		fit_menu(overlay_panel_height())
		options_scroll_offset = clampf(options_scroll_offset, 0.0, options_max_scroll())
		var page_open: bool = game.state in ["ready", "paused"] and (options_open or online_open or controls_open)
		var title_page: bool = game.state == "ready" and not page_open
		for button in [game_menu_button, view_menu_button, options_menu_button, help_menu_button,
				minimize_window_button, maximize_window_button, close_window_button]:
			button.visible = retro_layout_active
		exit_button.visible = title_page and retro_layout_active
		primary.visible = game.state in ["ready", "paused", "finished"] and not page_open \
			and not (game.state == "finished" and game.crash_view_time > 0.0)
		secondary.visible = game.state in ["paused", "finished"] and not page_open
		options_button.visible = title_page
		bot_looks_button.visible = title_page
		online_button.visible = title_page
		controls_button.visible = title_page
		options_back.visible = game.state in ["ready", "paused"] and (options_open or controls_open)
		online_back.visible = game.state in ["ready", "paused"] and online_open
		online_join.visible = game.state in ["ready", "paused"] and online_open
		online_quick_match.visible = game.state in ["ready", "paused"] and online_open
		online_host_public.visible = game.state in ["ready", "paused"] and online_open
		online_private_join.visible = game.state in ["ready", "paused"] and online_open
		mode_toggle.visible = title_page
		pause_game_button.visible = retro_layout_active and game.state in ["playing", "countdown"]
		restart_game_button.visible = retro_layout_active and not game.online_mode \
			and game.state in ["playing", "countdown"] and game.sim.riders[game.player_rider_id()].alive
		mode_toggle.set_pressed_no_signal(game.endless_mode)
		quick_restart.visible = game.state == "playing" and not game.sim.riders[game.player_rider_id()].alive \
			and (game.endless_mode or (touch_ui_enabled and not game.online_mode))
		if game.player_respawn_pending:
			quick_restart.text = "RESPAWNING..." if game.auto_mode and not game.online_mode else "WAITING FOR SPACE"
		elif game.online_mode:
			quick_restart.text = "RESPAWN PIPE"
		else:
			quick_restart.text = "RESTART PIPE" if game.endless_mode else "RESTART ROUND"
		quick_restart.disabled = game.player_respawn_pending
		var ui_factor := ui_scale_factor()
		var available := screen_size()
		var restart_font_size := roundi(17.0 * ui_factor * touch_controls.touch_control_scale())
		if quick_restart.get_theme_font_size("font_size") != restart_font_size:
			quick_restart.add_theme_font_size_override("font_size", restart_font_size)
		if not retro_layout_active:
			quick_restart.position = Vector2((available.x - 228.0) / 2.0, (available.y - 44.0) / 2.0 if touch_ui_enabled else available.y - 145.0) * ui_factor
			quick_restart.size = Vector2(228, 44) * ui_factor
		options_content.visible = game.state in ["ready", "paused"] and options_open
		online_server_entry.visible = false
		online_room_entry.visible = game.state in ["ready", "paused"] and online_open
		bot_selector.visible = options_content.visible
		size_selector.visible = options_content.visible
		fov_slider.visible = options_content.visible
		player_name_entry.visible = options_content.visible
		player_color_picker.visible = options_content.visible
		player_color_label.visible = options_content.visible
		secondary_color_picker.visible = options_content.visible
		detail_color_picker.visible = options_content.visible
		secondary_auto.visible = options_content.visible
		detail_auto.visible = options_content.visible
		pattern_selector.visible = options_content.visible
		material_selector.visible = options_content.visible
		joint_selector.visible = options_content.visible
		bot_palette_selector.visible = options_content.visible
		bot_mix_selector.visible = options_content.visible
		bot_saturation_slider.visible = options_content.visible
		bot_brightness_slider.visible = options_content.visible
		for check in bot_pattern_checks:
			check.visible = options_content.visible
		reduced_glow_toggle.visible = options_content.visible
		pipe_preview.visible = options_content.visible
		if pipe_preview.visible:
			pipe_preview.set_appearance(game.player_color, game.player_pattern,
				game.player_material, game.player_joint_style,
				game.player_secondary_color, game.player_detail_color, game.reduced_glow)
		auto_toggle.visible = game.state in ["ready", "paused", "finished"] and not (game.state == "ready" and (options_open or controls_open))
		auto_toggle.set_pressed_no_signal(game.auto_mode)
		hud_toggle.visible = game.state in ["paused", "finished"] and not (game.state == "ready" and (options_open or controls_open))
		hud_toggle.set_pressed_no_signal(game.hud_enabled)
		full_screen_toggle.visible = not OS.has_feature("web") and game.state in ["ready", "paused", "finished"] \
			and not (game.state == "ready" and (options_open or online_open or controls_open))
		full_screen_toggle.set_pressed_no_signal(game.is_fullscreen())
	queue_redraw()

func _draw() -> void:
	if game == null or game.sim.riders.is_empty():
		return
	if not game.hud_enabled and not touch_ui_enabled and game.state in ["playing", "countdown"]:
		draw_collision_feedback()
		return
	if not touch_ui_enabled:
		if game.state in ["ready", "paused"] or (game.state == "finished" and game.crash_view_time <= 0.0):
			draw_retro_menu_overlay()
		else:
			draw_retro_gameplay()
		return
	if game.state in ["ready", "paused"] or (game.state == "finished" and game.crash_view_time <= 0.0):
		draw_legacy_overlay()
		return
	if touch_ui_enabled:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui_scale_factor())
		touch_draw_active = true
		if game.hud_enabled:
			draw_touch_game_hud()
		draw_collision_feedback()
		touch_draw_active = false
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var sim = game.sim
	var focus_id: int = game.watch_id if game.auto_mode else game.player_rider_id()
	var focus_rider: Dictionary = sim.riders[focus_id]
	panel(Rect2(24, 24, 252, 190))
	label_at("PIPE / ENDLESS" if game.endless_mode else "PIPE / SURVIVAL", Vector2(44, 53), 18, ACCENT)
	label_at("%d / %d ALIVE" % [sim.alive_ids().size(), sim.riders.size()], Vector2(43, 97), 32)
	var seconds := int(sim.elapsed_time)
	label_at("SESSION  %02d:%02d" % [seconds / 60, seconds % 60] if game.endless_mode
		else "ROUND  %02d:%02d" % [seconds / 60, seconds % 60], Vector2(44, 139), 21, MUTED, true)
	label_at("ORB VALUES", Vector2(44, 169), 13, MUTED)
	draw_orb_legend(Vector2(48, 196), 77.0, 14)
	panel(Rect2(size.x / 2.0 - 186, 24, 372, 88))
	var following: bool = game.auto_mode or not sim.riders[game.player_rider_id()].alive
	centered("AUTO MODE / FOLLOWING" if game.auto_mode else ("SPECTATING" if following else "YOUR PIPE"), 53, 16, MUTED)
	centered(game.sim.rider_name(game.watch_id if following else game.player_rider_id()), 89, 28,
		game.sim.rider_color(game.watch_id if following else game.player_rider_id()))
	draw_leaderboard(focus_id)
	panel(Rect2(24, size.y - 192, 252, 136))
	label_at(game.sim.rider_name(focus_id) + " / SCORE" if game.auto_mode else "YOUR SCORE", Vector2(44, size.y - 161), 17, MUTED)
	label_at(str(focus_rider.score), Vector2(43, size.y - 112), 44, Color("ffdb77"), true)
	var score_detail := "%d ORBS / %d ELIMINATIONS" % [focus_rider.orb_count, focus_rider.eliminations]
	if focus_rider.combo_count > 1:
		score_detail = "COMBO x%.1f / %.1fs" % [focus_rider.combo_multiplier, focus_rider.combo_time]
	label_at(score_detail, Vector2(44, size.y - 77), 15, ACCENT if focus_rider.combo_count > 1 else MUTED)
	draw_boost(focus_rider)
	draw_play_messages()
	draw_collision_feedback()

func leaderboard_ids(focus_id: int) -> Array:
	var sim = game.sim
	var ranking: Array[int] = []
	for i in range(sim.riders.size()):
		ranking.append(i)
	ranking.sort_custom(func(a: int, b: int):
		return sim.riders[a].score > sim.riders[b].score if sim.riders[a].score != sim.riders[b].score else a < b)
	var shown := ranking.slice(0, 3 if game.auto_mode else 5)
	if focus_id not in shown:
		shown[shown.size() - 1] = focus_id
	return [ranking, shown]

func retro_roster_ids(focus_id: int) -> Array:
	var ranking: Array = leaderboard_ids(focus_id)[0]
	retro_roster_scroll = clampi(retro_roster_scroll, 0, maxi(0, ranking.size() - 7))
	var shown: Array = ranking.slice(retro_roster_scroll, mini(retro_roster_scroll + 7, ranking.size()))
	if focus_id not in shown and not shown.is_empty():
		shown[shown.size() - 1] = focus_id
	return shown

func retro_roster_max_scroll() -> int:
	return maxi(0, game.sim.riders.size() - 7) if game != null else 0

func draw_leaderboard(focus_id: int) -> void:
	var lists := leaderboard_ids(focus_id)
	var ranking: Array = lists[0]
	var shown: Array = lists[1]
	var x := size.x - 280
	panel(Rect2(x, 24, 256, 58 + shown.size() * 35))
	label_at("LEADERS", Vector2(x + 20, 56), 19)
	label_at("SCORE", Vector2(x + 184, 56), 14, MUTED)
	for row in range(shown.size()):
		var i: int = shown[row]
		var y := 88.0 + row * 35.0
		var alive: bool = game.sim.riders[i].alive
		var rider_color: Color = game.sim.rider_color(i)
		var color: Color = rider_color if alive else rider_color.darkened(0.45)
		if i == focus_id:
			draw_style_box(box(Color("203b4a"), 5), Rect2(x + 10, y - 23, 236, 31))
		draw_circle(Vector2(x + 23, y - 6), 4.5, color)
		var score := str(game.sim.riders[i].score)
		var width := mono.get_string_size(score, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var score_x := x + 235.0 - width
		var name_x := x + 36.0
		var name_width := score_x - name_x - 8.0
		var rank := ranking.find(i) + 1
		var name_text := fit_leaderboard_name(game.sim.rider_name(i), rank, name_width)
		label_at(name_text, Vector2(name_x, y), 17, color)
		label_at(score, Vector2(score_x, y), 18, INK if i == focus_id else MUTED, true)

func draw_orb_legend(origin: Vector2, spacing: float, font_size: int) -> void:
	var values: Array[int] = [Scoring.BLUE_ORB_POINTS, Scoring.ORB_POINTS, Scoring.VIOLET_ORB_POINTS]
	for i in range(values.size()):
		var x := origin.x + float(i) * spacing
		draw_circle(Vector2(x, origin.y - 4.0), 5.0, Scoring.orb_color(values[i]))
		label_at(str(values[i]), Vector2(x + 12.0, origin.y), font_size, INK, true)

func fit_leaderboard_name(name: String, rank: int, max_width: float) -> String:
	var prefix := "%02d " % rank
	if font.get_string_size(prefix + name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x <= max_width:
		return prefix + name
	var shortened := name
	while not shortened.is_empty():
		var candidate := prefix + shortened + "…"
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x <= max_width:
			return candidate
		shortened = shortened.left(shortened.length() - 1)
	return prefix.strip_edges()

func boost_status(rider: Dictionary) -> String:
	if not rider.alive:
		return "PIPE LOST"
	if rider.boosting:
		return "BOOSTING 2x"
	if rider.boost_locked and game.boost_held and not game.auto_mode:
		return "RELEASE SHIFT"
	return "READY" if rider.pressure >= 0.999 else "RECHARGING"

func draw_boost(rider: Dictionary) -> void:
	var x := size.x - 316
	var y := size.y - 192
	var amount: float = rider.pressure
	var color := Color("ffb65a") if rider.boosting else ACCENT
	panel(Rect2(x, y, 292, 136))
	label_at("AUTO BOOST" if game.auto_mode else "BOOST", Vector2(x + 20, y + 33), 23, INK)
	label_at("%d%%" % roundi(amount * 100.0), Vector2(x + 206, y + 33), 24, color, true)
	draw_style_box(box(Color("23384d"), 5), Rect2(x + 20, y + 52, 252, 14))
	if amount > 0.0:
		draw_style_box(box(color, 5), Rect2(x + 20, y + 52, 252 * amount, 14))
	label_at(boost_status(rider), Vector2(x + 20, y + 94), 19, color)
	label_at("AI CONTROLS BOOST" if game.auto_mode else "HOLD SHIFT TO BOOST", Vector2(x + 20, y + 119), 14, MUTED)

func draw_touch_game_hud() -> void:
	if not game.hud_enabled:
		return
	var rider: Dictionary = game.sim.riders[game.player_rider_id()]
	var bounds := screen_size()
	var panel_width := minf(236.0, bounds.x - 128.0)
	panel(Rect2(16, 16, panel_width, 100))
	label_at("%d / %d ALIVE" % [game.sim.alive_ids().size(), game.sim.riders.size()], Vector2(30, 45), 18, INK)
	if bounds.x >= 360.0:
		label_at("SCORE %d   /   %d ORBS" % [rider.score, rider.orb_count], Vector2(30, 73), 15, MUTED)
		var status := "AUTO / TAP PAUSE" if game.auto_mode else "LEFT STEERS / RIGHT ORBITS"
		if rider.combo_count > 1:
			status = "COMBO x%.1f / %.1fs" % [rider.combo_multiplier, rider.combo_time]
		label_at(status,
			Vector2(30, 99), 13, ACCENT)
	else:
		label_at("SCORE %d" % rider.score, Vector2(30, 73), 15, MUTED)
		var status := "AUTO / PAUSE" if game.auto_mode else "LEFT STEERS / RIGHT ORBITS"
		if rider.combo_count > 1:
			status = "COMBO x%.1f" % rider.combo_multiplier
		label_at(status, Vector2(30, 99), 13, ACCENT)
	panel(Rect2(16, 116, 176, 34))
	draw_orb_legend(Vector2(32, 139), 56.0, 13)
	draw_play_messages()

func draw_play_messages() -> void:
	var sim = game.sim
	var bounds := screen_size() if touch_draw_active else size
	var h := bounds.y
	if game.camera.first_person and game.state in ["playing", "countdown"]:
		var center := bounds / 2.0
		draw_circle(center, 2, Color(0.9, 1.0, 1.0, 0.8))
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(center + direction * 8, center + direction * 14, Color(0.8, 1.0, 1.0, 0.65), 1.5)
	if game.state == "playing" and sim.riders[game.player_rider_id()].alive:
		var queued := " > ".join(game.turn_queue).to_upper()
		if not queued.is_empty():
			centered("QUEUED / " + queued, h - 161, 17, ACCENT)
		if not touch_ui_enabled and game.hud_enabled and game.clearance > 2 and not game.camera.overview:
			var control_hint := "C / CAMERA     F / TAKE CONTROL     ESC / PAUSE" if game.auto_mode else "WASD / STEER     HOLD SHIFT / BOOST     ESC / PAUSE"
			centered(control_hint, 137, 13, MUTED)
		if game.clearance <= 2 and not game.auto_mode:
			centered("BLOCKED AHEAD / TURN", 148, 22, Color("ffb65a"))
		if game.score_message_time > 0.0 and not game.auto_mode:
			centered(game.score_message, h / 2.0 + 65, 20, Color("ffdb77"))
	if not touch_ui_enabled and game.hud_enabled and game.camera.overview \
			and game.state in ["playing", "countdown"]:
		centered("V / PIPE VIEW     TAB / SELECT PIPE     RIGHT DRAG / ORBIT", 137, 13, MUTED)
	if game.fov_message_time > 0.0:
		centered(game.fov_message, h / 2.0 - 68, 17, ACCENT)
	if game.state == "playing" and not sim.riders[game.player_rider_id()].alive and (not game.auto_mode or game.endless_mode):
		if touch_ui_enabled:
			var lost_width := minf(456.0, bounds.x - 32.0)
			panel(Rect2((bounds.x - lost_width) / 2.0, h - 230, lost_width, 76))
			centered("PIPE LOST", h - 201, 20, Color("ffb65a"))
			centered("Tap Respawn when ready" if game.online_mode else
				("Restarting..." if game.endless_mode and game.auto_mode else "Tap PAUSE to watch survivors"),
				h - 174, 15, MUTED)
		elif game.endless_mode:
			panel(Rect2(size.x / 2 - 228, h - 230, 456, 76))
			centered("PIPE LOST / " + str(sim.riders[game.player_rider_id()].cause).to_upper(), h - 201, 20, Color("ffb65a"))
			centered("Press R or click Respawn / session continues" if game.online_mode
				else ("Your pipe returns automatically / session continues" if game.auto_mode
				else "Press R or click Restart / session continues"), h - 174, 17, MUTED)
		else:
			panel(Rect2(size.x / 2 - 228, h - 230, 456, 76))
			centered("PIPE LOST / " + str(sim.riders[game.player_rider_id()].cause).to_upper(), h - 201, 20, Color("ffb65a"))
			centered("R to restart / Tab to follow survivors", h - 174, 17, MUTED)
	if game.state == "countdown":
		centered(str(ceili(game.countdown)), h / 2.0 + 25, 88, ACCENT)
		centered("AUTO MODE  /  SIT BACK AND WATCH" if game.auto_mode else "YOUR PIPE  /  GET READY", h / 2.0 + 68, 17)

func draw_collision_feedback() -> void:
	if game.collision_feedback_time <= 0.0:
		return
	var bounds := screen_size() if touch_draw_active else size
	var view_rect := Rect2(Vector2.ZERO, bounds)
	if retro_layout_active and not touch_draw_active:
		view_rect = retro_world_rect()
	var age: float = game.COLLISION_FEEDBACK_DURATION - game.collision_feedback_time
	var flash := clampf(1.0 - age / 0.14, 0.0, 1.0)
	if flash > 0.0:
		draw_rect(view_rect, Color(1.0, 0.26, 0.045, flash * 0.16))
	var point: Vector2 = game.camera.unproject_position(game.collision_position)
	if touch_draw_active:
		point /= ui_scale_factor()
	elif retro_layout_active:
		point += view_rect.position
	if not game.camera.is_position_behind(game.collision_position) and view_rect.grow(48.0).has_point(point):
		var marker_alpha := clampf(game.collision_feedback_time / 0.65, 0.0, 1.0)
		var pulse := fposmod(age * 1.4, 1.0)
		draw_circle(point, 5.0, Color(1.0, 0.38, 0.08, marker_alpha * 0.28))
		draw_arc(point, 14.0 + pulse * 9.0, 0.0, TAU, 40,
			Color(1.0, 0.64, 0.18, marker_alpha), 3.0, true)
		if age < 0.38:
			var burst: float = age / 0.38
			for spoke in range(8):
				var angle := float(spoke) * TAU / 8.0 + 0.18
				var direction := Vector2(cos(angle), sin(angle))
				draw_line(point + direction * 8.0, point + direction * (19.0 + burst * 15.0),
					Color(1.0, 0.8, 0.34, 1.0 - burst), 2.0, true)
	var label_y := bounds.y * 0.69
	if retro_layout_active and not touch_draw_active:
		viewport_centered(game.collision_feedback_label, 0.69, 20, Color("ffcf83"))
	else:
		centered(game.collision_feedback_label, label_y, 20, Color("ffcf83"))

func draw_retro_shell() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var viewport_rect := Rect2(retro_origin + Vector2(36, 114) * retro_root_scale,
		Vector2(814 + retro_wide_offset, 726) * retro_root_scale)
	draw_rect(Rect2(0, 0, size.x, viewport_rect.position.y), RETRO_GRAY)
	draw_rect(Rect2(0, viewport_rect.position.y, viewport_rect.position.x, viewport_rect.size.y), RETRO_GRAY)
	draw_rect(Rect2(viewport_rect.end.x, viewport_rect.position.y,
		size.x - viewport_rect.end.x, viewport_rect.size.y), RETRO_GRAY)
	draw_rect(Rect2(0, viewport_rect.end.y, size.x, size.y - viewport_rect.end.y), RETRO_GRAY)
	draw_set_transform(retro_origin, 0.0, Vector2.ONE * retro_root_scale)
	draw_retro_frame(Rect2(24, 16, 1392 + retro_wide_offset, 868), true)
	draw_rect(Rect2(32, 24, 1376 + retro_wide_offset, 42), RETRO_BLUE)
	draw_string(font, Vector2(57, 54), "Pipe Survival", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("ffffff"))
	draw_retro_bevel(Rect2(32, 66, 1376 + retro_wide_offset, 42), true)
	draw_rect(Rect2(32, 108, 1376 + retro_wide_offset, 4), RETRO_GRAY)
	draw_rect(Rect2(32, 110, 2, 736), RETRO_GRAY)
	draw_retro_frame(Rect2(34, 112, 818 + retro_wide_offset, 730), false)
	draw_rect(Rect2(852 + retro_wide_offset, 110, 10, 736), RETRO_GRAY)
	draw_retro_bevel(Rect2(858 + retro_wide_offset, 110, 552, 734), false)
	draw_rect(Rect2(1410 + retro_wide_offset, 110, 4, 736), RETRO_GRAY)
	draw_retro_bevel(Rect2(32, 846, 1376 + retro_wide_offset, 28), true)
	var status := retro_status_text()
	draw_string(font, Vector2(44, 866), status, HORIZONTAL_ALIGNMENT_LEFT, 1050, 15, RETRO_BLACK)
	draw_string(font, Vector2(1124 + retro_wide_offset, 866), "PIPE SURVIVAL",
		HORIZONTAL_ALIGNMENT_LEFT, 250, 14, RETRO_DARK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_retro_frame(rect: Rect2, raised: bool) -> void:
	var dark := Color("000000")
	var light := Color("ffffff") if raised else Color("808080")
	var shadow := Color("808080") if raised else Color("ffffff")
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), dark)
	draw_rect(Rect2(rect.position, Vector2(2, rect.size.y)), dark)
	draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - 2), Vector2(rect.size.x, 2)), dark)
	draw_rect(Rect2(Vector2(rect.end.x - 2, rect.position.y), Vector2(2, rect.size.y)), dark)
	draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4, 2)), light)
	draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(2, rect.size.y - 4)), light)
	draw_rect(Rect2(Vector2(rect.position.x + 2, rect.end.y - 4), Vector2(rect.size.x - 4, 2)), shadow)
	draw_rect(Rect2(Vector2(rect.end.x - 4, rect.position.y + 2), Vector2(2, rect.size.y - 4)), shadow)

func draw_retro_bevel(rect: Rect2, sunken: bool) -> void:
	draw_rect(rect, Color("000000"))
	draw_rect(rect.grow(-1.0), RETRO_GRAY)
	var highlight := Color("ffffff") if not sunken else Color("808080")
	var shadow := Color("808080") if not sunken else Color("ffffff")
	draw_line(rect.position + Vector2(1, 1), Vector2(rect.end.x - 1, rect.position.y + 1), highlight, 2.0)
	draw_line(rect.position + Vector2(1, 1), Vector2(rect.position.x + 1, rect.end.y - 1), highlight, 2.0)
	draw_line(Vector2(rect.position.x + 1, rect.end.y - 1), rect.end - Vector2(1, 1), shadow, 2.0)
	draw_line(Vector2(rect.end.x - 1, rect.position.y + 1), rect.end - Vector2(1, 1), shadow, 2.0)

func bot_count_summary() -> String:
	if game.bot_count == 0:
		return "SOLO RUN"
	return "1 BOT" if game.bot_count == 1 else "%d BOTS" % game.bot_count

func player_roster_summary() -> String:
	return "SOLO RUN" if game.bot_count == 0 else "YOU + " + bot_count_summary()

func retro_status_text() -> String:
	if game.state == "ready":
		return "READY  |  %s  |  %dM CUBE" % [bot_count_summary(), game.arena_width]
	var focus_id: int = game.watch_id if game.auto_mode or not game.sim.riders[game.player_rider_id()].alive else game.player_rider_id()
	var rider: Dictionary = game.sim.riders[focus_id]
	var status := "ACTIVE" if rider.alive else "LOST"
	var seconds := int(game.sim.elapsed_time)
	return "PIPE #%02d %s  |  SCORE %d  |  TIME %02d:%02d  |  CAMERA %s" % [
		focus_id + 1, status, rider.score, seconds / 60, seconds % 60, game.camera.view_name().to_upper()]

func draw_retro_menu_overlay() -> void:
	fit_menu(overlay_panel_height())
	draw_retro_shell()
	overlay_draw_active = true
	draw_set_transform(menu_canvas.position, 0.0, menu_canvas.scale)
	var rect := Rect2(RETRO_RIGHT_ORIGIN + Vector2(retro_wide_offset, 0), RETRO_RIGHT_SIZE)
	if game.state == "ready":
		if options_open:
			draw_options_page(rect)
		elif online_open:
			draw_online_page(rect)
		elif controls_open:
			draw_controls_page(rect)
		else:
			draw_title_page(rect)
	elif game.state == "paused" and options_open:
		draw_options_page(rect)
	elif game.state == "paused" and online_open:
		draw_online_page(rect)
	elif game.state == "paused" and controls_open:
		draw_controls_page(rect)
	else:
		draw_retro_pause_page(rect)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	overlay_draw_active = false

func draw_retro_pause_page(rect: Rect2) -> void:
	var title := "PAUSED"
	var subtitle := "ROUND PAUSED  /  PIPE SURVIVAL"
	var lines: Array[String]
	var action := "RESUME"
	if game.state == "finished":
		var winner: int = game.sim.winner
		title = "ROUND WON" if winner == 0 else "ROUND OVER"
		subtitle = "NO SURVIVORS" if winner < 0 else game.sim.rider_name(winner) + " IS THE LAST PIPE STANDING"
		var seconds := int(game.sim.elapsed_time)
		var rider: Dictionary = game.sim.riders[game.player_rider_id()]
		lines = ["Round time  %d:%02d" % [seconds / 60, seconds % 60],
			"Your score  %d" % rider.score,
			"Orbs %d  /  Eliminations %d" % [rider.orb_count, rider.eliminations]]
		if game.auto_mode:
			lines.append("Next round in %d seconds." % ceili(game.auto_restart_left))
		else:
			lines.append("Select Play Again to start a new round.")
		action = "PLAY AGAIN"
	else:
		if game.auto_mode:
			lines = ["Every pipe steers and boosts automatically.",
				"Tab follows another pipe; V changes pipe display.",
				"C changes camera; H hides the interface.",
				"The arena continues while the round is paused."]
		else:
			lines = ["W / S pitch; A / D turn.", "Hold Shift to boost; release to recharge.",
				"C changes camera; Q / E adjusts FOV.",
				"V / Tab show pipe view; Esc resumes."]
	centered(title, rect.position.y + 68, 31, RETRO_BLACK)
	centered(subtitle, rect.position.y + 99, 14, Color("000080"))
	draw_retro_bevel(Rect2(rect.position + Vector2(28, 122), Vector2(504, 202)), true)
	for i in range(lines.size()):
		label_at(lines[i], rect.position + Vector2(47, 157 + i * 34), 17, RETRO_BLACK)
	label_at("ROUND STATUS", rect.position + Vector2(38, 353), 14, Color("000080"))
	draw_menu_toggles(rect, 370)
	primary.visible = true
	primary.text = action
	primary.position = rect.position + Vector2(38, 444)
	primary.size = Vector2(484, 52)
	secondary.visible = true
	secondary.text = "BACK TO TITLE"
	secondary.position = rect.position + Vector2(38, 510)
	secondary.size = Vector2(484, 44)

func draw_retro_gameplay() -> void:
	draw_retro_shell()
	if game.collision_feedback_time > 0.0:
		draw_collision_feedback()
	draw_retro_view_messages()
	overlay_draw_active = true
	draw_set_transform(retro_origin + Vector2(retro_wide_offset, 0) * retro_root_scale,
		0.0, Vector2.ONE * retro_root_scale)
	draw_retro_gameplay_panel()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	overlay_draw_active = false

func draw_retro_view_messages() -> void:
	var view_rect := retro_world_rect()
	if game.state == "countdown":
		var countdown_text := str(ceili(game.countdown))
		viewport_centered(countdown_text, 0.52, 88, Color("ffffff"))
		viewport_centered("YOUR PIPE  /  GET READY" if not game.auto_mode else "AUTO MODE  /  WATCH THE PIPES",
			0.59, 19, Color("ffffff"))
	if game.camera.first_person and game.state in ["playing", "countdown"]:
		var crosshair := view_rect.get_center()
		draw_circle(crosshair, 2.0, Color(0.9, 1.0, 1.0, 0.8))
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(crosshair + direction * 8.0, crosshair + direction * 14.0,
				Color(0.8, 1.0, 1.0, 0.65), 1.5)
	if game.state == "playing" and game.sim.riders[game.player_rider_id()].alive:
		var queued := " > ".join(game.turn_queue).to_upper()
		if not queued.is_empty():
			viewport_centered("QUEUED / " + queued, 0.91, 17, Color("56eddf"))
		if game.clearance <= 2 and not game.auto_mode:
			viewport_centered("BLOCKED AHEAD / TURN", 0.12, 22, Color("ffb65a"))
	if game.score_message_time > 0.0 and not game.score_message.is_empty():
		viewport_centered(game.score_message, 0.73, 20, Color("ffdb77"))
	if game.fov_message_time > 0.0:
		viewport_centered(game.fov_message, 0.10, 16, Color("ffffff"))

func draw_retro_gameplay_panel() -> void:
	var sim = game.sim
	var player_id: int = game.player_rider_id()
	var focus_id: int = game.watch_id if game.auto_mode or not sim.riders[player_id].alive else player_id
	var focus: Dictionary = sim.riders[focus_id]
	var active_count: int = sim.alive_ids().size()
	draw_retro_group(Rect2(876, 124, 318, 90), "SCORE")
	label_at(str(focus.score), Vector2(894, 194), 39, Color("006600"), true)
	draw_retro_group(Rect2(1202, 124, 200, 90), "PIPES ACTIVE")
	label_at("%d / %d" % [active_count, sim.riders.size()], Vector2(1218, 187), 26, Color("000080"), true)
	var seconds := int(sim.elapsed_time)
	draw_retro_group(Rect2(876, 222, 252, 70), "ROUND TIME")
	label_at("%02d:%02d" % [seconds / 60, seconds % 60], Vector2(894, 275), 24, RETRO_BLACK, true)
	draw_retro_group(Rect2(1136, 222, 266, 70), "CURRENT PIPE")
	label_at("#%02d  %s" % [focus_id + 1, "ACTIVE" if focus.alive else "LOST"],
		Vector2(1152, 274), 18, Color("000080"))
	draw_retro_group(Rect2(876, 300, 302, 182), "CONTROLS     BOOST %d%%" % roundi(focus.pressure * 100.0))
	var control_rows: Array[Array] = [
		["W / S", "PITCH"], ["A / D", "TURN"], ["SHIFT", "BOOST"], ["ESC", "PAUSE"]]
	if game.auto_mode:
		control_rows = [["TAB", "FOLLOW PIPE"], ["V", "PIPE DISPLAY"], ["F", "TAKE CONTROL"], ["ESC", "PAUSE"]]
	for row in range(control_rows.size()):
		var y := 326.0 + row * 30.0
		draw_retro_bevel(Rect2(892, y, 63, 24), false)
		label_at(control_rows[row][0], Vector2(899, y + 17), 12, RETRO_BLACK)
		label_at(control_rows[row][1], Vector2(968, y + 18), 13, RETRO_BLACK)
	draw_retro_bevel(Rect2(892, 454, 268, 12), true)
	if focus.pressure > 0.0:
		draw_rect(Rect2(896, 458, 260.0 * focus.pressure, 4),
			Color("000080") if not focus.boosting else Color("a00000"))
	draw_retro_group(Rect2(1186, 300, 216, 182), "CAMERA")
	var camera_names: Array[String] = ["CHASE", "FIRST PERSON", "OVERVIEW"]
	var camera_mouse_position := (get_viewport().get_mouse_position() - retro_origin) / retro_root_scale \
		- Vector2(retro_wide_offset, 0)
	for view_id in range(camera_names.size()):
		var row_rect := Rect2(1196, 327 + view_id * 38, 190, 31)
		if row_rect.has_point(camera_mouse_position):
			draw_rect(row_rect, Color("d0d0d0"))
		var center := Vector2(1208, 342 + view_id * 38)
		draw_circle(center, 8.0, Color("ffffff"))
		draw_arc(center, 8.0, 0.0, TAU, 24, RETRO_DARK, 2.0)
		if game.camera.view == view_id:
			draw_circle(center, 4.0, RETRO_BLACK)
		label_at(camera_names[view_id], Vector2(1223, 347 + view_id * 38), 13, RETRO_BLACK)
	label_at("CLICK TO SELECT", Vector2(1201, 461), 12, RETRO_DARK)
	draw_retro_group(Rect2(876, 490, 526, 274), "PIPE ROSTER")
	var can_watch: bool = game.auto_mode or not sim.riders[player_id].alive
	label_at("CLICK ACTIVE PIPE TO FOLLOW" if can_watch else "PIPE / SCORE / STATUS",
		Vector2(894, 518), 13, RETRO_DARK)
	var shown := retro_roster_ids(focus_id)
	for row in range(shown.size()):
		var rider_id: int = shown[row]
		var rider: Dictionary = sim.riders[rider_id]
		var y := 546.0 + row * 29.0
		var color: Color = sim.rider_color(rider_id)
		if rider_id == focus_id:
			draw_rect(Rect2(886, y - 17, 478, 27), RETRO_BLUE)
		elif can_watch and rider.alive:
			var mouse_position := (get_viewport().get_mouse_position() - retro_origin) / retro_root_scale
			if Rect2(886, y - 17, 478, 27).has_point(mouse_position):
				draw_rect(Rect2(886, y - 17, 478, 27), Color("a0a0a0"))
		draw_rect(Rect2(894, y - 13, 12, 12), color)
		label_at("#%02d  %s" % [rider_id + 1, sim.rider_name(rider_id)], Vector2(916, y), 15,
			Color("ffffff") if rider_id == focus_id else (RETRO_DARK if rider.alive else Color("808080")))
		label_at(str(rider.score), Vector2(1246, y), 15,
			Color("ffffff") if rider_id == focus_id else RETRO_BLACK, true)
		label_at("ACTIVE" if rider.alive else "LOST", Vector2(1310, y), 14,
			Color("ffffff") if rider_id == focus_id else (Color("006600") if rider.alive else RETRO_DARK))
	if retro_roster_max_scroll() > 0:
		draw_retro_bevel(Rect2(1368, 533, 26, 207), true)
		draw_retro_bevel(Rect2(1371, 536, 20, 20), false)
		draw_retro_bevel(Rect2(1371, 717, 20, 20), false)
		label_at("^", Vector2(1377, 551), 13, RETRO_BLACK)
		label_at("v", Vector2(1377, 733), 13, RETRO_BLACK)
		var track_height := 153.0
		var thumb_height := maxf(24.0, track_height * 7.0 / game.sim.riders.size())
		var thumb_y := 560.0 + (track_height - thumb_height) * float(retro_roster_scroll) / float(retro_roster_max_scroll())
		draw_retro_bevel(Rect2(1372, thumb_y, 18, thumb_height), false)

func draw_retro_group(rect: Rect2, title: String) -> void:
	draw_retro_bevel(rect, true)
	draw_string(font, rect.position + Vector2(10, 17), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("000080"))

func draw_legacy_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.012, 0.025, 0.5))
	var panel_height := overlay_panel_height()
	fit_menu(panel_height)
	var rect := Rect2(Vector2.ZERO, Vector2(560, panel_height))
	overlay_draw_active = true
	draw_set_transform(menu_canvas.position, 0.0, menu_canvas.scale)
	panel(rect, Color("0d1b2b"))
	draw_rect(Rect2(Vector2(25, 0), Vector2(510, 3)), ACCENT)
	if game.state == "ready":
		if options_open:
			draw_options_page(rect)
		elif online_open:
			draw_online_page(rect)
		elif controls_open:
			draw_controls_page(rect)
		else:
			draw_title_page(rect)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		overlay_draw_active = false
		return
	var title := "PAUSED"
	var subtitle := "AUTO MODE CONTROLS" if game.auto_mode else "CONTROLS"
	var lines: Array[String] = []
	var action := "TAP  /  RESUME" if touch_ui_enabled else "ESC  /  RESUME"
	if game.state == "paused":
		if touch_ui_enabled:
			if game.auto_mode:
				lines = ["Auto mode steers and boosts for you.", "Tap RESUME to return to the round.",
				"Drag the right side to orbit; pinch to zoom.",
				"On resume, tap VIEW for overview controls.", "GAME OPTIONS keeps the round settings."]
			else:
				lines = ["Drag the lower-left side to steer.", "Hold BOOST; release to recharge.",
					"Drag right to orbit; pinch to zoom.", "On resume, tap VIEW for overview controls.",
					"Tap RESUME to return to the round.", "GAME OPTIONS keeps the round settings."]
		elif game.auto_mode:
			lines = ["Every pipe steers and boosts automatically.", "Overview: V display / Tab select",
				"Outside overview, Tab follows a pipe.", "Camera: C / FOV: Q / E / take control: F",
				"Arrows: orbit / look / mouse: overview orbit / zoom", "Hide HUD: H"]
		else:
			lines = ["Pitch: W / S    Turn: A / D", "Boost: hold Shift", "FOV: Q / E",
				"Camera: C", "Overview: V display / Tab select",
				"Arrows: look / mouse: overview orbit / zoom    HUD: H"]
	elif game.state == "finished":
		var winner: int = game.sim.winner
		title = "ROUND WON" if winner == 0 else "ROUND OVER"
		subtitle = "NO SURVIVORS" if winner < 0 else game.sim.rider_name(winner) + " IS THE LAST PIPE STANDING"
		var secs := int(game.sim.elapsed_time)
		lines = ["Round lasted %d:%02d" % [secs / 60, secs % 60],
			"Your score: %d" % int(game.sim.riders[game.player_rider_id()].score),
			"%d orbs collected / %d eliminations" % [game.sim.riders[game.player_rider_id()].orb_count, game.sim.riders[game.player_rider_id()].eliminations]]
		if game.auto_mode:
			lines.append("Next round in %d seconds." % ceili(game.auto_restart_left))
		else:
			lines.append("Esc / Back to Title")
		action = "ENTER  /  PLAY AGAIN"
	centered(title, rect.position.y + 72, 33)
	centered(subtitle, rect.position.y + 102, 14, ACCENT)
	for i in range(lines.size()):
		centered(lines[i], rect.position.y + 149 + i * 27, 17, MUTED)
	var toggle_height := menu_target_height(42)
	draw_menu_toggles(rect, 300)
	primary.visible = true
	primary.text = action
	var primary_y := 365.0
	if touch_ui_enabled:
		primary_y = 300.0 + toggle_height + 12.0
	primary.position = rect.position + Vector2(38, primary_y)
	primary.size = Vector2(484, menu_target_height(52))
	if game.state in ["paused", "finished"]:
		secondary.visible = true
		secondary.text = "BACK TO TITLE"
		var secondary_y := 430.0
		if touch_ui_enabled:
			secondary_y = primary_y + menu_target_height(52) + 12.0
		secondary.position = rect.position + Vector2(38, secondary_y)
		secondary.size = Vector2(484, menu_target_height(42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	overlay_draw_active = false

func draw_title_page(rect: Rect2) -> void:
	if retro_layout_active:
		draw_retro_title_page(rect)
		return
	centered("PIPE / ENDLESS" if game.endless_mode else "PIPE / SURVIVAL", rect.position.y + 67, 32)
	centered("TRAILS RECYCLE INSIDE THE SAME CUBE" if game.endless_mode else "SURVIVAL IN A GROWING 3D PIPE MAZE",
		rect.position.y + 96, 14, ACCENT)
	draw_style_box(box(Color("101f31"), 9), Rect2(Vector2(30, 119), Vector2(500, 144)))
	draw_rect(Rect2(Vector2(30, 119), Vector2(3, 144)), ACCENT)
	label_at("HOW TO PLAY", Vector2(48, 144), 13, ACCENT)
	if game.endless_mode:
		centered("Only a dead rider's trail disappears; bots return after a delay.", 171, 17, INK)
		centered("Survivors keep moving; score and streak reset each life.", 196, 15, MUTED)
		if touch_ui_enabled:
			if game.auto_mode:
				centered("VIEW swaps camera  /  PAUSE opens controls", 246, 13, ACCENT)
			else:
				centered("Thumbstick steers  /  Hold BOOST  /  VIEW swaps camera  /  PAUSE", 246, 13, ACCENT)
		elif game.auto_mode:
			centered("Auto respawns  /  F take control  /  C camera  /  Esc pause", 246, 13, ACCENT)
		else:
			centered("WASD steer  /  Shift boost  /  R restart  /  Esc pause", 246, 13, ACCENT)
	else:
		centered("Hit a wall or trail and you're out. Last pipe wins.", 171, 17, INK)
		centered("Steer through open cells; the trail you leave stays behind.", 196, 15, MUTED)
		centered("SCORE   Orbs +25  /  Close pass +15  /  Elimination +100  /  chain to x2.5", 221, 13, MUTED)
		if touch_ui_enabled:
			if game.auto_mode:
				centered("VIEW swaps camera  /  PAUSE opens controls", 246, 13, ACCENT)
			else:
				centered("Thumbstick steers  /  Hold BOOST  /  VIEW swaps camera  /  PAUSE", 246, 13, ACCENT)
		elif game.auto_mode:
			centered("C camera  /  F take control  /  Esc pauses", 246, 13, ACCENT)
		else:
			centered("WASD steer  /  Hold Shift to boost  /  Esc pause", 246, 13, ACCENT)
	var mode_height := menu_target_height(42)
	label_at("MODE", Vector2(38, 292), 13, ACCENT)
	label_at("PLAY OPTIONS", Vector2(202, 292), 13, ACCENT)
	draw_title_mode_controls(rect, 310)
	options_button.visible = true
	bot_looks_button.visible = true
	var options_y := 310.0 + mode_height + 24.0
	var nav_height := menu_target_height(43)
	var primary_y := options_y + nav_height + 24.0
	var summary_y := primary_y + menu_target_height(52) + 29.0
	var nav_buttons := [options_button, bot_looks_button, online_button, controls_button]
	var nav_labels := ["ROUND", "BOT LOOKS", "ONLINE", "CONTROLS"]
	if touch_ui_enabled:
		nav_labels = ["ROUND", "BOTS", "ONLINE", "HELP"]
	for i in range(nav_buttons.size()):
		var nav_button: Button = nav_buttons[i]
		nav_button.visible = true
		nav_button.text = nav_labels[i]
		nav_button.position = rect.position + Vector2(38 + i * 123, options_y)
		nav_button.size = Vector2(115, menu_target_height(43))
	options_button.tooltip_text = "Round setup and pipe appearance"
	controls_button.tooltip_text = "Controls and views"
	primary.visible = true
	primary.text = "ENTER  /  WATCH AUTO MODE" if game.auto_mode else "ENTER  /  START ROUND"
	primary.position = rect.position + Vector2(38, primary_y)
	primary.size = Vector2(484, menu_target_height(52))
	var mode_name := "ENDLESS" if game.endless_mode else "SURVIVAL"
	centered("%s    /    %s    /    %dM CUBE" % [mode_name, player_roster_summary(), game.arena_width], rect.position.y + summary_y, 14, MUTED)

func draw_retro_title_page(rect: Rect2) -> void:
	centered("PIPE", rect.position.y + 96, 68, Color("808080"))
	centered("PIPE", rect.position.y + 90, 68, RETRO_BLACK)
	centered("SURVIVAL", rect.position.y + 139, 31, RETRO_BLACK)
	draw_line(rect.position + Vector2(34, 166), rect.position + Vector2(518, 166), RETRO_DARK, 2.0)
	primary.visible = true
	primary.text = "START GAME"
	primary.position = rect.position + Vector2(38, 194)
	primary.size = Vector2(484, 58)
	var nav_buttons: Array[Button] = [controls_button, options_button, online_button]
	var nav_labels := ["HOW TO PLAY", "OPTIONS...", "ONLINE..."]
	var nav_positions := [Vector2(38, 270), Vector2(38, 336), Vector2(38, 402)]
	for index in range(nav_buttons.size()):
		var button := nav_buttons[index]
		button.visible = true
		button.text = nav_labels[index]
		button.position = rect.position + nav_positions[index]
		button.size = Vector2(484, 52)
	bot_looks_button.visible = false
	exit_button.visible = true
	exit_button.position = rect.position + Vector2(38, 468)
	exit_button.size = Vector2(484, 52)
	label_at("MODE", rect.position + Vector2(38, 554), 13, RETRO_DARK)
	label_at("DRIVING", rect.position + Vector2(202, 554), 13, RETRO_DARK)
	label_at("DISPLAY", rect.position + Vector2(366, 554), 13, RETRO_DARK)
	draw_title_mode_controls(rect, 570)
	centered("%s   /   %dM CUBE" % [player_roster_summary(), game.arena_width], rect.position.y + 650, 14, RETRO_DARK)
	controls_button.tooltip_text = "Controls, views, objective, and scoring"

func draw_online_page(rect: Rect2) -> void:
	primary.visible = false
	secondary.visible = false
	options_button.visible = false
	online_button.visible = false
	controls_button.visible = false
	options_back.visible = false
	mode_toggle.visible = false
	auto_toggle.visible = false
	hud_toggle.visible = false
	centered("ONLINE ROOMS", rect.position.y + 65, 31)
	centered("PUBLIC QUEUE OR A PRIVATE JOIN CODE", rect.position.y + 94, 14, ACCENT)
	centered("Pick a room in one click. Share a private code when you want friends only.",
		rect.position.y + 126, 15, MUTED)
	label_at("PRIVATE CODE (OPTIONAL)", rect.position + Vector2(38, 164), 15, ACCENT)
	online_room_entry.position = rect.position + Vector2(38, 177)
	online_room_entry.size = Vector2(484, menu_target_height(46))
	online_quick_match.visible = true
	online_quick_match.position = rect.position + Vector2(38, 242)
	online_quick_match.size = Vector2(232, menu_target_height(44))
	online_host_public.visible = true
	online_host_public.position = rect.position + Vector2(290, 242)
	online_host_public.size = Vector2(232, menu_target_height(44))
	online_private_join.visible = true
	online_private_join.position = rect.position + Vector2(38, 298)
	online_private_join.size = Vector2(232, menu_target_height(44))
	centered("Quick Match finds the shared room. Host Public opens it for anyone to join.",
		rect.position.y + 366, 14, MUTED)
	var room: Dictionary = game.online_last_state.get("room", {})
	var member_count := int(room.get("human_count", 0))
	var actor_count := int(room.get("actor_target", 32))
	centered("STATUS  /  %s" % game.online_status, rect.position.y + 400, 17,
		ACCENT if game.online_connected else MUTED)
	centered("ROOM  /  %s    PLAYERS  /  %d    ACTORS  /  %d" % [game.online_room_id, member_count, actor_count],
		rect.position.y + 426, 14, MUTED)
	online_join.visible = true
	online_join.text = "DISCONNECT" if game.online_connected else "CONNECT TO ROOM"
	online_join.position = rect.position + Vector2(38, 455)
	online_join.size = Vector2(232, menu_target_height(44))
	online_back.visible = true
	online_back.position = rect.position + Vector2(286, 455)
	online_back.size = Vector2(236, menu_target_height(44))
	online_server_entry.visible = false

func make_private_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var alphabet := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for _i in range(6):
		code += alphabet[rng.randi_range(0, alphabet.length() - 1)]
	return code

func draw_controls_page(rect: Rect2) -> void:
	if retro_layout_active:
		draw_retro_controls_page(rect)
		return
	centered("CONTROLS + VIEWS", rect.position.y + 65, 31)
	centered("EXPLORE THE ARENA YOUR WAY", rect.position.y + 94, 14, ACCENT)
	label_at("KEYBOARD" if touch_ui_enabled else "CAMERA & OVERVIEW",
		rect.position + Vector2(38, 137), 15, ACCENT)
	var view_lines: Array[String]
	var play_lines: Array[String]
	if touch_ui_enabled:
		view_lines = ["WASD  /  steer; Shift  /  boost",
			"C  /  Chase, First Person, Overview",
			"V  /  pipe display; Tab  /  highlight a pipe",
			"Arrows  /  look or orbit; Q / E  /  FOV",
			"Right drag  /  orbit; wheel  /  zoom",
			"F  /  Auto Mode; H  /  hide HUD; Esc  /  pause",
			"R  /  restart; Enter  /  start or replay"]
		play_lines = ["VIEW swaps cameras; PIPES changes display",
			"NEXT highlights a pipe; drag to steer or orbit",
			"Pinch to zoom; hold BOOST; tap PAUSE"]
	else:
		view_lines = ["C  /  Chase, First Person, Overview",
			"V  /  Normal, highlight, bright ends",
			"Tab / Shift+Tab  /  select a spectator target",
			"Arrows look or orbit; right drag orbits overview",
			"Wheel zooms overview; Q / E changes FOV"]
		play_lines = ["WASD steers; hold Shift to boost; R restarts",
			"F toggles Auto Mode; H hides HUD and labels",
			"Esc pauses or resumes"]
	var line_step := 30 if touch_ui_enabled else 27
	for i in range(view_lines.size()):
		label_at(view_lines[i], rect.position + Vector2(38, 164 + i * line_step), 16 if touch_ui_enabled else 17, INK)
	var play_heading_y := 380 if touch_ui_enabled else 325
	label_at("TOUCH CONTROLS" if touch_ui_enabled else "PLAY & DISPLAY",
		rect.position + Vector2(38, play_heading_y), 15, ACCENT)
	for i in range(play_lines.size()):
		label_at(play_lines[i], rect.position + Vector2(38, play_heading_y + 28 + i * line_step),
			16 if touch_ui_enabled else 17, INK)
	options_back.visible = true
	options_back.text = "BACK TO TITLE"
	options_back.position = rect.position + Vector2(38, 447 if not touch_ui_enabled else 488)
	options_back.size = Vector2(484, menu_target_height(44))

func draw_retro_controls_page(rect: Rect2) -> void:
	centered("HOW TO PLAY", rect.position.y + 55, 31, RETRO_BLACK)
	centered("CONTROLS, OBJECTIVE, AND SCORING", rect.position.y + 84, 14, RETRO_BLUE)
	draw_retro_bevel(Rect2(rect.position + Vector2(28, 105), Vector2(498, 260)), true)
	label_at("MOVEMENT", rect.position + Vector2(44, 132), 15, RETRO_BLUE)
	var movement_lines: Array[String] = [
		"W / S pitch; A / D turn.",
		"Hold Shift to boost; release to recharge.",
		"C changes camera; Q / E adjusts field of view.",
		"V changes pipe display; Tab cycles spectator targets.",
		"Arrows orbit or look; right-drag orbits Overview.",
		"Esc pauses; R restarts; F toggles Auto Mode; H hides HUD.",
		"F11 toggles Full Screen; select Display again to restore the window."]
	for index in range(movement_lines.size()):
		label_at(movement_lines[index], rect.position + Vector2(44, 161 + index * 30), 14, RETRO_BLACK)
	draw_retro_bevel(Rect2(rect.position + Vector2(28, 382), Vector2(498, 230)), true)
	label_at("OBJECTIVE + SCORE", rect.position + Vector2(44, 410), 15, RETRO_BLUE)
	label_at("Avoid walls and trails; the last pipe standing wins.", rect.position + Vector2(44, 440), 14, RETRO_BLACK)
	label_at("Orbs award 15, 25, or 50 points; close passes award 15.", rect.position + Vector2(44, 469), 14, RETRO_BLACK)
	label_at("Eliminations award 100; survival time also adds points.", rect.position + Vector2(44, 498), 14, RETRO_BLACK)
	label_at("Chains scale rewards up to x2.5.", rect.position + Vector2(44, 527), 14, RETRO_BLACK)
	label_at("Click an active roster row to follow while spectating.",
		rect.position + Vector2(44, 554), 14, RETRO_BLACK)
	if game.endless_mode:
		label_at("Endless: lost pipes return after a delay; trails recycle.", rect.position + Vector2(44, 581), 14, RETRO_BLACK)
	options_back.visible = true
	options_back.text = "BACK"
	options_back.position = rect.position + Vector2(38, 676)
	options_back.size = Vector2(484, 44)

func draw_title_mode_controls(rect: Rect2, offset_y: float) -> void:
	var width := 156.0
	var gap := 8.0
	var origin := rect.position + Vector2(38, offset_y)
	mode_toggle.text = ("ENDLESS" if game.endless_mode else "SURVIVAL") if touch_ui_enabled else ("MODE / ENDLESS" if game.endless_mode else "MODE / SURVIVAL")
	mode_toggle.position = origin
	mode_toggle.size = Vector2(width, menu_target_height(42))
	auto_toggle.text = "AUTO / %s" % ("ON" if game.auto_mode else "OFF")
	auto_toggle.position = origin + Vector2(width + gap, 0)
	auto_toggle.size = Vector2(width, menu_target_height(42))
	hud_toggle.text = "HUD / %s" % ("ON" if game.hud_enabled else "OFF")
	hud_toggle.visible = false
	full_screen_toggle.text = "FULL SCREEN / %s" % ("ON" if game.is_fullscreen() else "OFF")
	full_screen_toggle.position = origin + Vector2((width + gap) * 2, 0)
	full_screen_toggle.size = Vector2(width, menu_target_height(42))

func draw_options_page(rect: Rect2) -> void:
	centered("BOT LOOKS" if bot_looks_focus else "ROUND OPTIONS", rect.position.y + 64, 31)
	centered("LOCAL BOT COLOR + PATTERN CONTROLS" if bot_looks_focus else "ROUND AND PLAYER SETTINGS",
		rect.position.y + 94, 14, ACCENT)
	centered("Choose colors and pattern mix; Custom unlocks extra options." if bot_looks_focus else
		"Set your pipe and bot looks. Scroll for all appearance options.", rect.position.y + 130, 16, MUTED)
	var name_label_y := 123.0 if not touch_ui_enabled else 144.0
	var name_field_y := 135.0 if not touch_ui_enabled else 160.0
	var color_label_y := 207.0 if not touch_ui_enabled else 253.0
	var color_field_y := 219.0 if not touch_ui_enabled else 269.0
	var layout := options_layout()
	var row_gap: float = layout.row_gap
	var detail_field_y := color_field_y + row_gap
	var material_field_y := color_field_y + row_gap * 2.0
	var preview_y: float = layout.preview_y
	var preview_height: float = layout.preview_height
	var bot_field_y: float = layout.bot_field_y
	var fov_label_y: float = layout.fov_label_y
	var fov_slider_y: float = layout.fov_slider_y
	draw_set_transform(menu_canvas.position + Vector2(options_content.position.x,
		options_content.position.y - options_scroll_offset) * menu_canvas.scale, 0.0, menu_canvas.scale)
	draw_option_label("BOT COUNT", Vector2(38, 40.0 - OPTIONS_VIEW_INSET), 15, MUTED)
	draw_option_label("ARENA SIZE", Vector2(291, 40.0 - OPTIONS_VIEW_INSET), 15, MUTED)
	bot_selector.position = Vector2(38, 52.0 - OPTIONS_VIEW_INSET - options_scroll_offset)
	bot_selector.size = Vector2(231, menu_target_height(46))
	bot_selector.select(bot_selector.get_item_index(game.bot_count))
	size_selector.position = Vector2(291, 52.0 - OPTIONS_VIEW_INSET - options_scroll_offset)
	size_selector.size = Vector2(231, menu_target_height(46))
	size_selector.select(size_selector.get_item_index(game.arena_width))
	draw_option_label("PIPE NAME", Vector2(38, name_label_y - OPTIONS_VIEW_INSET), 15, MUTED)
	if not player_name_entry.has_focus() and player_name_entry.text != game.player_name:
		player_name_entry.text = game.player_name
	player_name_entry.position = Vector2(38, name_field_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	player_name_entry.size = Vector2(484, menu_target_height(46))
	draw_option_label("PRIMARY COLOR", Vector2(38, color_label_y - OPTIONS_VIEW_INSET), 15, MUTED)
	draw_option_label("SECONDARY COLOR", Vector2(291, color_label_y - OPTIONS_VIEW_INSET), 15, MUTED)
	if player_color_picker.color != game.player_color:
		player_color_picker.color = game.player_color
	player_color_picker.position = Vector2(38, color_field_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	player_color_picker.size = Vector2(231, menu_target_height(46))
	player_color_label.position = player_color_picker.position
	player_color_label.size = player_color_picker.size
	var label_color := Color("071d23") if game.player_color.get_luminance() > 0.48 else INK
	player_color_label.add_theme_color_override("font_color", label_color)
	var derived_accent: Color = game.player_color.darkened(0.65) if game.player_color.get_luminance() > 0.3 else game.player_color.lightened(0.65)
	sync_color_picker(secondary_color_picker, game.player_secondary_color if game.player_secondary_color.a > 0.0 else derived_accent)
	secondary_color_picker.position = Vector2(291, color_field_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	secondary_color_picker.size = Vector2(160, menu_target_height(46))
	secondary_auto.position = Vector2(459, color_field_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	secondary_auto.size = Vector2(63, menu_target_height(46))
	secondary_auto.modulate = (RETRO_BLUE if retro_layout_active else ACCENT) \
		if game.player_secondary_color.a <= 0.0 else (RETRO_BLACK if retro_layout_active else INK)
	draw_option_label("DETAIL COLOR", Vector2(38, detail_field_y - 12.0 - OPTIONS_VIEW_INSET), 15, MUTED)
	draw_option_label("PIPE PATTERN", Vector2(291, detail_field_y - 12.0 - OPTIONS_VIEW_INSET), 15, MUTED)
	sync_color_picker(detail_color_picker, game.player_detail_color if game.player_detail_color.a > 0.0 else game.player_color)
	detail_color_picker.position = Vector2(38, detail_field_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	detail_color_picker.size = Vector2(160, menu_target_height(46))
	detail_auto.position = Vector2(206, detail_field_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	detail_auto.size = Vector2(63, menu_target_height(46))
	detail_auto.modulate = (RETRO_BLUE if retro_layout_active else ACCENT) \
		if game.player_detail_color.a <= 0.0 else (RETRO_BLACK if retro_layout_active else INK)
	pattern_selector.position = Vector2(291, detail_field_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	pattern_selector.size = Vector2(231, menu_target_height(46))
	pattern_selector.select(pattern_selector.get_item_index(game.player_pattern))
	draw_option_label("PIPE MATERIAL", Vector2(38, material_field_y - 12.0 - OPTIONS_VIEW_INSET), 15, MUTED)
	draw_option_label("JOINT STYLE", Vector2(291, material_field_y - 12.0 - OPTIONS_VIEW_INSET), 15, MUTED)
	material_selector.position = Vector2(38, material_field_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	material_selector.size = Vector2(231, menu_target_height(46))
	material_selector.select(material_selector.get_item_index(game.player_material))
	joint_selector.position = Vector2(291, material_field_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	joint_selector.size = Vector2(231, menu_target_height(46))
	joint_selector.select(joint_selector.get_item_index(game.player_joint_style))
	pipe_preview.position = Vector2(38, preview_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	pipe_preview.size = Vector2(484, preview_height)
	var preview_content_top := preview_y - OPTIONS_VIEW_INSET
	var preview_top := maxf(preview_content_top, options_scroll_offset)
	var preview_bottom := minf(preview_content_top + pipe_preview.size.y,
		options_scroll_offset + options_content.size.y)
	pipe_preview.visible = not bot_looks_focus and preview_bottom - preview_top >= 30.0
	if pipe_preview.visible:
		var preview_rect := Rect2(Vector2(pipe_preview.position.x, preview_top),
			Vector2(pipe_preview.size.x, preview_bottom - preview_top))
		if retro_layout_active:
			draw_retro_bevel(preview_rect, true)
		else:
			panel(preview_rect, Color("162536"))
	draw_option_label("BOT PALETTE", Vector2(38, bot_field_y - 12.0 - OPTIONS_VIEW_INSET), 15, MUTED)
	draw_option_label("BOT PATTERN MIX", Vector2(291, bot_field_y - 12.0 - OPTIONS_VIEW_INSET), 15, MUTED)
	bot_palette_selector.position = Vector2(38, bot_field_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	bot_palette_selector.size = Vector2(231, menu_target_height(46))
	bot_palette_selector.select(bot_palette_selector.get_item_index(game.bot_palette))
	bot_mix_selector.position = Vector2(291, bot_field_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	bot_mix_selector.size = Vector2(231, menu_target_height(46))
	bot_mix_selector.select(bot_mix_selector.get_item_index(game.bot_pattern_mix))
	draw_option_label("CUSTOM SATURATION", Vector2(38, layout.custom_label_y - OPTIONS_VIEW_INSET), 15, MUTED)
	draw_option_label("CUSTOM BRIGHTNESS", Vector2(291, layout.custom_label_y - OPTIONS_VIEW_INSET), 15, MUTED)
	bot_saturation_slider.position = Vector2(38, layout.custom_slider_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	bot_saturation_slider.size = Vector2(231, menu_target_height(30))
	bot_saturation_slider.set_value_no_signal(game.bot_custom_saturation)
	bot_saturation_slider.editable = game.bot_palette == BotStyle.Palette.CUSTOM
	bot_brightness_slider.position = Vector2(291, layout.custom_slider_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	bot_brightness_slider.size = Vector2(231, menu_target_height(30))
	bot_brightness_slider.set_value_no_signal(game.bot_custom_brightness)
	bot_brightness_slider.editable = game.bot_palette == BotStyle.Palette.CUSTOM
	draw_option_label("CUSTOM BOT PATTERNS", Vector2(38, layout.pattern_label_y - OPTIONS_VIEW_INSET), 15, MUTED)
	for i in range(bot_pattern_checks.size()):
		var check := bot_pattern_checks[i]
		check.position = Vector2(38 + (i % 3) * 163, layout.checks_y + floori(float(i) / 3.0) * layout.check_step - OPTIONS_VIEW_INSET - options_scroll_offset)
		check.size = Vector2(158, menu_target_height(33))
		check.disabled = game.bot_pattern_mix != BotStyle.PatternMix.CUSTOM
		check.set_pressed_no_signal(bool(game.bot_custom_pattern_mask & (1 << i)))
	reduced_glow_toggle.position = Vector2(38, layout.reduced_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	reduced_glow_toggle.size = Vector2(484, menu_target_height(46))
	reduced_glow_toggle.set_pressed_no_signal(game.reduced_glow)
	if not is_equal_approx(fov_slider.value, game.camera.base_fov):
		fov_slider.set_value_no_signal(game.camera.base_fov)
	draw_option_label("FIELD OF VIEW", Vector2(38, fov_label_y - OPTIONS_VIEW_INSET), 15, MUTED)
	draw_option_label("%d°" % roundi(fov_slider.value),
		Vector2(466, fov_label_y - OPTIONS_VIEW_INSET), 15, ACCENT, true)
	fov_slider.position = Vector2(38, fov_slider_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	var slider_height := menu_target_height(22)
	fov_slider.size = Vector2(484, slider_height)
	var rail_position := Vector2(fov_slider.position.x + 8.0,
		fov_slider_y - OPTIONS_VIEW_INSET + slider_height / 2.0)
	var rail_width := fov_slider.size.x - 16
	if rail_position.y >= options_scroll_offset and rail_position.y + 4.0 <= options_scroll_offset + options_content.size.y:
		draw_style_box(box(Color("23384d"), 3), Rect2(rail_position, Vector2(rail_width, 4)))
		var progress := (fov_slider.value - fov_slider.min_value) / (fov_slider.max_value - fov_slider.min_value)
		if progress > 0.0:
			draw_style_box(box(ACCENT.darkened(0.2), 3), Rect2(rail_position, Vector2(rail_width * progress, 4)))
	draw_set_transform(menu_canvas.position, 0.0, menu_canvas.scale)
	options_back.visible = true
	options_back.text = "DONE"
	options_back.position = rect.position + Vector2(38, 676 if retro_layout_active else (716 if touch_ui_enabled else 686))
	options_back.size = Vector2(484, menu_target_height(44))

func draw_option_label(text: String, position: Vector2, size_value: int, color: Color, numeric := false) -> void:
	if position.y < options_scroll_offset or position.y > options_scroll_offset + options_content.size.y - 18.0:
		return
	label_at(text, position, size_value, color, numeric)

func draw_menu_toggles(rect: Rect2, offset_y: float) -> void:
	var width := 156.0
	var gap := 8.0
	var origin := rect.position + Vector2(38, offset_y)
	auto_toggle.text = "AUTO / %s" % ("ON" if game.auto_mode else "OFF")
	auto_toggle.position = origin
	auto_toggle.size = Vector2(width, menu_target_height(42))
	hud_toggle.text = "HUD  /  %s" % ("ON" if game.hud_enabled else "OFF")
	hud_toggle.position = origin + Vector2(width + gap, 0)
	hud_toggle.size = Vector2(width, menu_target_height(42))
	full_screen_toggle.text = "FULL SCREEN / %s" % ("ON" if game.is_fullscreen() else "OFF")
	full_screen_toggle.position = origin + Vector2((width + gap) * 2, 0)
	full_screen_toggle.size = Vector2(width, menu_target_height(42))
