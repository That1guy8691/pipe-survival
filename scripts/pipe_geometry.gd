extends RefCounted
## Two reusable tube meshes: straight and a true quarter-circle plumbing elbow.

const Appearance = preload("res://scripts/pipe_appearance.gd")

static func centerline(elbow: bool, t: float) -> Vector3:
	if elbow:
		return Vector3(1.0 - cos(t * PI * 0.5), 0.0, 1.0 - sin(t * PI * 0.5))
	return Vector3(0.0, 0.0, 1.0 - t * 2.0)

static func tangent(elbow: bool, t: float) -> Vector3:
	if elbow:
		return Vector3(sin(t * PI * 0.5), 0.0, -cos(t * PI * 0.5))
	return Vector3.FORWARD

static func orientation(incoming: Vector3i, outgoing: Vector3i,
		up_direction: Vector3i = Vector3i.UP) -> Basis:
	var z_axis := -Vector3(incoming)
	var x_axis: Vector3
	if incoming != outgoing:
		x_axis = Vector3(outgoing)
	else:
		var up_axis := Vector3(up_direction)
		up_axis -= z_axis * up_axis.dot(z_axis)
		if up_axis.length_squared() < 0.0001:
			up_axis = Vector3.UP if absf(z_axis.y) < 0.9 else Vector3.BACK
		x_axis = up_axis.normalized().cross(z_axis).normalized()
	return Basis(x_axis, z_axis.cross(x_axis), z_axis)

static func make_tube(elbow: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_times := PackedFloat32Array([0.0, 0.0625, 0.125, 0.875, 0.9375, 1.0])
	if elbow:
		ring_times = PackedFloat32Array([0.0, 0.0625, 0.125, 0.25, 0.375,
			0.5, 0.625, 0.75, 0.875, 0.9375, 1.0])
	const SIDES := 12
	for ring in range(ring_times.size() - 1):
		for side in range(SIDES):
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
				Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)]:
				var t := ring_times[ring + corner.x]
				var angle := float(side + corner.y) / SIDES * TAU
				var side_axis := tangent(elbow, t).cross(Vector3.UP)
				var normal := Vector3.UP * cos(angle) + side_axis * sin(angle)
				var radius := 0.645 if t < 0.07 or t > 0.93 else 0.6
				surface.set_normal(normal)
				surface.set_uv(Vector2(float(side + corner.y) / SIDES, t))
				surface.add_vertex(centerline(elbow, t) + normal * radius)
	return surface.commit()

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = 0.62
	result.roughness = 0.28
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.emission_enabled = true
	result.emission = color * 0.13
	return result

static func growing_material(color: Color) -> ShaderMaterial:
	return Appearance.material(color, Appearance.Pattern.SOLID, 2.0, 0.0)
