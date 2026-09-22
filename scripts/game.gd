extends Node3D

const Rules = preload("res://scripts/simulation.gd")
const Motion = preload("res://scripts/motion.gd")
const PipeRenderer = preload("res://scripts/pipe_renderer.gd")
const Arena = preload("res://scripts/arena.gd")
const CameraRig = preload("res://scripts/camera_rig.gd")
const Hud = preload("res://scripts/hud.gd")
const OrbRenderer = preload("res://scripts/orb_renderer.gd")
var sim := Rules.new()
var motion := Motion.new(sim)
var pipes := PipeRenderer.new()
var camera := CameraRig.new()
var hud := Hud.new()
var orbs := OrbRenderer.new()
var state := "ready"
var countdown := 3.0
var bot_count := Rules.DEFAULT_BOTS
var arena_width := 60
var player_name := "YOU"
var player_color := Color("56eddf")
var arena: Node3D
var turn_queue: Array[String]:
	get: return motion.turn_queue
var watch_id := 0
var clearance := 10
var automated := false
var auto_mode := false
var hud_enabled := true
var auto_restart_left := 5.0
var paused_from := "playing"
var orbit_idle := 0.0
var boost_held := false
var camera_left_held := false
var camera_right_held := false
var camera_up_held := false
var camera_down_held := false
var score_message := ""
var score_message_time := 0.0

func _ready() -> void:
	DisplayServer.window_set_min_size(Vector2i(960, 600))
	pipes.model = sim
	orbs.model = sim
	add_child(pipes)
	add_child(orbs)
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	hud.game = self
	hud.primary_clicked.connect(primary_action)
	hud.secondary_clicked.connect(show_title)
	motion.completed.connect(on_completed)
	motion.planned.connect(on_planned)
	get_window().focus_exited.connect(func():
		boost_held = false
		camera_left_held = false
		camera_right_held = false
		camera_up_held = false
		camera_down_held = false
		if state == "playing" and not automated and not auto_mode:
			paused_from = state
			state = "paused")
	show_title()
	if "--qa" in OS.get_cmdline_user_args():
		automated = true
		var driver = load("res://tests/visual_smoke.gd").new()
		driver.game = self
		add_child(driver)

func reset_world(seed_value: int = 0) -> void:
	sim.reset(seed_value, bot_count, arena_width, player_name, player_color)
	if not is_instance_valid(arena) or arena.width != sim.arena_width:
		if is_instance_valid(arena):
			remove_child(arena)
			arena.queue_free()
		arena = Arena.new()
		arena.width = sim.arena_width
		add_child(arena)
	camera.set_arena_size(sim.arena_width)
	pipes.reset(sim.riders.size())
	motion.autoplay = auto_mode
	motion.reset()
	pipes.begin_step(sim.riders, motion.directions)
	pipes.animate(0.0, sim.riders)
	orbs.sync(sim.scoring)
	boost_held = false
	camera_left_held = false
	camera_right_held = false
	camera_up_held = false
	camera_down_held = false
	watch_id = 0
	score_message_time = 0.0
	auto_restart_left = 5.0
	orbit_idle = 0.0
	camera.initialized = false
	update_clearance()

func show_title() -> void:
	reset_world(814)
	state = "ready"
	motion.autoplay = true
	for tick in range(60):
		motion.advance(Rules.STEP_TIME)
		if sim.finished:
			break
	state = "ready"
	motion.autoplay = auto_mode
	camera.overview = true

func start_round(seed_value: int = 0) -> void:
	reset_world(seed_value)
	state = "countdown"
	countdown = 3.0
	camera.overview = auto_mode

func set_auto_mode(enabled: bool) -> void:
	auto_mode = enabled
	motion.autoplay = enabled
	turn_queue.clear()
	boost_held = false
	motion.boost_requested = false
	auto_restart_left = 5.0
	# Keep the current segment intact; the next junction uses the new driver.
	if not enabled and sim.riders[0].alive:
		watch_id = 0
		camera.initialized = false

func set_hud_enabled(enabled: bool) -> void:
	hud_enabled = enabled
	update_hud_visibility()

func update_hud_visibility() -> void:
	# Menus remain accessible with Escape; resuming restores the clean view.
	hud.visible = hud_enabled or state in ["ready", "paused"]
	if is_instance_valid(arena):
		arena.set_labels_visible(hud_enabled)
	for i in range(sim.riders.size()):
		var hidden_head := camera.first_person and i == watch_id and state not in ["ready", "finished"]
		pipes.markers[i].visible = hud_enabled and sim.riders[i].alive and not hidden_head and (not auto_mode or i == watch_id)

func toggle_pause() -> void:
	if state == "paused":
		state = paused_from
	elif state in ["playing", "countdown"] or (state == "finished" and auto_mode):
		paused_from = state
		state = "paused"
		boost_held = false

func primary_action() -> void:
	if state == "paused":
		state = paused_from
	elif state in ["ready", "finished"]:
		start_round()

func on_planned(indices: Array[int]) -> void:
	for i in indices:
		pipes.begin_rider(i, sim.riders[i], motion.directions[i])
	update_clearance()

func update_clearance() -> void:
	clearance = 0
	for distance in range(1, 11):
		if not sim.is_open(sim.riders[0].cell + motion.directions[0] * distance):
			break
		clearance += 1

func on_completed(moves: Array[Dictionary]) -> void:
	for move: Dictionary in moves:
		pipes.animate_rider(move.id, 1.0)
		if move.id == 0 and move.has("orb_points"):
			score_message = "+25  ORB COLLECTED"
			score_message_time = 1.5
		if move.get("credited_to", -1) == 0:
			score_message = "+100  ELIMINATION"
			score_message_time = 2.0
	pipes.commit(moves)
	orbs.sync(sim.scoring)
	if not sim.riders[watch_id].alive:
		var living := sim.alive_ids()
		if not living.is_empty():
			watch_id = living[0]
		if not auto_mode:
			camera.overview = true
		camera.initialized = false
	if sim.finished:
		state = "finished"
		auto_restart_left = 5.0

func _process(delta: float) -> void:
	if camera.view == CameraRig.View.RING:
		var orbit_axis := float(camera_right_held) - float(camera_left_held)
		var look_axis := float(camera_up_held) - float(camera_down_held)
		camera.ring_angle = wrapf(camera.ring_angle - orbit_axis * delta * 1.8, -PI, PI)
		camera.ring_look_pitch = clampf(camera.ring_look_pitch + look_axis * delta * 1.1, -0.8, 0.8)
	if state == "countdown":
		countdown -= delta
		if countdown <= 0.0:
			state = "playing"
	elif state == "playing":
		motion.boost_requested = boost_held
		motion.advance(minf(delta, 0.1))
		score_message_time = maxf(0.0, score_message_time - delta)
	elif state == "finished" and auto_mode:
		auto_restart_left = maxf(0.0, auto_restart_left - delta)
		if auto_restart_left <= 0.0:
			var last_view = camera.view
			var last_distance := camera.distance
			start_round()
			camera.view = last_view
			camera.distance = last_distance
	orbit_idle = maxf(0.0, orbit_idle - delta)
	if auto_mode and camera.overview and state in ["countdown", "playing", "finished"] and orbit_idle <= 0.0:
		camera.yaw += delta * 0.055
	for i in range(sim.riders.size()):
		if sim.riders[i].alive:
			pipes.animate_rider(i, motion.progress(i))
	if not pipes.plans.is_empty():
		var head_pose := pipes.pose(watch_id, motion.progress(watch_id))
		camera.boosting = sim.riders[watch_id].boosting and state == "playing"
		camera.follow(head_pose, delta, state in ["ready", "finished"])
		for i in range(sim.riders.size()):
			var hidden := camera.first_person and i == watch_id and state not in ["ready", "finished"]
			pipes.heads[i].visible = sim.riders[i].alive and not hidden
		if state == "ready":
			camera.yaw += delta * 0.055
	update_hud_visibility()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if state != "ready" and key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			match key:
				KEY_LEFT: camera_left_held = event.pressed
				KEY_RIGHT: camera_right_held = event.pressed
				KEY_UP: camera_up_held = event.pressed
				KEY_DOWN: camera_down_held = event.pressed
			if event.pressed and not event.echo:
				if camera.view != CameraRig.View.RING:
					var horizontal := -1.0 if key == KEY_LEFT else 1.0 if key == KEY_RIGHT else 0.0
					var vertical := -1.0 if key == KEY_UP else 1.0 if key == KEY_DOWN else 0.0
					camera.orbit_step(horizontal, vertical)
				orbit_idle = 4.0
			return
		if key == KEY_SHIFT and not auto_mode:
			boost_held = event.pressed and state == "playing"
			if not event.pressed:
				sim.riders[0].boost_locked = false
		if not event.pressed or event.echo:
			return
		if key == KEY_ENTER or key == KEY_KP_ENTER:
			primary_action()
		elif key == KEY_ESCAPE:
			toggle_pause()
		elif key == KEY_F:
			set_auto_mode(not auto_mode)
		elif key == KEY_H:
			set_hud_enabled(not hud_enabled)
		elif key == KEY_R:
			start_round()
		elif key == KEY_C:
			camera.toggle()
		elif key == KEY_TAB and (auto_mode or not sim.riders[0].alive):
			var alive := sim.alive_ids()
			if not alive.is_empty():
				var step := -1 if event.shift_pressed else 1
				watch_id = alive[(alive.find(watch_id) + step + alive.size()) % alive.size()]
				camera.initialized = false
		elif state in ["playing", "countdown"] and sim.riders[0].alive and not auto_mode:
			var command := ""
			match key:
				KEY_W: command = "up"
				KEY_S: command = "down"
				KEY_A: command = "left"
				KEY_D: command = "right"
			if not command.is_empty() and turn_queue.size() < 2:
				turn_queue.append(command)
	elif event is InputEventMouseMotion and camera.overview and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera.orbit(event.relative)
		orbit_idle = 4.0
	elif event is InputEventMouseButton and event.pressed and camera.overview:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom(-3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom(3.0)
