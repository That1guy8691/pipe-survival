extends SceneTree

const Rules = preload("res://scripts/simulation.gd")
const Renderer = preload("res://scripts/pipe_renderer.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sim := Rules.new()
	var renderer := Renderer.new()
	renderer.model = sim
	root.add_child(renderer)
	for width in [40, 60, 80, 100]:
		for bots in [31, 7, 23, 15]:
			sim.reset(821, bots, width)
			renderer.reset(sim.riders.size())
			var faces := {}
			var directions: Array[Vector3i] = []
			for i in range(sim.riders.size()):
				var rider: Dictionary = sim.riders[i]
				var forward: Vector3i = rider.forward
				faces[forward] = true
				check(not sim.inside(rider.cell - forward), "Every inlet is on a wall")
				check(sim.is_open(rider.cell + forward), "Inlet faces a clear interior cell")
				check(Vector3(forward).dot(Vector3(rider.up)) == 0.0, "Vertical starts retain valid steering frame")
				renderer.begin_rider(i, rider, forward)
				check(renderer.pose(i, 0.0).position.is_equal_approx(renderer.inlets[i].position), "Pipe begins exactly at its fixed wall fitting")
				directions.append(forward)
			check(faces.size() == 6, "Spawns use all six faces at every bot count")
			var visible_count := 0
			for inlet in renderer.inlets:
				visible_count += int(inlet.visible)
			check(visible_count == bots + 1, "Reset hides unused inlets after changing bot count")
			var origin := renderer.inlets[0].position
			sim.advance(directions)
			check(renderer.inlets[0].position == origin, "Wall anchor stays fixed after movement")
			check(sim.occupied.has(sim.riders[0].source_cell), "Starter cell remains a solid owned trail")

	# Sample normal rounds, excluding the source cells so ports cannot fake coverage.
	for seed_value in [814, 821]:
		sim.reset(seed_value, 15)
		var initial := sim.occupied.duplicate()
		var visited_faces := {}
		var edge_orbs := 0
		for cell: Vector3i in sim.scoring.orbs:
			for axis in range(3):
				if cell[axis] == 0 or cell[axis] == sim.cell_count - 1:
					edge_orbs += 1
					break
		check(edge_orbs > 0, "Pickups reach the outer cell layer")
		for tick in range(400):
			if sim.finished:
				break
			var choices: Array[Vector3i] = []
			for i in range(sim.riders.size()):
				choices.append(sim.bot_direction(i) if sim.riders[i].alive else sim.riders[i].forward)
			sim.advance(choices)
		var outer_cells := 0
		for cell: Vector3i in sim.occupied:
			if initial.has(cell):
				continue
			var outer := false
			for axis in range(3):
				if cell[axis] == 0 or cell[axis] == sim.cell_count - 1:
					visited_faces[Vector2i(axis, cell[axis])] = true
					outer = true
			outer_cells += int(outer)
		check(visited_faces.size() == 6, "Bots grow new trails along every outer face")
		print("COVERAGE seed=%d cells=%d outer=%d faces=%d edge_orbs=%d" % [seed_value, sim.occupied.size(), outer_cells, visited_faces.size(), edge_orbs])
	print("INLETS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
