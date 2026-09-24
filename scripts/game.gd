extends Node3D

const Rules = preload("res://scripts/simulation.gd")
const Motion = preload("res://scripts/motion.gd")
const PipeRenderer = preload("res://scripts/pipe_renderer.gd")
const Arena = preload("res://scripts/arena.gd")
const CameraRig = preload("res://scripts/camera_rig.gd")
const Hud = preload("res://scripts/hud.gd")
const OrbRenderer = preload("res://scripts/orb_renderer.gd")
const MultiplayerClient = preload("res://scripts/multiplayer_client.gd")
const AUTO_PLAYER_RESPAWN_DELAY := 2.5
const BOT_RESPAWN_MIN_DELAY := 4.0
const BOT_RESPAWN_MAX_DELAY := 12.0
const RESPAWN_RETRY_DELAY := 0.75
const TITLE_PREVIEW_STEPS := 60
const CRASH_VIEW_DURATION := 1.25
const COLLISION_FEEDBACK_DURATION := 2.0
const ONLINE_BACKLOG_LIMIT := 3
const ONLINE_CATCH_UP_STEPS := 8
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
var player_pattern := PipeRenderer.Appearance.Pattern.SOLID
var player_material := PipeRenderer.Appearance.Finish.ALLOY
var player_joint_style := PipeRenderer.Appearance.JointStyle.COLLARED
var arena: Node3D
var turn_queue: Array[String]:
	get: return motion.turn_queue
var watch_id := 0
var overview_focus_id := 0
var overview_style := PipeRenderer.OverviewStyle.NORMAL
var clearance := 10
var automated := false
var auto_mode := false
var endless_mode := false
var hud_enabled := true
var auto_restart_left := 5.0
var paused_from := "playing"
var orbit_idle := 0.0
var boost_held := false
var score_message := ""
var score_message_time := 0.0
var fov_message_time := 0.0
var fov_message := ""
var respawn_timers: Array[float] = []
var respawn_rng := RandomNumberGenerator.new()
var player_respawn_pending := false
var title_preview_steps_left := 0
var crash_view_time := 0.0
var crash_position := Vector3.ZERO
var collision_feedback_time := 0.0
var collision_position := Vector3.ZERO
var collision_feedback_label := ""
var online_client := MultiplayerClient.new()
var online_connected := false
var online_status := "OFFLINE"
var online_server_url := str(ProjectSettings.get_setting("application/config/multiplayer_server_url",
	"ws://127.0.0.1:8787"))
var online_room_id := "PUBLIC"
var online_player_slot := -1
var online_last_state: Dictionary = {}
var online_mode := false
var online_progress := 0.0
var online_step_duration := Rules.STEP_TIME
var online_step_active := false
var online_state_queue: Array[Dictionary] = []

func _ready() -> void:
	respawn_rng.randomize()
	if not DisplayServer.is_touchscreen_available():
		DisplayServer.window_set_min_size(Vector2i(960, 600))
	pipes.model = sim
	orbs.model = sim
	add_child(pipes)
	add_child(orbs)
	add_child(camera)
	add_child(online_client)
	online_client.connected_to_room.connect(_on_online_welcome)
	online_client.state_received.connect(_on_online_state)
	online_client.room_event.connect(_on_online_event)
	online_client.connection_rejected.connect(_on_online_rejected)
	online_client.connection_failed.connect(_on_online_connection_failed)
	online_client.disconnected.connect(_on_online_disconnected)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	hud.game = self
	hud.primary_clicked.connect(primary_action)
	hud.secondary_clicked.connect(show_title)
	hud.quick_restart_clicked.connect(request_player_restart)
	hud.touch_turn_requested.connect(queue_turn)
	hud.touch_boost_changed.connect(set_touch_boost)
	hud.touch_view_requested.connect(swap_camera_view)
	hud.touch_overview_style_requested.connect(cycle_overview_style)
	hud.touch_overview_focus_requested.connect(func(): cycle_overview_focus(1))
	hud.touch_pause_requested.connect(toggle_pause)
	hud.touch_camera_orbit_requested.connect(orbit_camera_from_touch)
	hud.touch_camera_zoom_requested.connect(zoom_camera_from_touch)
	motion.completed.connect(on_completed)
	motion.planned.connect(on_planned)
	get_window().focus_exited.connect(func():
		boost_held = false
		if state == "playing" and not automated and not auto_mode:
			paused_from = state
			state = "paused")
	show_title()
	if "--qa" in OS.get_cmdline_user_args():
		automated = true
		var driver = load("res://tests/visual_smoke.gd").new()
		driver.game = self
		add_child(driver)

func reset_world(seed_value: int = 0, title_preview: bool = false) -> void:
	online_mode = false
	online_state_queue.clear()
	online_step_active = false
	online_progress = 0.0
	pipes.player_id = 0
	title_preview_steps_left = 0
	crash_view_time = 0.0
	collision_feedback_time = 0.0
	collision_feedback_label = ""
	sim.endless_mode = endless_mode and not title_preview
	sim.reset(seed_value, bot_count, arena_width, player_name, player_color)
	respawn_timers.clear()
	for i in range(sim.riders.size()):
		respawn_timers.append(-1.0)
	player_respawn_pending = false
	if not is_instance_valid(arena) or arena.width != sim.arena_width:
		if is_instance_valid(arena):
			remove_child(arena)
			arena.queue_free()
		arena = Arena.new()
		arena.width = sim.arena_width
		add_child(arena)
	camera.set_arena_size(sim.arena_width)
	pipes.player_pattern = player_pattern
	pipes.player_material = player_material
	pipes.player_joint_style = player_joint_style
	pipes.reset(sim.riders.size())
	motion.autoplay = auto_mode
	motion.reset()
	pipes.begin_step(sim.riders, motion.directions)
	pipes.animate(0.0, sim.riders)
	orbs.sync(sim.scoring)
	boost_held = false
	watch_id = 0
	overview_focus_id = 0
	score_message_time = 0.0
	fov_message_time = 0.0
	auto_restart_left = 5.0
	orbit_idle = 0.0
	camera.initialized = false
	camera.clear_impact()
	update_clearance()

func show_title() -> void:
	reset_world(814, true)
	state = "ready"
	title_preview_steps_left = TITLE_PREVIEW_STEPS
	camera.overview = true

func advance_title_preview() -> void:
	if title_preview_steps_left == 0:
		return
	# Let the menu draw and accept input between backdrop steps, including on Web.
	motion.autoplay = true
	motion.advance(Rules.STEP_TIME)
	title_preview_steps_left -= 1
	if sim.finished:
		title_preview_steps_left = 0
	state = "ready"
	motion.autoplay = auto_mode

func start_round(seed_value: int = 0) -> void:
	reset_world(seed_value)
	state = "countdown"
	countdown = 3.0
	camera.overview = auto_mode

func set_auto_mode(enabled: bool) -> void:
	if online_mode and enabled:
		return
	var was_auto := auto_mode
	auto_mode = enabled
	motion.autoplay = enabled
	turn_queue.clear()
	boost_held = false
	motion.boost_requested = false
	auto_restart_left = 5.0
	if endless_mode and not online_mode and state in ["playing", "paused"] and not sim.riders[player_rider_id()].alive:
		if enabled and not player_respawn_pending:
			player_respawn_pending = true
			respawn_timers[player_rider_id()] = AUTO_PLAYER_RESPAWN_DELAY
		elif not enabled and was_auto:
			player_respawn_pending = false
			respawn_timers[player_rider_id()] = -1.0
	# Keep the current segment intact; the next junction uses the new driver.
	if not enabled and sim.riders[player_rider_id()].alive:
		watch_id = 0
		camera.initialized = false
	overview_focus_id = watch_id if enabled or not sim.riders[player_rider_id()].alive else player_rider_id()
	update_pipe_display()

func set_hud_enabled(enabled: bool) -> void:
	hud_enabled = enabled
	update_hud_visibility()

func update_hud_visibility() -> void:
	# Menus remain accessible with Escape; resuming restores the clean view.
	hud.visible = hud_enabled or collision_feedback_time > 0.0 or state in ["ready", "paused", "finished"] or (hud.touch_ui_enabled and state in ["playing", "countdown"])
	if is_instance_valid(arena):
		arena.set_labels_visible(hud_enabled)
	for i in range(sim.riders.size()):
		var hidden_head := camera.first_person and i == watch_id and state not in ["ready", "finished"]
		pipes.markers[i].visible = hud_enabled and sim.riders[i].alive and not hidden_head and (not auto_mode or i == watch_id)

func toggle_pause() -> void:
	if state == "paused":
		state = paused_from
	elif state == "finished" and not auto_mode:
		show_title()
	elif state in ["playing", "countdown"] or (state == "finished" and auto_mode):
		paused_from = state
		state = "paused"
		boost_held = false

func primary_action() -> void:
	if state == "paused":
		state = paused_from
	elif state in ["ready", "finished"]:
		start_round()
	elif endless_mode and state == "playing" and not sim.riders[player_rider_id()].alive:
		request_player_restart()

func on_planned(indices: Array[int]) -> void:
	for i in indices:
		pipes.begin_rider(i, sim.riders[i], motion.directions[i])
	if sim.riders[player_rider_id()].alive:
		update_clearance()

func update_clearance() -> void:
	clearance = 0
	for distance in range(1, 11):
		if online_mode:
			break
		if not sim.is_open(sim.riders[player_rider_id()].cell + motion.directions[player_rider_id()] * distance):
			break
		clearance += 1

func on_completed(moves: Array[Dictionary]) -> void:
	var player_crash: Dictionary = {}
	var player_elimination: Dictionary = {}
	for move: Dictionary in moves:
		if move.died:
			if move.id == player_rider_id():
				player_crash = move
			elif int(move.get("pipe_owner", -1)) == player_rider_id():
				player_elimination = move
		if endless_mode and move.died:
			var dead_id: int = move.id
			if dead_id == 0:
				respawn_timers[dead_id] = AUTO_PLAYER_RESPAWN_DELAY if auto_mode else -1.0
				player_respawn_pending = auto_mode
				boost_held = false
				motion.boost_requested = false
				motion.turn_queue.clear()
			else:
				respawn_timers[dead_id] = roll_bot_respawn_delay()
		pipes.animate_rider(move.id, 1.0)
	for award: Dictionary in sim.scoring.last_awards:
		if award.rider_id != player_rider_id():
			continue
		var event_text := ""
		for event_name: String in award.events:
			var label := "ORB COLLECTED" if event_name == "ORB" else event_name
			event_text += (" + " if not event_text.is_empty() else "") + label
		score_message = "+%d  %s" % [award.points, event_text]
		if award.combo_count > 1:
			score_message += "  /  x%.1f COMBO" % award.multiplier
		score_message_time = 2.0 if "ELIMINATION" in award.events else 1.5
	pipes.commit(moves)
	orbs.sync(sim.scoring)
	if not player_crash.is_empty():
		collision_position = collision_world_position(player_crash)
		collision_feedback_label = collision_label_for_player_crash(player_crash)
		collision_feedback_time = COLLISION_FEEDBACK_DURATION
		camera.trigger_impact(1.0)
		if not endless_mode:
			crash_position = collision_position
			crash_view_time = CRASH_VIEW_DURATION
			camera.overview = true
			camera.initialized = false
	elif not player_elimination.is_empty():
		collision_position = collision_world_position(player_elimination)
		collision_feedback_label = "ELIMINATION / " + sim.rider_name(player_elimination.id).to_upper()
		collision_feedback_time = COLLISION_FEEDBACK_DURATION
		camera.trigger_impact(0.72)
	if not sim.riders[watch_id].alive and crash_view_time <= 0.0:
		var living := sim.alive_ids()
		if not living.is_empty():
			watch_id = living[0]
		if not auto_mode and not endless_mode:
			camera.overview = true
		camera.initialized = false
	if sim.finished:
		state = "finished"
		auto_restart_left = 5.0

func collision_world_position(move: Dictionary) -> Vector3:
	var target: Vector3i = move.target
	var target_position := sim.world(target)
	if not sim.inside(target):
		return (sim.world(move.cell) + target_position) * 0.5
	return target_position

func collision_label_for_player_crash(move: Dictionary) -> String:
	var cause: String = sim.riders[player_rider_id()].cause
	if cause == "Head-on collision":
		return "HEAD-ON COLLISION"
	if cause == "Another pipe":
		var owner_id: int = int(move.get("pipe_owner", -1))
		if owner_id >= 0:
			return "CRASHED INTO " + sim.rider_name(owner_id).to_upper()
		return "PIPE COLLISION"
	if cause == "Your own pipe":
		return "OWN PIPE COLLISION"
	return "WALL IMPACT"

func _process(delta: float) -> void:
	fov_message_time = maxf(0.0, fov_message_time - delta)
	collision_feedback_time = maxf(0.0, collision_feedback_time - delta)
	if online_mode and state in ["playing", "paused"] and online_step_active:
		var skipped := 0
		while online_state_queue.size() > ONLINE_BACKLOG_LIMIT and skipped < ONLINE_CATCH_UP_STEPS:
			_finish_online_step()
			skipped += 1
		online_progress = minf(1.0, online_progress + delta / online_step_duration)
		if online_progress >= 1.0:
			_finish_online_step()
	if state == "ready":
		advance_title_preview()
	elif state == "countdown":
		countdown -= delta
		if countdown <= 0.0:
			state = "playing"
	elif state == "playing":
		if not online_mode:
			motion.boost_requested = boost_held
			motion.advance(minf(delta, 0.1))
		score_message_time = maxf(0.0, score_message_time - delta)
		if endless_mode and not online_mode:
			advance_endless_respawns(delta)
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
			pipes.animate_rider(i, online_progress if online_mode else motion.progress(i))
	update_pipe_display()
	if not pipes.plans.is_empty() and (not endless_mode or sim.riders[watch_id].alive):
		if crash_view_time > 0.0:
			camera.boosting = false
			camera.focus_point(crash_position, delta)
			if state != "paused":
				crash_view_time = maxf(0.0, crash_view_time - delta)
				if crash_view_time <= 0.0:
					if not sim.riders[watch_id].alive:
						var living := sim.alive_ids()
						if not living.is_empty():
							watch_id = living[0]
					camera.initialized = false
		else:
			var head_pose := pipes.pose(watch_id, online_progress if online_mode else motion.progress(watch_id))
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
			if event.pressed and not event.echo:
				var horizontal := -1.0 if key == KEY_LEFT else 1.0 if key == KEY_RIGHT else 0.0
				var vertical := -1.0 if key == KEY_UP else 1.0 if key == KEY_DOWN else 0.0
				camera.orbit_step(horizontal, vertical)
				orbit_idle = 4.0
			return
		if key == KEY_SHIFT and not auto_mode:
			boost_held = event.pressed and state == "playing" and sim.riders[player_rider_id()].alive
			if online_connected:
				online_client.send_boost(boost_held, sim.ticks)
			if not event.pressed:
				sim.riders[player_rider_id()].boost_locked = false
		if not event.pressed or event.echo:
			return
		if key == KEY_Q and state in ["playing", "countdown", "paused", "finished"]:
			adjust_camera_fov(-2.0)
		elif key == KEY_E and state in ["playing", "countdown", "paused", "finished"]:
			adjust_camera_fov(2.0)
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			primary_action()
		elif key == KEY_ESCAPE:
			toggle_pause()
		elif key == KEY_F:
			set_auto_mode(not auto_mode)
		elif key == KEY_H:
			set_hud_enabled(not hud_enabled)
		elif key == KEY_R:
			if online_mode:
				if state == "playing" and not sim.riders[player_rider_id()].alive:
					request_player_restart()
				return
			if endless_mode and state == "playing" and not sim.riders[player_rider_id()].alive:
				request_player_restart()
			else:
				start_round()
		elif key == KEY_C:
			swap_camera_view()
		elif key == KEY_V and camera.overview and state != "ready" and crash_view_time <= 0.0:
			cycle_overview_style()
		elif key == KEY_TAB and camera.overview and state != "ready" and crash_view_time <= 0.0:
			cycle_overview_focus(-1 if event.shift_pressed else 1)
		elif key == KEY_TAB and (auto_mode or not sim.riders[player_rider_id()].alive):
			var alive := sim.alive_ids()
			if not alive.is_empty():
				var step := -1 if event.shift_pressed else 1
				watch_id = alive[(alive.find(watch_id) + step + alive.size()) % alive.size()]
				camera.initialized = false
		elif state in ["playing", "countdown"] and sim.riders[player_rider_id()].alive and not auto_mode:
			var command := ""
			match key:
				KEY_W: command = "up"
				KEY_S: command = "down"
				KEY_A: command = "left"
				KEY_D: command = "right"
			if not command.is_empty():
				queue_turn(command)
	elif event is InputEventMouseMotion and camera.overview and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera.orbit(event.relative)
		orbit_idle = 4.0
	elif event is InputEventMouseButton and event.pressed and camera.overview:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom(-3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom(3.0)

func queue_turn(command: String) -> void:
	if state not in ["playing", "countdown"] or not sim.riders[player_rider_id()].alive or auto_mode:
		return
	if command not in ["up", "down", "left", "right"]:
		return
	if online_mode:
		if online_connected:
			online_client.send_turn(command, sim.ticks)
		return
	if turn_queue.size() < 2:
		turn_queue.append(command)

func set_touch_boost(held: bool) -> void:
	boost_held = held and state == "playing" and not auto_mode and sim.riders[player_rider_id()].alive
	if online_connected:
		online_client.send_boost(boost_held, sim.ticks)
	if not held:
		sim.riders[player_rider_id()].boost_locked = false

func orbit_camera_from_touch(relative: Vector2) -> void:
	camera.orbit(relative)
	orbit_idle = 4.0

func zoom_camera_from_touch(distance_change: float) -> void:
	var zoom_amount := distance_change * 0.04
	if camera.overview:
		camera.zoom(-zoom_amount)
	else:
		camera.set_base_fov(camera.base_fov - zoom_amount)

func swap_camera_view() -> void:
	camera.toggle()
	if camera.overview and (auto_mode or not sim.riders[player_rider_id()].alive):
		overview_focus_id = watch_id
	update_pipe_display()
	fov_message = camera.view_name()
	fov_message_time = 1.5

func update_pipe_display() -> void:
	var active_overview := camera.overview and state != "ready" and crash_view_time <= 0.0
	pipes.set_overview_style(overview_style if active_overview else PipeRenderer.OverviewStyle.NORMAL,
		overview_focus_id)
	hud.queue_redraw()

func cycle_overview_style() -> void:
	overview_style = (overview_style + 1) % PipeRenderer.OverviewStyle.size()
	update_pipe_display()
	fov_message = "PIPE VIEW / " + overview_style_name()
	fov_message_time = 1.5

func cycle_overview_focus(step: int) -> void:
	var alive := sim.alive_ids()
	if alive.is_empty():
		return
	var index := alive.find(overview_focus_id)
	if index < 0:
		index = 0 if step > 0 else alive.size()
	index = (index + step + alive.size()) % alive.size()
	overview_focus_id = alive[index]
	if auto_mode or not sim.riders[player_rider_id()].alive:
		watch_id = overview_focus_id
		camera.initialized = false
	overview_style = PipeRenderer.OverviewStyle.HIGHLIGHT
	update_pipe_display()
	fov_message = "HIGHLIGHT / " + sim.rider_name(overview_focus_id).to_upper()
	fov_message_time = 1.5

func overview_style_name() -> String:
	match overview_style:
		PipeRenderer.OverviewStyle.HIGHLIGHT: return "HIGHLIGHT"
		PipeRenderer.OverviewStyle.ENDS: return "BRIGHT ENDS"
	return "NORMAL"

func adjust_camera_fov(change: float) -> void:
	camera.set_base_fov(camera.base_fov + change)
	fov_message = "FOV / %d°" % roundi(camera.base_fov)
	fov_message_time = 1.5

func set_endless_mode(enabled: bool) -> void:
	endless_mode = enabled
	hud.queue_redraw()

func connect_online(server_url: String, room_id: String) -> void:
	var normalized_url := server_url.strip_edges()
	if normalized_url.is_empty():
		normalized_url = online_server_url
	var normalized_room := room_id.strip_edges().to_upper()
	if normalized_room.is_empty():
		normalized_room = "PUBLIC"
	online_server_url = normalized_url
	online_room_id = normalized_room
	online_status = "CONNECTING"
	online_connected = false
	online_mode = false
	online_player_slot = -1
	online_last_state.clear()
	online_state_queue.clear()
	online_step_active = false
	player_respawn_pending = false
	hud.queue_redraw()
	var error := online_client.connect_to_room(normalized_url, normalized_room, player_name, player_color)
	if error != OK:
		online_status = "CONNECT ERROR %d" % error
		hud.queue_redraw()

func disconnect_online() -> void:
	online_client.leave("left")
	online_client.close()
	online_connected = false
	online_mode = false
	online_player_slot = -1
	online_status = "OFFLINE"
	online_last_state.clear()
	online_state_queue.clear()
	online_step_active = false
	player_respawn_pending = false
	hud.queue_redraw()

func _on_online_welcome(message: Dictionary) -> void:
	online_connected = true
	online_status = "CONNECTED"
	online_mode = true
	# Auto Mode is a local solo assist and is never allowed to drive an online slot.
	auto_mode = false
	motion.autoplay = false
	boost_held = false
	turn_queue.clear()
	state = "playing"
	countdown = 0.0
	camera.overview = true
	camera.initialized = false
	online_progress = 0.0
	online_state_queue.clear()
	online_step_active = false
	player_respawn_pending = false
	var player: Dictionary = message.get("player", {})
	online_player_slot = int(player.get("slot", -1))
	var room: Dictionary = message.get("room", {})
	online_room_id = str(room.get("room_id", online_room_id))
	endless_mode = str(room.get("mode", "endless")) == "endless"
	hud.queue_redraw()

func _on_online_state(message: Dictionary) -> void:
	online_last_state = message
	if bool(message.get("full_snapshot", false)):
		online_state_queue.clear()
		online_step_active = false
		online_progress = 0.0
		_apply_online_state(message)
	else:
		online_state_queue.append(message)
		if not online_step_active:
			_begin_online_step()
	if online_connected:
		online_status = "SYNCED / TICK %d" % int(message.get("tick", 0))
	hud.queue_redraw()

func _on_online_event(message: Dictionary) -> void:
	var event_name := str(message.get("event", "")).to_upper()
	if online_connected and not event_name.is_empty():
		online_status = "%s / %d PLAYERS" % [event_name, int(message.get("room", {}).get("human_count", 0))]
	hud.queue_redraw()

func _on_online_rejected(reason: String) -> void:
	online_connected = false
	online_mode = false
	online_state_queue.clear()
	online_step_active = false
	online_player_slot = -1
	player_respawn_pending = false
	online_status = "REJECTED / " + reason
	hud.queue_redraw()

func _on_online_connection_failed(reason: String) -> void:
	online_connected = false
	online_mode = false
	online_state_queue.clear()
	online_step_active = false
	player_respawn_pending = false
	online_status = "CONNECT ERROR / " + reason
	hud.queue_redraw()

func _on_online_disconnected(reason: String) -> void:
	if online_status.begins_with("REJECTED /"):
		return
	online_connected = false
	online_mode = false
	online_state_queue.clear()
	online_step_active = false
	online_player_slot = -1
	player_respawn_pending = false
	online_status = "DISCONNECTED" if reason.is_empty() else "DISCONNECTED / " + reason
	hud.queue_redraw()

func request_player_restart() -> void:
	if state != "playing" or sim.riders[player_rider_id()].alive:
		return
	if online_mode:
		if online_connected and endless_mode and not player_respawn_pending:
			online_client.send_respawn()
			player_respawn_pending = true
			hud.queue_redraw()
		return
	if not endless_mode:
		start_round()
		return
	player_respawn_pending = true
	respawn_timers[0] = 0.0
	advance_endless_respawns(0.0)

func player_rider_id() -> int:
	if online_mode and online_player_slot >= 0 and online_player_slot < sim.riders.size():
		return online_player_slot
	return 0

func _vector_from_wire(value, fallback: Vector3i = Vector3i.ZERO) -> Vector3i:
	if value is Array and value.size() >= 3:
		return Vector3i(int(value[0]), int(value[1]), int(value[2]))
	return fallback

func _wire_rider(wire: Dictionary, current: Dictionary = {}) -> Dictionary:
	var rider := current.duplicate()
	rider.cell = _vector_from_wire(wire.get("cell"), rider.get("cell", Vector3i.ZERO))
	rider.forward = _vector_from_wire(wire.get("forward"), rider.get("forward", Vector3i.FORWARD))
	rider.up = _vector_from_wire(wire.get("up"), rider.get("up", Vector3i.UP))
	rider.source_cell = _vector_from_wire(wire.get("source_cell"), rider.cell)
	rider.source_forward = _vector_from_wire(wire.get("source_forward"), rider.forward)
	for key in ["alive", "length", "score", "pressure", "boosting", "cause", "orb_count",
			"eliminations", "combo_count", "combo_multiplier", "combo_time", "name"]:
		if wire.has(key):
			rider[key] = wire[key]
	if wire.has("color"):
		rider.color = Color.from_string(str(wire.color), rider.get("color", player_color))
	return rider

func _wire_move(wire: Dictionary) -> Dictionary:
	return {"id": int(wire.get("id", -1)),
		"cell": _vector_from_wire(wire.get("cell")),
		"target": _vector_from_wire(wire.get("target")),
		"incoming": _vector_from_wire(wire.get("incoming"), Vector3i.FORWARD),
		"outgoing": _vector_from_wire(wire.get("outgoing"), Vector3i.FORWARD),
		"up": _vector_from_wire(wire.get("up"), Vector3i.UP),
		"died": bool(wire.get("died", false)),
		"pipe_owner": int(wire.get("pipe_owner", -1))}

func _begin_online_step() -> void:
	if online_state_queue.is_empty() or not online_mode:
		return
	var message: Dictionary = online_state_queue[0]
	var moves: Array = message.get("moves", [])
	if moves.is_empty():
		online_state_queue.pop_front()
		_apply_online_state(message)
		_begin_online_step()
		return
	for raw_move in moves:
		if not raw_move is Dictionary:
			continue
		var move := _wire_move(raw_move)
		if move.id >= 0 and move.id < sim.riders.size():
			pipes.begin_rider(move.id,
				{"cell": move.cell, "forward": move.incoming, "up": move.up, "alive": true},
				move.outgoing)
	online_progress = 0.0
	# A short catch-up step prevents an occasional packet burst from growing into seconds of delay.
	var packet_duration := maxf(0.08, float(message.get("step_duration", Rules.STEP_TIME)))
	online_step_duration = maxf(0.08,
		packet_duration / (1.0 + 0.25 * max(0, online_state_queue.size() - 1)))
	online_step_active = true

func _finish_online_step() -> void:
	if not online_step_active or online_state_queue.is_empty():
		return
	var message: Dictionary = online_state_queue.pop_front()
	for raw_move in message.get("moves", []):
		if not raw_move is Dictionary:
			continue
		var rider_id := int(raw_move.get("id", -1))
		if rider_id >= 0 and rider_id < sim.riders.size():
			pipes.animate_rider(rider_id, 1.0)
	_apply_online_state(message)
	online_progress = 0.0
	online_step_active = false
	_begin_online_step()

func _apply_online_state(message: Dictionary) -> void:
	if not online_mode:
		return
	var wires: Array = message.get("riders", [])
	if wires.is_empty():
		return
	var full := bool(message.get("full_snapshot", false))
	var previously_alive: Array[bool] = []
	for rider: Dictionary in sim.riders:
		previously_alive.append(bool(rider.alive))
	if full or sim.riders.size() != wires.size():
		sim.endless_mode = endless_mode
		sim.reset(int(str(message.get("tick", 0))) + 1701, maxi(wires.size() - 1, 1), 60,
			player_name, player_color)
		pipes.player_id = online_player_slot
	for i in range(mini(wires.size(), sim.riders.size())):
		if wires[i] is Dictionary:
			sim.riders[i] = _wire_rider(wires[i], sim.riders[i])
	var player_id := player_rider_id()
	if player_id >= 0 and player_id < sim.riders.size():
		if sim.riders[player_id].alive or (player_id < previously_alive.size() and previously_alive[player_id]):
			player_respawn_pending = false
	sim.ticks = int(message.get("tick", sim.ticks))
	sim.finished = false
	sim.winner = -1
	sim.scoring.orbs.clear()
	for raw_orb in message.get("orbs", []):
		if raw_orb is Dictionary:
			sim.scoring.orbs[_vector_from_wire(raw_orb.get("cell"))] = int(raw_orb.get("points", 0))
	var histories: Array = []
	if full:
		sim.occupied.clear()
		for i in range(wires.size()):
			var rider_history: Array = []
			if i < Array(message.get("history", [])).size():
				for raw_move in Array(message.get("history", [])[i]):
					var move := _wire_move(raw_move)
					rider_history.append(move)
					sim.occupied[move.cell] = i
					sim.occupied[move.target] = i
			histories.append(rider_history)
			if i < sim.riders.size() and sim.riders[i].alive:
				sim.occupied[sim.riders[i].cell] = i
		pipes.rebuild_from_history(histories)
		motion.reset()
		watch_id = player_rider_id()
		overview_focus_id = watch_id
		camera.initialized = false
	else:
		var moves: Array[Dictionary] = []
		var player_crash: Dictionary = {}
		for raw_move in message.get("moves", []):
			var move := _wire_move(raw_move)
			moves.append(move)
			if move.id == player_rider_id() and move.died:
				player_crash = move
		pipes.commit(moves)
		if not player_crash.is_empty():
			collision_position = collision_world_position(player_crash)
			collision_feedback_label = collision_label_for_player_crash(player_crash)
			collision_feedback_time = COLLISION_FEEDBACK_DURATION
			camera.trigger_impact(1.0)
		for i in range(mini(wires.size(), sim.riders.size())):
			if sim.riders[i].alive:
				pipes.begin_rider(i, sim.riders[i], sim.riders[i].forward)
				if i >= previously_alive.size() or not previously_alive[i]:
					pipes.restore_rider(i, sim.riders[i])
		online_progress = 0.0
	if online_connected:
		online_status = "SYNCED / TICK %d" % sim.ticks
	orbs.sync(sim.scoring)
	hud.queue_redraw()

func roll_bot_respawn_delay() -> float:
	return respawn_rng.randf_range(BOT_RESPAWN_MIN_DELAY, BOT_RESPAWN_MAX_DELAY)

func advance_endless_respawns(delta: float) -> void:
	for i in range(sim.riders.size()):
		if sim.riders[i].alive:
			continue
		if i == 0 and not player_respawn_pending:
			continue
		if i > 0 and respawn_timers[i] < 0.0:
			continue
		respawn_timers[i] = maxf(0.0, respawn_timers[i] - delta)
		if respawn_timers[i] > 0.0:
			continue
		if not sim.respawn_rider(i):
			respawn_timers[i] = RESPAWN_RETRY_DELAY
			continue
		respawn_timers[i] = -1.0
		if i == 0:
			player_respawn_pending = false
			watch_id = 0
		else:
			sim.cycle_bot_identity(i)
			pipes.reroll_bot_appearance(i)
			if not sim.riders[watch_id].alive:
				watch_id = i
		pipes.restore_rider(i, sim.riders[i])
		motion.respawn_rider(i)
		camera.initialized = false
		update_hud_visibility()
