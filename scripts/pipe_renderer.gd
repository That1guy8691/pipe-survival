extends Node3D

const Rules = preload("res://scripts/simulation.gd")
const Geometry = preload("res://scripts/pipe_geometry.gd")
const Inlet = preload("res://scripts/pipe_inlet.gd")
const Appearance = preload("res://scripts/pipe_appearance.gd")
const BotStyle = preload("res://scripts/bot_style.gd")
enum OverviewStyle { NORMAL, HIGHLIGHT, ENDS }
var player_pattern := Appearance.Pattern.SOLID
var player_material := Appearance.Finish.ALLOY
var player_joint_style := Appearance.JointStyle.COLLARED
var player_secondary_color := Color.TRANSPARENT
var player_detail_color := Color.TRANSPARENT
var bot_palette := BotStyle.Palette.STANDARD
var bot_pattern_mix := BotStyle.PatternMix.ALL
var bot_custom_pattern_mask := BotStyle.ALL_PATTERNS_MASK
var reduced_glow := false
var player_id := 0
var pattern_rng := RandomNumberGenerator.new()
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
var applied_overview_style := -1
var applied_focus_id := -1

func _ready() -> void:
	pattern_rng.randomize()
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
			batch.multimesh.use_custom_data = true
			batch.multimesh.mesh = meshes[kind]
			batch.multimesh.instance_count = 256
			batch.multimesh.visible_instance_count = 0
			var batch_material := Appearance.material(pipe_color, player_pattern if i == player_id else 0,
				2.0 if kind == 0 else PI * 0.5,
				1.0, player_material if i == player_id else Appearance.Finish.ALLOY,
				player_joint_style if i == player_id else Appearance.JointStyle.COLLARED)
			batch_material.set_shader_parameter("use_instance_phase", true)
			batch.material_override = batch_material
			add_child(batch)
			per_rider.append(batch)
		batches.append(per_rider)
		counts.append([0, 0])
		var moving := MeshInstance3D.new()
		var material := Geometry.growing_material(pipe_color,
			player_material if i == player_id else Appearance.Finish.ALLOY,
			player_joint_style if i == player_id else Appearance.JointStyle.COLLARED)
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
		marker.font_size = 38 if i == player_id else 28
		marker.pixel_size = 0.014
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.modulate = pipe_color
		marker.outline_size = 10
		marker.no_depth_test = i == player_id
		add_child(marker)
		markers.append(marker)

func reset(total: int = Rules.DEFAULT_BOTS + 1) -> void:
	ensure_count(total)
	applied_overview_style = -1
	applied_focus_id = -1
	plans.clear()
	for i in range(batches.size()):
		counts[i] = [0, 0]
		for batch: MultiMeshInstance3D in batches[i]:
			batch.multimesh.visible_instance_count = 0
		var visible_rider: bool = i < total and bool(model.riders[i].alive)
		active[i].visible = visible_rider
		heads[i].visible = visible_rider
		markers[i].visible = visible_rider
		inlets[i].visible = visible_rider
	for i in range(total):
		plans.append({})
		var rider: Dictionary = model.riders[i]
		var pipe_color: Color = model.rider_color(i)
		# Pick for this round; Endless respawns draw again from the selected mix.
		var pattern := player_pattern if i == player_id else BotStyle.choose_pattern(pattern_rng,
			bot_pattern_mix, bot_custom_pattern_mask)
		var finish := player_material if i == player_id else Appearance.Finish.ALLOY
		var joint_style := player_joint_style if i == player_id else pattern_rng.randi_range(
			Appearance.JointStyle.COLLARED, Appearance.JointStyle.SEAMLESS)
		var secondary := player_secondary_color if i == player_id else Color.TRANSPARENT
		var detail := player_detail_color if i == player_id else Color.TRANSPARENT
		var glow := glow_for(i)
		for batch: MultiMeshInstance3D in batches[i]:
			Appearance.apply(batch.material_override, pipe_color, pattern, finish, joint_style,
				secondary, detail, glow)
		var fitting_color := detail if detail.a > 0.0 else pipe_color
		inlet_materials[i].albedo_color = fitting_color
		inlet_materials[i].emission = fitting_color * 0.13 * glow
		inlet_materials[i].roughness = 0.5 if reduced_glow else 0.28
		Appearance.apply(active_materials[i], pipe_color, pattern, finish, joint_style,
			secondary, detail, glow)
		var head_material := heads[i].material_override as StandardMaterial3D
		head_material.albedo_color = fitting_color.lightened(0.25)
		head_material.emission = fitting_color * 0.5 * glow
		head_material.roughness = 0.5 if reduced_glow else 0.28
		markers[i].text = model.rider_name(i)
		markers[i].modulate = pipe_color
		var forward: Vector3i = rider.source_forward
		inlets[i].transform = Transform3D(Geometry.orientation(forward, forward),
			model.world(rider.source_cell) - Vector3(forward) * Rules.SPACING * 0.5)

func reroll_bot_appearance(index: int) -> void:
	if index <= 0 or index >= active_materials.size():
		return
	var old_pattern := int(active_materials[index].get_shader_parameter("pattern"))
	var pattern := BotStyle.choose_pattern(pattern_rng, bot_pattern_mix,
		bot_custom_pattern_mask, old_pattern)
	var joint_style := pattern_rng.randi_range(
		Appearance.JointStyle.COLLARED, Appearance.JointStyle.SEAMLESS)
	var pipe_color: Color = model.rider_color(index)
	var glow := glow_for(index)
	for batch: MultiMeshInstance3D in batches[index]:
		Appearance.apply(batch.material_override, pipe_color, pattern, Appearance.Finish.ALLOY,
			joint_style, Color.TRANSPARENT, Color.TRANSPARENT, glow)
	Appearance.apply(active_materials[index], pipe_color, pattern,
		Appearance.Finish.ALLOY, joint_style, Color.TRANSPARENT, Color.TRANSPARENT, glow)

func glow_for(index: int) -> float:
	if reduced_glow:
		return 0.2
	return 1.8 if index != player_id and bot_palette == BotStyle.Palette.NEON else 1.0

func set_overview_style(style: int, focus_id: int) -> void:
	if style == applied_overview_style and focus_id == applied_focus_id:
		return
	applied_overview_style = style
	applied_focus_id = focus_id
	for i in range(batches.size()):
		if i >= model.riders.size():
			continue
		var focused := i == focus_id
		var trail_brightness := 1.0
		var head_brightness := 1.0
		var inlet_brightness := 1.0
		var label_alpha := 1.0
		var head_emission := 0.5
		var inlet_emission := 0.13
		match style:
			OverviewStyle.HIGHLIGHT:
				if not focused:
					trail_brightness = 0.12
					head_brightness = 0.28
					inlet_brightness = 0.32
					label_alpha = 0.24
					head_emission = 0.12
					inlet_emission = 0.04
			OverviewStyle.ENDS:
				trail_brightness = 0.16
				head_brightness = 1.35
				inlet_brightness = 1.7
				label_alpha = 0.9
				head_emission = 1.15
				inlet_emission = 0.55
		var pipe_color: Color = model.rider_color(i)
		var fitting_color := player_detail_color if i == player_id and player_detail_color.a > 0.0 else pipe_color
		var glow := glow_for(i)
		if reduced_glow:
			head_brightness = minf(head_brightness, 1.0)
			inlet_brightness = minf(inlet_brightness, 1.0)
		for batch: MultiMeshInstance3D in batches[i]:
			(batch.material_override as ShaderMaterial).set_shader_parameter(
				"display_brightness", trail_brightness)
		active_materials[i].set_shader_parameter("display_brightness", trail_brightness)
		var head_material := heads[i].material_override as StandardMaterial3D
		head_material.albedo_color = scale_rgb(fitting_color.lightened(0.25), head_brightness)
		head_material.emission = fitting_color * head_emission * glow
		inlet_materials[i].albedo_color = scale_rgb(fitting_color, inlet_brightness)
		inlet_materials[i].emission = fitting_color * inlet_emission * glow
		markers[i].modulate = Color(pipe_color.r, pipe_color.g, pipe_color.b, label_alpha)

static func scale_rgb(color: Color, factor: float) -> Color:
	return Color(color.r * factor, color.g * factor, color.b * factor, color.a)

func begin_step(riders: Array[Dictionary], directions: Array[Vector3i]) -> void:
	for i in range(riders.size()):
		begin_rider(i, riders[i], directions[i])

func begin_rider(i: int, rider: Dictionary, outgoing: Vector3i) -> void:
	var elbow: bool = outgoing != rider.forward
	var basis := Geometry.orientation(rider.forward, outgoing, rider.up)
	var origin: Vector3 = model.world(rider.cell)
	var rainbow_phase := Appearance.rainbow_phase(rider.forward, outgoing, rider.up)
	plans[i] = {"basis": basis, "origin": origin, "elbow": elbow,
		"incoming": rider.forward, "outgoing": outgoing, "up": rider.up,
		"rainbow_phase": rainbow_phase}
	active[i].visible = rider.alive
	if not rider.alive:
		return
	active[i].mesh = meshes[1 if elbow else 0]
	active[i].transform = Transform3D(basis, origin)
	active_materials[i].set_shader_parameter("segment_length", PI * 0.5 if elbow else 2.0)
	active_materials[i].set_shader_parameter("rainbow_phase", rainbow_phase)
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
		var segment_up: Vector3i = move.get("up", Vector3i.UP)
		batch.multimesh.set_instance_transform(count, Transform3D(
			Geometry.orientation(move.incoming, move.outgoing, segment_up), model.world(move.cell)))
		batch.multimesh.set_instance_custom_data(count,
			Color(float(plans[i].get("rainbow_phase", 0.0)), 0.0, 0.0, 1.0))
		counts[i][kind] += 1
		batch.multimesh.visible_instance_count = counts[i][kind]
		active[i].visible = false
		if move.died:
			heads[i].visible = false
			markers[i].visible = false

func rebuild_from_history(histories: Array) -> void:
	"""Recreate visible authoritative trails after a full network snapshot."""
	reset(model.riders.size())
	for i in range(model.riders.size()):
		if i >= histories.size():
			continue
		for raw_move in histories[i]:
			if not raw_move is Dictionary:
				continue
			var move: Dictionary = raw_move
			var segment_rider := {"cell": move.get("cell", Vector3i.ZERO),
				"forward": move.get("incoming", Vector3i.FORWARD),
				"up": move.get("up", Vector3i.UP), "alive": true}
			begin_rider(i, segment_rider, move.get("outgoing", segment_rider.forward))
			commit([move])
		if model.riders[i].alive:
			begin_rider(i, model.riders[i], model.riders[i].forward)
			restore_rider(i, model.riders[i])

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
	markers[index].text = model.rider_name(index)
	heads[index].visible = true
	markers[index].visible = true

func grow_buffer(buffer: MultiMesh, count: int) -> void:
	var saved: Array[Transform3D] = []
	var saved_custom_data: Array[Color] = []
	for i in range(count):
		saved.append(buffer.get_instance_transform(i))
		saved_custom_data.append(buffer.get_instance_custom_data(i))
	buffer.instance_count = count * 2
	for i in range(count):
		buffer.set_instance_transform(i, saved[i])
		buffer.set_instance_custom_data(i, saved_custom_data[i])
