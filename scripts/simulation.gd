extends RefCounted
## Authoritative grid rules. Presentation never determines collisions.

const DEFAULT_SIZE := 30
const SPACING := 2.0
const DEFAULT_WIDTH := DEFAULT_SIZE * SPACING
const SPEED := 6.0
const STEP_TIME := SPACING / SPEED
const DEFAULT_BOTS := 15
const MAX_BOTS := 31
const Scoring = preload("res://scripts/scoring.gd")
const COLORS := [Color("56eddf"), Color("ffb65a"), Color("aa8cff"),
	Color("ff6e91"), Color("82df8b"), Color("62b4ff"), Color("eddf72"), Color("eaa4ec")]
const BOT_NAME_POOL := ["COPPER", "VIOLET", "CORAL", "MOSS", "COBALT", "GOLD", "ORCHID",
	"BRASS", "RIVET", "GASKET", "WRENCH", "SPANNER", "BOLT", "NUTMEG", "VALVE",
	"SPROCKET", "TURBINE", "FLUX", "STEAM", "HYDRO", "BRINE", "DRIP", "BUBBLES",
	"WOBBLE", "ZIGZAG", "TINKER", "RUMBLE", "NIMBUS", "COMET", "PIXEL", "ECHO",
	"NOVA", "ORBIT", "QUASAR", "SONIC", "ONYX", "AMBER", "OPAL", "QUARTZ", "RUBY",
	"SAFFRON", "LUMEN", "SPARK", "DYNAMO", "NOODLE", "SCOOTER", "TANGO", "RASCAL",
	"GIZMO", "WIDGET", "PIP", "TUBING", "JOINT", "MANIFOLD", "MENDER", "CIRCUIT",
	"PLUMBUM", "TAPPER", "JUMPER", "PIVOT", "BOILER", "WAVE", "RIPPLE", "SPLASH",
	"SQUIGGLE", "SWIRL", "GLITCH", "SCRAPPY", "ZEPHYR", "JUNO", "KELVIN", "MERCURY",
	"TOOLBOX", "TWIST", "RATCHET", "FERRULE", "COUPLER", "BOUNCER", "PULSE", "TITAN",
	"BLIP", "CORKSCREW", "FUSE", "TORQUE", "MIST", "SOLDER", "WELDER", "PIPELINE",
	"GUTTER", "DRAIN", "NOZZLE", "HOPPER", "RADIATOR", "SPRINKLER", "JET", "SEAM",
	"SLEEVE", "FLANGE", "THREAD", "TRICKLE"]
const AXES := [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN,
	Vector3i.FORWARD, Vector3i.BACK]

var riders: Array[Dictionary] = []
var player_name := "YOU"
var player_color := Color("56eddf")
var bot_name_bag: Array[String] = []
var recent_bot_names: Array[String] = []
var occupied: Dictionary = {}
var rng := RandomNumberGenerator.new()
var ticks := 0
var finished := false
var winner := -1
var elapsed_time := 0.0
var scoring := Scoring.new()
var cell_count := DEFAULT_SIZE
var arena_width: float:
	get: return cell_count * SPACING

func reset(seed_value: int = 0, bot_count: int = DEFAULT_BOTS, width: int = 60,
		new_player_name: String = "YOU", new_player_color: Color = Color("56eddf")) -> void:
	cell_count = clampi(int(width / SPACING), 20, 50)
	player_name = new_player_name.strip_edges().left(18)
	if player_name.is_empty():
		player_name = "YOU"
	player_color = new_player_color
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	riders.clear()
	occupied.clear()
	ticks = 0
	finished = false
	winner = -1
	elapsed_time = 0.0
	var spawns := spawn_cells(clampi(bot_count, 1, MAX_BOTS) + 1)
	var round_names: Array[String] = [player_name]
	for i in range(spawns.size()):
		var cell := spawns[i]
		var forward := inlet_direction(cell)
		var up := Vector3i.BACK if forward.y != 0 else Vector3i.UP
		riders.append({"cell": cell, "forward": forward, "up": up,
			"source_cell": cell, "source_forward": forward,
			"alive": true, "length": 0, "death_tick": -1, "cause": "",
			"score": 0, "survival_time": 0.0, "orb_count": 0, "eliminations": 0,
			"pressure": 1.0, "boosting": false, "boost_locked": false,
			"name": _next_bot_name(round_names) if i > 0 else player_name,
			"color": color_for(i) if i > 0 else player_color})
		occupied[cell] = i
	scoring.reset(self)
	# A visible, reachable first pickup teaches collection without a new tutorial.
	var first_orb: Vector3i = riders[0].cell + riders[0].forward * 4
	if is_open(first_orb):
		scoring.orbs[first_orb] = Scoring.ORB_POINTS
		scoring.revision += 1

static func color_for(index: int) -> Color:
	return COLORS[index] if index < COLORS.size() else Color.from_hsv(fmod(index * 0.618034, 1.0), 0.48, 0.98)

func rider_color(index: int) -> Color:
	return riders[index].color

func rider_name(index: int) -> String:
	return str(riders[index].name)

func _name_is_taken(candidate: String, names: Array[String]) -> bool:
	for name in names:
		if candidate.to_lower() == name.to_lower():
			return true
	return false

func _fill_bot_name_bag(excluded: Array[String]) -> void:
	bot_name_bag.clear()
	for name in BOT_NAME_POOL:
		if not _name_is_taken(name, recent_bot_names) and not _name_is_taken(name, excluded):
			bot_name_bag.append(name)
	if bot_name_bag.is_empty():
		for name in BOT_NAME_POOL:
			if not _name_is_taken(name, excluded):
				bot_name_bag.append(name)
	bot_name_bag.shuffle()

func _next_bot_name(excluded: Array[String]) -> String:
	if bot_name_bag.is_empty():
		_fill_bot_name_bag(excluded)
	var selected: String = bot_name_bag.pop_back()
	while _name_is_taken(selected, excluded):
		if bot_name_bag.is_empty():
			_fill_bot_name_bag(excluded)
		selected = bot_name_bag.pop_back()
	excluded.append(selected)
	recent_bot_names.append(selected)
	if recent_bot_names.size() > MAX_BOTS:
		recent_bot_names.pop_front()
	return selected

func spawn_cells(count: int) -> Array[Vector3i]:
	# Wall inlets replace floating starts; spread them across all six faces.
	var chosen: Array[Vector3i] = [Vector3i(3, 3, 0)]
	var face_counts := {Vector3i.BACK: 1}
	var candidates: Array[Vector3i] = []
	var coordinates := [3, roundi(lerpf(3.0, cell_count - 4.0, 1.0 / 3.0)),
		roundi(lerpf(3.0, cell_count - 4.0, 2.0 / 3.0)), cell_count - 4]
	for a in coordinates:
		for b in coordinates:
			for edge in [0, cell_count - 1]:
				candidates.append(Vector3i(a, b, edge))
				candidates.append(Vector3i(a, edge, b))
				candidates.append(Vector3i(edge, a, b))
	while chosen.size() < count:
		var best := Vector3i.ZERO
		var best_distance := -1.0
		for candidate in candidates:
			if candidate in chosen:
				continue
			if face_counts.get(inlet_direction(candidate), 0) > int(chosen.size() / 6):
				continue
			var nearest_distance := INF
			for existing in chosen:
				nearest_distance = minf(nearest_distance, Vector3(existing - candidate).length_squared())
			if nearest_distance > best_distance:
				best = candidate
				best_distance = nearest_distance
		chosen.append(best)
		var face := inlet_direction(best)
		face_counts[face] = face_counts.get(face, 0) + 1
	return chosen

func inlet_direction(cell: Vector3i) -> Vector3i:
	for axis in range(3):
		if cell[axis] == 0 or cell[axis] == cell_count - 1:
			var direction := Vector3i.ZERO
			direction[axis] = 1 if cell[axis] == 0 else -1
			return direction
	return Vector3i.ZERO

func elapse(delta: float) -> void:
	elapsed_time += delta
	scoring.elapse(riders, delta)

func world(cell: Vector3i) -> Vector3:
	return (Vector3(cell) - Vector3.ONE * (cell_count - 1) * 0.5) * SPACING

func inside(cell: Vector3i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.z >= 0 and cell.x < cell_count and cell.y < cell_count and cell.z < cell_count

func is_open(cell: Vector3i) -> bool:
	return inside(cell) and not occupied.has(cell)

static func turn(rider: Dictionary, command: String) -> Vector3i:
	var forward: Vector3i = rider.forward
	var up: Vector3i = rider.up
	var right := Vector3i(Vector3(forward).cross(Vector3(up)))
	match command:
		"left": return -right
		"right": return right
		"up": return up
		"down": return -up
	return forward

static func next_up(rider: Dictionary, outgoing: Vector3i) -> Vector3i:
	if outgoing == rider.up:
		return -rider.forward
	if outgoing == -rider.up:
		return rider.forward
	return rider.up

func legal_directions(rider: Dictionary) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for direction: Vector3i in AXES:
		if direction != -rider.forward:
			result.append(direction)
	return result

func bot_direction(index: int) -> Vector3i:
	var rider: Dictionary = riders[index]
	var best: Vector3i = rider.forward
	var best_score := -INF
	var nearest_orb := scoring.nearest(rider.cell)
	for direction: Vector3i in legal_directions(rider):
		var target: Vector3i = rider.cell + direction
		if not is_open(target):
			continue
		var runway := 0
		for distance in range(1, 4):
			if not is_open(rider.cell + direction * distance):
				break
			runway += 1
		var blocked_exits := 0
		for side: Vector3i in AXES:
			if inside(target + side) and not is_open(target + side):
				blocked_exits += 1
		# Limited flood lookahead avoids easy dead ends without a perfect map solver.
		# Penalize nearby pipes, not the safe outer lanes beside an arena wall.
		var score := reachable_space(target, 28) * 0.12 - blocked_exits * 0.7 + runway * 0.5
		score += rng.randf_range(0.0, 2.3)
		if direction == rider.forward:
			score += 1.8
		var toward_orb := Vector3(nearest_orb - rider.cell)
		if toward_orb.length_squared() > 0.0:
			score += Vector3(direction).dot(toward_orb.normalized()) * 2.2
		if scoring.orbs.has(target):
			score += 5.0
		for other_index in range(riders.size()):
			var other: Dictionary = riders[other_index]
			if other_index != index and other.alive:
				if target == other.cell + other.forward:
					score -= 7.0
		if score > best_score:
			best_score = score
			best = direction
	return best

func reachable_space(start: Vector3i, limit: int) -> int:
	var seen: Dictionary = {start: true}
	var queue: Array[Vector3i] = [start]
	var cursor := 0
	while cursor < queue.size() and seen.size() < limit:
		var cell := queue[cursor]
		cursor += 1
		for direction: Vector3i in AXES:
			var neighbor := cell + direction
			if not seen.has(neighbor) and is_open(neighbor):
				seen[neighbor] = true
				queue.append(neighbor)
	return mini(seen.size(), limit)

func advance(directions: Array[Vector3i], movers: Array[int] = [], elapsed: float = STEP_TIME) -> Array[Dictionary]:
	if finished:
		return []
	elapse(elapsed)
	var targets: Dictionary = {}
	var moves: Array[Dictionary] = []
	for i in range(riders.size()):
		var rider: Dictionary = riders[i]
		if not rider.alive or (not movers.is_empty() and i not in movers):
			continue
		var direction := directions[i]
		if direction not in legal_directions(rider):
			direction = rider.forward
		var target: Vector3i = rider.cell + direction
		targets[target] = int(targets.get(target, 0)) + 1
		moves.append({"id": i, "cell": rider.cell, "incoming": rider.forward,
			"outgoing": direction, "target": target, "up": next_up(rider, direction)})
	# Resolve all intents against the same pre-step occupancy, including head-on ties.
	for move: Dictionary in moves:
		var rider: Dictionary = riders[move.id]
		var cause := ""
		if not inside(move.target):
			cause = "Arena wall"
		elif occupied.has(move.target):
			cause = "Your own pipe" if occupied[move.target] == move.id else "Another pipe"
		elif targets[move.target] > 1:
			cause = "Head-on collision"
		move["died"] = not cause.is_empty()
		move["pipe_owner"] = int(occupied.get(move.target, -1))
		rider.length += 1
		if move.died:
			rider.alive = false
			rider.boosting = false
			rider.death_tick = ticks + 1
			rider.cause = cause
		else:
			rider.cell = move.target
			rider.up = move.up
			rider.forward = move.outgoing
	for move: Dictionary in moves:
		if not move.died:
			occupied[move.target] = move.id
	scoring.resolve(self, moves)
	ticks += 1
	var living := alive_ids()
	if living.size() <= 1:
		finished = true
		winner = living[0] if living.size() == 1 else -1
		if winner >= 0:
			riders[winner].score += Scoring.WIN_POINTS
	return moves

func alive_ids() -> Array[int]:
	var result: Array[int] = []
	for i in range(riders.size()):
		if riders[i].alive:
			result.append(i)
	return result
