extends SceneTree

const Rules = preload("res://scripts/simulation.gd")
const Renderer = preload("res://scripts/pipe_renderer.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sim := Rules.new()
	sim.reset(15, 7, 100)
	var renderer := Renderer.new()
	renderer.model = sim
	root.add_child(renderer)
	renderer.reset(8)
	var first := Transform3D.IDENTITY
	for i in range(300):
		var moves: Array[Dictionary] = [{"id": 0, "cell": Vector3i(i % 50, int(i / 50), 0),
			"incoming": Vector3i.FORWARD, "outgoing": Vector3i.FORWARD, "died": false}]
		renderer.commit(moves)
		if i == 0:
			first = renderer.batches[0][0].multimesh.get_instance_transform(0)
	var buffer: MultiMesh = renderer.batches[0][0].multimesh
	var passed := buffer.instance_count >= 300 and buffer.visible_instance_count == 300
	passed = passed and buffer.get_instance_transform(0).is_equal_approx(first)
	passed = passed and buffer.get_instance_transform(299).origin == sim.world(Vector3i(49, 5, 0))
	renderer.reset(8)
	passed = passed and buffer.visible_instance_count == 0
	print("RENDER BUFFER: %s (growth preserves first/last sections and restart clears visibility)" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
