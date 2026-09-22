extends RefCounted
## Shared appearance for completed trails, growing segments, and the options preview.

enum Pattern { SOLID, STRIPES, SPOTS }
const NAMES := ["Solid", "Stripes", "Spots"]
const SHADER = preload("res://scripts/pipe_pattern.gdshader")

static func apply(material: ShaderMaterial, color: Color, pattern: int) -> void:
	material.set_shader_parameter("pipe_color", color)
	material.set_shader_parameter("pattern", clampi(pattern, Pattern.SOLID, Pattern.SPOTS))
	var accent := color.darkened(0.65) if color.get_luminance() > 0.3 else color.lightened(0.65)
	material.set_shader_parameter("accent_color", accent)

static func material(color: Color, pattern: int = Pattern.SOLID,
		segment_length: float = 2.0, fill: float = 1.0) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = SHADER
	apply(result, color, pattern)
	result.set_shader_parameter("segment_length", segment_length)
	result.set_shader_parameter("fill", fill)
	return result
