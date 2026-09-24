extends RefCounted
## Shared appearance for completed trails, growing segments, and the options preview.

enum Pattern { SOLID, STRIPES, SPOTS, RAINBOW, HELIX, CHECKER, CROSSHATCH, RINGS, CHROME }
enum Finish { ALLOY, BRUSHED_STEEL, CERAMIC, POLYMER, RUBBER }
enum JointStyle { COLLARED, SEAMLESS }
const NAMES := ["Solid", "Stripes", "Spots", "Rainbow", "Helix", "Checker", "Crosshatch", "Rings", "Chrome"]
const FINISH_NAMES := ["Standard Alloy", "Brushed Steel", "Ceramic", "Polymer", "Rubber"]
const JOINT_NAMES := ["Collared", "Seamless"]
const SHADER = preload("res://scripts/pipe_pattern.gdshader")

static func apply(material: ShaderMaterial, color: Color, pattern: int,
		finish: int = Finish.ALLOY, joint_style: int = JointStyle.COLLARED,
		secondary: Color = Color.TRANSPARENT, detail: Color = Color.TRANSPARENT,
		glow_scale: float = 1.0) -> void:
	material.set_shader_parameter("pipe_color", color)
	material.set_shader_parameter("pattern", clampi(pattern, Pattern.SOLID, Pattern.CHROME))
	material.set_shader_parameter("finish", clampi(finish, Finish.ALLOY, Finish.RUBBER))
	material.set_shader_parameter("joint_style", clampi(joint_style, JointStyle.COLLARED, JointStyle.SEAMLESS))
	var accent := secondary if secondary.a > 0.0 else (color.darkened(0.65)
		if color.get_luminance() > 0.3 else color.lightened(0.65))
	material.set_shader_parameter("accent_color", accent)
	material.set_shader_parameter("detail_color", detail if detail.a > 0.0 else color)
	material.set_shader_parameter("custom_accent", secondary.a > 0.0)
	material.set_shader_parameter("custom_detail", detail.a > 0.0)
	material.set_shader_parameter("glow_scale", glow_scale)

static func rainbow_phase(incoming: Vector3i, outgoing: Vector3i, up: Vector3i) -> float:
	var forward_axis := -Vector3(incoming)
	var side_axis := Vector3(outgoing) if incoming != outgoing else Vector3(up).cross(forward_axis)
	var up_axis := forward_axis.cross(side_axis).normalized()
	var angle := atan2(Vector3(up).dot(side_axis.normalized()), Vector3(up).dot(up_axis))
	return fposmod(-angle / TAU, 1.0)

static func material(color: Color, pattern: int = Pattern.SOLID,
		segment_length: float = 2.0, fill: float = 1.0,
		finish: int = Finish.ALLOY, joint_style: int = JointStyle.COLLARED,
		secondary: Color = Color.TRANSPARENT, detail: Color = Color.TRANSPARENT,
		glow_scale: float = 1.0) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = SHADER
	apply(result, color, pattern, finish, joint_style, secondary, detail, glow_scale)
	result.set_shader_parameter("segment_length", segment_length)
	result.set_shader_parameter("fill", fill)
	return result
