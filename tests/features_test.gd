extends SceneTree

const Rules = preload("res://scripts/simulation.gd")
const Motion = preload("res://scripts/motion.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	var sim := Rules.new()
	for bots in [7, 15, 23, 31]:
		sim.reset(15, bots)
		check(sim.riders.size() == bots + 1, "%d bots selectable" % bots)
		check(sim.occupied.size() == bots + 1, "Every spawn is unique")
		var positions_valid := true
		for rider: Dictionary in sim.riders:
			positions_valid = positions_valid and sim.inside(rider.cell)
		check(positions_valid, "All spawn cells are within the enlarged arena")
		var orbs_valid := true
		for cell: Vector3i in sim.scoring.orbs:
			orbs_valid = orbs_valid and sim.is_open(cell)
		check(orbs_valid, "Orbs start only in empty cells")

	sim.reset(10, 7)
	var motion := Motion.new(sim)
	motion.bots_boost = false
	motion.reset()
	motion.boost_requested = true
	motion.plan(0)
	for frame in range(60):
		motion.advance(1.0 / 60.0)
	check(sim.riders[0].length == 6, "Boosted player traverses six cells per second")
	check(sim.riders[1].length == 3, "Another pipe retains normal speed during player boost")
	check(absf(sim.riders[0].pressure - 0.5) < 0.001, "One second of boost uses half the meter")
	check(sim.riders[0].orb_count >= 1, "Travel collects the introductory orb")
	check(sim.riders[0].score >= 26, "Orb and time both award points")
	check(absf(sim.elapsed_time - 1.0) < 0.001, "Round clock remains real time during boost")
	var pressure: float = sim.riders[0].pressure
	motion.boost_requested = false
	motion.plan(0)
	motion.advance(0.2)
	check(sim.riders[0].pressure > pressure, "Releasing boost recharges pressure")
	sim.reset(10, 7)
	motion = Motion.new(sim)
	motion.bots_boost = false
	motion.reset()
	motion.boost_requested = true
	motion.plan(0)
	motion.advance(2.05)
	check(not sim.riders[0].boosting and sim.riders[0].boost_locked, "A sustained burst naturally exhausts the meter")

	sim.reset(11, 7)
	motion = Motion.new(sim)
	motion.reset()
	sim.riders[0].pressure = 0.01
	motion.boost_requested = true
	motion.plan(0)
	check(not sim.riders[0].boosting and sim.riders[0].boost_locked, "Empty meter locks boost until release")
	motion.boost_requested = false
	motion.plan(0)
	check(not sim.riders[0].boost_locked, "Release clears boost lock")

	# A boosted step must not skip a nearby obstacle.
	sim.reset(12, 7)
	motion = Motion.new(sim)
	motion.reset()
	var target: Vector3i = sim.riders[0].cell + sim.riders[0].forward
	sim.occupied[target] = 0
	motion.boost_requested = true
	motion.plan(0)
	motion.advance(Rules.STEP_TIME * 0.5)
	check(not sim.riders[0].alive and sim.riders[0].cause == "Your own pipe", "Boost cannot tunnel through a pipe")
	var dead_score: int = sim.riders[0].score
	sim.elapse(2.0)
	check(sim.riders[0].score == dead_score, "Eliminated players stop receiving survival points")

	# Credit a living pipe owner, without awarding a self-collision bonus.
	sim.reset(13, 7)
	var directions: Array[Vector3i] = []
	for rider: Dictionary in sim.riders:
		directions.append(rider.forward)
	target = sim.riders[1].cell + sim.riders[1].forward
	sim.occupied[target] = 0
	sim.advance(directions)
	check(sim.riders[0].eliminations == 1 and sim.riders[0].score == 100, "Opponent pipe collision awards 100 to its living owner")
	check(sim.riders[1].eliminations == 0, "Victim receives no elimination points")
	sim.reset(18, 7)
	for i in range(2, sim.riders.size()):
		sim.riders[i].alive = false
	sim.riders[1].cell = Vector3i(29, 15, 15)
	sim.riders[1].forward = Vector3i.RIGHT
	directions.clear()
	for rider: Dictionary in sim.riders:
		directions.append(rider.forward)
	sim.advance(directions)
	check(sim.finished and sim.winner == 0 and sim.riders[0].score == 250, "Last survivor receives the 250-point win bonus")

	# Simultaneous events at different speeds are resolved as one collision group.
	sim.reset(14, 7)
	for i in range(2, sim.riders.size()):
		sim.riders[i].alive = false
	sim.occupied.clear()
	sim.riders[0].cell = Vector3i(4, 10, 10)
	sim.riders[0].forward = Vector3i.RIGHT
	sim.riders[1].cell = Vector3i(6, 10, 10)
	sim.riders[1].forward = Vector3i.LEFT
	sim.occupied[sim.riders[0].cell] = 0
	sim.occupied[sim.riders[1].cell] = 1
	motion = Motion.new(sim)
	motion.reset()
	motion.directions[0] = Vector3i.RIGHT
	motion.directions[1] = Vector3i.LEFT
	motion.duration[0] = Rules.STEP_TIME * 0.5
	motion.duration[1] = Rules.STEP_TIME
	motion.elapsed[1] = Rules.STEP_TIME * 0.5
	motion.advance(Rules.STEP_TIME * 0.5)
	check(sim.finished and sim.winner == -1, "Coincident boosted and normal arrivals eliminate both heads")
	check(sim.riders[0].score == 0 and sim.riders[1].score == 0, "Head-on draw gives no win or elimination bonus")

	# Fractional-frame time cannot award the same second twice.
	sim.reset(17, 7)
	for i in range(600):
		sim.elapse(1.0 / 60.0)
	check(sim.riders[0].score == 10, "Survival scoring awards exactly one point per second")
	print("FEATURES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
