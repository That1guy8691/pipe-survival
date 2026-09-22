extends MultiMeshInstance3D

const Rules = preload("res://scripts/simulation.gd")
var shown_revision := -1
var model

func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.46
	sphere.height = 0.92
	sphere.radial_segments = 12
	sphere.rings = 6
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffdb77")
	material_override = material

func sync(scoring) -> void:
	if shown_revision == scoring.revision:
		return
	shown_revision = scoring.revision
	multimesh.instance_count = scoring.orbs.size()
	var i := 0
	for cell: Vector3i in scoring.orbs:
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, model.world(cell)))
		i += 1
