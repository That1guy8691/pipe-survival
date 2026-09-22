extends RefCounted
## A wall fitting whose local -Z points into the arena, like a straight pipe.

const Geometry = preload("res://scripts/pipe_geometry.gd")

static func make(color: Color) -> Node3D:
	var inlet := Node3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(2.2, 2.2, 0.16)
	attach(inlet, plate, Geometry.material(Color("344759")), Vector3(0, 0, -0.08))
	var collar := TorusMesh.new()
	collar.inner_radius = 0.65
	collar.outer_radius = 0.91
	collar.rings = 24
	collar.ring_segments = 12
	var neck := attach(inlet, collar, Geometry.material(color), Vector3(0, 0, -0.24))
	neck.rotation.x = PI * 0.5
	var bolt := CylinderMesh.new()
	bolt.top_radius = 0.12
	bolt.bottom_radius = 0.12
	bolt.height = 0.1
	bolt.radial_segments = 6
	var steel := Geometry.material(Color("b3c5d2"))
	for x in [-0.84, 0.84]:
		for y in [-0.84, 0.84]:
			var screw := attach(inlet, bolt, steel, Vector3(x, y, -0.21))
			screw.rotation.x = PI * 0.5
	return inlet

static func attach(parent: Node3D, mesh: Mesh, material: Material, offset: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	parent.add_child(instance)
	return instance
