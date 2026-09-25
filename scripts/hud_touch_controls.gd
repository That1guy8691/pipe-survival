extends Control
## Touch buttons, gesture ownership, and steering queue input for the gameplay HUD.

signal touch_turn_requested(command: String)
signal touch_boost_changed(held: bool)
signal touch_view_requested
signal touch_overview_style_requested
signal touch_overview_focus_requested
signal touch_pause_requested
signal touch_camera_orbit_requested(relative: Vector2)
signal touch_camera_zoom_requested(distance_change: float)

const INK := Color("e8f2f5")
const ACCENT := Color("56eddf")
var game: Node
var font: Font
var enabled := false
var ui_factor := 1.0
var touch_boost := Button.new()
var touch_view := Button.new()
var touch_overview_style := Button.new()
var touch_overview_focus := Button.new()
var touch_pause := Button.new()
var applied_touch_scale := -1.0
var joystick_touch_index := -1
var joystick_vector := Vector2.ZERO
var joystick_direction := ""
var joystick_pending_direction := ""
var joystick_center_position := Vector2.ZERO
var camera_touch_points: Dictionary = {}
var camera_pinch_distance := 0.0
var boost_held := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_touch_controls()
	get_window().focus_exited.connect(cancel_gestures)

func refresh(model: Node, touch_enabled: bool, scale_factor: float) -> void:
	game = model
	enabled = touch_enabled
	ui_factor = scale_factor
	visible = enabled
	if game == null:
		return
	if not touch_camera_active():
		cancel_gestures()
	elif not steering_active():
		release_touch_joystick()
		set_boost(false)
	if joystick_pending_direction != "" and joystick_touch_index != -1 and game.turn_queue.size() < 2:
		var pending_direction := joystick_pending_direction
		joystick_pending_direction = ""
		touch_turn_requested.emit(pending_direction)
	var available := screen_size()
	var control_scale := touch_control_scale()
	update_touch_scale(ui_factor * control_scale)
	var touch_active: bool = enabled and game.state in ["playing", "countdown"]
	var overview_active: bool = touch_active and game.camera.overview and game.crash_view_time <= 0.0
	touch_boost.visible = steering_active()
	touch_boost.position = Vector2(available.x - 172 * control_scale, available.y - 118 * control_scale) * ui_factor
	touch_boost.size = Vector2(152, 96) * control_scale * ui_factor
	if not game.sim.riders.is_empty():
		touch_boost.text = "BOOST\n%d%%" % roundi(game.sim.riders[game.player_rider_id()].pressure * 100.0)
	touch_view.visible = touch_active
	touch_view.position = Vector2(available.x - 128 * control_scale, 124 * control_scale) * ui_factor
	touch_view.size = Vector2(120, 48) * control_scale * ui_factor
	touch_overview_style.visible = overview_active
	touch_overview_style.position = Vector2(available.x - 168 * control_scale, 180 * control_scale) * ui_factor
	touch_overview_style.size = Vector2(160, 48) * control_scale * ui_factor
	touch_overview_style.text = "PIPES / " + game.overview_style_name()
	touch_overview_focus.visible = overview_active
	touch_overview_focus.position = Vector2(available.x - 168 * control_scale, 236 * control_scale) * ui_factor
	touch_overview_focus.size = Vector2(160, 48) * control_scale * ui_factor
	var focus_name: String = game.sim.rider_name(game.overview_focus_id).to_upper()
	if focus_name.length() > 10:
		focus_name = focus_name.left(9) + "…"
	touch_overview_focus.text = "NEXT / " + focus_name
	touch_pause.visible = touch_active
	touch_pause.position = Vector2(available.x - 82 * control_scale, 16 * control_scale) * ui_factor
	touch_pause.size = Vector2(72, 48) * control_scale * ui_factor
	queue_redraw()

func steering_active() -> bool:
	return game != null and enabled and game.state in ["playing", "countdown"] \
		and not game.auto_mode and game.sim.riders[game.player_rider_id()].alive

func cancel_gestures() -> void:
	release_touch_joystick()
	camera_touch_points.clear()
	camera_pinch_distance = 0.0
	set_boost(false)

func set_boost(held: bool) -> void:
	if held == boost_held:
		return
	boost_held = held
	touch_boost_changed.emit(held)

func handle_input(event: InputEvent) -> bool:
	if not event is InputEventScreenTouch and not event is InputEventScreenDrag:
		return false
	var camera_owned := camera_touch_points.has(event.index)
	update_touch_camera_gesture(event)
	if steering_active():
		if event is InputEventScreenTouch:
			if event.pressed and joystick_touch_index == -1 and camera_touch_points.is_empty() \
					and touch_steering_zone(event.position) and not touch_camera_control_at(event.position):
				joystick_touch_index = event.index
				joystick_center_position = event.position / ui_scale_factor()
				update_touch_joystick(event.position)
				return true
			if not event.pressed and event.index == joystick_touch_index:
				release_touch_joystick()
				return true
		elif event.index == joystick_touch_index:
			update_touch_joystick(event.position)
			return true
	return camera_owned or camera_touch_points.has(event.index)

func _draw() -> void:
	if steering_active():
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui_factor)
		draw_touch_joystick()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func ui_scale_factor() -> float:
	return ui_factor

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
	touch_boost.button_down.connect(func(): set_boost(true))
	touch_boost.button_up.connect(func(): set_boost(false))
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
	return game != null and enabled and game.state in ["playing", "countdown"] \
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

func update_touch_scale(factor: float) -> void:
	if is_equal_approx(applied_touch_scale, factor):
		return
	applied_touch_scale = factor
	touch_boost.add_theme_font_size_override("font_size", roundi(17.0 * factor))
	touch_view.add_theme_font_size_override("font_size", roundi(14.0 * factor))
	touch_overview_style.add_theme_font_size_override("font_size", roundi(12.0 * factor))
	touch_overview_focus.add_theme_font_size_override("font_size", roundi(12.0 * factor))
	touch_pause.add_theme_font_size_override("font_size", roundi(14.0 * factor))

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
