extends RefCounted

const ORB_POINTS := 25
const ELIMINATION_POINTS := 100
const WIN_POINTS := 250
const ORB_COUNT := 100
var orbs: Dictionary = {}
var revision := 0

func reset(sim) -> void:
	orbs.clear()
	refill(sim)
	revision += 1

func elapse(riders: Array[Dictionary], delta: float) -> void:
	for rider: Dictionary in riders:
		if rider.alive:
			var before := int(rider.survival_time + 0.00001)
			rider.survival_time += delta
			rider.score += int(rider.survival_time + 0.00001) - before

func resolve(sim, moves: Array[Dictionary]) -> void:
	for move: Dictionary in moves:
		var rider: Dictionary = sim.riders[move.id]
		if not move.died and orbs.has(move.target):
			rider.score += ORB_POINTS
			rider.orb_count += 1
			move["orb_points"] = ORB_POINTS
			orbs.erase(move.target)
			revision += 1
		var owner: int = move.get("pipe_owner", -1)
		if move.died and owner >= 0 and owner != move.id and sim.riders[owner].alive:
			sim.riders[owner].score += ELIMINATION_POINTS
			sim.riders[owner].eliminations += 1
			move["credited_to"] = owner
	refill(sim)

func refill(sim) -> void:
	var attempts := 0
	while orbs.size() < ORB_COUNT and attempts < 2000:
		attempts += 1
		var cell := Vector3i(sim.rng.randi_range(0, sim.cell_count - 1),
			sim.rng.randi_range(0, sim.cell_count - 1), sim.rng.randi_range(0, sim.cell_count - 1))
		if not sim.is_open(cell) or orbs.has(cell):
			continue
		var exits := 0
		for direction: Vector3i in sim.AXES:
			if sim.is_open(cell + direction):
				exits += 1
		if exits < 3:
			continue
		orbs[cell] = ORB_POINTS
		revision += 1

func nearest(cell: Vector3i) -> Vector3i:
	var best := cell
	var distance := INF
	for candidate: Vector3i in orbs:
		var delta := Vector3(candidate - cell).length_squared()
		if delta < distance:
			distance = delta
			best = candidate
	return best
