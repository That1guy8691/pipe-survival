extends SceneTree

const Rules = preload("res://scripts/simulation.gd")
const Protocol = preload("res://scripts/multiplayer_protocol.gd")

var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func packet(tick: int, riders: Array[Dictionary], moves: Array[Dictionary] = [],
		full: bool = false, orbs: Dictionary = {}) -> Dictionary:
	return Protocol.parse_packet(Protocol.state_message({"room_id": "TEST"}, tick, riders,
		moves, [[], []] if full else [], full, orbs).to_utf8_buffer())

func move(from_cell: Vector3i, to_cell: Vector3i, died: bool = false,
		owner: int = -1) -> Dictionary:
	return {"id": 0, "cell": from_cell, "target": to_cell,
		"incoming": Vector3i.RIGHT, "outgoing": Vector3i.RIGHT,
		"up": Vector3i.UP, "died": died, "pipe_owner": owner}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	game.set_process(false)
	game.state = "playing"
	game.online_mode = true
	game.online_connected = true
	game.online_player_slot = 0
	game.endless_mode = true
	var riders: Array[Dictionary] = []
	for rider: Dictionary in game.sim.riders.slice(0, 2):
		riders.append(rider.duplicate(true))
	riders[0].cell = Vector3i(10, 10, 10)
	riders[0].source_cell = riders[0].cell
	riders[0].forward = Vector3i.RIGHT
	riders[0].source_forward = Vector3i.RIGHT
	riders[0].up = Vector3i.UP
	riders[0].alive = true
	riders[0].name = "PILOT"
	riders[1].cell = Vector3i(13, 10, 10)
	riders[1].source_cell = riders[1].cell
	riders[1].forward = Vector3i.UP
	riders[1].source_forward = Vector3i.UP
	riders[1].alive = true
	riders[1].name = "BLOCKER"
	game._on_online_state(packet(0, riders, [], true))
	check(game.sim.riders.size() == 2 and game.sim.riders[0].cell == Vector3i(10, 10, 10),
		"Full snapshot places the player at the authoritative cell")
	var stale_orb := Vector3i(16, 12, 12)
	var moved_orb := Vector3i(17, 12, 12)
	var before_orbs: int = game.sim.scoring.revision
	game._on_online_state(packet(0, riders, [], false, {stale_orb: 25}))
	game._on_online_state(packet(0, riders, [], false, {moved_orb: 25}))
	check(game.orbs.multimesh.instance_count == 1
		and game.sim.scoring.orbs.has(moved_orb) and not game.sim.scoring.orbs.has(stale_orb)
		and game.sim.scoring.revision == before_orbs + 2
		and game.orbs.shown_revision == game.sim.scoring.revision,
		"Online orb visuals follow each authoritative orb update")
	if DisplayServer.get_name() != "headless":
		check(game.orbs.multimesh.get_instance_transform(0).origin == game.sim.world(moved_orb),
			"The rendered orb instance moves to the authoritative cell")
	game._on_online_state(packet(0, riders))
	var first_move := move(Vector3i(10, 10, 10), Vector3i(11, 10, 10))
	var second_move := move(Vector3i(11, 10, 10), Vector3i(12, 10, 10))
	var first_riders := riders.duplicate(true)
	first_riders[0].cell = first_move.target
	var second_riders := first_riders.duplicate(true)
	second_riders[0].cell = second_move.target
	game._on_online_state(packet(1, first_riders, [first_move]))
	check(game.online_playback.step_active and game.sim.riders[0].cell == first_move.cell,
		"The server move animates before it is committed")
	game._process(Rules.STEP_TIME * 0.5)
	var half_progress: float = game.online_playback.progress
	game._on_online_state(packet(2, second_riders, [second_move], false, {moved_orb: 25}))
	check(game.online_playback.state_queue.size() == 2 and is_equal_approx(game.online_playback.progress, half_progress),
		"An early packet is buffered without snapping the active move")
	check(game.sim.scoring.orbs.has(moved_orb)
		and game.orbs.shown_revision == game.sim.scoring.revision,
		"Latest orb positions are shown while an older pipe move is animating")
	game._process(Rules.STEP_TIME * 0.5)
	check(game.sim.ticks == 1 and game.sim.riders[0].cell == first_move.target
		and game.online_playback.step_active and is_zero_approx(game.online_playback.progress),
		"The next authoritative move begins at the previous move's endpoint")
	game._process(Rules.STEP_TIME)
	check(game.sim.ticks == 2 and game.sim.riders[0].cell == second_move.target
		and not game.online_playback.step_active,
		"Queued moves finish in tick order")
	game._process(Rules.STEP_TIME * 2.0)
	check(is_zero_approx(game.online_playback.progress) and game.sim.riders[0].cell == second_move.target,
		"A late packet cannot rewind an idle online pipe")
	var death_move := move(second_move.target, riders[1].cell, true, 1)
	var dead_riders := second_riders.duplicate(true)
	dead_riders[0].alive = false
	dead_riders[0].cause = "Another pipe"
	game._on_online_state(packet(3, dead_riders, [death_move]))
	game._process(Rules.STEP_TIME)
	check(not game.sim.riders[0].alive and game.collision_feedback_label == "CRASHED INTO BLOCKER"
		and game.collision_feedback_time > 0.0,
		"Online death identifies the pipe at the server collision target")
	check(game.collision_label_for_player_crash({"pipe_owner": -1}) == "PIPE COLLISION",
		"An older server without collision-owner data still reports a pipe collision accurately")
	check(not game.pipes.inlets[0].visible,
		"A dead rider's pipe is removed")
	var respawned_riders := dead_riders.duplicate(true)
	respawned_riders[0].alive = true
	respawned_riders[0].cause = ""
	respawned_riders[0].cell = Vector3i(0, 15, 15)
	respawned_riders[0].source_cell = respawned_riders[0].cell
	respawned_riders[0].forward = Vector3i.RIGHT
	respawned_riders[0].source_forward = Vector3i.RIGHT
	game._on_online_state(packet(4, respawned_riders))
	check(game.sim.riders[0].alive and game.pipes.inlets[0].visible
		and game.pipes.heads[0].visible,
		"Server respawn restores the inlet and player head")
	var resumed_riders := respawned_riders.duplicate(true)
	resumed_riders[0].cell = Vector3i(1, 15, 15)
	game.state = "paused"
	game._on_online_state(packet(5, resumed_riders,
		[move(Vector3i(0, 15, 15), Vector3i(1, 15, 15))]))
	game._process(Rules.STEP_TIME)
	check(game.sim.ticks == 5 and game.sim.riders[0].cell == Vector3i(1, 15, 15)
		and not game.online_playback.step_active,
		"Online presentation stays synced while the pause menu is open")
	for tick in range(6, 11):
		var from_cell := Vector3i(tick - 5, 15, 15)
		var to_cell := Vector3i(tick - 4, 15, 15)
		var queued_riders := resumed_riders.duplicate(true)
		queued_riders[0].cell = to_cell
		game._on_online_state(packet(tick, queued_riders, [move(from_cell, to_cell)]))
	game._process(0.0)
	check(game.sim.ticks == 7 and game.online_playback.state_queue.size() == 3
		and game.pipes.counts[0][0] == 3,
		"A burst catches up old ticks without dropping their collision trails")
	game._on_online_state(packet(11, dead_riders, [], true))
	check(not game.pipes.inlets[0].visible and not game.pipes.heads[0].visible
		and not game.pipes.markers[0].visible,
		"Full snapshots hide the inlet and head of a dead rider")
	game.queue_free()
	await process_frame
	print("MULTIPLAYER PLAYBACK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
