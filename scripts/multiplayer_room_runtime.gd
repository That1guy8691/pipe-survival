extends RefCounted
## Authoritative simulation state for one online room.

const Rules = preload("res://scripts/simulation.gd")
const Room = preload("res://scripts/online_room.gd")
const Protocol = preload("res://scripts/multiplayer_protocol.gd")

const DEFAULT_SEED := 1701
const RESPAWN_DELAY := 2.5
const HALF_STEP_TIME := Rules.STEP_TIME / 2.0
const BOOST_DRAIN := 0.5
const BOOST_REFILL := 0.25

var room: Room
var sim := Rules.new()
var human_clients_by_slot: Dictionary = {}
var inputs: Dictionary = {}
var respawn_timers: Array[float] = []
var trail_history: Array = []
var half_step_phase := 0
var state_changed := false
var last_step_duration := Rules.STEP_TIME

func _init(configured_room: Room = null) -> void:
	room = configured_room
	if room == null:
		room = Room.new()
		room.configure("PUBLIC", "public", "endless", Room.DEFAULT_HUMAN_CAP, Room.MAX_ACTORS)
	sim.endless_mode = room.mode == "endless"
	var room_seed := DEFAULT_SEED + absi(room.room_id.hash()) % 100000
	sim.reset(room_seed, Rules.MAX_BOTS, 60)
	for _i in range(sim.riders.size()):
		respawn_timers.append(-1.0)
		trail_history.append([])

func join(connection_id: int, requested_name: String, color: Color) -> Dictionary:
	var result := room.join(connection_id, requested_name, color)
	if not bool(result.get("ok", false)):
		return result
	var member: Dictionary = result.member
	inputs[connection_id] = {"turns": [], "boost": false, "respawn_requested": false}
	human_clients_by_slot[int(member.slot)] = connection_id
	_activate_human(member)
	return result

func receive_input(connection_id: int, turn: String, boost: bool, boost_present: bool = true) -> void:
	if not inputs.has(connection_id):
		return
	var input: Dictionary = inputs[connection_id]
	if turn in Protocol.VALID_TURNS:
		var turns: Array = input.turns
		if turns.size() < 2:
			turns.append(turn)
		input["turns"] = turns
	if boost_present:
		input["boost"] = boost
	inputs[connection_id] = input

func request_respawn(connection_id: int) -> bool:
	if not inputs.has(connection_id) or room.mode != "endless":
		return false
	var member: Dictionary = room.members.get(connection_id, {})
	var slot := int(member.get("slot", -1))
	if slot < 0 or slot >= sim.riders.size() or sim.riders[slot].alive:
		return false
	var input: Dictionary = inputs[connection_id]
	input["respawn_requested"] = true
	inputs[connection_id] = input
	return true

func leave(connection_id: int, reason: String = "left") -> Dictionary:
	if not inputs.has(connection_id):
		return {"ok": false, "reason": "NOT_JOINED"}
	var result := room.leave(connection_id, reason)
	var member: Dictionary = result.get("member", {})
	if not member.is_empty():
		var slot := int(member.get("slot", -1))
		human_clients_by_slot.erase(slot)
		_activate_bot(slot)
	inputs.erase(connection_id)
	return result

func step(delta: float = Rules.STEP_TIME) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	var steps := maxi(1, roundi(delta / HALF_STEP_TIME))
	state_changed = false
	for _step in range(steps):
		moves.append_array(_half_step())
	return moves

func _half_step() -> Array[Dictionary]:
	half_step_phase = (half_step_phase + 1) % 2
	var directions: Array[Vector3i] = []
	var movers: Array[int] = []
	var fast_move := false
	for i in range(sim.riders.size()):
		var rider: Dictionary = sim.riders[i]
		if not rider.alive:
			directions.append(rider.forward)
			continue
		var connection_id: int = int(human_clients_by_slot.get(i, -1))
		var input: Dictionary = inputs.get(connection_id, {})
		var requested := bool(input.get("boost", false))
		if not requested:
			rider.boost_locked = false
		if requested and rider.pressure < HALF_STEP_TIME * BOOST_DRAIN:
			rider.boost_locked = true
		rider.boosting = requested and not rider.boost_locked
		rider.pressure = clampf(rider.pressure + HALF_STEP_TIME *
			(-BOOST_DRAIN if rider.boosting else BOOST_REFILL), 0.0, 1.0)
		var due: bool = half_step_phase == 0 or bool(rider.boosting)
		if due:
			movers.append(i)
			fast_move = fast_move or rider.boosting
		if connection_id >= 0 and inputs.has(connection_id):
			var turns: Array = input.turns
			var direction: Vector3i = rider.forward
			if due and not turns.is_empty():
				direction = Rules.turn(rider, str(turns.pop_front()))
				input["turns"] = turns
			inputs[connection_id] = input
			directions.append(direction)
		else:
			directions.append(sim.bot_direction(i) if due else rider.forward)
	last_step_duration = HALF_STEP_TIME if fast_move else Rules.STEP_TIME
	var moves: Array[Dictionary] = []
	if movers.is_empty():
		sim.elapse(HALF_STEP_TIME)
	else:
		moves = sim.advance(directions, movers, HALF_STEP_TIME)
	for move: Dictionary in moves:
		if bool(move.get("died", false)):
			var dead_connection := int(human_clients_by_slot.get(move.id, -1))
			respawn_timers[move.id] = -1.0 if dead_connection >= 0 else RESPAWN_DELAY
			if dead_connection >= 0 and inputs.has(dead_connection):
				var input: Dictionary = inputs[dead_connection]
				input["respawn_requested"] = false
				input["boost"] = false
				input["turns"] = []
				inputs[dead_connection] = input
			trail_history[move.id].clear()
		else:
			trail_history[move.id].append(move.duplicate())
	for i in range(sim.riders.size()):
		if sim.riders[i].alive:
			continue
		var connection_id: int = int(human_clients_by_slot.get(i, -1))
		if connection_id >= 0 and inputs.has(connection_id):
			var input: Dictionary = inputs[connection_id]
			if bool(input.get("respawn_requested", false)) and sim.respawn_rider(i):
				input["respawn_requested"] = false
				inputs[connection_id] = input
				state_changed = true
			continue
		if connection_id >= 0 or respawn_timers[i] < 0.0:
			continue
		respawn_timers[i] = maxf(0.0, respawn_timers[i] - HALF_STEP_TIME)
		if respawn_timers[i] <= 0.0:
			if sim.respawn_rider(i):
				respawn_timers[i] = -1.0
				state_changed = true
			else:
				respawn_timers[i] = 0.75
	if not room.match_started:
		room.start_match()
	return moves

func state_message(moves: Array[Dictionary] = [], full_snapshot: bool = false) -> String:
	return Protocol.state_message(room.snapshot(), sim.ticks, sim.riders, moves,
		trail_history if full_snapshot else [], full_snapshot, sim.scoring.orbs,
		last_step_duration)

func event_message(event_name: String, member: Dictionary) -> String:
	var copy := member.duplicate()
	copy["color"] = Color(member.color).to_html(false)
	return JSON.stringify({"version": Protocol.VERSION, "type": "event",
		"event": event_name, "member": copy, "room": room.snapshot()})

func has_client(connection_id: int) -> bool:
	return inputs.has(connection_id)

func client_ids() -> Array[int]:
	var ids: Array[int] = []
	for connection_id in inputs.keys():
		ids.append(int(connection_id))
	return ids

func _activate_human(member: Dictionary) -> void:
	var slot := int(member.slot)
	var rider: Dictionary = sim.riders[slot]
	sim.remove_rider_trail(slot)
	trail_history[slot].clear()
	rider.alive = false
	rider.name = member.name
	rider.color = member.color
	rider.bot_personality = -1
	_reset_rider_stats(rider)
	if sim.respawn_rider(slot):
		respawn_timers[slot] = -1.0

func _activate_bot(slot: int) -> void:
	if slot < 0 or slot >= sim.riders.size():
		return
	var rider: Dictionary = sim.riders[slot]
	sim.remove_rider_trail(slot)
	trail_history[slot].clear()
	rider.alive = false
	rider.name = "BOT-%02d" % (slot + 1)
	rider.color = Rules.color_for(slot)
	rider.bot_personality = sim.personality_rng.randi_range(Rules.BotPersonality.COLLECTOR,
		Rules.BotPersonality.SURVIVOR)
	_reset_rider_stats(rider)
	if sim.respawn_rider(slot):
		respawn_timers[slot] = -1.0

func _reset_rider_stats(rider: Dictionary) -> void:
	rider.score = 0
	rider.survival_time = 0.0
	rider.orb_count = 0
	rider.eliminations = 0
	rider.combo_count = 0
	rider.combo_multiplier = 1.0
	rider.combo_time = 0.0
	rider.length = 0
	rider.cause = ""
