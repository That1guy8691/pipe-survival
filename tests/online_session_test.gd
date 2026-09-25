extends SceneTree
## Room transitions must not leak server state into a local round.

const Protocol = preload("res://scripts/multiplayer_protocol.gd")
var checks := 0
var failures := 0

class RecordingClient:
	extends "res://scripts/multiplayer_client.gd"
	var leaves := 0
	var closes := 0
	var boosts: Array[bool] = []

	func leave(_reason: String = "left") -> void:
		leaves += 1

	func close() -> void:
		closes += 1

	func send_boost(enabled: bool, _sequence: int = 0) -> void:
		boosts.append(enabled)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	game.set_process(false)
	game.arena_width = 80
	game.bot_count = 0
	game.show_title()
	var original_client = game.online_client
	var recorder := RecordingClient.new()
	game.online_client = recorder
	game._on_online_welcome({"player": {"slot": 1}, "room": {"mode": "endless"}})
	check(not game.title_exhibition, "Joining a room ends title exhibition behavior")
	var server_sim = game.Rules.new()
	server_sim.reset(1701, 1, 60)
	server_sim.riders[1].boosting = true
	var snapshot := Protocol.parse_packet(Protocol.state_message({}, 0, server_sim.riders,
		[], [[], []], true).to_utf8_buffer())
	game._on_online_state(snapshot)
	check(game.sim.riders.size() == 2 and game.pipes.player_id == 1 and game.watch_id == 1,
		"Joining from solo play assigns the authoritative player slot")
	check(game.sim.riders[1].boosting,
		"Applying a server snapshot does not run local bot decisions over server boost state")
	check(game.arena.width == 60 and game.camera.arena_width == 60,
		"Online geometry and camera bounds use the server arena instead of local options")
	game.set_touch_boost(true)
	game.toggle_pause()
	check(not game.boost_held and recorder.boosts == [true, false],
		"Opening the pause menu releases boost on the server")
	game.primary_action()
	game.set_touch_boost(true)
	game.get_window().focus_exited.emit()
	check(not game.boost_held and not recorder.boosts.back(),
		"Losing focus releases boost on the server")

	var riders: Array[Dictionary] = []
	for rider: Dictionary in game.sim.riders.slice(0, 2):
		riders.append(rider.duplicate(true))
	var stale_packet := Protocol.parse_packet(Protocol.state_message({}, 99, riders,
		[], [], false, {Vector3i(5, 6, 7): 50}).to_utf8_buffer())
	game.show_title()
	check(recorder.leaves == 1 and recorder.closes == 1 and not game.online_connected,
		"Returning to title leaves and closes the room connection")
	var local_orbs: Dictionary = game.sim.scoring.orbs.duplicate()
	game._on_online_state(stale_packet)
	check(game.sim.scoring.orbs == local_orbs and game.online_playback.state_queue.is_empty(),
		"Late room packets cannot change local pickups or accumulate in playback")

	game._on_online_welcome({"player": {"slot": 1}, "room": {"mode": "endless"}})
	game._on_online_disconnected("connection lost")
	check(game.state == "ready" and game.title_exhibition and not game.online_mode,
		"Connection loss returns to a valid title exhibition instead of local-driving server state")
	check(game.online_player_slot == -1 and game.online_status.contains("connection lost"),
		"Connection loss clears the remote slot and preserves the reason")
	game.online_client = original_client
	recorder.free()
	game.queue_free()
	await process_frame
	print("ONLINE SESSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
