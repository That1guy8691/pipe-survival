extends RefCounted
## Per-pipe segment clocks: boosting never changes another pipe's speed.

signal completed(moves: Array[Dictionary])
signal planned(indices: Array[int])
const Rules = preload("res://scripts/simulation.gd")
const BOOST_MULTIPLIER := 2.0
const DRAIN := 0.5
const REFILL := 0.25
var sim
var elapsed: Array[float] = []
var duration: Array[float] = []
var directions: Array[Vector3i] = []
var turn_queue: Array[String] = []
var boost_requested := false
var autoplay := false
var bots_boost := true

func _init(model) -> void:
	sim = model

func reset() -> void:
	elapsed.clear()
	duration.clear()
	directions.clear()
	turn_queue.clear()
	boost_requested = false
	for rider: Dictionary in sim.riders:
		elapsed.append(0.0)
		duration.append(Rules.STEP_TIME)
		directions.append(rider.forward)
	for i in range(sim.riders.size()):
		plan(i)

func plan(index: int) -> void:
	var rider: Dictionary = sim.riders[index]
	var direction: Vector3i = rider.forward
	if index > 0 or autoplay:
		direction = sim.bot_direction(index)
	elif not turn_queue.is_empty():
		direction = Rules.turn(rider, turn_queue.pop_front())
	directions[index] = direction
	var requested := boost_requested
	if index > 0 or autoplay:
		requested = bots_boost and rider.pressure > 0.3 and sim.rng.randf() < 0.22
		for distance in range(1, 6):
			if not sim.is_open(rider.cell + direction * distance):
				requested = false
	if not requested:
		rider.boost_locked = false
	var cost := Rules.STEP_TIME / BOOST_MULTIPLIER * DRAIN
	if requested and rider.pressure < cost:
		rider.boost_locked = true
	rider.boosting = requested and not rider.boost_locked
	duration[index] = Rules.STEP_TIME / BOOST_MULTIPLIER if rider.boosting else Rules.STEP_TIME
	elapsed[index] = 0.0

func respawn_rider(index: int) -> void:
	if index < 0 or index >= sim.riders.size() or not sim.riders[index].alive:
		return
	if index == 0:
		turn_queue.clear()
		boost_requested = false
		sim.riders[index].boost_locked = false
	elapsed[index] = 0.0
	duration[index] = Rules.STEP_TIME
	directions[index] = sim.riders[index].forward
	plan(index)
	var planned_indices: Array[int] = [index]
	planned.emit(planned_indices)

func progress(index: int) -> float:
	return clampf(elapsed[index] / duration[index], 0.0, 1.0)

func advance(delta: float) -> void:
	var remaining := delta
	while remaining > 0.000001 and not sim.finished:
		var next_event := INF
		for i in sim.alive_ids():
			next_event = minf(next_event, duration[i] - elapsed[i])
		var consumed := minf(remaining, maxf(next_event, 0.0))
		sim.elapse(consumed)
		for i in sim.alive_ids():
			var rider: Dictionary = sim.riders[i]
			elapsed[i] += consumed
			rider.pressure = clampf(rider.pressure + consumed * (-DRAIN if rider.boosting else REFILL), 0.0, 1.0)
		remaining -= consumed
		var due: Array[int] = []
		for i in sim.alive_ids():
			if elapsed[i] >= duration[i] - 0.000001:
				due.append(i)
		if due.is_empty():
			break
		var moves: Array[Dictionary] = sim.advance(directions, due, 0.0)
		completed.emit(moves)
		if sim.finished:
			break
		var continuing: Array[int] = []
		for i in due:
			if sim.riders[i].alive:
				plan(i)
				continuing.append(i)
		planned.emit(continuing)
