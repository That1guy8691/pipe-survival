extends SubViewportContainer
## A straight section and elbow rendered with the actual gameplay meshes/materials.

const Geometry = preload("res://scripts/pipe_geometry.gd")
const Appearance = preload("res://scripts/pipe_appearance.gd")
var viewport := SubViewport.new()
var materials: Array[ShaderMaterial] = []
var current_color := Color.TRANSPARENT
var current_pattern := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	viewport.size = Vector2i(484, 96)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c8deed")
	environment.environment.ambient_light_energy = 0.8
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.4
	viewport.add_child(light)
	var path := Node3D.new()
	viewport.add_child(path)
	# A connected straight, quarter-turn, and straight show both kinds of surface.
	var cells := [Vector3(0, 0, 2), Vector3.ZERO, Vector3(2, 0, 0)]
	var incoming := [Vector3i.FORWARD, Vector3i.FORWARD, Vector3i.RIGHT]
	var outgoing := [Vector3i.FORWARD, Vector3i.RIGHT, Vector3i.RIGHT]
	for i in range(cells.size()):
		var elbow: bool = incoming[i] != outgoing[i]
		var mesh := MeshInstance3D.new()
		mesh.mesh = Geometry.make_tube(elbow)
		var material := Appearance.material(Color.WHITE, 0, PI * 0.5 if elbow else 2.0)
		mesh.material_override = material
		mesh.transform = Transform3D(Geometry.orientation(incoming[i], outgoing[i]), cells[i])
		material.set_shader_parameter("rainbow_phase",
			Appearance.rainbow_phase(incoming[i], outgoing[i], Vector3i.UP))
		materials.append(material)
		path.add_child(mesh)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.2
	viewport.add_child(camera)
	camera.position = Vector3(4.6, 6, 6)
	camera.look_at(Vector3(1, 0, 1))
	camera.current = true
	visibility_changed.connect(request_update)
	resized.connect(request_update)
	request_update()

func set_appearance(color: Color, pattern: int) -> void:
	if current_color == color and current_pattern == pattern:
		return
	current_color = color
	current_pattern = pattern
	for material in materials:
		Appearance.apply(material, color, pattern)
	request_update()

func request_update() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
