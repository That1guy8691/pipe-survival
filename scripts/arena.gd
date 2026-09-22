extends Node3D

const Rules = preload("res://scripts/simulation.gd")
var width := Rules.DEFAULT_WIDTH
var labels: Array[Label3D] = []
var half_width: float:
	get: return width * 0.5

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("070e1b")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("99b6d7")
	settings.ambient_light_energy = 0.65
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -25, 0)
	key.light_color = Color("d4ebff")
	key.light_energy = 1.6
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(30, 135, 15)
	fill.light_color = Color("74aaf7")
	fill.light_energy = 0.7
	add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * width
	floor_mesh.mesh = plane
	floor_mesh.position.y = -half_width - 0.04
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("111f30")
	floor_material.roughness = 0.8
	floor_mesh.material_override = floor_material
	add_child(floor_mesh)
	make_grid()
	for x in [-half_width, half_width]:
		for y in [-half_width, half_width]:
			beam(Vector3(x, y, -half_width), Vector3(x, y, half_width))
	for x in [-half_width, half_width]:
		for z in [-half_width, half_width]:
			beam(Vector3(x, -half_width, z), Vector3(x, half_width, z))
	for y in [-half_width, half_width]:
		for z in [-half_width, half_width]:
			beam(Vector3(-half_width, y, z), Vector3(half_width, y, z))
	wall_label("NORTH / -Z", Vector3(0, half_width - 2.5, -half_width), Vector3.ZERO)
	wall_label("SOUTH / +Z", Vector3(0, half_width - 2.5, half_width), Vector3(0, PI, 0))
	wall_label("WEST / -X", Vector3(-half_width, half_width - 2.5, 0), Vector3(0, PI / 2, 0))
	wall_label("EAST / +X", Vector3(half_width, half_width - 2.5, 0), Vector3(0, -PI / 2, 0))

func make_grid() -> void:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("203b52")
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for value in range(-int(half_width), int(half_width) + 1, 4):
		for side in [-half_width, half_width]:
			for pair: Array in [
				[Vector3(value, side, -half_width), Vector3(value, side, half_width)],
				[Vector3(-half_width, side, value), Vector3(half_width, side, value)],
				[Vector3(side, value, -half_width), Vector3(side, value, half_width)],
				[Vector3(side, -half_width, value), Vector3(side, half_width, value)],
				[Vector3(value, -half_width, side), Vector3(value, half_width, side)],
				[Vector3(-half_width, value, side), Vector3(half_width, value, side)]]:
				mesh.surface_add_vertex(pair[0])
				mesh.surface_add_vertex(pair[1])
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)

func beam(start: Vector3, end: Vector3) -> void:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.07, start.distance_to(end))
	instance.mesh = box
	instance.position = (start + end) / 2.0
	var delta := (end - start).normalized()
	var up := Vector3.UP if absf(delta.y) < 0.9 else Vector3.BACK
	instance.basis = Basis.looking_at(delta, up)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("44838f")
	instance.material_override = material
	add_child(instance)

func wall_label(text: String, location: Vector3, rotation_value: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = location
	label.rotation = rotation_value
	label.font_size = 52
	label.pixel_size = 0.022
	label.modulate = Color("63869e")
	label.outline_size = 0
	label.double_sided = true
	add_child(label)
	labels.append(label)

func set_labels_visible(enabled: bool) -> void:
	for label in labels:
		label.visible = enabled
