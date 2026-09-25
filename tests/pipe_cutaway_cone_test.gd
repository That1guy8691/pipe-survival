extends "res://tests/pipe_cutaway_visual_test.gd"
## Camera-relative blockers, nearby hazards, and the user's three-tap shoulder views.

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	game.set_process(false)
	game.hud.set_process(false)
	game.bot_count = 3
	game.pipes.pattern_rng.seed = 821
	game.start_round(821)
	game.state = "playing"
	game.hud.hide()
	game.orbs.hide()
	game.arena.set_labels_visible(false)
	game.pipes.reset(4)
	for i in range(4):
		game.pipes.inlets[i].hide()
		game.pipes.heads[i].hide()
		game.pipes.markers[i].hide()
		game.pipes.active[i].hide()
	for z in range(25, 15, -1):
		section(0, Vector3i(15, 15, z), Vector3i.FORWARD, Vector3i.FORWARD)
	var rider: Dictionary = game.sim.riders[0]
	rider.cell = Vector3i(15, 15, 15)
	rider.forward = Vector3i.FORWARD
	rider.up = Vector3i.UP
	game.pipes.begin_rider(0, rider, rider.forward)
	game.pipes.animate_rider(0, 0.5)
	game.pipes.heads[0].show()
	var pose: Dictionary = game.pipes.pose(0, 0.5)
	game.camera.view = game.camera.View.CHASE
	var blocker: MultiMeshInstance3D = game.pipes.batches[1][0]
	var hazard: MultiMeshInstance3D = game.pipes.batches[2][0]
	var rear: MultiMeshInstance3D = game.pipes.batches[3][0]
	# Three arrow presses are +/- 0.432 radians. Include the original view too.
	for taps in [-3, 0, 3]:
		game.camera.chase_yaw = 0.0
		for _tap in range(absi(taps)):
			game.camera.orbit_step(signi(taps), 0.0)
		game.camera.initialized = false
		game.camera.follow(pose, 0.0)
		for view_offset in [0.0, 0.22]:
			# Move the head off screen center without moving the obstruction: the
			# cone must follow the real target, including while the camera catches up.
			game.camera.quaternion = game.camera.quaternion * Quaternion(Vector3.UP, view_offset)
			var label := "shoulder-%d-offset-%.2f" % [taps, view_offset]
			blocker.multimesh.visible_instance_count = 0
			cutaway(true)
			var reference := await capture(label + "-reference.png")
			var halfway: Vector3 = game.camera.global_position.lerp(pose.position, 0.45)
			var basis: Basis = game.camera.global_basis * Basis(Vector3.UP, PI * 0.5)
			for index in range(7):
				blocker.multimesh.set_instance_transform(index,
					Transform3D(basis, halfway + game.camera.global_basis.x * (index - 3) * 2.0))
			blocker.multimesh.visible_instance_count = 7
			cutaway(false)
			var blocked := await capture(label + "-off.png")
			cutaway(true)
			var cleared := await capture(label + "-on.png")
			var point: Vector2 = game.camera.unproject_position(pose.position)
			check(region_differences(blocked, reference, point, 20.0) > 100,
				label + " fixture obscures the followed head")
			check_revealed(label, blocked, cleared, reference, point, 20.0)
			blocker.multimesh.visible_instance_count = 0
			# A pipe one cell ahead is a real threat, even when it overlaps the cone tip.
			hazard.multimesh.set_instance_transform(0,
				Transform3D(basis, pose.position + pose.forward * 2.0))
			hazard.multimesh.visible_instance_count = 1
			rear.multimesh.set_instance_transform(0,
				Transform3D(basis, pose.position + pose.forward * 8.0))
			rear.multimesh.visible_instance_count = 1
			cutaway(false)
			var solid_hazards := await capture(label + "-hazards-off.png")
			cutaway(true)
			var filtered_hazards := await capture(label + "-hazards-on.png")
			check(differences(solid_hazards, filtered_hazards) < 10,
				label + " keeps the unobstructing tail and hazards ahead solid")
			hazard.multimesh.visible_instance_count = 0
			rear.multimesh.visible_instance_count = 0
	await check_close_chase(pose, blocker)
	await capture_crowded_round()
	print("CONE CUTAWAY: %d failures" % failures)
	quit(1 if failures else 0)

func check_close_chase(pose: Dictionary, blocker: MultiMeshInstance3D) -> void:
	# Arena walls can clamp the camera much closer than its usual chase distance.
	for camera_distance in [2.0, 3.0, game.camera.DEFAULT_CHASE_DISTANCE]:
		for camera_fov in [60.0, 110.0]:
			game.camera.chase_distance = camera_distance
			game.camera.base_fov = camera_fov
			game.camera.initialized = false
			game.camera.follow(pose, 0.0)
			var label := "distance-%.2f-fov-%.0f" % [camera_distance, camera_fov]
			blocker.multimesh.visible_instance_count = 0
			cutaway(true)
			var reference := await capture(label + "-reference.png")
			blocker.multimesh.set_instance_transform(0, Transform3D(
				game.camera.global_basis * Basis(Vector3.UP, PI * 0.5),
				game.camera.global_position.lerp(pose.position, 0.45)))
			blocker.multimesh.visible_instance_count = 1
			cutaway(false)
			var blocked := await capture(label + "-off.png")
			cutaway(true)
			var cleared := await capture(label + "-on.png")
			var point: Vector2 = game.camera.unproject_position(pose.position)
			check_revealed(label, blocked, cleared, reference, point, 20.0)
	game.camera.chase_distance = game.camera.DEFAULT_CHASE_DISTANCE
	game.camera.base_fov = 78.0
	blocker.multimesh.visible_instance_count = 0

func capture_crowded_round() -> void:
	game.bot_count = 31
	game.arena_width = 40
	game.set_auto_mode(true)
	game.start_round(821)
	game.state = "playing"
	for step in range(140):
		if game.sim.finished:
			break
		game.motion.advance(game.Rules.STEP_TIME)
	var alive: Array = game.sim.alive_ids()
	check(not alive.is_empty(), "The crowded fixture has a living pipe to follow")
	if alive.is_empty():
		return
	game.watch_id = alive[0]
	game.camera.view = game.camera.View.CHASE
	game.crash_view_time = 0.0
	game.state = "playing"
	for taps in [-3, 0, 3]:
		game.camera.chase_yaw = float(taps) * 0.144
		game.camera.initialized = false
		game._process(0.0)
		cutaway(false)
		await capture("crowded-%d-off.png" % taps)
		cutaway(true)
		await capture("crowded-%d-on.png" % taps)
	if "--motion" not in OS.get_cmdline_user_args() or directory.is_empty():
		return
	# Fixed simulation time produces a repeatable six-second clip, independent of
	# capture speed. It sweeps between the preferred shoulder angles during play.
	for frame in range(180):
		game.camera.chase_yaw = lerpf(-0.432, 0.432, smoothstep(0.0, 1.0, frame / 179.0))
		game._process(1.0 / 30.0)
		await capture("motion-%03d.png" % frame)
