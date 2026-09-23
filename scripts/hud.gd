extends Control

signal primary_clicked
signal secondary_clicked
signal quick_restart_clicked
signal touch_turn_requested(command: String)
signal touch_boost_changed(held: bool)
signal touch_pause_requested
const INK := Color("e8f2f5")
const MUTED := Color("8da4b8")
const ACCENT := Color("56eddf")
const PLAYER_COLOR := Color("56eddf")
const Appearance = preload("res://scripts/pipe_appearance.gd")
const PipePreview = preload("res://scripts/pipe_preview.gd")
var game: Node
var font := SystemFont.new()
var mono := SystemFont.new()
var primary := Button.new()
var secondary := Button.new()
var options_button := Button.new()
var options_back := Button.new()
var bot_selector := OptionButton.new()
var size_selector := OptionButton.new()
var fov_slider := HSlider.new()
var player_name_entry := LineEdit.new()
var player_color_picker := ColorPickerButton.new()
var player_color_label := Label.new()
var pattern_selector := OptionButton.new()
var pipe_preview := PipePreview.new()
var auto_toggle := Button.new()
var hud_toggle := Button.new()
var mode_toggle := Button.new()
var quick_restart := Button.new()
var menu_canvas := Control.new()
var options_content := Control.new()
var touch_directions: Array[Button] = []
var touch_boost := Button.new()
var touch_pause := Button.new()
var options_open := false
var touch_ui_enabled := false
var overlay_draw_active := false
var touch_draw_active := false
var applied_touch_scale := -1.0
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
	options_content.position = Vector2(0, 130)
	options_content.size = Vector2(560, 360)
	options_content.clip_contents = true
	for button in [primary, secondary, options_button, options_back, auto_toggle, hud_toggle, mode_toggle]:
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
	for button in [secondary, options_button, options_back]:
		button.add_theme_color_override("font_color", MUTED)
		button.add_theme_stylebox_override("normal", box(Color("162536"), 9))
		button.add_theme_stylebox_override("hover", box(Color("23384d"), 9))
	options_button.text = "GAME OPTIONS"
	options_button.pressed.connect(func():
		options_open = true
		options_scroll_offset = 0.0)
	options_back.text = "DONE"
	options_back.pressed.connect(finish_options)
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
	options_content.add_child(player_color_picker)
	player_color_picker.color = PLAYER_COLOR
	player_color_picker.edit_alpha = false
	player_color_picker.tooltip_text = "Choose the color for your pipe"
	player_color_picker.focus_mode = Control.FOCUS_NONE
	player_color_picker.add_theme_stylebox_override("normal", box(PLAYER_COLOR, 7))
	player_color_picker.add_theme_stylebox_override("hover", box(PLAYER_COLOR.lightened(0.2), 7))
	player_color_picker.color_changed.connect(func(value: Color): game.player_color = value)
	options_content.add_child(player_color_label)
	player_color_label.text = "CHANGE COLOR"
	player_color_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_color_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player_color_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_color_label.add_theme_font_override("font", font)
	player_color_label.add_theme_font_size_override("font_size", 16)
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
	pipe_preview.visible = false
	options_content.add_child(pipe_preview)
	build_touch_controls()

static func box(color: Color, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style

func build_touch_controls() -> void:
	for direction in ["up", "left", "down", "right"]:
		var button := Button.new()
		button.text = direction.to_upper()
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_color_override("font_color", INK)
		button.add_theme_stylebox_override("normal", box(Color(0.035, 0.075, 0.11, 0.8), 12))
		button.add_theme_stylebox_override("hover", box(Color(0.09, 0.18, 0.23, 0.92), 12))
		button.add_theme_stylebox_override("pressed", box(Color("287f86"), 12))
		button.pressed.connect(_emit_touch_turn.bind(direction))
		add_child(button)
		touch_directions.append(button)
	configure_touch_button(touch_boost, "BOOST", 15)
	touch_boost.button_down.connect(func(): touch_boost_changed.emit(true))
	touch_boost.button_up.connect(func(): touch_boost_changed.emit(false))
	add_child(touch_boost)
	configure_touch_button(touch_pause, "PAUSE", 14)
	touch_pause.pressed.connect(func(): touch_pause_requested.emit())
	add_child(touch_pause)

func _emit_touch_turn(direction: String) -> void:
	touch_turn_requested.emit(direction)

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
	return 1.0 / maxf(canvas_scale, 0.01)

func screen_size() -> Vector2:
	return size / ui_scale_factor()

func fit_menu(panel_height: float) -> void:
	var available := screen_size()
	var screen_scale := minf(1.0, minf((available.x - 32.0) / 560.0, (available.y - 24.0) / panel_height))
	screen_scale = clampf(screen_scale, 0.45, 1.0)
	var canvas_scale := screen_scale * ui_scale_factor()
	menu_canvas.scale = Vector2.ONE * canvas_scale
	menu_canvas.position = Vector2((size.x - 560.0 * canvas_scale) / 2.0,
		(size.y - panel_height * canvas_scale) / 2.0)

func update_touch_scale(factor: float) -> void:
	if is_equal_approx(applied_touch_scale, factor):
		return
	applied_touch_scale = factor
	for button in touch_directions:
		button.add_theme_font_size_override("font_size", roundi(13.0 * factor))
	touch_boost.add_theme_font_size_override("font_size", roundi(15.0 * factor))
	touch_pause.add_theme_font_size_override("font_size", roundi(14.0 * factor))
	quick_restart.add_theme_font_size_override("font_size", roundi(17.0 * factor))

func _input(event: InputEvent) -> void:
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
			options_scroll_offset = clampf(options_drag_start_scroll + drag_distance / scale, 0.0, 76.0)
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
			options_scroll_offset = minf(76.0, options_scroll_offset + 48.0)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and options_drag_index == -2:
		options_drag_index = -1
	elif event is InputEventMouseMotion and options_drag_index == -2 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var drag_distance: float = options_drag_start.y - event.position.y
		if absf(drag_distance) > 6.0:
			options_scroll_offset = clampf(options_drag_start_scroll + drag_distance / scale, 0.0, 76.0)
			get_viewport().set_input_as_handled()

static func clean_player_name(value: String) -> String:
	var cleaned := value.strip_edges().left(18)
	return "YOU" if cleaned.is_empty() else cleaned

func finish_options() -> void:
	if game == null:
		options_open = false
		return
	game.player_name = clean_player_name(player_name_entry.text)
	game.player_color = player_color_picker.color
	game.player_pattern = pattern_selector.get_selected_id()
	player_name_entry.release_focus()
	options_open = false
	options_scroll_offset = 0.0
	game.show_title()

func label_at(text: String, location: Vector2, size_value: int = 18, color: Color = INK, numeric: bool = false) -> void:
	draw_string(mono if numeric else font, location, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value, color)

func centered(text: String, y: float, size_value: int, color: Color = INK) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x
	var anchor_x := size.x / 2.0
	if overlay_draw_active:
		anchor_x = 280.0
	elif touch_draw_active:
		anchor_x = screen_size().x / 2.0
	label_at(text, Vector2(anchor_x - width / 2.0, y), size_value, color)

func panel(rect: Rect2, color: Color = Color(0.025, 0.055, 0.095, 0.9)) -> void:
	draw_style_box(box(color), rect)

func _process(_delta: float) -> void:
	if game != null:
		if game.state != "ready":
			options_open = false
		var panel_height := 664.0 if game.state == "ready" and options_open else 520.0
		fit_menu(panel_height)
		options_scroll_offset = clampf(options_scroll_offset, 0.0, 76.0)
		options_content.position = Vector2(0, 130.0 - options_scroll_offset)
		primary.visible = game.state in ["ready", "paused", "finished"] and not (game.state == "ready" and options_open)
		secondary.visible = game.state == "paused"
		options_button.visible = game.state == "ready" and not options_open
		options_back.visible = game.state == "ready" and options_open
		mode_toggle.visible = game.state == "ready" and not options_open
		mode_toggle.set_pressed_no_signal(game.endless_mode)
		quick_restart.visible = game.state == "playing" and not game.sim.riders[0].alive and (game.endless_mode or touch_ui_enabled)
		quick_restart.text = ("RESPAWNING..." if game.auto_mode else "WAITING FOR SPACE") if game.player_respawn_pending else ("RESTART PIPE" if game.endless_mode else "RESTART ROUND")
		var ui_factor := ui_scale_factor()
		var available := screen_size()
		update_touch_scale(ui_factor)
		quick_restart.position = Vector2((available.x - 228.0) / 2.0, (available.y - 44.0) / 2.0 if touch_ui_enabled else available.y - 145.0) * ui_factor
		quick_restart.size = Vector2(228, 44) * ui_factor
		options_content.visible = game.state == "ready" and options_open
		bot_selector.visible = options_content.visible
		size_selector.visible = options_content.visible
		fov_slider.visible = options_content.visible
		player_name_entry.visible = options_content.visible
		player_color_picker.visible = options_content.visible
		player_color_label.visible = options_content.visible
		pattern_selector.visible = options_content.visible
		pipe_preview.visible = options_content.visible
		if pipe_preview.visible:
			pipe_preview.set_appearance(game.player_color, game.player_pattern)
		auto_toggle.visible = game.state in ["ready", "paused", "finished"] and not (game.state == "ready" and options_open)
		auto_toggle.set_pressed_no_signal(game.auto_mode)
		hud_toggle.visible = game.state in ["ready", "paused", "finished"] and not (game.state == "ready" and options_open)
		hud_toggle.set_pressed_no_signal(game.hud_enabled)
		var steer_visible: bool = touch_ui_enabled and game.state in ["playing", "countdown"] and not game.auto_mode and game.sim.riders[0].alive
		var touch_active: bool = touch_ui_enabled and game.state in ["playing", "countdown"]
		for i in range(touch_directions.size()):
			var button := touch_directions[i]
			button.visible = steer_visible
			button.size = Vector2(52, 48) * ui_factor
			button.position = (Vector2(18, available.y - 132) + [Vector2(54, 0), Vector2(0, 54), Vector2(54, 54), Vector2(108, 54)][i]) * ui_factor
		touch_boost.visible = steer_visible
		touch_boost.position = Vector2(available.x - 128, available.y - 76) * ui_factor
		touch_boost.size = Vector2(110, 52) * ui_factor
		if not game.sim.riders.is_empty():
			touch_boost.text = "BOOST %d%%" % roundi(game.sim.riders[0].pressure * 100.0)
		touch_pause.visible = touch_active
		touch_pause.position = Vector2(available.x - 92, 16) * ui_factor
		touch_pause.size = Vector2(76, 42) * ui_factor
	queue_redraw()

func _draw() -> void:
	if game == null or game.sim.riders.is_empty():
		return
	if game.state in ["ready", "paused", "finished"]:
		draw_overlay()
		return
	if not game.hud_enabled and not touch_ui_enabled:
		return
	if touch_ui_enabled:
		if game.hud_enabled:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui_scale_factor())
			touch_draw_active = true
			draw_touch_game_hud()
			touch_draw_active = false
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var sim = game.sim
	var focus_id: int = game.watch_id if game.auto_mode else 0
	var focus_rider: Dictionary = sim.riders[focus_id]
	panel(Rect2(24, 24, 252, 140))
	label_at("PIPE / ENDLESS" if game.endless_mode else "PIPE / SURVIVAL", Vector2(44, 53), 18, ACCENT)
	label_at("%d / %d ALIVE" % [sim.alive_ids().size(), sim.riders.size()], Vector2(43, 97), 32)
	var seconds := int(sim.elapsed_time)
	label_at("SESSION  %02d:%02d" % [seconds / 60, seconds % 60] if game.endless_mode
		else "ROUND  %02d:%02d" % [seconds / 60, seconds % 60], Vector2(44, 139), 21, MUTED, true)
	panel(Rect2(size.x / 2.0 - 186, 24, 372, 88))
	var following: bool = game.auto_mode or not sim.riders[0].alive
	centered("AUTO MODE / FOLLOWING" if game.auto_mode else ("SPECTATING" if following else "YOUR PIPE"), 53, 16, MUTED)
	centered(game.sim.rider_name(game.watch_id if following else 0), 89, 28, game.sim.rider_color(game.watch_id if following else 0))
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
		label_at("%02d %s" % [ranking.find(i) + 1, game.sim.rider_name(i)], Vector2(x + 36, y), 17, color)
		var score := str(game.sim.riders[i].score)
		var width := mono.get_string_size(score, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		label_at(score, Vector2(x + 235 - width, y), 18, INK if i == focus_id else MUTED, true)

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
	var rider: Dictionary = game.sim.riders[0]
	var bounds := screen_size()
	var panel_width := minf(236.0, bounds.x - 128.0)
	panel(Rect2(16, 16, panel_width, 100))
	label_at("%d / %d ALIVE" % [game.sim.alive_ids().size(), game.sim.riders.size()], Vector2(30, 45), 18, INK)
	if bounds.x >= 360.0:
		label_at("SCORE %d   /   %d ORBS" % [rider.score, rider.orb_count], Vector2(30, 73), 15, MUTED)
		label_at("AUTO STEERS / TAP PAUSE" if game.auto_mode else "ARROWS STEER / HOLD BOOST",
			Vector2(30, 99), 13, ACCENT)
	else:
		label_at("SCORE %d" % rider.score, Vector2(30, 73), 15, MUTED)
		label_at("AUTO / PAUSE" if game.auto_mode else "STEER / BOOST", Vector2(30, 99), 13, ACCENT)
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
	if game.state == "playing" and sim.riders[0].alive:
		var queued := " > ".join(game.turn_queue).to_upper()
		if not queued.is_empty():
			centered("QUEUED / " + queued, h - 161, 17, ACCENT)
		if not touch_ui_enabled and game.hud_enabled and game.clearance > 2:
			var control_hint := "C / CAMERA     F / TAKE CONTROL     ESC / PAUSE" if game.auto_mode else "WASD / STEER     HOLD SHIFT / BOOST     ESC / PAUSE"
			centered(control_hint, 137, 13, MUTED)
		if game.clearance <= 2 and not game.auto_mode:
			centered("BLOCKED AHEAD / TURN", 148, 22, Color("ffb65a"))
		if game.score_message_time > 0.0 and not game.auto_mode:
			centered(game.score_message, h / 2.0 + 65, 20, Color("ffdb77"))
	if game.fov_message_time > 0.0:
		centered(game.fov_message, h / 2.0 - 68, 17, ACCENT)
	if game.state == "playing" and not sim.riders[0].alive and (not game.auto_mode or game.endless_mode):
		if touch_ui_enabled:
			var lost_width := minf(456.0, bounds.x - 32.0)
			panel(Rect2((bounds.x - lost_width) / 2.0, h - 230, lost_width, 76))
			centered("PIPE LOST", h - 201, 20, Color("ffb65a"))
			centered("Restarting..." if game.endless_mode and game.auto_mode else "Tap PAUSE to watch survivors",
				h - 174, 15, MUTED)
		elif game.endless_mode:
			panel(Rect2(size.x / 2 - 228, h - 230, 456, 76))
			centered("PIPE LOST / " + str(sim.riders[0].cause).to_upper(), h - 201, 20, Color("ffb65a"))
			centered("Your pipe returns automatically / session continues" if game.auto_mode
				else "Press R or click Restart / session continues", h - 174, 17, MUTED)
		else:
			panel(Rect2(size.x / 2 - 228, h - 230, 456, 76))
			centered("PIPE LOST / " + str(sim.riders[0].cause).to_upper(), h - 201, 20, Color("ffb65a"))
			centered("R to restart / Tab to follow survivors", h - 174, 17, MUTED)
	if game.state == "countdown":
		centered(str(ceili(game.countdown)), h / 2.0 + 25, 88, ACCENT)
		centered("AUTO MODE  /  SIT BACK AND WATCH" if game.auto_mode else "YOUR PIPE  /  GET READY", h / 2.0 + 68, 17)

func draw_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.012, 0.025, 0.5))
	var panel_height := 664.0 if game.state == "ready" and options_open else 520.0
	fit_menu(panel_height)
	var rect := Rect2(Vector2.ZERO, Vector2(560, panel_height))
	overlay_draw_active = true
	draw_set_transform(menu_canvas.position, 0.0, menu_canvas.scale)
	panel(rect, Color("0d1b2b"))
	draw_rect(Rect2(Vector2(25, 0), Vector2(510, 3)), ACCENT)
	if game.state == "ready":
		if options_open:
			draw_options_page(rect)
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
				lines = ["Auto mode steers and boosts for you.", "Tap PAUSE to resume the round.",
				"GAME OPTIONS keeps the round settings."]
			else:
				lines = ["Tap the direction pad to steer.", "Hold BOOST; release to recharge.",
					"Tap PAUSE to resume whenever you need.", "GAME OPTIONS keeps the round settings."]
		elif game.auto_mode:
			lines = ["Every pipe steers and boosts automatically.", "Follow a pipe: Tab / Shift+Tab",
				"Camera: C / FOV: Q / E / take control: F", "Arrow keys: orbit / look",
				"Overview: mouse orbit / wheel zoom", "Hide HUD: H"]
		else:
			lines = ["Pitch: W / S    Turn: A / D", "Boost: hold Shift", "FOV: Q / E",
				"Camera: C", "Arrow keys: orbit / look",
				"Overview: mouse orbit / wheel zoom    HUD: H"]
	elif game.state == "finished":
		var winner: int = game.sim.winner
		title = "ROUND WON" if winner == 0 else "ROUND OVER"
		subtitle = "NO SURVIVORS" if winner < 0 else game.sim.rider_name(winner) + " IS THE LAST PIPE STANDING"
		var secs := int(game.sim.elapsed_time)
		lines = ["Round lasted %d:%02d" % [secs / 60, secs % 60],
			"Your score: %d" % int(game.sim.riders[0].score),
			"%d orbs collected / %d eliminations" % [game.sim.riders[0].orb_count, game.sim.riders[0].eliminations]]
		if game.auto_mode:
			lines.append("Next round in %d seconds." % ceili(game.auto_restart_left))
		action = "ENTER  /  PLAY AGAIN"
	centered(title, rect.position.y + 72, 33)
	centered(subtitle, rect.position.y + 102, 14, ACCENT)
	for i in range(lines.size()):
		centered(lines[i], rect.position.y + 149 + i * 27, 17, MUTED)
	draw_menu_toggles(rect, 300)
	primary.visible = true
	primary.text = action
	primary.position = rect.position + Vector2(38, 365)
	primary.size = Vector2(484, 52)
	if game.state == "paused":
		secondary.visible = true
		secondary.text = "BACK TO TITLE"
		secondary.position = rect.position + Vector2(38, 430)
		secondary.size = Vector2(484, 42)
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
			lines.append("Touch arrows / hold BOOST / PAUSE opens controls.")
		elif game.auto_mode:
			lines.append("Auto respawns / F take control / C camera / Esc pause.")
		else:
			lines.append("WASD steer / Shift boost / R restart / Esc pause.")
	else:
		lines = ["Steer through the cube; the trail you leave stays behind.",
			"Orbs +25  /  close passes +15  /  eliminations +100  /  chain to x2.5.",
		"Crash into walls or trails and you're out. Last pipe wins."]
		if touch_ui_enabled:
			lines.append("Tap PAUSE to view round controls." if game.auto_mode else "Touch arrows / hold BOOST / tap PAUSE.")
		elif game.auto_mode:
			lines.append("C camera / F take control / Esc pauses.")
		else:
			lines.append("WASD steer / hold Shift to boost / Esc pause.")
	for i in range(lines.size()):
		centered(lines[i], rect.position.y + 151 + i * 27, 17, MUTED)
	draw_title_mode_controls(rect, 270)
	options_button.visible = true
	options_button.text = "GAME OPTIONS"
	options_button.position = rect.position + Vector2(38, 330)
	options_button.size = Vector2(484, 43)
	primary.visible = true
	primary.text = "ENTER  /  WATCH AUTO MODE" if game.auto_mode else "ENTER  /  START ROUND"
	primary.position = rect.position + Vector2(38, 389)
	primary.size = Vector2(484, 52)
	var mode_name := "ENDLESS" if game.endless_mode else "SURVIVAL"
	centered("%s    /    YOU + %d BOTS    /    %dM CUBE" % [mode_name, game.bot_count, game.arena_width], rect.position.y + 486, 14, MUTED)

func draw_title_mode_controls(rect: Rect2, offset_y: float) -> void:
	var width := 156.0
	var gap := 8.0
	var origin := Vector2(38, offset_y)
	mode_toggle.text = "MODE / ENDLESS" if game.endless_mode else "MODE / SURVIVAL"
	mode_toggle.position = origin
	mode_toggle.size = Vector2(width, 42)
	auto_toggle.text = "AUTO / %s" % ("ON" if game.auto_mode else "OFF")
	auto_toggle.position = origin + Vector2(width + gap, 0)
	auto_toggle.size = Vector2(width, 42)
	hud_toggle.text = "HUD / %s" % ("ON" if game.hud_enabled else "OFF")
	hud_toggle.position = origin + Vector2((width + gap) * 2, 0)
	hud_toggle.size = Vector2(width, 42)

func draw_options_page(rect: Rect2) -> void:
	centered("ROUND OPTIONS", rect.position.y + 64, 31)
	centered("ROUND AND PLAYER SETTINGS", rect.position.y + 94, 14, ACCENT)
	centered("Set up your pipe; swipe or scroll for camera settings.", rect.position.y + 130, 16, MUTED)
	draw_set_transform(menu_canvas.position + Vector2(0, (130.0 - options_scroll_offset) * menu_canvas.scale.y),
		0.0, menu_canvas.scale)
	draw_option_label("BOT COUNT", Vector2(38, 40), 15, MUTED)
	draw_option_label("ARENA SIZE", Vector2(291, 40), 15, MUTED)
	bot_selector.position = Vector2(38, 52)
	bot_selector.size = Vector2(231, 46)
	bot_selector.select(bot_selector.get_item_index(game.bot_count))
	size_selector.position = Vector2(291, 52)
	size_selector.size = Vector2(231, 46)
	size_selector.select(size_selector.get_item_index(game.arena_width))
	draw_option_label("PIPE NAME", Vector2(38, 123), 15, MUTED)
	if not player_name_entry.has_focus() and player_name_entry.text != game.player_name:
		player_name_entry.text = game.player_name
	player_name_entry.position = Vector2(38, 135)
	player_name_entry.size = Vector2(484, 46)
	draw_option_label("PIPE COLOR", Vector2(38, 207), 15, MUTED)
	draw_option_label("PIPE PATTERN", Vector2(291, 207), 15, MUTED)
	if player_color_picker.color != game.player_color:
		player_color_picker.color = game.player_color
	player_color_picker.position = Vector2(38, 219)
	player_color_picker.size = Vector2(231, 46)
	player_color_label.position = player_color_picker.position
	player_color_label.size = player_color_picker.size
	var label_color := Color("071d23") if game.player_color.get_luminance() > 0.48 else INK
	player_color_label.add_theme_color_override("font_color", label_color)
	pattern_selector.position = Vector2(291, 219)
	pattern_selector.size = Vector2(231, 46)
	pattern_selector.select(pattern_selector.get_item_index(game.player_pattern))
	pipe_preview.position = Vector2(38, 281)
	pipe_preview.size = Vector2(484, 96)
	var preview_top := maxf(pipe_preview.position.y, options_scroll_offset)
	var preview_bottom := minf(pipe_preview.position.y + pipe_preview.size.y,
		options_scroll_offset + options_content.size.y)
	if preview_bottom > preview_top:
		panel(Rect2(Vector2(pipe_preview.position.x, preview_top),
			Vector2(pipe_preview.size.x, preview_bottom - preview_top)), Color("162536"))
	if not is_equal_approx(fov_slider.value, game.camera.base_fov):
		fov_slider.set_value_no_signal(game.camera.base_fov)
	draw_option_label("FIELD OF VIEW", Vector2(38, 405), 15, MUTED)
	draw_option_label("%d°" % roundi(fov_slider.value), Vector2(466, 405), 15, ACCENT, true)
	fov_slider.position = Vector2(38, 414)
	fov_slider.size = Vector2(484, 22)
	var rail_position := fov_slider.position + Vector2(8, 9)
	var rail_width := fov_slider.size.x - 16
	draw_style_box(box(Color("23384d"), 3), Rect2(rail_position, Vector2(rail_width, 4)))
	var progress := (fov_slider.value - fov_slider.min_value) / (fov_slider.max_value - fov_slider.min_value)
	if progress > 0.0:
		draw_style_box(box(ACCENT.darkened(0.2), 3), Rect2(rail_position, Vector2(rail_width * progress, 4)))
	draw_set_transform(menu_canvas.position, 0.0, menu_canvas.scale)
	options_back.visible = true
	options_back.text = "DONE"
	options_back.position = Vector2(38, 584)
	options_back.size = Vector2(484, 44)
	centered("PLAYING AS %s  /  %d BOTS  /  %dm CUBE" % [game.player_name, game.bot_count, game.arena_width], rect.position.y + 650, 14, MUTED)

func draw_option_label(text: String, position: Vector2, size_value: int, color: Color, numeric := false) -> void:
	if position.y < options_scroll_offset or position.y > options_scroll_offset + options_content.size.y - 18.0:
		return
	label_at(text, position, size_value, color, numeric)

func draw_menu_toggles(rect: Rect2, offset_y: float) -> void:
	auto_toggle.text = "AUTO MODE  /  %s" % ("ON" if game.auto_mode else "OFF")
	auto_toggle.position = Vector2(38, offset_y)
	auto_toggle.size = Vector2(231, 42)
	hud_toggle.text = "HUD  /  %s" % ("ON" if game.hud_enabled else "OFF")
	hud_toggle.position = Vector2(291, offset_y)
	hud_toggle.size = Vector2(231, 42)
