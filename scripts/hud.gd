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
const OPTIONS_VIEW_TOP := 168.0
const OPTIONS_VIEW_INSET := 38.0
const OPTIONS_VIEW_HEIGHT := 500.0
const Appearance = preload("res://scripts/pipe_appearance.gd")
const BotStyle = preload("res://scripts/bot_style.gd")
const PipePreview = preload("res://scripts/pipe_preview.gd")
const Scoring = preload("res://scripts/scoring.gd")
var game: Node
var font := SystemFont.new()
var mono := SystemFont.new()
var primary := Button.new()
var secondary := Button.new()
var options_button := Button.new()
var bot_looks_button := Button.new()
var online_button := Button.new()
var controls_button := Button.new()
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
var mode_toggle := Button.new()
var quick_restart := Button.new()
var menu_canvas := Control.new()
var options_content := Control.new()
var touch_boost := Button.new()
var touch_view := Button.new()
var touch_overview_style := Button.new()
var touch_overview_focus := Button.new()
var touch_pause := Button.new()
var options_open := false
var online_open := false
var controls_open := false
var bot_looks_focus := false
var touch_ui_enabled := false
var overlay_draw_active := false
var touch_draw_active := false
var applied_touch_scale := -1.0
var applied_menu_screen_scale := -1.0
var menu_screen_scale := 1.0
var joystick_touch_index := -1
var joystick_vector := Vector2.ZERO
var joystick_direction := ""
var joystick_pending_direction := ""
var joystick_center_position := Vector2.ZERO
var camera_touch_points: Dictionary = {}
var camera_pinch_distance := 0.0
var options_scroll_offset := 0.0
var options_drag_index := -1
var options_drag_start := Vector2.ZERO
var options_drag_start_scroll := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_ui_enabled = DisplayServer.is_touchscreen_available()
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI"])
	mono.font_names = PackedStringArray(["Consolas"])
	add_child(menu_canvas)
	menu_canvas.add_child(options_content)
	options_content.position = Vector2(0, OPTIONS_VIEW_TOP)
	options_content.size = Vector2(560, OPTIONS_VIEW_HEIGHT)
	options_content.clip_contents = true
	for button in [primary, secondary, options_button, bot_looks_button, online_button, controls_button, options_back,
			online_back, online_join, online_quick_match, online_host_public, online_private_join,
			auto_toggle, hud_toggle, mode_toggle]:
		menu_canvas.add_child(button)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", Color("071d23"))
		button.add_theme_stylebox_override("normal", box(ACCENT, 9))
		button.add_theme_stylebox_override("hover", box(ACCENT.lightened(0.2), 9))
		button.add_theme_stylebox_override("pressed", box(ACCENT.darkened(0.15), 9))
	add_child(quick_restart)
	quick_restart.focus_mode = Control.FOCUS_NONE
	quick_restart.add_theme_font_override("font", font)
	quick_restart.add_theme_font_size_override("font_size", 20)
	quick_restart.add_theme_color_override("font_color", Color("071d23"))
	quick_restart.add_theme_stylebox_override("normal", box(ACCENT, 9))
	quick_restart.add_theme_stylebox_override("hover", box(ACCENT.lightened(0.2), 9))
	quick_restart.add_theme_stylebox_override("pressed", box(ACCENT.darkened(0.15), 9))
	primary.pressed.connect(func(): primary_clicked.emit())
	secondary.pressed.connect(func(): secondary_clicked.emit())
	quick_restart.pressed.connect(func(): quick_restart_clicked.emit())
	for button in [secondary, options_button, bot_looks_button, online_button, controls_button, options_back, online_back]:
		button.add_theme_color_override("font_color", MUTED)
		button.add_theme_stylebox_override("normal", box(Color("162536"), 9))
		button.add_theme_stylebox_override("hover", box(Color("23384d"), 9))
	options_button.text = "GAME OPTIONS"
	options_button.pressed.connect(func():
		options_open = true
		online_open = false
		controls_open = false
		bot_looks_focus = false
		options_scroll_offset = 0.0)
	bot_looks_button.text = "BOT LOOKS"
	bot_looks_button.tooltip_text = "Set local bot colors and patterns"
	bot_looks_button.pressed.connect(func():
		options_open = true
		online_open = false
		controls_open = false
		bot_looks_focus = true
		var bot_field_y: float = options_layout().bot_field_y
		options_scroll_offset = clampf(bot_field_y - OPTIONS_VIEW_INSET - 24.0,
			0.0, options_max_scroll()))
	online_button.text = "ONLINE"
	online_button.pressed.connect(func():
		online_open = true
		options_open = false
		controls_open = false)
	controls_button.text = "CONTROLS + VIEWS"
	controls_button.pressed.connect(func():
		controls_open = true
		online_open = false
		options_open = false)
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
	auto_toggle.add_theme_color_override("font_color", MUTED)
	auto_toggle.add_theme_color_override("font_pressed_color", Color("071d23"))
	auto_toggle.add_theme_stylebox_override("normal", box(Color("23384d"), 9))
	auto_toggle.add_theme_stylebox_override("hover", box(Color("30485c"), 9))
	auto_toggle.toggled.connect(func(enabled: bool): game.set_auto_mode(enabled))
	hud_toggle.toggle_mode = true
	hud_toggle.add_theme_color_override("font_color", MUTED)
	hud_toggle.add_theme_color_override("font_pressed_color", Color("071d23"))
	hud_toggle.add_theme_stylebox_override("normal", box(Color("23384d"), 9))
	hud_toggle.add_theme_stylebox_override("hover", box(Color("30485c"), 9))
	hud_toggle.toggled.connect(func(enabled: bool): game.set_hud_enabled(enabled))
	for toggle in [auto_toggle, hud_toggle]:
		toggle.add_theme_font_size_override("font_size", 18)
	mode_toggle.toggle_mode = true
	mode_toggle.add_theme_font_size_override("font_size", 15)
	mode_toggle.add_theme_color_override("font_color", MUTED)
	mode_toggle.add_theme_color_override("font_pressed_color", Color("071d23"))
	mode_toggle.add_theme_stylebox_override("normal", box(Color("23384d"), 9))
	mode_toggle.add_theme_stylebox_override("hover", box(Color("30485c"), 9))
	mode_toggle.toggled.connect(func(enabled: bool): game.set_endless_mode(enabled))
	quick_restart.text = "RESTART PIPE"
	quick_restart.add_theme_font_size_override("font_size", 17)
	options_content.add_child(bot_selector)
	for count in [7, 15, 23, 31]:
		bot_selector.add_item("%d BOTS" % count, count)
	bot_selector.select(1)
	bot_selector.focus_mode = Control.FOCUS_NONE
	bot_selector.add_theme_font_override("font", font)
	bot_selector.add_theme_font_size_override("font_size", 18)
	var selector_normal := box(Color("23384d"), 7)
	selector_normal.content_margin_left = 12
	selector_normal.content_margin_right = 10
	var selector_hover := box(Color("30485c"), 7)
	selector_hover.content_margin_left = 12
	selector_hover.content_margin_right = 10
	bot_selector.add_theme_stylebox_override("normal", selector_normal)
	bot_selector.add_theme_stylebox_override("hover", selector_hover)
	bot_selector.item_selected.connect(func(index: int):
		game.bot_count = bot_selector.get_item_id(index)
		game.show_title())
	options_content.add_child(size_selector)
	for width in [40, 60, 80, 100]:
		size_selector.add_item("%d x %d x %d" % [width, width, width], width)
	size_selector.select(1)
	size_selector.focus_mode = Control.FOCUS_NONE
	size_selector.add_theme_font_override("font", font)
	size_selector.add_theme_font_size_override("font_size", 18)
	var size_selector_normal := box(Color("23384d"), 7)
	size_selector_normal.content_margin_left = 12
	size_selector_normal.content_margin_right = 10
	var size_selector_hover := box(Color("30485c"), 7)
	size_selector_hover.content_margin_left = 12
	size_selector_hover.content_margin_right = 10
	size_selector.add_theme_stylebox_override("normal", size_selector_normal)
	size_selector.add_theme_stylebox_override("hover", size_selector_hover)
	size_selector.item_selected.connect(func(index: int):
		game.arena_width = size_selector.get_item_id(index)
		game.show_title())
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
	player_name_entry.add_theme_color_override("font_color", INK)
	player_name_entry.add_theme_color_override("font_placeholder_color", MUTED)
	player_name_entry.add_theme_stylebox_override("normal", box(Color("23384d"), 7))
	player_name_entry.add_theme_stylebox_override("focus", box(Color("30485c"), 7))
	player_name_entry.text = "YOU"
	player_name_entry.text_changed.connect(func(value: String): game.player_name = clean_player_name(value))
	menu_canvas.add_child(online_server_entry)
	online_server_entry.placeholder_text = "WebSocket server URL"
	online_server_entry.text = "wss://pipe-survival.onrender.com"
	online_server_entry.max_length = 160
	online_server_entry.add_theme_font_override("font", font)
	online_server_entry.add_theme_font_size_override("font_size", 18)
	online_server_entry.add_theme_color_override("font_color", INK)
	online_server_entry.add_theme_color_override("font_placeholder_color", MUTED)
	online_server_entry.add_theme_stylebox_override("normal", box(Color("23384d"), 7))
	online_server_entry.add_theme_stylebox_override("focus", box(Color("30485c"), 7))
	menu_canvas.add_child(online_room_entry)
	online_room_entry.placeholder_text = "PUBLIC or private room code"
	online_room_entry.text = "PUBLIC"
	online_room_entry.max_length = 12
	online_room_entry.add_theme_font_override("font", font)
	online_room_entry.add_theme_font_size_override("font_size", 18)
	online_room_entry.add_theme_color_override("font_color", INK)
	online_room_entry.add_theme_color_override("font_placeholder_color", MUTED)
	online_room_entry.add_theme_stylebox_override("normal", box(Color("23384d"), 7))
	online_room_entry.add_theme_stylebox_override("focus", box(Color("30485c"), 7))
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
		picker.add_theme_stylebox_override("normal", box(Color("23384d"), 7))
		picker.add_theme_stylebox_override("hover", box(Color("30485c"), 7))
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
		button.add_theme_color_override("font_color", INK)
		button.add_theme_stylebox_override("normal", box(Color("23384d"), 7))
		button.add_theme_stylebox_override("hover", box(Color("30485c"), 7))
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
	joint_selector.item_selected.connect(func(index: int):
		game.player_joint_style = joint_selector.get_item_id(index))
	for selector in [bot_palette_selector, bot_mix_selector]:
		options_content.add_child(selector)
		selector.focus_mode = Control.FOCUS_NONE
		selector.add_theme_font_override("font", font)
		selector.add_theme_font_size_override("font_size", 18)
		selector.add_theme_stylebox_override("normal", selector_normal)
		selector.add_theme_stylebox_override("hover", selector_hover)
	for i in range(BotStyle.PALETTE_NAMES.size()):
		bot_palette_selector.add_item(BotStyle.PALETTE_NAMES[i], i)
	for i in range(BotStyle.MIX_NAMES.size()):
		bot_mix_selector.add_item(BotStyle.MIX_NAMES[i], i)
	bot_palette_selector.item_selected.connect(func(index: int):
		game.bot_palette = bot_palette_selector.get_item_id(index)
		game.show_title())
	bot_mix_selector.item_selected.connect(func(index: int):
		game.bot_pattern_mix = bot_mix_selector.get_item_id(index)
		game.show_title())
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
			game.show_title())
	bot_brightness_slider.value_changed.connect(func(value: float):
		game.bot_custom_brightness = value
		if game.bot_palette == BotStyle.Palette.CUSTOM:
			game.show_title())
	for i in range(Appearance.NAMES.size()):
		var check := CheckBox.new()
		check.text = Appearance.NAMES[i]
		check.button_pressed = true
		check.focus_mode = Control.FOCUS_NONE
		check.add_theme_font_override("font", font)
		check.add_theme_font_size_override("font_size", 15)
		check.add_theme_color_override("font_color", INK)
		options_content.add_child(check)
		bot_pattern_checks.append(check)
		check.toggled.connect(func(enabled: bool): set_custom_bot_pattern(i, enabled))
	options_content.add_child(reduced_glow_toggle)
	reduced_glow_toggle.text = "REDUCED GLOW"
	reduced_glow_toggle.focus_mode = Control.FOCUS_NONE
	reduced_glow_toggle.add_theme_font_override("font", font)
	reduced_glow_toggle.add_theme_font_size_override("font_size", 17)
	reduced_glow_toggle.add_theme_color_override("font_color", INK)
	reduced_glow_toggle.toggled.connect(func(enabled: bool):
		game.reduced_glow = enabled
		game.show_title())
	pipe_preview.visible = false
	options_content.add_child(pipe_preview)
	build_touch_controls()

static func box(color: Color, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style

func build_touch_controls() -> void:
	configure_touch_button(touch_boost, "BOOST\n100%", 17)
	touch_boost.add_theme_stylebox_override("normal", box(Color("14757d"), 24))
	touch_boost.add_theme_stylebox_override("hover", box(Color("19949b"), 24))
	touch_boost.add_theme_stylebox_override("pressed", box(Color("27b9b0"), 24))
	touch_boost.button_down.connect(func(): touch_boost_changed.emit(true))
	touch_boost.button_up.connect(func(): touch_boost_changed.emit(false))
	add_child(touch_boost)
	configure_touch_button(touch_view, "VIEW", 14)
	touch_view.add_theme_stylebox_override("normal", box(Color("123b47", 0.94), 14))
	touch_view.add_theme_stylebox_override("hover", box(Color("1b5860", 0.98), 14))
	touch_view.add_theme_stylebox_override("pressed", box(Color("287f86"), 14))
	touch_view.pressed.connect(func(): touch_view_requested.emit())
	add_child(touch_view)
	configure_touch_button(touch_overview_style, "PIPES / NORMAL", 12)
	touch_overview_style.pressed.connect(func(): touch_overview_style_requested.emit())
	add_child(touch_overview_style)
	configure_touch_button(touch_overview_focus, "NEXT / YOU", 12)
	touch_overview_focus.pressed.connect(func(): touch_overview_focus_requested.emit())
	add_child(touch_overview_focus)
	configure_touch_button(touch_pause, "PAUSE", 14)
	touch_pause.pressed.connect(func(): touch_pause_requested.emit())
	add_child(touch_pause)

func configure_touch_button(button: Button, title: String, font_size: int) -> void:
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_stylebox_override("normal", box(Color(0.035, 0.075, 0.11, 0.82), 12))
	button.add_theme_stylebox_override("hover", box(Color(0.09, 0.18, 0.23, 0.94), 12))
	button.add_theme_stylebox_override("pressed", box(Color("287f86"), 12))

func ui_scale_factor() -> float:
	if not touch_ui_enabled:
		return 1.0
	var canvas_scale := get_viewport().get_stretch_transform().get_scale().x
	var display_scale := maxf(DisplayServer.screen_get_scale(), 1.0)
	return display_scale / maxf(canvas_scale, 0.01)

func screen_size() -> Vector2:
	return size / ui_scale_factor()

func touch_joystick_center() -> Vector2:
	if joystick_touch_index != -1:
		return joystick_center_position
	var available := screen_size()
	return Vector2(120.0, available.y - 108.0)

func touch_control_scale() -> float:
	var available := screen_size()
	return clampf(minf(available.x / 420.0, available.y / 620.0), 0.72, 1.0)

func update_touch_joystick(position: Vector2) -> void:
	var factor := ui_scale_factor()
	var displacement := position - touch_joystick_center() * factor
	var radius := 66.0 * touch_control_scale() * factor
	var distance := displacement.length()
	joystick_vector = displacement.limit_length(radius) / radius
	if distance < 12.0 * touch_control_scale() * factor:
		joystick_direction = ""
		joystick_pending_direction = ""
		queue_redraw()
		return
	var direction := ""
	if absf(displacement.x) > absf(displacement.y):
		direction = "right" if displacement.x > 0.0 else "left"
	else:
		direction = "down" if displacement.y > 0.0 else "up"
	if direction != joystick_direction:
		joystick_direction = direction
		if game.turn_queue.size() >= 2:
			joystick_pending_direction = direction
		else:
			joystick_pending_direction = ""
			touch_turn_requested.emit(direction)
	queue_redraw()

func release_touch_joystick() -> void:
	joystick_touch_index = -1
	joystick_vector = Vector2.ZERO
	joystick_direction = ""
	joystick_pending_direction = ""
	joystick_center_position = Vector2.ZERO
	queue_redraw()

func touch_camera_active() -> bool:
	return game != null and touch_ui_enabled and game.state in ["playing", "countdown", "paused"] \
		and game.crash_view_time <= 0.0

func touch_steering_zone(position: Vector2) -> bool:
	return game != null and not game.auto_mode and game.sim.riders[game.player_rider_id()].alive \
		and position.x <= size.x * 0.5 and position.y >= size.y * 0.42

func touch_camera_control_at(position: Vector2) -> bool:
	for button in [touch_boost, touch_view, touch_overview_style, touch_overview_focus, touch_pause]:
		if button.visible and button.get_global_rect().has_point(position):
			return true
	return false

func update_touch_camera_gesture(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not event.pressed:
			if camera_touch_points.has(event.index):
				camera_touch_points.erase(event.index)
				camera_pinch_distance = touch_camera_points_distance()
			return
		if not touch_camera_active() or touch_camera_control_at(event.position) \
				or (touch_steering_zone(event.position) and camera_touch_points.is_empty()):
			return
		camera_touch_points[event.index] = event.position
		camera_pinch_distance = touch_camera_points_distance()
	elif event is InputEventScreenDrag and camera_touch_points.has(event.index):
		if not touch_camera_active():
			camera_touch_points.erase(event.index)
			camera_pinch_distance = touch_camera_points_distance()
			return
		camera_touch_points[event.index] = event.position
		if camera_touch_points.size() >= 2:
			var next_distance := touch_camera_points_distance()
			if camera_pinch_distance > 0.0:
				touch_camera_zoom_requested.emit(next_distance - camera_pinch_distance)
			camera_pinch_distance = next_distance
		else:
			touch_camera_orbit_requested.emit(event.relative)

func touch_camera_points_distance() -> float:
	if camera_touch_points.size() < 2:
		return 0.0
	var points: Array = camera_touch_points.values()
	var first_point: Vector2 = points[0]
	var second_point: Vector2 = points[1]
	return first_point.distance_to(second_point)

func fit_menu(panel_height: float) -> void:
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
	return 560.0 if touch_ui_enabled else 520.0

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
	if not overlay_draw_active or not touch_ui_enabled:
		return base_size
	var draw_font := mono if numeric else font
	var font_size := menu_control_font_size(base_size)
	var text_width := draw_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if text_width > max_width:
		font_size = maxi(1, floori(float(font_size) * max_width / text_width))
	return font_size

func update_touch_scale(factor: float) -> void:
	if is_equal_approx(applied_touch_scale, factor):
		return
	applied_touch_scale = factor
	touch_boost.add_theme_font_size_override("font_size", roundi(17.0 * factor))
	touch_view.add_theme_font_size_override("font_size", roundi(14.0 * factor))
	touch_overview_style.add_theme_font_size_override("font_size", roundi(12.0 * factor))
	touch_overview_focus.add_theme_font_size_override("font_size", roundi(12.0 * factor))
	touch_pause.add_theme_font_size_override("font_size", roundi(14.0 * factor))
	quick_restart.add_theme_font_size_override("font_size", roundi(17.0 * factor))

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not touch_ui_enabled:
		touch_ui_enabled = true
		if game != null:
			game.update_hud_visibility()
		queue_redraw()
	update_touch_camera_gesture(event)
	if game != null and touch_ui_enabled and game.state in ["playing", "countdown"] \
			and not game.auto_mode and game.sim.riders[game.player_rider_id()].alive:
		if event is InputEventScreenTouch:
			if event.pressed and joystick_touch_index == -1 \
					and camera_touch_points.is_empty() and touch_steering_zone(event.position):
				joystick_touch_index = event.index
				joystick_center_position = event.position / ui_scale_factor()
				update_touch_joystick(event.position)
				get_viewport().set_input_as_handled()
			elif not event.pressed and event.index == joystick_touch_index:
				release_touch_joystick()
				get_viewport().set_input_as_handled()
		elif event is InputEventScreenDrag and event.index == joystick_touch_index:
			update_touch_joystick(event.position)
			get_viewport().set_input_as_handled()
	elif joystick_touch_index != -1:
		release_touch_joystick()
	if not options_open or game == null or game.state != "ready":
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
		game.show_title()

func sync_color_picker(picker: ColorPickerButton, color: Color) -> void:
	if picker.color == color:
		return
	picker.set_block_signals(true)
	picker.color = color
	picker.set_block_signals(false)

func close_menu_page() -> void:
	if controls_open:
		controls_open = false
	else:
		finish_options()

func label_at(text: String, location: Vector2, size_value: int = 18, color: Color = INK, numeric: bool = false) -> void:
	var max_width := 560.0 - location.x - 20.0 if overlay_draw_active else -1.0
	var draw_size := menu_text_font_size(text, size_value, max_width, numeric)
	draw_string(mono if numeric else font, location, text, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, color)

func centered(text: String, y: float, size_value: int, color: Color = INK) -> void:
	var draw_size := menu_text_font_size(text, size_value, 512.0, false)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size).x
	var anchor_x := size.x / 2.0
	if overlay_draw_active:
		anchor_x = 280.0
	elif touch_draw_active:
		anchor_x = screen_size().x / 2.0
	draw_string(font, Vector2(anchor_x - width / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, color)

func panel(rect: Rect2, color: Color = Color(0.025, 0.055, 0.095, 0.9)) -> void:
	draw_style_box(box(color), rect)

func _process(_delta: float) -> void:
	if game != null:
		if joystick_pending_direction != "" and joystick_touch_index != -1 \
				and game.state in ["playing", "countdown"] and not game.auto_mode \
				and game.sim.riders[game.player_rider_id()].alive and game.turn_queue.size() < 2:
			var pending_direction := joystick_pending_direction
			joystick_pending_direction = ""
			touch_turn_requested.emit(pending_direction)
		if game.state != "ready":
			options_open = false
			online_open = false
			controls_open = false
			bot_looks_focus = false
		options_content.size = Vector2(560, 530.0 if touch_ui_enabled else OPTIONS_VIEW_HEIGHT)
		fit_menu(overlay_panel_height())
		options_scroll_offset = clampf(options_scroll_offset, 0.0, options_max_scroll())
		primary.visible = game.state in ["ready", "paused", "finished"] and not (game.state == "ready" and (options_open or online_open or controls_open))
		secondary.visible = game.state in ["paused", "finished"]
		options_button.visible = game.state == "ready" and not options_open and not online_open and not controls_open
		bot_looks_button.visible = game.state == "ready" and not options_open and not online_open and not controls_open
		online_button.visible = game.state == "ready" and not options_open and not online_open and not controls_open
		controls_button.visible = game.state == "ready" and not options_open and not online_open and not controls_open
		options_back.visible = game.state == "ready" and (options_open or controls_open)
		online_back.visible = game.state == "ready" and online_open
		online_join.visible = game.state == "ready" and online_open
		online_quick_match.visible = game.state == "ready" and online_open
		online_host_public.visible = game.state == "ready" and online_open
		online_private_join.visible = game.state == "ready" and online_open
		mode_toggle.visible = game.state == "ready" and not options_open and not online_open and not controls_open
		mode_toggle.set_pressed_no_signal(game.endless_mode)
		quick_restart.visible = game.state == "playing" and not game.sim.riders[game.player_rider_id()].alive and (game.endless_mode or (touch_ui_enabled and not game.online_mode))
		if game.player_respawn_pending:
			quick_restart.text = "RESPAWNING..." if game.auto_mode and not game.online_mode else "WAITING FOR SPACE"
		elif game.online_mode:
			quick_restart.text = "RESPAWN PIPE"
		else:
			quick_restart.text = "RESTART PIPE" if game.endless_mode else "RESTART ROUND"
		quick_restart.disabled = game.player_respawn_pending
		var ui_factor := ui_scale_factor()
		var available := screen_size()
		var touch_scale := touch_control_scale()
		update_touch_scale(ui_factor * touch_scale)
		quick_restart.position = Vector2((available.x - 228.0) / 2.0, (available.y - 44.0) / 2.0 if touch_ui_enabled else available.y - 145.0) * ui_factor
		quick_restart.size = Vector2(228, 44) * ui_factor
		options_content.visible = game.state == "ready" and options_open
		online_server_entry.visible = false
		online_room_entry.visible = game.state == "ready" and online_open
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
		hud_toggle.visible = game.state in ["ready", "paused", "finished"] and not (game.state == "ready" and (options_open or controls_open))
		hud_toggle.set_pressed_no_signal(game.hud_enabled)
		var steer_visible: bool = touch_ui_enabled and game.state in ["playing", "countdown"] and not game.auto_mode and game.sim.riders[game.player_rider_id()].alive
		var touch_active: bool = touch_ui_enabled and game.state in ["playing", "countdown"]
		var overview_active: bool = touch_active and game.camera.overview and game.crash_view_time <= 0.0
		if not steer_visible and joystick_touch_index != -1:
			release_touch_joystick()
		touch_boost.visible = steer_visible
		touch_boost.position = Vector2(available.x - 172 * touch_scale, available.y - 118 * touch_scale) * ui_factor
		touch_boost.size = Vector2(152, 96) * touch_scale * ui_factor
		if not game.sim.riders.is_empty():
			touch_boost.text = "BOOST\n%d%%" % roundi(game.sim.riders[game.player_rider_id()].pressure * 100.0)
		touch_view.visible = touch_active
		touch_view.position = Vector2(available.x - 128 * touch_scale, 124 * touch_scale) * ui_factor
		touch_view.size = Vector2(120, 48) * touch_scale * ui_factor
		touch_overview_style.visible = overview_active
		touch_overview_style.position = Vector2(available.x - 168 * touch_scale, 180 * touch_scale) * ui_factor
		touch_overview_style.size = Vector2(160, 48) * touch_scale * ui_factor
		touch_overview_style.text = "PIPES / " + game.overview_style_name()
		touch_overview_focus.visible = overview_active
		touch_overview_focus.position = Vector2(available.x - 168 * touch_scale, 236 * touch_scale) * ui_factor
		touch_overview_focus.size = Vector2(160, 48) * touch_scale * ui_factor
		var focus_name: String = game.sim.rider_name(game.overview_focus_id).to_upper()
		if focus_name.length() > 10:
			focus_name = focus_name.left(9) + "…"
		touch_overview_focus.text = "NEXT / " + focus_name
		touch_pause.visible = touch_active
		touch_pause.position = Vector2(available.x - 82 * touch_scale, 16 * touch_scale) * ui_factor
		touch_pause.size = Vector2(72, 48) * touch_scale * ui_factor
	queue_redraw()

func _draw() -> void:
	if game == null or game.sim.riders.is_empty():
		return
	if game.state in ["ready", "paused"] or (game.state == "finished" and game.crash_view_time <= 0.0):
		draw_overlay()
		return
	if not game.hud_enabled and not touch_ui_enabled:
		draw_collision_feedback()
		return
	if touch_ui_enabled:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui_scale_factor())
		touch_draw_active = true
		if game.hud_enabled:
			draw_touch_game_hud()
		if game.state in ["playing", "countdown"] and not game.auto_mode and game.sim.riders[game.player_rider_id()].alive:
			draw_touch_joystick()
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

func draw_touch_joystick() -> void:
	var center := touch_joystick_center()
	var control_scale := touch_control_scale()
	var radius := 70.0 * control_scale
	var knob_position := center + joystick_vector * 38.0 * control_scale
	draw_circle(center, radius, Color(0.025, 0.065, 0.095, 0.76))
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.32, 0.73, 0.78, 0.88), 3.0 * control_scale, true)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + direction * 45.0 * control_scale,
			center + direction * 54.0 * control_scale,
			Color(0.55, 0.76, 0.79, 0.64), 2.0 * control_scale, true)
	draw_circle(knob_position, 29.0 * control_scale, Color(0.12, 0.34, 0.4, 0.98))
	draw_arc(knob_position, 29.0 * control_scale, 0.0, TAU, 48, ACCENT, 2.5 * control_scale, true)

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
	var age: float = game.COLLISION_FEEDBACK_DURATION - game.collision_feedback_time
	var flash := clampf(1.0 - age / 0.14, 0.0, 1.0)
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, bounds), Color(1.0, 0.26, 0.045, flash * 0.16))
	var point: Vector2 = game.camera.unproject_position(game.collision_position)
	if touch_draw_active:
		point /= ui_scale_factor()
	if not game.camera.is_position_behind(game.collision_position) and Rect2(Vector2.ZERO, bounds).grow(48.0).has_point(point):
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
	centered(game.collision_feedback_label, bounds.y * 0.69, 20, Color("ffcf83"))

func draw_overlay() -> void:
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
	centered("PIPE / ENDLESS" if game.endless_mode else "PIPE / SURVIVAL", rect.position.y + 74, 32)
	centered("TRAILS RECYCLE INSIDE THE SAME CUBE" if game.endless_mode else "SURVIVAL IN A GROWING 3D PIPE MAZE",
		rect.position.y + 104, 14, ACCENT)
	var lines: Array[String]
	if game.endless_mode:
		lines = ["Finite cube; only the dead rider's trail disappears.",
			"Bots return after a delay while other pipes keep moving.",
			"Each life starts with a fresh score and survival streak."]
		if touch_ui_enabled:
			lines.append("Thumbstick steers / hold BOOST / VIEW swaps camera / PAUSE.")
		elif game.auto_mode:
			lines.append("Auto respawns / F take control / C camera / Esc pause.")
		else:
			lines.append("WASD steer / Shift boost / R restart / Esc pause.")
	else:
		lines = ["Steer through the cube; the trail you leave stays behind.",
			"Orbs +25  /  close passes +15  /  eliminations +100  /  chain to x2.5.",
		"Crash into walls or trails and you're out. Last pipe wins."]
		if touch_ui_enabled:
			lines.append("Tap VIEW to swap camera / PAUSE for controls." if game.auto_mode else "Thumbstick steers / hold BOOST / tap VIEW or PAUSE.")
		elif game.auto_mode:
			lines.append("C camera / F take control / Esc pauses.")
		else:
			lines.append("WASD steer / hold Shift to boost / Esc pause.")
	for i in range(lines.size()):
		centered(lines[i], rect.position.y + 151 + i * 27, 17, MUTED)
	var mode_height := menu_target_height(42)
	draw_title_mode_controls(rect, 270)
	options_button.visible = true
	bot_looks_button.visible = true
	var options_y := 330.0
	var primary_y := 389.0
	var summary_y := 486.0
	if touch_ui_enabled:
		options_y = 270.0 + mode_height + 12.0
		primary_y = options_y + menu_target_height(43) + 12.0
		summary_y = primary_y + menu_target_height(52) + 24.0
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
	centered("%s    /    YOU + %d BOTS    /    %dM CUBE" % [mode_name, game.bot_count, game.arena_width], rect.position.y + summary_y, 14, MUTED)

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
			"Tab / Shift+Tab  /  Highlight another pipe",
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

func draw_title_mode_controls(rect: Rect2, offset_y: float) -> void:
	var width := 156.0
	var gap := 8.0
	var origin := Vector2(38, offset_y)
	mode_toggle.text = ("ENDLESS" if game.endless_mode else "SURVIVAL") if touch_ui_enabled else ("MODE / ENDLESS" if game.endless_mode else "MODE / SURVIVAL")
	mode_toggle.position = origin
	mode_toggle.size = Vector2(width, menu_target_height(42))
	auto_toggle.text = "AUTO / %s" % ("ON" if game.auto_mode else "OFF")
	auto_toggle.position = origin + Vector2(width + gap, 0)
	auto_toggle.size = Vector2(width, menu_target_height(42))
	hud_toggle.text = "HUD / %s" % ("ON" if game.hud_enabled else "OFF")
	hud_toggle.position = origin + Vector2((width + gap) * 2, 0)
	hud_toggle.size = Vector2(width, menu_target_height(42))

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
	draw_set_transform(menu_canvas.position + Vector2(0, (OPTIONS_VIEW_TOP - options_scroll_offset) * menu_canvas.scale.y),
		0.0, menu_canvas.scale)
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
	secondary_auto.modulate = ACCENT if game.player_secondary_color.a <= 0.0 else INK
	draw_option_label("DETAIL COLOR", Vector2(38, detail_field_y - 12.0 - OPTIONS_VIEW_INSET), 15, MUTED)
	draw_option_label("PIPE PATTERN", Vector2(291, detail_field_y - 12.0 - OPTIONS_VIEW_INSET), 15, MUTED)
	sync_color_picker(detail_color_picker, game.player_detail_color if game.player_detail_color.a > 0.0 else game.player_color)
	detail_color_picker.position = Vector2(38, detail_field_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	detail_color_picker.size = Vector2(160, menu_target_height(46))
	detail_auto.position = Vector2(206, detail_field_y - OPTIONS_VIEW_INSET - options_scroll_offset)
	detail_auto.size = Vector2(63, menu_target_height(46))
	detail_auto.modulate = ACCENT if game.player_detail_color.a <= 0.0 else INK
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
		panel(Rect2(Vector2(pipe_preview.position.x, preview_top),
			Vector2(pipe_preview.size.x, preview_bottom - preview_top)), Color("162536"))
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
	options_back.position = Vector2(38, 716 if touch_ui_enabled else 686)
	options_back.size = Vector2(484, menu_target_height(44))
	if not touch_ui_enabled:
		centered("PLAYING AS %s  /  %d BOTS  /  %dm CUBE" % [game.player_name, game.bot_count, game.arena_width], rect.position.y + 744.0, 14, MUTED)

func draw_option_label(text: String, position: Vector2, size_value: int, color: Color, numeric := false) -> void:
	if position.y < options_scroll_offset or position.y > options_scroll_offset + options_content.size.y - 18.0:
		return
	label_at(text, position, size_value, color, numeric)

func draw_menu_toggles(rect: Rect2, offset_y: float) -> void:
	auto_toggle.text = ("AUTO / %s" % ("ON" if game.auto_mode else "OFF")) if touch_ui_enabled else ("AUTO MODE  /  %s" % ("ON" if game.auto_mode else "OFF"))
	auto_toggle.position = Vector2(38, offset_y)
	auto_toggle.size = Vector2(231, menu_target_height(42))
	hud_toggle.text = "HUD  /  %s" % ("ON" if game.hud_enabled else "OFF")
	hud_toggle.position = Vector2(291, offset_y)
	hud_toggle.size = Vector2(231, menu_target_height(42))
