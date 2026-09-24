extends SceneTree
## Appearance survives the growing-to-batched handoff, round reset, and Endless respawn.

const Appearance = preload("res://scripts/pipe_appearance.gd")
const Geometry = preload("res://scripts/pipe_geometry.gd")
const Rules = preload("res://scripts/simulation.gd")
var failures := 0
var checks := 0
var directory := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-dir="):
			directory = argument.trim_prefix("--qa-dir=")
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func capture(filename: String) -> void:
	if directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(filename))

func check_turn_phase_continuity() -> void:
	var directions: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP,
		Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]
	for incoming in directions:
		for up in directions:
			if Vector3(incoming).dot(Vector3(up)) != 0.0:
				continue
			var rider := {"forward": incoming, "up": up}
			for outgoing in directions:
				if outgoing == incoming or outgoing == -incoming:
					continue
				var next_up: Vector3i = Rules.next_up(rider, outgoing)
				var entry_phase := Appearance.rainbow_phase(incoming, outgoing, up)
				var elbow_basis := Geometry.orientation(incoming, outgoing)
				var exit_angle := atan2(Vector3(next_up).dot(elbow_basis.z),
					Vector3(next_up).dot(elbow_basis.y))
				var exit_phase := fposmod(-exit_angle / TAU, 1.0)
				check(absf(wrapf(entry_phase - exit_phase, -0.5, 0.5)) < 0.0001,
					"Rainbow hue orientation stays continuous through %s to %s" % [incoming, outgoing])

func check_instance_phase_survives_growth(game) -> void:
	var buffer := MultiMesh.new()
	buffer.transform_format = MultiMesh.TRANSFORM_3D
	buffer.use_custom_data = true
	buffer.mesh = SphereMesh.new()
	buffer.instance_count = 4
	var expected_transform := Transform3D(Basis.IDENTITY, Vector3(2, 3, 4))
	var expected_phase := Color(0.375, 0.0, 0.0, 1.0)
	buffer.set_instance_transform(0, expected_transform)
	buffer.set_instance_custom_data(0, expected_phase)
	var phase_before: Color = buffer.get_instance_custom_data(0)
	var transform_before: Transform3D = buffer.get_instance_transform(0)
	game.pipes.grow_buffer(buffer, 1)
	check(buffer.get_instance_custom_data(0) == phase_before
		and buffer.get_instance_transform(0) == transform_before
		and buffer.instance_count == 2,
		"Rainbow phase remains attached to elbows when trail buffers grow")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	game.set_process(false)
	game.hud.set_process(false)
	game.hud.hide()
	game.bot_count = 1
	game.arena_width = 40
	game.player_color = Color("56eddf")
	for endless in [false, true]:
		game.endless_mode = endless
		for pattern in range(Appearance.Pattern.size()):
			game.player_pattern = pattern
			game.start_round(812)
			game.state = "playing"
			game.arena.hide()
			game.orbs.hide()
			game.hud.hide()
			game.pipes.reset(2)
			for i in range(2):
				game.pipes.inlets[i].hide()
				game.pipes.heads[i].hide()
				game.pipes.markers[i].hide()
				game.pipes.active[i].hide()
			var active: ShaderMaterial = game.pipes.active_materials[0]
			for batch in game.pipes.batches[0]:
				check(batch.material_override.get_shader_parameter("pattern") == pattern,
					"Reset must apply the player pattern to both trail meshes")
				check(batch.material_override.get_shader_parameter("pipe_color") == game.player_color,
					"Reset must preserve the selected base color")
			var bot_pattern: int = game.pipes.active_materials[1].get_shader_parameter("pattern")
			check(bot_pattern in range(Appearance.Pattern.size()), "Bots must use a supported random pattern")
			for batch in game.pipes.batches[1]:
				check(batch.material_override.get_shader_parameter("pattern") == bot_pattern,
					"Bot growing and completed sections must share their random pattern")
			var moves: Array[Dictionary] = [
				{"id": 0, "cell": Vector3i(10, 10, 11), "incoming": Vector3i.FORWARD, "outgoing": Vector3i.FORWARD, "died": false},
				{"id": 0, "cell": Vector3i(10, 10, 10), "incoming": Vector3i.FORWARD, "outgoing": Vector3i.RIGHT, "died": false}]
			var rider: Dictionary = game.sim.riders[0].duplicate()
			for move in moves:
				rider.cell = move.cell
				rider.forward = move.incoming
				game.pipes.begin_rider(0, rider, move.outgoing)
				game.pipes.animate_rider(0, 1.0)
				var expected_phase := Appearance.rainbow_phase(move.incoming, move.outgoing, rider.up)
				check(is_equal_approx(active.get_shader_parameter("rainbow_phase"), expected_phase),
					"Growing pipe aligns its rainbow phase through straight and elbow turns")
				var kind := 0 if move.incoming == move.outgoing else 1
				var finished: ShaderMaterial = game.pipes.batches[0][kind].material_override
				for uniform in ["pattern", "pipe_color", "accent_color", "segment_length", "fill"]:
					check(active.get_shader_parameter(uniform) == finished.get_shader_parameter(uniform),
						"Growing and completed sections must agree on %s" % uniform)
				var segment: Array[Dictionary] = [move]
				game.pipes.commit(segment)
				var instance_index: int = game.pipes.counts[0][kind] - 1
				var phase: float = game.pipes.batches[0][kind].multimesh.get_instance_custom_data(instance_index).r
				check(is_equal_approx(phase, expected_phase),
					"Completed sections retain their rainbow phase at straight and elbow joints")
			check(game.pipes.counts[0] == [1, 1], "The straight and elbow both reach the trail")
			rider.cell = Vector3i(11, 10, 10)
			rider.forward = Vector3i.RIGHT
			game.pipes.begin_rider(0, rider, Vector3i.RIGHT)
			game.pipes.animate_rider(0, 0.55)
			var center: Vector3 = game.sim.world(Vector3i(10, 10, 10)) + Vector3(1, 0, 1)
			game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			game.camera.size = 6.0
			game.camera.position = center + Vector3(3.6, 6, 5)
			game.camera.look_at(center)
			if not endless:
				await capture("pipe-pattern-%d-growing.png" % pattern)
				game.pipes.animate_rider(0, 1.0)
				var final_segment: Array[Dictionary] = [{"id": 0, "cell": rider.cell, "incoming": Vector3i.RIGHT,
					"outgoing": Vector3i.RIGHT, "died": false}]
				game.pipes.commit(final_segment)
				await capture("pipe-pattern-%d-complete.png" % pattern)
			else:
				game.sim.remove_rider_trail(0)
				game.sim.riders[0].alive = false
				game.pipes.remove_rider(0)
				game.request_player_restart()
				check(game.sim.riders[0].alive and game.pipes.active[0].visible,
					"Endless restart restores the growing pipe")
				check(active.get_shader_parameter("pattern") == pattern,
					"Endless restart retains the selected pattern")
	check_turn_phase_continuity()
	check_instance_phase_survives_growth(game)
	check_bot_patterns(game)
	check_custom_appearance(game)
	print("PIPE PATTERNS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check_bot_patterns(game) -> void:
	game.bot_count = 31
	game.endless_mode = true
	game.pipes.pattern_rng.seed = 518
	game.start_round(812)
	game.state = "playing"
	var seen := {}
	var seen_joint_styles := {}
	for i in range(1, game.sim.riders.size()):
		var material: ShaderMaterial = game.pipes.active_materials[i]
		var pattern: int = material.get_shader_parameter("pattern")
		var joint_style: int = material.get_shader_parameter("joint_style")
		var bot_name: String = game.sim.rider_name(i)
		seen[pattern] = true
		seen_joint_styles[joint_style] = true
		check(joint_style in range(Appearance.JointStyle.size()),
			"Bot %d must use a supported random joint style" % i)
		for batch in game.pipes.batches[i]:
			check(batch.material_override.get_shader_parameter("pattern") == pattern,
				"Bot %d must keep its pattern across straight and elbow sections" % i)
			check(batch.material_override.get_shader_parameter("joint_style") == joint_style,
				"Bot %d must use its joint style across straight and elbow sections" % i)
		game.sim.remove_rider_trail(i)
		game.sim.riders[i].alive = false
		game.pipes.remove_rider(i)
		game.respawn_timers[i] = 0.0
		game.advance_endless_respawns(0.01)
		check(game.sim.riders[i].alive, "Bot %d must respawn" % i)
		var respawned_pattern: int = material.get_shader_parameter("pattern")
		var respawned_joint_style: int = material.get_shader_parameter("joint_style")
		check(game.sim.rider_name(i) != bot_name and game.pipes.markers[i].text == game.sim.rider_name(i),
			"Bot %d must return under a new name" % i)
		check(respawned_pattern != pattern and respawned_pattern in range(Appearance.Pattern.size()),
			"Bot %d must return with a different supported pattern" % i)
		for batch in game.pipes.batches[i]:
			check(batch.material_override.get_shader_parameter("pattern") == respawned_pattern
				and batch.material_override.get_shader_parameter("joint_style") == respawned_joint_style,
				"Bot %d must apply its new appearance across every pipe section" % i)
	for pattern in range(Appearance.Pattern.size()):
		check(seen.has(pattern), "Seeded bot selection must include %s" % Appearance.NAMES[pattern])
	for joint_style in range(Appearance.JointStyle.size()):
		check(seen_joint_styles.has(joint_style), "Seeded bot selection must include the %s joint style" % Appearance.JOINT_NAMES[joint_style])

func check_custom_appearance(game) -> void:
	var BotStyle = load("res://scripts/bot_style.gd")
	game.bot_count = 7
	game.player_pattern = Appearance.Pattern.STRIPES
	game.player_joint_style = Appearance.JointStyle.COLLARED
	game.player_secondary_color = Color("f0a642")
	game.player_detail_color = Color("4670d8")
	game.bot_palette = BotStyle.Palette.MUTED
	game.bot_pattern_mix = BotStyle.PatternMix.CUSTOM
	game.bot_custom_pattern_mask = (1 << Appearance.Pattern.SOLID) | (1 << Appearance.Pattern.RINGS)
	game.reduced_glow = true
	game.start_round(812)
	var player_material: ShaderMaterial = game.pipes.active_materials[0]
	check(player_material.get_shader_parameter("accent_color") == game.player_secondary_color
		and player_material.get_shader_parameter("detail_color") == game.player_detail_color,
		"Player secondary and detail colors reach the growing pipe")
	check(game.pipes.batches[0][0].material_override.get_shader_parameter("detail_color") == game.player_detail_color
		and game.pipes.inlet_materials[0].albedo_color == game.player_detail_color,
		"Detail color reaches completed trails and wall fittings")
	check(is_equal_approx(float(player_material.get_shader_parameter("glow_scale")), 0.2)
		and game.pipes.heads[0].material_override.emission.r < game.player_detail_color.r * 0.5,
		"Reduced Glow dims pipe and head emission")
	for i in range(1, game.sim.riders.size()):
		var bot_color: Color = game.sim.rider_color(i)
		var bot_pattern: int = game.pipes.active_materials[i].get_shader_parameter("pattern")
		check(bot_color.v <= 0.721 and bot_pattern in [Appearance.Pattern.SOLID, Appearance.Pattern.RINGS],
			"Muted bots use the selected custom pattern mix")
		game.pipes.reroll_bot_appearance(i)
		check(game.pipes.active_materials[i].get_shader_parameter("pattern") in
			[Appearance.Pattern.SOLID, Appearance.Pattern.RINGS],
			"Bot respawn keeps the custom pattern mix")
