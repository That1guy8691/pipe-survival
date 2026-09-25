extends RefCounted
## Buffers authoritative snapshots and animates their moves in tick order.

signal state_applied(full: bool, previously_alive: Array[bool], player_crash: Dictionary)

const Rules = preload("res://scripts/simulation.gd")
const BACKLOG_LIMIT := 3
const CATCH_UP_STEPS := 8
var sim
var pipes
var orbs
var player_id := 0
var last_state: Dictionary = {}
var progress := 0.0
var step_duration := Rules.STEP_TIME
var step_active := false
var state_queue: Array[Dictionary] = []

func _init(model, pipe_renderer, orb_renderer) -> void:
	sim = model
	pipes = pipe_renderer
	orbs = orb_renderer

func reset() -> void:
	last_state = {}
	state_queue.clear()
	progress = 0.0
	step_duration = Rules.STEP_TIME
	step_active = false
	player_id = 0

func receive(message: Dictionary) -> void:
	last_state = message
	if bool(message.get("full_snapshot", false)):
		state_queue.clear()
		step_active = false
		progress = 0.0
		_apply_state(message)
	else:
		_apply_orbs(message)
		state_queue.append(message)
		if not step_active:
			_begin_step()

func advance(delta: float) -> void:
	if not step_active:
		return
	var skipped := 0
	while state_queue.size() > BACKLOG_LIMIT and skipped < CATCH_UP_STEPS:
		_finish_step()
		skipped += 1
	if not step_active:
		return
	progress = minf(1.0, progress + delta / step_duration)
	if progress >= 1.0:
		_finish_step()

func _begin_step() -> void:
	# State-only packets may arrive in a burst; consume them without recursion.
	while not state_queue.is_empty():
		var message: Dictionary = state_queue[0]
		var moves: Array = message.get("moves", [])
		if moves.is_empty():
			state_queue.pop_front()
			_apply_state(message)
			continue
		for raw_move in moves:
			if not raw_move is Dictionary:
				continue
			var move := _wire_move(raw_move)
			if move.id >= 0 and move.id < sim.riders.size():
				pipes.begin_rider(move.id,
					{"cell": move.cell, "forward": move.incoming, "up": move.up, "alive": true},
					move.outgoing)
		progress = 0.0
		# Keep packet bursts from turning into seconds of presentation delay.
		var packet_duration := maxf(0.08, float(message.get("step_duration", Rules.STEP_TIME)))
		step_duration = maxf(0.08,
			packet_duration / (1.0 + 0.25 * max(0, state_queue.size() - 1)))
		step_active = true
		return

func _finish_step() -> void:
	if not step_active or state_queue.is_empty():
		return
	var message: Dictionary = state_queue.pop_front()
	for raw_move in message.get("moves", []):
		if not raw_move is Dictionary:
			continue
		var rider_id := int(raw_move.get("id", -1))
		if rider_id >= 0 and rider_id < sim.riders.size():
			pipes.animate_rider(rider_id, 1.0)
	_apply_state(message)
	progress = 0.0
	step_active = false
	_begin_step()

func _apply_state(message: Dictionary) -> void:
	var wires: Array = message.get("riders", [])
	if wires.is_empty():
		return
	var full := bool(message.get("full_snapshot", false))
	var previously_alive: Array[bool] = []
	for rider: Dictionary in sim.riders:
		previously_alive.append(bool(rider.alive))
	if full or sim.riders.size() != wires.size():
		sim.reset(int(str(message.get("tick", 0))) + 1701, maxi(wires.size() - 1, 0), 60,
			sim.player_name, sim.player_color)
		pipes.player_id = player_id
	for i in range(mini(wires.size(), sim.riders.size())):
		if wires[i] is Dictionary:
			sim.riders[i] = _wire_rider(wires[i], sim.riders[i])
	sim.ticks = int(message.get("tick", sim.ticks))
	sim.finished = false
	sim.winner = -1
	var player_crash: Dictionary = {}
	if full:
		_apply_orbs(message)
		sim.occupied.clear()
		var histories: Array = []
		var wire_histories: Array = message.get("history", [])
		for i in range(wires.size()):
			var rider_history: Array = []
			if i < wire_histories.size():
				for raw_move in wire_histories[i]:
					var move := _wire_move(raw_move)
					rider_history.append(move)
					sim.occupied[move.cell] = i
					sim.occupied[move.target] = i
			histories.append(rider_history)
			if i < sim.riders.size() and sim.riders[i].alive:
				sim.occupied[sim.riders[i].cell] = i
		pipes.rebuild_from_history(histories)
	else:
		var moves: Array[Dictionary] = []
		for raw_move in message.get("moves", []):
			var move := _wire_move(raw_move)
			moves.append(move)
			if move.id == player_id and move.died:
				player_crash = move
		pipes.commit(moves)
		for i in range(mini(wires.size(), sim.riders.size())):
			if sim.riders[i].alive:
				pipes.begin_rider(i, sim.riders[i], sim.riders[i].forward)
				if i >= previously_alive.size() or not previously_alive[i]:
					pipes.restore_rider(i, sim.riders[i])
		progress = 0.0
	orbs.sync(sim.scoring)
	state_applied.emit(full, previously_alive, player_crash)

func _apply_orbs(message: Dictionary) -> void:
	var server_orbs: Dictionary = {}
	for raw_orb in message.get("orbs", []):
		if raw_orb is Dictionary:
			server_orbs[_vector_from_wire(raw_orb.get("cell"))] = int(raw_orb.get("points", 0))
	if sim.scoring.orbs != server_orbs:
		sim.scoring.orbs = server_orbs
		sim.scoring.revision += 1
		orbs.sync(sim.scoring)

static func _vector_from_wire(value, fallback: Vector3i = Vector3i.ZERO) -> Vector3i:
	if value is Array and value.size() >= 3:
		return Vector3i(int(value[0]), int(value[1]), int(value[2]))
	return fallback

func _wire_rider(wire: Dictionary, current: Dictionary) -> Dictionary:
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
		rider.color = Color.from_string(str(wire.color), rider.get("color", sim.player_color))
	return rider

static func _wire_move(wire: Dictionary) -> Dictionary:
	return {"id": int(wire.get("id", -1)),
		"cell": _vector_from_wire(wire.get("cell")),
		"target": _vector_from_wire(wire.get("target")),
		"incoming": _vector_from_wire(wire.get("incoming"), Vector3i.FORWARD),
		"outgoing": _vector_from_wire(wire.get("outgoing"), Vector3i.FORWARD),
		"up": _vector_from_wire(wire.get("up"), Vector3i.UP),
		"died": bool(wire.get("died", false)),
		"pipe_owner": int(wire.get("pipe_owner", -1))}
