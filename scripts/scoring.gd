extends RefCounted

const ORB_POINTS := 25
const BLUE_ORB_POINTS := 15
const VIOLET_ORB_POINTS := 50
const BLUE_ORB_COLOR := Color("54caff")
const GOLD_ORB_COLOR := Color("ffdb77")
const VIOLET_ORB_COLOR := Color("c879ff")
const NEAR_MISS_POINTS := 15
const ELIMINATION_POINTS := 100
const WIN_POINTS := 250
const ORB_COUNT := 100
const COMBO_WINDOW := 4.0
const MAX_COMBO_EVENTS := 4
const COMBO_STEP := 0.5
var orbs: Dictionary = {}
var revision := 0
var last_awards: Array[Dictionary] = []

func reset(sim) -> void:
	orbs.clear()
	last_awards.clear()
	refill(sim)
	revision += 1

func elapse(riders: Array[Dictionary], delta: float) -> void:
	for rider: Dictionary in riders:
		if rider.alive:
			var before := int(rider.survival_time + 0.00001)
			rider.survival_time += delta
			rider.score += int(rider.survival_time + 0.00001) - before
			if rider.combo_time > 0.0:
				rider.combo_time = maxf(0.0, rider.combo_time - delta)
				if rider.combo_time <= 0.0:
					reset_combo(rider)

func resolve(sim, moves: Array[Dictionary]) -> void:
	last_awards.clear()
	var rewards: Dictionary = {}
	for move: Dictionary in moves:
		var rider: Dictionary = sim.riders[move.id]
		if move.died:
			rider.near_miss_active = false
			reset_combo(rider)
		else:
			var in_tight_pass := _in_tight_pass(sim, move, rider)
			if in_tight_pass and not rider.near_miss_active:
				move["near_miss"] = true
				_queue_reward(rewards, move.id, "NEAR MISS", NEAR_MISS_POINTS)
			rider.near_miss_active = in_tight_pass
		var orb_points := int(orbs.get(move.target, 0))
		if not move.died and orb_points > 0:
			rider.orb_count += 1
			move["orb_points"] = orb_points
			orbs.erase(move.target)
			_queue_reward(rewards, move.id, "%s ORB" % orb_name(orb_points), orb_points)
			revision += 1
		var owner: int = move.get("pipe_owner", -1)
		if move.died and owner >= 0 and owner != move.id and sim.riders[owner].alive:
			sim.riders[owner].eliminations += 1
			move["credited_to"] = owner
			_queue_reward(rewards, owner, "ELIMINATION", ELIMINATION_POINTS)
	for rider_id_value in rewards:
		var rider_id: int = int(rider_id_value)
		var rider: Dictionary = sim.riders[rider_id]
		var combo_count := 1
		if rider.combo_time > 0.0:
			combo_count = mini(int(rider.combo_count) + 1, MAX_COMBO_EVENTS)
		var multiplier := 1.0 + float(combo_count - 1) * COMBO_STEP
		var reward: Dictionary = rewards[rider_id]
		var base_points: int = int(reward.base_points)
		var points := roundi(base_points * multiplier)
		rider.score += points
		rider.combo_count = combo_count
		rider.combo_multiplier = multiplier
		rider.combo_time = COMBO_WINDOW
		last_awards.append({"rider_id": rider_id, "base_points": base_points,
			"points": points, "events": reward.events.duplicate(), "combo_count": combo_count,
			"multiplier": multiplier})
	refill(sim)

func _in_tight_pass(sim, move: Dictionary, rider: Dictionary) -> bool:
	var beside_pipe := false
	for direction: Vector3i in sim.AXES:
		var neighbor: Vector3i = move.target + direction
		if neighbor != move.cell and sim.occupied.has(neighbor):
			beside_pipe = true
			break
	if not beside_pipe:
		return false
	var safe_exits := 0
	for direction: Vector3i in sim.legal_directions(rider):
		if sim.is_open(move.target + direction):
			safe_exits += 1
	return safe_exits <= 2

func _queue_reward(rewards: Dictionary, rider_id: int, event_name: String, points: int) -> void:
	if not rewards.has(rider_id):
		rewards[rider_id] = {"base_points": 0, "events": []}
	var reward: Dictionary = rewards[rider_id]
	reward.base_points = int(reward.base_points) + points
	var events: Array = reward.events
	events.append(event_name)
	reward.events = events
	rewards[rider_id] = reward

func reset_combo(rider: Dictionary) -> void:
	rider.combo_count = 0
	rider.combo_multiplier = 1.0
	rider.combo_time = 0.0

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
		orbs[cell] = roll_orb_points(sim.rng)
		revision += 1

func best_target(cell: Vector3i) -> Vector3i:
	var best := cell
	var best_utility := -INF
	for candidate: Vector3i in orbs:
		var distance := Vector3(candidate - cell).length()
		var value_weight := sqrt(float(orbs[candidate]) / float(ORB_POINTS))
		var utility := value_weight / (distance + 4.0)
		if utility > best_utility:
			best_utility = utility
			best = candidate
	return best

static func roll_orb_points(rng: RandomNumberGenerator) -> int:
	var roll := rng.randf()
	if roll < 0.20:
		return BLUE_ORB_POINTS
	if roll < 0.90:
		return ORB_POINTS
	return VIOLET_ORB_POINTS

static func orb_name(points: int) -> String:
	match points:
		BLUE_ORB_POINTS: return "BLUE"
		ORB_POINTS: return "GOLD"
		VIOLET_ORB_POINTS: return "VIOLET"
	return "UNKNOWN"

static func orb_color(points: int) -> Color:
	match points:
		BLUE_ORB_POINTS: return BLUE_ORB_COLOR
		ORB_POINTS: return GOLD_ORB_COLOR
		VIOLET_ORB_POINTS: return VIOLET_ORB_COLOR
	return Color.WHITE

static func orb_scale(points: int) -> float:
	match points:
		BLUE_ORB_POINTS: return 0.84
		ORB_POINTS: return 1.0
		VIOLET_ORB_POINTS: return 1.2
	return 1.0
