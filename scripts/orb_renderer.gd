extends MultiMeshInstance3D

const Rules = preload("res://scripts/simulation.gd")
const Scoring = preload("res://scripts/scoring.gd")
const GLOW_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;

void fragment() {
	float facing = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	float rim = pow(1.0 - facing, 2.0);
	ALBEDO = COLOR.rgb * 0.3;
	EMISSION = COLOR.rgb * (0.3 + rim * 1.2);
	ALPHA = COLOR.a * (0.04 + rim * 0.24);
}
"""
var shown_revision := -1
var model
var glow_multimesh: MultiMesh

func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.46
	sphere.height = 0.92
	sphere.radial_segments = 12
	sphere.rings = 6
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material_override = material
	glow_multimesh = MultiMesh.new()
	glow_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	glow_multimesh.use_colors = true
	glow_multimesh.mesh = sphere
	var glow_material := ShaderMaterial.new()
	var glow_shader := Shader.new()
	glow_shader.code = GLOW_SHADER_CODE
	glow_material.shader = glow_shader
	var glow_instance := MultiMeshInstance3D.new()
	glow_instance.multimesh = glow_multimesh
	glow_instance.material_override = glow_material
	add_child(glow_instance)

func sync(scoring) -> void:
	if shown_revision == scoring.revision:
		return
	shown_revision = scoring.revision
	multimesh.instance_count = scoring.orbs.size()
	glow_multimesh.instance_count = scoring.orbs.size()
	var i := 0
	for cell: Vector3i in scoring.orbs:
		var points: int = scoring.orbs[cell]
		var scale := Scoring.orb_scale(points)
		var location: Vector3 = model.world(cell)
		var core_basis := Basis.IDENTITY.scaled(Vector3.ONE * scale * 0.9)
		var glow_basis := Basis.IDENTITY.scaled(Vector3.ONE * scale * 1.28)
		multimesh.set_instance_transform(i, Transform3D(core_basis, location))
		glow_multimesh.set_instance_transform(i, Transform3D(glow_basis, location))
		var color: Color = Scoring.orb_color(points)
		multimesh.set_instance_color(i, color)
		glow_multimesh.set_instance_color(i, Color(color.r, color.g, color.b, 0.8))
		i += 1
