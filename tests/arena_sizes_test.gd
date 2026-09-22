extends SceneTree

const Rules = preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	var sim := Rules.new()
	for width in [40, 60, 80, 100]:
		for bots in [7, 15, 23, 31]:
			sim.reset(821, bots, width)
			var context := "%d units / %d bots" % [width, bots]
			check(sim.arena_width == width, context + ": selected width")
			check(sim.occupied.size() == bots + 1, context + ": unique spawns")
			var valid := true
			for rider: Dictionary in sim.riders:
				valid = valid and sim.inside(rider.cell)
			check(valid, context + ": every spawn inside")
			valid = true
			for cell: Vector3i in sim.scoring.orbs:
				valid = valid and sim.is_open(cell)
			check(valid, context + ": orbs in empty valid cells")
			var limit := float(width) / 2.0 - 1.0
			check(sim.world(Vector3i.ZERO) == Vector3.ONE * -limit, context + ": negative world boundary")
			check(sim.world(Vector3i.ONE * (sim.cell_count - 1)) == Vector3.ONE * limit, context + ": positive world boundary")
			check(not sim.inside(Vector3i(sim.cell_count, 0, 0)), context + ": wall collision boundary")
			var moves: Array[Vector3i] = []
			for rider: Dictionary in sim.riders:
				moves.append(rider.forward)
			sim.occupied.erase(sim.riders[0].cell)
			sim.riders[0].cell = Vector3i(sim.cell_count - 1, 1, 1)
			sim.riders[0].forward = Vector3i.RIGHT
			moves[0] = Vector3i.RIGHT
			sim.occupied[sim.riders[0].cell] = 0
			sim.advance(moves)
			check(not sim.riders[0].alive and sim.riders[0].cause == "Arena wall", context + ": crossing wall eliminates player")
	print("ARENA SIZES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
