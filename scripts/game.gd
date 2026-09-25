extends Node3D

const Rules = preload("res://scripts/simulation.gd")
const Motion = preload("res://scripts/motion.gd")
const PipeRenderer = preload("res://scripts/pipe_renderer.gd")
const BotStyle = preload("res://scripts/bot_style.gd")
const Arena = preload("res://scripts/arena.gd")
const CameraRig = preload("res://scripts/camera_rig.gd")
const Hud = preload("res://scripts/hud.gd")
const OrbRenderer = preload("res://scripts/orb_renderer.gd")
const MultiplayerClient = preload("res://scripts/multiplayer_client.gd")
const OnlinePlayback = preload("res://scripts/online_playback.gd")
const AUTO_PLAYER_RESPAWN_DELAY := 2.5
const BOT_RESPAWN_MIN_DELAY := 4.0
const BOT_RESPAWN_MAX_DELAY := 12.0
const RESPAWN_RETRY_DELAY := 0.75
const TITLE_CAMERA_OVERVIEW_MIN := 4.5
const TITLE_CAMERA_OVERVIEW_MAX := 7.0
const TITLE_CAMERA_CHASE_MIN := 3.5
const TITLE_CAMERA_CHASE_MAX := 5.5
const TITLE_RESTART_DELAY := 1.2
const TITLE_WARMUP_STEPS := 18
const CRASH_VIEW_DURATION := 1.25
const COLLISION_FEEDBACK_DURATION := 2.0
var sim := Rules.new()
var motion := Motion.new(sim)
var pipes := PipeRenderer.new()
var camera := CameraRig.new()
var hud := Hud.new()
var orbs := OrbRenderer.new()
var online_playback := OnlinePlayback.new(sim, pipes, orbs)
var world_layer := CanvasLayer.new()
var world_container := SubViewportContainer.new()
var world_viewport := SubViewport.new()
var state := "ready"
var countdown := 3.0
var bot_count := Rules.DEFAULT_BOTS
var arena_width := 60
var player_name := "YOU"
var player_color := Color("56eddf")
var player_secondary_color := Color.TRANSPARENT
var player_detail_color := Color.TRANSPARENT
var player_pattern := PipeRenderer.Appearance.Pattern.SOLID
var player_material := PipeRenderer.Appearance.Finish.ALLOY
var player_joint_style := PipeRenderer.Appearance.JointStyle.COLLARED
var bot_palette := BotStyle.Palette.STANDARD
var bot_custom_saturation := 0.65
var bot_custom_brightness := 0.8
var bot_pattern_mix := BotStyle.PatternMix.ALL
var bot_custom_pattern_mask := BotStyle.ALL_PATTERNS_MASK
var reduced_glow := false
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
var window_mode_before_fullscreen := DisplayServer.WINDOW_MODE_WINDOWED
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
var title_exhibition := false
var title_camera_time := 0.0
var title_restart_time := 0.0
var title_rng := RandomNumberGenerator.new()
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
var online_last_state: Dictionary:
	get: return online_playback.last_state
var online_mode := false

func _ready() -> void:
	respawn_rng.randomize()
	title_rng.randomize()
	if not DisplayServer.is_touchscreen_available():
		DisplayServer.window_set_min_size(Vector2i(960, 600))
	pipes.model = sim
	orbs.model = sim
	world_layer.layer = -1
	add_child(world_layer)
	world_layer.add_child(world_container)
	world_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_container.stretch = false
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_viewport.size = Vector2i(814, 726)
	world_container.add_child(world_viewport)
	world_viewport.add_child(pipes)
	world_viewport.add_child(orbs)
	world_viewport.add_child(camera)
	add_child(online_client)
	online_client.connected_to_room.connect(_on_online_welcome)
	online_client.state_received.connect(_on_online_state)
	online_client.room_event.connect(_on_online_event)
	online_client.connection_rejected.connect(_on_online_rejected)
	online_client.connection_failed.connect(_on_online_connection_failed)
	online_client.disconnected.connect(_on_online_disconnected)
	online_playback.state_applied.connect(_on_online_state_applied)
	var layer := CanvasLayer.new()
	layer.layer = 1
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
		set_boost(false)
		if state == "playing" and not automated and not auto_mode:
			paused_from = state
			state = "paused")
	show_title()
	update_world_viewport_layout()
	if "--qa" in OS.get_cmdline_user_args():
		automated = true
		var driver = load("res://tests/visual_smoke.gd").new()
		driver.game = self
		add_child(driver)

func reset_world(seed_value: int = 0, title_preview: bool = false) -> void:
	hud.cancel_touch_input()
	if online_mode or online_connected or online_status == "CONNECTING":
		_end_online_session("OFFLINE")
	online_playback.reset()
	pipes.player_id = 0
	title_exhibition = title_preview
	title_restart_time = 0.0
	crash_view_time = 0.0
	collision_feedback_time = 0.0
	collision_feedback_label = ""
	sim.endless_mode = endless_mode
	sim.reset(seed_value, bot_count, arena_width, player_name, player_color)
	for i in range(1, sim.riders.size()):
		sim.riders[i].color = BotStyle.color_for(sim.riders[i].color, bot_palette,
			bot_custom_saturation, bot_custom_brightness)
	respawn_timers.clear()
	for i in range(sim.riders.size()):
		respawn_timers.append(-1.0)
	player_respawn_pending = false
	sync_arena_size()
	camera.chase_distance = 10.0 if title_exhibition else camera.DEFAULT_CHASE_DISTANCE
	pipes.player_pattern = player_pattern
	pipes.player_material = player_material
	pipes.player_joint_style = player_joint_style
	pipes.player_secondary_color = player_secondary_color
	pipes.player_detail_color = player_detail_color
	pipes.bot_palette = bot_palette
	pipes.bot_pattern_mix = bot_pattern_mix
	pipes.bot_custom_pattern_mask = bot_custom_pattern_mask
	pipes.reduced_glow = reduced_glow
	pipes.reset(sim.riders.size())
	motion.autoplay = title_exhibition or auto_mode
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

func sync_arena_size() -> void:
	if not is_instance_valid(arena) or arena.width != sim.arena_width:
		if is_instance_valid(arena):
			world_viewport.remove_child(arena)
			arena.queue_free()
		arena = Arena.new()
		arena.width = sim.arena_width
		world_viewport.add_child(arena)
	camera.set_arena_size(sim.arena_width)

func show_title() -> void:
	reset_world(int(title_rng.randi()), true)
	state = "ready"
	for step in range(TITLE_WARMUP_STEPS):
		if sim.finished:
			break
		motion.advance(Rules.STEP_TIME)
	camera.overview = true
	camera.yaw = title_rng.randf_range(-PI, PI)
	camera.pitch = title_rng.randf_range(0.28, 0.58)
	camera.distance = float(arena_width) * title_rng.randf_range(1.3, 1.55)
	camera.initialized = false
	title_camera_time = title_rng.randf_range(TITLE_CAMERA_OVERVIEW_MIN, TITLE_CAMERA_OVERVIEW_MAX)

func advance_title_preview(delta: float = Rules.STEP_TIME) -> void:
	if not title_exhibition or state != "ready":
		return
	if sim.finished:
		title_restart_time = maxf(0.0, title_restart_time - delta)
		if title_restart_time <= 0.0:
			show_title()
		return
	motion.autoplay = true
	motion.advance(minf(delta, 0.1))
	if endless_mode:
		advance_endless_respawns(delta)
	title_camera_time = maxf(0.0, title_camera_time - delta)
	if title_camera_time <= 0.0:
		advance_title_camera()
	state = "ready"

func advance_title_camera() -> void:
	var living := sim.alive_ids()
	if living.is_empty():
		return
	if camera.overview:
		var chase_candidates: Array[int] = []
		for rider_id: int in living:
			var rider_position: Vector3 = sim.world(sim.riders[rider_id].cell)
			if maxf(absf(rider_position.x), maxf(absf(rider_position.y), absf(rider_position.z))) \
					< float(arena_width) * 0.34:
				chase_candidates.append(rider_id)
		var target_pool: Array[int] = chase_candidates if not chase_candidates.is_empty() else living
		var next_watch: int = target_pool[title_rng.randi_range(0, target_pool.size() - 1)]
		if target_pool.size() > 1 and next_watch == watch_id:
			next_watch = target_pool[(target_pool.find(next_watch) + 1) % target_pool.size()]
		watch_id = next_watch
		overview_focus_id = watch_id
		camera.view = camera.View.CHASE
		camera.chase_distance = title_rng.randf_range(14.0, 18.0)
		camera.chase_yaw = title_rng.randf_range(-0.12, 0.12)
		camera.chase_pitch = title_rng.randf_range(0.65, 0.95)
		title_camera_time = title_rng.randf_range(TITLE_CAMERA_CHASE_MIN, TITLE_CAMERA_CHASE_MAX)
	else:
		camera.view = camera.View.OVERVIEW
		camera.yaw = title_rng.randf_range(-PI, PI)
		camera.pitch = title_rng.randf_range(0.24, 0.68)
		camera.distance = float(arena_width) * title_rng.randf_range(1.25, 1.6)
		title_camera_time = title_rng.randf_range(TITLE_CAMERA_OVERVIEW_MIN, TITLE_CAMERA_OVERVIEW_MAX)
	camera.initialized = false
	update_pipe_display()

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

func is_fullscreen() -> bool:
	return not OS.has_feature("web") and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

func set_fullscreen(enabled: bool) -> void:
	if OS.has_feature("web"):
		return
	var current_mode := DisplayServer.window_get_mode()
	if enabled and current_mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		window_mode_before_fullscreen = current_mode
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not enabled and current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(window_mode_before_fullscreen)
	if is_instance_valid(hud):
		hud.queue_redraw()

func update_hud_visibility() -> void:
	# Menus remain accessible with Escape; resuming restores the clean view.
	var menu_visible := state in ["ready", "paused"] or (state == "finished" and not auto_mode)
	hud.visible = hud_enabled or collision_feedback_time > 0.0 or menu_visible \
		or (hud.touch_ui_enabled and state in ["playing", "countdown"])
	if is_instance_valid(arena):
		arena.set_labels_visible(hud_enabled and state != "ready")
	for i in range(sim.riders.size()):
		var hidden_head := camera.first_person and i == watch_id and state not in ["ready", "finished"]
		pipes.markers[i].visible = hud_enabled and state != "ready" and sim.riders[i].alive \
			and not hidden_head and (not auto_mode or i == watch_id)

func toggle_pause() -> void:
	if state == "paused":
		state = paused_from
	elif state == "finished" and not auto_mode:
		show_title()
	elif state in ["playing", "countdown"] or (state == "finished" and auto_mode):
		paused_from = state
		state = "paused"
		set_boost(false)

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
			if not title_exhibition:
				if move.id == player_rider_id():
					player_crash = move
				elif int(move.get("pipe_owner", -1)) == player_rider_id():
					player_elimination = move
		if endless_mode and move.died:
			var dead_id: int = move.id
			if title_exhibition:
				respawn_timers[dead_id] = title_rng.randf_range(1.5, 3.5)
				if dead_id == 0:
					player_respawn_pending = true
			elif dead_id == 0:
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
		if not title_exhibition and not auto_mode and not endless_mode:
			camera.overview = true
		camera.initialized = false
	if sim.finished:
		if title_exhibition:
			title_restart_time = TITLE_RESTART_DELAY
		else:
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
	update_world_viewport_layout()
	fov_message_time = maxf(0.0, fov_message_time - delta)
	collision_feedback_time = maxf(0.0, collision_feedback_time - delta)
	if online_mode and state in ["playing", "paused"]:
		online_playback.advance(delta)
	if state == "ready":
		advance_title_preview(delta)
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
	if title_exhibition and camera.overview:
		camera.yaw += delta * 0.075
	elif auto_mode and camera.overview and state in ["countdown", "playing", "finished"] and orbit_idle <= 0.0:
		camera.yaw += delta * 0.055
	for i in range(sim.riders.size()):
		if sim.riders[i].alive:
			pipes.animate_rider(i, online_playback.progress if online_mode else motion.progress(i))
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
			var head_pose := pipes.pose(watch_id, online_playback.progress if online_mode else motion.progress(watch_id))
			camera.boosting = sim.riders[watch_id].boosting and state == "playing"
			camera.follow(head_pose, delta, state == "finished" or (state == "ready" and not title_exhibition))
		for i in range(sim.riders.size()):
			var hidden := camera.first_person and i == watch_id and state not in ["ready", "finished"]
			pipes.heads[i].visible = sim.riders[i].alive and not hidden
		if state == "ready":
			camera.yaw += delta * 0.055
	pipes.update_cutaway(camera, watch_id,
		state in ["countdown", "playing", "paused"] and crash_view_time <= 0.0
		and sim.riders[watch_id].alive and camera.view == camera.View.CHASE)
	update_hud_visibility()

func update_world_viewport_layout() -> void:
	if not is_instance_valid(world_container) or not is_instance_valid(hud):
		return
	var available := get_viewport().get_visible_rect().size
	var framed := not hud.touch_ui_enabled and (hud_enabled or state in ["ready", "paused", "finished"])
	var view_rect := Rect2(Vector2.ZERO, available)
	if framed:
		var scale := maxf(minf(available.x / 1392.0, available.y / 868.0), 0.45)
		var wide_offset := maxf(0.0, available.x / scale - 1392.0)
		var origin := Vector2(-24.0 * scale,
			(available.y - 868.0 * scale) / 2.0 - 16.0 * scale)
		view_rect = Rect2(origin + Vector2(36, 114) * scale,
			Vector2(814.0 + wide_offset, 726.0) * scale)
	world_container.position = view_rect.position
	world_container.size = view_rect.size
	var render_size := Vector2i(roundi(view_rect.size.x), roundi(view_rect.size.y))
	if world_viewport.size != render_size:
		world_viewport.size = render_size

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
			set_boost(event.pressed)
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
		elif key == KEY_F11:
			set_fullscreen(not is_fullscreen())
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
	set_boost(held)

func set_boost(held: bool) -> void:
	boost_held = held and state == "playing" and not auto_mode and sim.riders[player_rider_id()].alive
	if online_mode and online_connected:
		online_client.send_boost(boost_held, sim.ticks)
	if not held:
		motion.boost_requested = false
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
	finish_camera_view_change()

func select_camera_view(view_id: int) -> void:
	camera.set_view(view_id)
	finish_camera_view_change()

func finish_camera_view_change() -> void:
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

func select_spectator_rider(rider_id: int) -> void:
	if state not in ["countdown", "playing"] or rider_id < 0 or rider_id >= sim.riders.size():
		return
	if not (auto_mode or not sim.riders[player_rider_id()].alive) or not sim.riders[rider_id].alive:
		return
	watch_id = rider_id
	overview_focus_id = rider_id
	camera.initialized = false
	update_pipe_display()
	fov_message = "FOLLOWING / " + sim.rider_name(rider_id).to_upper()
	fov_message_time = 1.5
	hud.queue_redraw()

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
	if state == "ready":
		show_title()
	hud.queue_redraw()

func connect_online(server_url: String, room_id: String) -> void:
	var normalized_url := server_url.strip_edges()
	if normalized_url.is_empty():
		normalized_url = online_server_url
	var normalized_room := room_id.strip_edges().to_upper()
	if normalized_room.is_empty():
		normalized_room = "PUBLIC"
	_end_online_session("OFFLINE", true)
	online_server_url = normalized_url
	online_room_id = normalized_room
	online_status = "CONNECTING"
	hud.queue_redraw()
	var error := online_client.connect_to_room(normalized_url, normalized_room, player_name, player_color)
	if error != OK:
		online_status = "CONNECT ERROR %d" % error
		hud.queue_redraw()

func disconnect_online() -> void:
	_end_online_session("OFFLINE", true)

func _end_online_session(status_text: String, return_to_title: bool = false) -> void:
	var was_online := online_mode
	online_client.leave("left")
	online_client.close()
	online_connected = false
	online_mode = false
	online_player_slot = -1
	online_status = "OFFLINE"
	online_playback.reset()
	boost_held = false
	motion.boost_requested = false
	turn_queue.clear()
	player_respawn_pending = false
	if return_to_title and was_online:
		show_title()
	online_status = status_text
	hud.queue_redraw()

func _on_online_welcome(message: Dictionary) -> void:
	online_connected = true
	online_status = "CONNECTED"
	online_mode = true
	title_exhibition = false
	title_camera_time = 0.0
	title_restart_time = 0.0
	crash_view_time = 0.0
	collision_feedback_time = 0.0
	camera.chase_distance = camera.DEFAULT_CHASE_DISTANCE
	# Auto Mode is a local solo assist and is never allowed to drive an online slot.
	auto_mode = false
	motion.autoplay = false
	motion.boost_requested = false
	boost_held = false
	turn_queue.clear()
	state = "playing"
	countdown = 0.0
	camera.overview = true
	camera.initialized = false
	online_playback.reset()
	player_respawn_pending = false
	var player: Dictionary = message.get("player", {})
	online_player_slot = int(player.get("slot", -1))
	var room: Dictionary = message.get("room", {})
	online_room_id = str(room.get("room_id", online_room_id))
	endless_mode = str(room.get("mode", "endless")) == "endless"
	sim.endless_mode = endless_mode
	hud.queue_redraw()

func _on_online_state(message: Dictionary) -> void:
	if not online_mode or not online_connected:
		return
	sim.endless_mode = endless_mode
	online_playback.player_id = maxi(online_player_slot, 0)
	online_playback.receive(message)
	if online_connected:
		online_status = "SYNCED / TICK %d" % int(message.get("tick", 0))
	hud.queue_redraw()

func _on_online_state_applied(full: bool, previously_alive: Array[bool], player_crash: Dictionary) -> void:
	var player_id := player_rider_id()
	if sim.riders[player_id].alive or (player_id < previously_alive.size() and previously_alive[player_id]):
		player_respawn_pending = false
	if full:
		sync_arena_size()
		watch_id = player_id
		overview_focus_id = watch_id
		camera.initialized = false
	if not player_crash.is_empty():
		collision_position = collision_world_position(player_crash)
		collision_feedback_label = collision_label_for_player_crash(player_crash)
		collision_feedback_time = COLLISION_FEEDBACK_DURATION
		camera.trigger_impact(1.0)
	if online_connected:
		online_status = "SYNCED / TICK %d" % sim.ticks
	hud.queue_redraw()

func _on_online_event(message: Dictionary) -> void:
	var event_name := str(message.get("event", "")).to_upper()
	if online_connected and not event_name.is_empty():
		online_status = "%s / %d PLAYERS" % [event_name, int(message.get("room", {}).get("human_count", 0))]
	hud.queue_redraw()

func _on_online_rejected(reason: String) -> void:
	_end_online_session("REJECTED / " + reason, true)

func _on_online_connection_failed(reason: String) -> void:
	_end_online_session("CONNECT ERROR / " + reason, true)

func _on_online_disconnected(reason: String) -> void:
	if online_status.begins_with("REJECTED /"):
		return
	_end_online_session("DISCONNECTED" if reason.is_empty() else "DISCONNECTED / " + reason, true)

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
			if not title_exhibition:
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
