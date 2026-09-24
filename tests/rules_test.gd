extends SceneTree

const Rules = preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func isolated(cells: Array[Vector3i], forwards: Array[Vector3i]):
	var sim = Rules.new()
	sim.reset(1, 7)
	sim.occupied.clear()
	for i in range(8):
		sim.riders[i].alive = i < cells.size()
		if i < cells.size():
			sim.riders[i].cell = cells[i]
			sim.riders[i].forward = forwards[i]
			sim.occupied[cells[i]] = i
	return sim

func forward_moves(sim) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for rider: Dictionary in sim.riders:
		result.append(rider.forward)
	return result

func _initialize() -> void:
	var sim = Rules.new()
	sim.reset(1, 7)
	check(sim.riders.size() == 8 and sim.occupied.size() == 8, "Eight unique spawn cells")
	var first_start: Vector3i = sim.riders[0].source_cell
	sim.reset(1, 7)
	check(sim.riders[0].source_cell == first_start, "A seed reproduces the same random start")
	var start_changed := false
	for seed_value in range(2, 12):
		sim.reset(seed_value, 7)
		if sim.riders[0].source_cell != first_start:
			start_changed = true
		check(sim.inlet_direction(sim.riders[0].source_cell) != Vector3i.ZERO,
			"Every random start is a wall inlet")
	check(start_changed, "Different round seeds can choose a different player start")
	var player_color := Color("f05f7f")
	sim.reset(31, 31, 100, "Copper", player_color)
	check(sim.rider_name(0) == "Copper" and sim.rider_color(0) == player_color,
		"Player-selected identity is applied to the player pipe")
	var first_bot_names: Array[String] = []
	var first_name_set: Dictionary = {}
	var player_name_reused := false
	for i in range(1, sim.riders.size()):
		var bot_name: String = sim.rider_name(i)
		first_bot_names.append(bot_name)
		first_name_set[bot_name] = true
		player_name_reused = player_name_reused or bot_name.to_lower() == "copper"
	check(first_bot_names.size() == 31 and first_name_set.size() == 31,
		"All 31 bots receive distinct names from the name pool")
	check(not player_name_reused, "A bot name cannot duplicate the player's name")
	sim.reset(32, 31, 100, "Copper", player_color)
	var next_bot_names: Array[String] = []
	var next_name_set: Dictionary = {}
	for i in range(1, sim.riders.size()):
		var bot_name: String = sim.rider_name(i)
		next_bot_names.append(bot_name)
		next_name_set[bot_name] = true
	var repeated_names := false
	for name in next_bot_names:
		if name in first_bot_names:
			repeated_names = true
	check(next_name_set.size() == 31 and not repeated_names,
		"Bot names stay unique and avoid the previous round's names")
	sim.reset(33, 7, 60, "Copper", player_color)
	check(sim.world(Vector3i.ZERO) == Vector3(-29, -29, -29), "Grid fits inside 60-unit cube")
	check(not sim.inside(Vector3i(30, 4, 4)), "Positive wall bound")
	check(not sim.inside(Vector3i(4, -1, 4)), "Negative wall bound")
	var rider: Dictionary = sim.riders[0].duplicate()
	for command in ["up", "left", "down", "right", "up", "up"]:
		var direction: Vector3i = Rules.turn(rider, command)
		var up: Vector3i = Rules.next_up(rider, direction)
		check(Vector3(direction).dot(Vector3(up)) == 0.0, "Steering preserves orthogonal frame")
		rider.forward = direction
		rider.up = up
	check(Rules.turn(rider, "left") == -Rules.turn(rider, "right"), "Opposite steering choices")

	sim = isolated([Vector3i(29, 4, 4), Vector3i(3, 3, 3)], [Vector3i.RIGHT, Vector3i.UP])
	var old_cell: Vector3i = sim.riders[0].cell
	sim.advance(forward_moves(sim))
	check(not sim.riders[0].alive and sim.riders[0].cause == "Arena wall", "Wall eliminates pipe")
	check(sim.occupied.has(old_cell), "Eliminated pipe remains solid")
	check(sim.finished and sim.winner == 1, "Last survivor wins")

	sim = isolated([Vector3i(4, 4, 4), Vector3i(10, 10, 10)], [Vector3i.RIGHT, Vector3i.UP])
	sim.occupied[Vector3i(5, 4, 4)] = 0
	sim.advance(forward_moves(sim))
	check(sim.riders[0].cause == "Your own pipe", "Self collision")

	sim = isolated([Vector3i(4, 4, 4), Vector3i(10, 10, 10)], [Vector3i.RIGHT, Vector3i.UP])
	sim.occupied[Vector3i(5, 4, 4)] = 1
	sim.advance(forward_moves(sim))
	check(sim.riders[0].cause == "Another pipe", "Opponent collision")

	sim = isolated([Vector3i(4, 4, 4), Vector3i(6, 4, 4)], [Vector3i.RIGHT, Vector3i.LEFT])
	sim.advance(forward_moves(sim))
	check(not sim.riders[0].alive and not sim.riders[1].alive, "Simultaneous head-on kills both")
	check(sim.finished and sim.winner == -1, "No survivor is a draw")

	sim = isolated([Vector3i(4, 4, 4), Vector3i(5, 4, 4)], [Vector3i.RIGHT, Vector3i.LEFT])
	sim.advance(forward_moves(sim))
	check(sim.alive_ids().is_empty(), "Head swaps cannot tunnel through each other")

	sim.reset(7, 7)
	var moves := forward_moves(sim)
	moves[0] = -sim.riders[0].forward
	var expected: Vector3i = sim.riders[0].cell + sim.riders[0].forward
	sim.advance(moves)
	check(sim.riders[0].cell == expected, "Immediate reversal rejected")
	sim.reset(7, 7)
	check(sim.ticks == 0 and sim.occupied.size() == 8 and sim.alive_ids().size() == 8, "Restart resets entire round")

	for seed_value in [23, 85, 194]:
		sim.reset(seed_value, 7)
		var previous_occupancy: int = sim.occupied.size()
		while not sim.finished and sim.ticks < 6000:
			var choices: Array[Vector3i] = []
			for i in range(8):
				choices.append(sim.bot_direction(i) if sim.riders[i].alive else sim.riders[i].forward)
			sim.advance(choices)
			if sim.occupied.size() < previous_occupancy:
				check(false, "Pipe occupancy must never shrink")
				break
			previous_occupancy = sim.occupied.size()
		check(sim.finished, "Bots complete a survival round, seed %d" % seed_value)
		print("ROUND seed=%d seconds=%.1f occupied=%d winner=%d" % [seed_value,
			sim.ticks * Rules.STEP_TIME, sim.occupied.size(), sim.winner])
	print("RULES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
