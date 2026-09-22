extends Node3D

const Rules = preload("res://scripts/simulation.gd")
const Geometry = preload("res://scripts/pipe_geometry.gd")
const Inlet = preload("res://scripts/pipe_inlet.gd")
var model
var meshes: Array[ArrayMesh] = []
var batches: Array = []
var counts: Array = []
var active: Array[MeshInstance3D] = []
var heads: Array[MeshInstance3D] = []
var markers: Array[Label3D] = []
var active_materials: Array[ShaderMaterial] = []
var plans: Array[Dictionary] = []
var inlets: Array[Node3D] = []

func _ready() -> void:
	meshes = [Geometry.make_tube(false), Geometry.make_tube(true)]

func ensure_count(total: int) -> void:
	for i in range(batches.size(), total):
		var inlet := Inlet.make(Rules.color_for(i))
		add_child(inlet)
		inlets.append(inlet)
		var per_rider: Array[MultiMeshInstance3D] = []
		for kind in range(2):
			var batch := MultiMeshInstance3D.new()
			batch.multimesh = MultiMesh.new()
			batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			batch.multimesh.mesh = meshes[kind]
			batch.multimesh.instance_count = 256
			batch.multimesh.visible_instance_count = 0
			batch.material_override = Geometry.material(Rules.color_for(i))
			add_child(batch)
			per_rider.append(batch)
		batches.append(per_rider)
		counts.append([0, 0])
		var moving := MeshInstance3D.new()
		var material := Geometry.growing_material(Rules.color_for(i))
		moving.material_override = material
		add_child(moving)
		active.append(moving)
		active_materials.append(material)
		var head := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.66
		sphere.height = 1.32
		sphere.radial_segments = 16
		sphere.rings = 8
		head.mesh = sphere
		var head_material := Geometry.material(Rules.color_for(i).lightened(0.25))
		head_material.emission = Rules.color_for(i) * 0.5
		head.material_override = head_material
		add_child(head)
		heads.append(head)
		var marker := Label3D.new()
		marker.text = Rules.name_for(i)
		marker.font_size = 38 if i == 0 else 28
		marker.pixel_size = 0.014
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.modulate = Rules.color_for(i)
		marker.outline_size = 10
		marker.no_depth_test = i == 0
		add_child(marker)
		markers.append(marker)

func reset(total: int = Rules.DEFAULT_BOTS + 1) -> void:
	ensure_count(total)
	plans.clear()
	for i in range(batches.size()):
		counts[i] = [0, 0]
		for batch: MultiMeshInstance3D in batches[i]:
			batch.multimesh.visible_instance_count = 0
		active[i].visible = i < total
		heads[i].visible = i < total
		markers[i].visible = i < total
		inlets[i].visible = i < total
	for i in range(total):
		plans.append({})
		var rider: Dictionary = model.riders[i]
		var forward: Vector3i = rider.source_forward
		inlets[i].transform = Transform3D(Geometry.orientation(forward, forward),
			model.world(rider.source_cell) - Vector3(forward) * Rules.SPACING * 0.5)

func begin_step(riders: Array[Dictionary], directions: Array[Vector3i]) -> void:
	for i in range(riders.size()):
		begin_rider(i, riders[i], directions[i])

func begin_rider(i: int, rider: Dictionary, outgoing: Vector3i) -> void:
	var elbow: bool = outgoing != rider.forward
	var basis := Geometry.orientation(rider.forward, outgoing)
	var origin: Vector3 = model.world(rider.cell)
	plans[i] = {"basis": basis, "origin": origin, "elbow": elbow,
		"incoming": rider.forward, "outgoing": outgoing, "up": rider.up}
	active[i].visible = rider.alive
	if not rider.alive:
		return
	active[i].mesh = meshes[1 if elbow else 0]
	active[i].transform = Transform3D(basis, origin)
	active_materials[i].set_shader_parameter("fill", 0.0)

func pose(index: int, progress: float) -> Dictionary:
	var plan: Dictionary = plans[index]
	var up := Vector3(plan.up)
	if plan.elbow:
		var axis := Vector3(plan.incoming).cross(Vector3(plan.outgoing)).normalized()
		up = up.rotated(axis, progress * PI * 0.5)
	return {"position": plan.origin + plan.basis * Geometry.centerline(plan.elbow, progress),
		"forward": plan.basis * Geometry.tangent(plan.elbow, progress), "up": up}

func animate(progress: float, riders: Array[Dictionary]) -> void:
	for i in range(riders.size()):
		if not riders[i].alive:
			continue
		animate_rider(i, progress)

func animate_rider(i: int, progress: float) -> void:
	active_materials[i].set_shader_parameter("fill", progress)
	var head_pose := pose(i, progress)
	heads[i].position = head_pose.position
	markers[i].position = head_pose.position + head_pose.up * 1.65

func commit(moves: Array[Dictionary]) -> void:
	for move: Dictionary in moves:
		var i: int = move.id
		var kind := 1 if move.incoming != move.outgoing else 0
		var batch: MultiMeshInstance3D = batches[i][kind]
		var count: int = counts[i][kind]
		if count >= batch.multimesh.instance_count:
			grow_buffer(batch.multimesh, count)
		batch.multimesh.set_instance_transform(count, Transform3D(
			Geometry.orientation(move.incoming, move.outgoing), model.world(move.cell)))
		counts[i][kind] += 1
		batch.multimesh.visible_instance_count = counts[i][kind]
		active[i].visible = false
		if move.died:
			heads[i].visible = false
			markers[i].visible = false

func grow_buffer(buffer: MultiMesh, count: int) -> void:
	var saved: Array[Transform3D] = []
	for i in range(count):
		saved.append(buffer.get_instance_transform(i))
	buffer.instance_count = count * 2
	for i in range(count):
		buffer.set_instance_transform(i, saved[i])
