extends Control

signal primary_clicked
signal secondary_clicked
const INK := Color("e8f2f5")
const MUTED := Color("8da4b8")
const ACCENT := Color("56eddf")
const PLAYER_COLOR := Color("56eddf")
var game: Node
var font := SystemFont.new()
var mono := SystemFont.new()
var primary := Button.new()
var secondary := Button.new()
var options_button := Button.new()
var options_back := Button.new()
var bot_selector := OptionButton.new()
var size_selector := OptionButton.new()
var player_name_entry := LineEdit.new()
var player_color_picker := ColorPickerButton.new()
var player_color_label := Label.new()
var auto_toggle := Button.new()
var hud_toggle := Button.new()
var options_open := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI"])
	mono.font_names = PackedStringArray(["Consolas"])
	for button in [primary, secondary, options_button, options_back, auto_toggle, hud_toggle]:
		add_child(button)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", Color("071d23"))
		button.add_theme_stylebox_override("normal", box(ACCENT, 9))
		button.add_theme_stylebox_override("hover", box(ACCENT.lightened(0.2), 9))
		button.add_theme_stylebox_override("pressed", box(ACCENT.darkened(0.15), 9))
	primary.pressed.connect(func(): primary_clicked.emit())
	secondary.pressed.connect(func(): secondary_clicked.emit())
	for button in [secondary, options_button, options_back]:
		button.add_theme_color_override("font_color", MUTED)
		button.add_theme_stylebox_override("normal", box(Color("162536"), 9))
		button.add_theme_stylebox_override("hover", box(Color("23384d"), 9))
	options_button.text = "GAME OPTIONS"
	options_button.pressed.connect(func(): options_open = true)
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
	add_child(bot_selector)
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
	add_child(size_selector)
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
	add_child(player_name_entry)
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
	add_child(player_color_picker)
	player_color_picker.color = PLAYER_COLOR
	player_color_picker.edit_alpha = false
	player_color_picker.tooltip_text = "Choose the color for your pipe"
	player_color_picker.focus_mode = Control.FOCUS_NONE
	player_color_picker.add_theme_stylebox_override("normal", box(PLAYER_COLOR, 7))
	player_color_picker.add_theme_stylebox_override("hover", box(PLAYER_COLOR.lightened(0.2), 7))
	player_color_picker.color_changed.connect(func(value: Color): game.player_color = value)
	add_child(player_color_label)
	player_color_label.text = "CHANGE COLOR"
	player_color_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_color_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player_color_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_color_label.add_theme_font_override("font", font)
	player_color_label.add_theme_font_size_override("font_size", 16)

static func box(color: Color, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style

static func clean_player_name(value: String) -> String:
	var cleaned := value.strip_edges().left(18)
	return "YOU" if cleaned.is_empty() else cleaned

func finish_options() -> void:
	if game == null:
		options_open = false
		return
	game.player_name = clean_player_name(player_name_entry.text)
	game.player_color = player_color_picker.color
	player_name_entry.release_focus()
	options_open = false
	game.show_title()

func label_at(text: String, location: Vector2, size_value: int = 18, color: Color = INK, numeric: bool = false) -> void:
	draw_string(mono if numeric else font, location, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value, color)

func centered(text: String, y: float, size_value: int, color: Color = INK) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x
	label_at(text, Vector2((size.x - width) / 2.0, y), size_value, color)

func panel(rect: Rect2, color: Color = Color(0.025, 0.055, 0.095, 0.9)) -> void:
	draw_style_box(box(color), rect)

func _process(_delta: float) -> void:
	if game != null:
		if game.state != "ready":
			options_open = false
		primary.visible = game.state in ["ready", "paused", "finished"] and not (game.state == "ready" and options_open)
		secondary.visible = game.state == "paused"
		options_button.visible = game.state == "ready" and not options_open
		options_back.visible = game.state == "ready" and options_open
		bot_selector.visible = game.state == "ready" and options_open
		size_selector.visible = game.state == "ready" and options_open
		player_name_entry.visible = game.state == "ready" and options_open
		player_color_picker.visible = game.state == "ready" and options_open
		player_color_label.visible = game.state == "ready" and options_open
		auto_toggle.visible = game.state in ["ready", "paused", "finished"] and not (game.state == "ready" and options_open)
		auto_toggle.set_pressed_no_signal(game.auto_mode)
		hud_toggle.visible = game.state in ["ready", "paused", "finished"] and not (game.state == "ready" and options_open)
		hud_toggle.set_pressed_no_signal(game.hud_enabled)
	queue_redraw()

func _draw() -> void:
	if game == null or game.sim.riders.is_empty():
		return
	if game.state in ["ready", "paused", "finished"]:
		draw_overlay()
		return
	var sim = game.sim
	var focus_id: int = game.watch_id if game.auto_mode else 0
	var focus_rider: Dictionary = sim.riders[focus_id]
	panel(Rect2(24, 24, 252, 140))
	label_at("PIPE / SURVIVAL", Vector2(44, 53), 18, ACCENT)
	label_at("%d / %d ALIVE" % [sim.alive_ids().size(), sim.riders.size()], Vector2(43, 97), 32)
	var seconds := int(sim.elapsed_time)
	label_at("ROUND  %02d:%02d" % [seconds / 60, seconds % 60], Vector2(44, 139), 21, MUTED, true)
	panel(Rect2(size.x / 2.0 - 186, 24, 372, 88))
	var following: bool = game.auto_mode or not sim.riders[0].alive
	centered("AUTO MODE / FOLLOWING" if game.auto_mode else ("SPECTATING" if following else "YOUR PIPE"), 53, 16, MUTED)
	centered(game.sim.rider_name(game.watch_id if following else 0), 89, 28, game.sim.rider_color(game.watch_id if following else 0))
	draw_leaderboard(focus_id)
	panel(Rect2(24, size.y - 192, 252, 136))
	label_at(game.sim.rider_name(focus_id) + " / SCORE" if game.auto_mode else "YOUR SCORE", Vector2(44, size.y - 161), 17, MUTED)
	label_at(str(focus_rider.score), Vector2(43, size.y - 112), 44, Color("ffdb77"), true)
	label_at("%d ORBS / %d ELIMINATIONS" % [focus_rider.orb_count, focus_rider.eliminations], Vector2(44, size.y - 77), 15, MUTED)
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

func draw_play_messages() -> void:
	var sim = game.sim
	var h := size.y
	if game.camera.first_person and game.state in ["playing", "countdown"]:
		var center := size / 2.0
		draw_circle(center, 2, Color(0.9, 1.0, 1.0, 0.8))
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(center + direction * 8, center + direction * 14, Color(0.8, 1.0, 1.0, 0.65), 1.5)
	if game.state == "playing" and sim.riders[0].alive:
		var queued := " > ".join(game.turn_queue).to_upper()
		if not queued.is_empty():
			centered("QUEUED / " + queued, h - 161, 17, ACCENT)
		if game.clearance <= 2 and not game.auto_mode:
			centered("BLOCKED AHEAD / TURN", 148, 22, Color("ffb65a"))
		if game.score_message_time > 0.0 and not game.auto_mode:
			centered(game.score_message, h / 2.0 + 65, 20, Color("ffdb77"))
	if game.state == "playing" and not sim.riders[0].alive and not game.auto_mode:
		panel(Rect2(size.x / 2 - 228, h - 230, 456, 76))
		centered("PIPE LOST / " + str(sim.riders[0].cause).to_upper(), h - 201, 20, Color("ffb65a"))
		centered("R to restart / Tab to follow survivors", h - 174, 17, MUTED)
	if game.state == "countdown":
		centered(str(ceili(game.countdown)), h / 2.0 + 25, 88, ACCENT)
		centered("AUTO MODE  /  SIT BACK AND WATCH" if game.auto_mode else "YOUR PIPE  /  GET READY", h / 2.0 + 68, 17)

func draw_overlay() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.012, 0.025, 0.5))
	var rect := Rect2(w / 2 - 280, h / 2 - 260, 560, 520)
	panel(rect, Color("0d1b2b"))
	draw_rect(Rect2(rect.position + Vector2(25, 0), Vector2(510, 3)), ACCENT)
	if game.state == "ready":
		if options_open:
			draw_options_page(rect)
		else:
			draw_title_page(rect)
		return
	var title := "PAUSED"
	var subtitle := "AUTO MODE CONTROLS" if game.auto_mode else "CONTROLS"
	var lines: Array[String] = []
	var action := "ESC  /  RESUME"
	if game.state == "paused":
		if game.auto_mode:
			lines = ["Every pipe steers and boosts automatically.", "Follow a pipe: Tab / Shift+Tab",
				"Change camera: C / take control: F", "Ring view: hold Left / Right to orbit",
				"Ring view: Up / Down to aim", "Overview: mouse orbit / wheel zoom / HUD: H"]
		else:
			lines = ["Pitch: W / S", "Turn: A / D", "Boost: hold Shift",
				"Ring view: hold Left / Right to orbit", "Ring view: Up / Down to aim",
				"Camera: C / overview mouse orbit / HUD: H"]
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

func draw_title_page(rect: Rect2) -> void:
	centered("PIPE / SURVIVAL", rect.position.y + 74, 32)
	centered("SURVIVAL IN A GROWING 3D PIPE MAZE", rect.position.y + 104, 14, ACCENT)
	var lines := ["Steer through the cube; the trail you leave stays behind.",
		"Orbs +25  /  survival +1 per second  /  eliminations +100.",
		"Crash into walls or trails and you're out. Last pipe wins.",
		"Press Esc during a round to pause and see the controls."]
	for i in range(lines.size()):
		centered(lines[i], rect.position.y + 151 + i * 27, 17, MUTED)
	draw_menu_toggles(rect, 270)
	options_button.visible = true
	options_button.text = "GAME OPTIONS"
	options_button.position = rect.position + Vector2(38, 330)
	options_button.size = Vector2(484, 43)
	primary.visible = true
	primary.text = "ENTER  /  WATCH AUTO MODE" if game.auto_mode else "ENTER  /  START ROUND"
	primary.position = rect.position + Vector2(38, 389)
	primary.size = Vector2(484, 52)
	centered("YOU + %d BOTS    /    %dM CUBE" % [game.bot_count, game.arena_width], rect.position.y + 486, 14, MUTED)

func draw_options_page(rect: Rect2) -> void:
	centered("ROUND OPTIONS", rect.position.y + 76, 31)
	centered("ROUND AND PLAYER SETTINGS", rect.position.y + 105, 14, ACCENT)
	centered("Bot names shuffle without repeats. Choose your name and color.", rect.position.y + 154, 16, MUTED)
	label_at("BOT COUNT", rect.position + Vector2(38, 202), 15, MUTED)
	label_at("ARENA SIZE", rect.position + Vector2(291, 202), 15, MUTED)
	bot_selector.position = rect.position + Vector2(38, 214)
	bot_selector.size = Vector2(231, 46)
	bot_selector.select(bot_selector.get_item_index(game.bot_count))
	size_selector.position = rect.position + Vector2(291, 214)
	size_selector.size = Vector2(231, 46)
	size_selector.select(size_selector.get_item_index(game.arena_width))
	label_at("PIPE NAME", rect.position + Vector2(38, 286), 15, MUTED)
	label_at("PIPE COLOR", rect.position + Vector2(378, 286), 15, MUTED)
	if not player_name_entry.has_focus() and player_name_entry.text != game.player_name:
		player_name_entry.text = game.player_name
	player_name_entry.position = rect.position + Vector2(38, 298)
	player_name_entry.size = Vector2(318, 46)
	if player_color_picker.color != game.player_color:
		player_color_picker.color = game.player_color
	player_color_picker.position = rect.position + Vector2(378, 298)
	player_color_picker.size = Vector2(144, 46)
	player_color_label.position = player_color_picker.position
	player_color_label.size = player_color_picker.size
	var label_color := Color("071d23") if game.player_color.get_luminance() > 0.48 else INK
	player_color_label.add_theme_color_override("font_color", label_color)
	options_back.visible = true
	options_back.text = "DONE"
	options_back.position = rect.position + Vector2(38, 372)
	options_back.size = Vector2(484, 48)
	centered("PLAYING AS %s  /  %d BOTS  /  %dm CUBE" % [game.player_name, game.bot_count, game.arena_width], rect.position.y + 484, 14, MUTED)

func draw_menu_toggles(rect: Rect2, offset_y: float) -> void:
	auto_toggle.text = "AUTO MODE  /  %s" % ("ON" if game.auto_mode else "OFF")
	auto_toggle.position = rect.position + Vector2(38, offset_y)
	auto_toggle.size = Vector2(231, 42)
	hud_toggle.text = "HUD  /  %s" % ("ON" if game.hud_enabled else "OFF")
	hud_toggle.position = rect.position + Vector2(291, offset_y)
	hud_toggle.size = Vector2(231, 42)
