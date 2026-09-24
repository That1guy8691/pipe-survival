extends RefCounted
## Shared appearance for completed trails, growing segments, and the options preview.

enum Pattern { SOLID, STRIPES, SPOTS, RAINBOW, HELIX, CHECKER, CROSSHATCH, RINGS }
const NAMES := ["Solid", "Stripes", "Spots", "Rainbow", "Helix", "Checker", "Crosshatch", "Rings"]
const SHADER = preload("res://scripts/pipe_pattern.gdshader")

static func apply(material: ShaderMaterial, color: Color, pattern: int) -> void:
	material.set_shader_parameter("pipe_color", color)
	material.set_shader_parameter("pattern", clampi(pattern, Pattern.SOLID, Pattern.RINGS))
	material.set_shader_parameter("rainbow_phase", 0.0)
	var accent := color.darkened(0.65) if color.get_luminance() > 0.3 else color.lightened(0.65)
	material.set_shader_parameter("accent_color", accent)

static func rainbow_phase(incoming: Vector3i, outgoing: Vector3i, up: Vector3i) -> float:
	var forward_axis := -Vector3(incoming)
	var side_axis := Vector3(outgoing) if incoming != outgoing else Vector3(up).cross(forward_axis)
	var up_axis := forward_axis.cross(side_axis).normalized()
	var angle := atan2(Vector3(up).dot(side_axis.normalized()), Vector3(up).dot(up_axis))
	return fposmod(-angle / TAU, 1.0)

static func material(color: Color, pattern: int = Pattern.SOLID,
		segment_length: float = 2.0, fill: float = 1.0) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = SHADER
	apply(result, color, pattern)
	result.set_shader_parameter("segment_length", segment_length)
	result.set_shader_parameter("fill", fill)
	return result
