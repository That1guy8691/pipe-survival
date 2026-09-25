extends SceneTree
## Rendered regression for the chase-camera tail, distant hazards, and foreground blockers.

var directory := ""
var failures := 0
var game

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-dir="):
			directory = argument.trim_prefix("--qa-dir=")
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func capture(filename: String) -> Image:
	# MultiMesh bounds are refreshed during rendering; capture after the following cull.
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	if not directory.is_empty():
		check(result.save_png(directory.path_join(filename)) == OK, "Save " + filename)
	return result

func differences(a: Image, b: Image, core_only: bool = false) -> int:
	var count := 0
	var center := Vector2(a.get_size()) * 0.5
	var radius := minf(a.get_width(), a.get_height()) * 0.20
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			if core_only and Vector2(x, y).distance_to(center) > radius:
				continue
			var left := a.get_pixel(x, y)
			var right := b.get_pixel(x, y)
			if maxf(absf(left.r - right.r), maxf(absf(left.g - right.g), absf(left.b - right.b))) > 0.04:
				count += 1
	return count

func section(id: int, cell: Vector3i, incoming: Vector3i, outgoing: Vector3i) -> void:
	var rider: Dictionary = game.sim.riders[id].duplicate()
	rider.cell = cell
	rider.forward = incoming
	rider.up = Vector3i.UP
	game.pipes.begin_rider(id, rider, outgoing)
	var moves: Array[Dictionary] = [{"id": id, "cell": cell, "incoming": incoming,
		"outgoing": outgoing, "up": Vector3i.UP, "died": false}]
	game.pipes.commit(moves)

func cutaway(enabled: bool) -> void:
	game.pipes.update_cutaway(game.camera, game.watch_id, enabled)

func region_differences(a: Image, b: Image, center: Vector2, radius: float) -> int:
	var count := 0
	for y in range(maxi(0, int(center.y - radius)), mini(a.get_height(), int(center.y + radius))):
		for x in range(maxi(0, int(center.x - radius)), mini(a.get_width(), int(center.x + radius))):
			if Vector2(x, y).distance_to(center) > radius:
				continue
			var left := a.get_pixel(x, y)
			var right := b.get_pixel(x, y)
			if maxf(absf(left.r - right.r), maxf(absf(left.g - right.g), absf(left.b - right.b))) > 0.04:
				count += 1
	return count

func check_turn_frame(label: String) -> void:
	var batch: MultiMeshInstance3D = game.pipes.batches[0][0]
	var visible_count := batch.multimesh.visible_instance_count
	# Remove the pre-turn straight run to capture an unobstructed reference.
	batch.multimesh.visible_instance_count = 0
	cutaway(true)
	var reference := await capture(label + "-reference.png")
	batch.multimesh.visible_instance_count = visible_count
	cutaway(false)
	var blocked := await capture(label + "-off.png")
	cutaway(true)
	var cleared := await capture(label + "-on.png")
	var head_pixel: Vector2 = game.camera.unproject_position(game.pipes.heads[0].global_position)
	head_pixel *= Vector2(reference.get_size()) / root.get_visible_rect().size
	var route_pixel := Vector2(reference.get_size()) * 0.5
	for point: Vector2 in [head_pixel, route_pixel]:
		# The route sample must exclude the connected collar just above the head.
		# Removing every old straight section from the reference also removes that rim.
		var sample_radius := 20.0 if point == head_pixel else 12.0
		check(region_differences(blocked, reference, point, sample_radius) > 100,
			label + " must reproduce the own-tail obstruction")
		var remaining := region_differences(cleared, reference, point, sample_radius)
		print("%s point=%s remaining_blocked_pixels=%d" % [label, point, remaining])
		check(remaining < 10, label + " still hides the head or route after W")

func check_up_turn() -> void:
	game.state = "playing"
	game.hud.hide()
	game.arena.set_labels_visible(false)
	game.pipes.reset(2)
	for i in range(2):
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
	game.pipes.heads[0].show()
	game.pipes.markers[0].show()
	game.camera.view = game.camera.View.CHASE
	game.camera.initialized = false
	game.pipes.begin_rider(0, rider, rider.forward)
	game.camera.follow(game.pipes.pose(0, 0.0), 0.0)
	game.pipes.begin_rider(0, rider, game.Rules.turn(rider, "up"))
	# Use the real chase smoothing while the head rounds the W elbow.
	for frame in range(21):
		var phase := frame / 20.0
		game.pipes.animate_rider(0, phase)
		game.camera.follow(game.pipes.pose(0, phase), game.Rules.STEP_TIME / 20.0)
		if frame in [15, 20]:
			await check_turn_frame("W-turn-%02d" % frame)
	section(0, rider.cell, rider.forward, Vector3i.UP)
	rider.cell += Vector3i.UP
	rider.forward = Vector3i.UP
	rider.up = Vector3i.BACK
	game.pipes.begin_rider(0, rider, rider.forward)
	for frame in range(11):
		var phase := frame / 20.0
		game.pipes.animate_rider(0, phase)
		game.camera.follow(game.pipes.pose(0, phase), game.Rules.STEP_TIME / 20.0)
	await check_turn_frame("W-exit")
	# Once clear of the bend, the new vertical straight tail must be intact too.
	for y in range(16, 21):
		section(0, Vector3i(15, y, 15), Vector3i.UP, Vector3i.UP)
	rider.cell = Vector3i(15, 21, 15)
	game.pipes.begin_rider(0, rider, rider.forward)
	for phase in [0.0, 0.5, 0.99]:
		game.pipes.animate_rider(0, phase)
		game.camera.initialized = false
		game.camera.follow(game.pipes.pose(0, phase), 0.0)
		cutaway(false)
		var plain := await capture("vertical-%s-off.png" % phase)
		cutaway(true)
		var filtered := await capture("vertical-%s-on.png" % phase)
		var changed := differences(plain, filtered)
		print("VERTICAL phase=%.2f changed_pixels=%d" % [phase, changed])
		check(changed < 10, "Cutaway removed the straight tail after W")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	game.set_process(false)
	game.hud.set_process(false)
	game.bot_count = 1
	game.player_pattern = game.PipeRenderer.Appearance.Pattern.CHECKER
	game.start_round(821)
	game.state = "playing"
	game.hud.hide()
	game.orbs.hide()
	game.arena.set_labels_visible(false)
	for i in range(2):
		game.pipes.inlets[i].hide()
		game.pipes.heads[i].hide()
		game.pipes.markers[i].hide()
		game.pipes.active[i].hide()
	for z in range(25, 15, -1):
		section(0, Vector3i(15, 15, z), Vector3i.FORWARD, Vector3i.FORWARD)
	game.sim.riders[0].cell = Vector3i(15, 15, 15)
	game.sim.riders[0].forward = Vector3i.FORWARD
	game.sim.riders[0].up = Vector3i.UP
	game.pipes.begin_rider(0, game.sim.riders[0], Vector3i.FORWARD)
	game.pipes.heads[0].show()
	game.pipes.markers[0].show()
	game.camera.view = game.camera.View.CHASE
	for phase in [0.0, 0.5, 0.99]:
		game.pipes.animate_rider(0, phase)
		game.camera.initialized = false
		game.camera.follow(game.pipes.pose(0, phase), 0.0)
		cutaway(false)
		var plain := await capture("straight-%s-off.png" % phase)
		cutaway(true)
		var filtered := await capture("straight-%s-on.png" % phase)
		var changed := differences(plain, filtered)
		print("STRAIGHT phase=%.2f changed_pixels=%d" % [phase, changed])
		check(changed < 10, "Cutaway removed the connected straight tail at phase %.2f" % phase)
	# Complete the growing cell and start the next one, as real movement does.
	section(0, Vector3i(15, 15, 15), Vector3i.FORWARD, Vector3i.FORWARD)
	game.sim.riders[0].cell = Vector3i(15, 15, 14)
	game.pipes.begin_rider(0, game.sim.riders[0], Vector3i.FORWARD)
	game.pipes.animate_rider(0, 0.0)
	game.camera.initialized = false
	game.camera.follow(game.pipes.pose(0, 0.0), 0.0)
	cutaway(false)
	var handoff_off := await capture("handoff-off.png")
	cutaway(true)
	var handoff_on := await capture("handoff-on.png")
	check(differences(handoff_off, handoff_on) < 10, "Tail develops a gap at the next grid cell")
	# A distant crossing must remain visible, including inside the circle.
	for x in range(12, 19):
		section(1, Vector3i(x, 15, 10), Vector3i.RIGHT, Vector3i.RIGHT)
	cutaway(false)
	var distant_off := await capture("distant-off.png")
	cutaway(true)
	var distant_on := await capture("distant-on.png")
	var changed := differences(distant_off, distant_on)
	print("DISTANT changed_pixels=%d" % changed)
	check(changed < 10, "Cutaway removed distant pipes")
	# Add a foreground crossing through the center of the view.
	var unobstructed := distant_on
	var batch: MultiMeshInstance3D = game.pipes.batches[1][0]
	var first: int = game.pipes.counts[1][0]
	var center: Vector3 = game.camera.global_position - game.camera.global_basis.z * 3.0
	for index in range(7):
		var orientation: Basis = game.camera.global_basis * Basis(Vector3.UP, PI * 0.5)
		batch.multimesh.set_instance_transform(first + index,
			Transform3D(orientation, center + game.camera.global_basis.x * (index - 3) * 2.0))
	batch.multimesh.visible_instance_count = first + 7
	cutaway(false)
	var blocked := await capture("blocked-off.png")
	cutaway(true)
	var cleared := await capture("blocked-on.png")
	check(differences(blocked, unobstructed, true) > 1000, "Foreground fixture must obscure the circle")
	changed = differences(cleared, unobstructed, true)
	print("FOREGROUND remaining_blocked_pixels=%d" % changed)
	check(changed < 10, "Foreground pipes still obscure the center")
	# An old loop of the followed pipe must clear too, despite sharing its color/material.
	batch.multimesh.visible_instance_count = first
	var own_batch: MultiMeshInstance3D = game.pipes.batches[0][0]
	for index in range(5):
		own_batch.multimesh.set_instance_transform(index,
			Transform3D(game.camera.global_basis * Basis(Vector3.UP, PI * 0.5),
				center + game.camera.global_basis.x * (index - 2) * 2.0))
	cutaway(false)
	var own_blocked := await capture("old-own-pipe-off.png")
	cutaway(true)
	var own_cleared := await capture("old-own-pipe-on.png")
	check(differences(own_blocked, unobstructed, true) > 1000, "Old own-pipe fixture must obscure the circle")
	changed = differences(own_cleared, unobstructed, true)
	print("OLD OWN PIPE remaining_blocked_pixels=%d" % changed)
	check(changed < 10, "Old sections of the followed pipe still obscure the center")
	game.swap_camera_view()
	game._process(0.0)
	check(not game.pipes.cutaway_enabled, "First person must keep collision hazards solid")
	game.swap_camera_view()
	game.swap_camera_view()
	game._process(0.0)
	check(game.pipes.cutaway_enabled, "Gameplay must enable the cutaway in chase view")
	game.state = "ready"
	game._process(0.0)
	check(not game.pipes.cutaway_enabled, "The title view must show all trails")
	await check_up_turn()
	# Capture the integrated game after the arena has accumulated real moving trails.
	game.bot_count = 15
	game.set_auto_mode(true)
	game.start_round(821)
	game.state = "playing"
	for step in range(80):
		if game.sim.finished:
			break
		game.motion.advance(game.Rules.STEP_TIME)
	game.camera.view = game.camera.View.CHASE
	game.camera.initialized = false
	game._process(0.0)
	game.hud.set_process(true)
	game.hud.show()
	game.orbs.show()
	cutaway(false)
	await capture("gameplay-off.png")
	cutaway(true)
	await capture("gameplay-on.png")
	print("PIPE CUTAWAY VISUAL: %d failures" % failures)
	quit(1 if failures else 0)
