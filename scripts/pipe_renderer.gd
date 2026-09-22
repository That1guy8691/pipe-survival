extends Node3D

const Rules = preload("res://scripts/simulation.gd")
const Geometry = preload("res://scripts/pipe_geometry.gd")
const Inlet = preload("res://scripts/pipe_inlet.gd")
const Appearance = preload("res://scripts/pipe_appearance.gd")
var player_pattern := Appearance.Pattern.SOLID
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
var inlet_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	meshes = [Geometry.make_tube(false), Geometry.make_tube(true)]

func ensure_count(total: int) -> void:
	for i in range(batches.size(), total):
		var pipe_color: Color = model.rider_color(i)
		var inlet_data: Dictionary = Inlet.make(pipe_color)
		var inlet: Node3D = inlet_data.node
		add_child(inlet)
		inlets.append(inlet)
		inlet_materials.append(inlet_data.color_material)
		var per_rider: Array[MultiMeshInstance3D] = []
		for kind in range(2):
			var batch := MultiMeshInstance3D.new()
			batch.multimesh = MultiMesh.new()
			batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			batch.multimesh.mesh = meshes[kind]
			batch.multimesh.instance_count = 256
			batch.multimesh.visible_instance_count = 0
			batch.material_override = Appearance.material(pipe_color, player_pattern if i == 0 else 0,
				2.0 if kind == 0 else PI * 0.5)
			add_child(batch)
			per_rider.append(batch)
		batches.append(per_rider)
		counts.append([0, 0])
		var moving := MeshInstance3D.new()
		var material := Geometry.growing_material(pipe_color)
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
		var head_material := Geometry.material(pipe_color.lightened(0.25))
		head_material.emission = pipe_color * 0.5
		head.material_override = head_material
		add_child(head)
		heads.append(head)
		var marker := Label3D.new()
		marker.text = model.rider_name(i)
		marker.font_size = 38 if i == 0 else 28
		marker.pixel_size = 0.014
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.modulate = pipe_color
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
		var pipe_color: Color = model.rider_color(i)
		for batch: MultiMeshInstance3D in batches[i]:
			Appearance.apply(batch.material_override, pipe_color, player_pattern if i == 0 else 0)
		inlet_materials[i].albedo_color = pipe_color
		inlet_materials[i].emission = pipe_color * 0.13
		Appearance.apply(active_materials[i], pipe_color, player_pattern if i == 0 else 0)
		var head_material := heads[i].material_override as StandardMaterial3D
		head_material.albedo_color = pipe_color.lightened(0.25)
		head_material.emission = pipe_color * 0.5
		markers[i].text = model.rider_name(i)
		markers[i].modulate = pipe_color
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
	active_materials[i].set_shader_parameter("segment_length", PI * 0.5 if elbow else 2.0)
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
		if model.endless_mode and move.died:
			remove_rider(i)
			continue
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

func remove_rider(index: int) -> void:
	if index < 0 or index >= batches.size():
		return
	counts[index] = [0, 0]
	for batch: MultiMeshInstance3D in batches[index]:
		batch.multimesh.visible_instance_count = 0
	active[index].visible = false
	active_materials[index].set_shader_parameter("fill", 0.0)
	heads[index].visible = false
	markers[index].visible = false
	inlets[index].visible = false
	plans[index] = {}

func restore_rider(index: int, rider: Dictionary) -> void:
	if index < 0 or index >= inlets.size():
		return
	var forward: Vector3i = rider.source_forward
	inlets[index].transform = Transform3D(Geometry.orientation(forward, forward),
		model.world(rider.source_cell) - Vector3(forward) * Rules.SPACING * 0.5)
	inlets[index].visible = true
	heads[index].position = model.world(rider.cell)
	markers[index].position = model.world(rider.cell) + Vector3(rider.up) * 1.65
	heads[index].visible = true
	markers[index].visible = true

func grow_buffer(buffer: MultiMesh, count: int) -> void:
	var saved: Array[Transform3D] = []
	for i in range(count):
		saved.append(buffer.get_instance_transform(i))
	buffer.instance_count = count * 2
	for i in range(count):
		buffer.set_instance_transform(i, saved[i])
