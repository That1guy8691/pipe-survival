extends SceneTree
## Menu startup must not simulate the entire backdrop before accepting input.

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	var before := Time.get_ticks_usec()
	root.add_child(game)
	print("Menu setup: %.1f ms" % ((Time.get_ticks_usec() - before) / 1000.0))
	game.set_process(false)
	check(game.state == "ready", "Startup must open the title menu")
	check(game.sim.elapsed_time > 0.0 and game.sim.elapsed_time <= game.TITLE_WARMUP_STEPS * game.Rules.STEP_TIME + 0.0001,
		"Startup prewarms only the short title exhibition")
	check(game.title_exhibition and game.motion.autoplay,
		"The title opens a live all-bot exhibition")
	game.primary_action()
	check(game.state == "countdown", "Start must work before the first backdrop step")
	check(not game.title_exhibition, "Starting must stop title exhibition behavior")
	check(game.sim.elapsed_time == 0.0, "Starting must create a fresh round")

	for auto in [false, true]:
		game.set_auto_mode(auto)
		game.bot_count = 31
		game.arena_width = 80
		game.endless_mode = auto
		game.player_name = "PREVIEW"
		game.player_color = Color("ee5f83")
		game.show_title()
		check(game.sim.riders.size() == 32 and game.sim.arena_width == 80,
			"The exhibition uses the selected bot count and arena size")
		check(game.sim.endless_mode == auto and game.sim.riders[0].name == "PREVIEW"
			and game.sim.riders[0].color == Color("ee5f83"),
			"The exhibition uses the selected mode and pipe identity")
		var preview_time_before: float = game.sim.elapsed_time
		game.advance_title_preview()
		check(game.state == "ready", "Backdrop simulation must keep the menu open")
		check(game.sim.elapsed_time > preview_time_before
			and game.sim.elapsed_time <= preview_time_before + game.Rules.STEP_TIME + 0.0001,
			"A preview update advances by at most one fixed step")
		check(game.motion.autoplay, "Every title pipe uses bot steering regardless of player mode")
		var first_time: float = game.sim.elapsed_time
		for step in range(5):
			game.advance_title_preview()
		check(game.sim.elapsed_time > first_time, "The title exhibition keeps moving instead of freezing")
		game.camera.view = game.camera.View.OVERVIEW
		game.title_camera_time = 0.0
		game.advance_title_preview(0.0)
		check(game.camera.view == game.camera.View.CHASE and game.sim.riders[game.watch_id].alive,
			"The title camera cuts from overview to a living random pipe")
		game.title_camera_time = 0.0
		game.advance_title_preview(0.0)
		check(game.camera.view == game.camera.View.OVERVIEW,
			"The title camera returns from chase to overview")
		game.primary_action()
		check(game.state == "countdown" and not game.title_exhibition and game.sim.elapsed_time == 0.0,
			"Interrupted preview work must not advance the new round")
		check(game.sim.occupied.size() == 32, "Preview trails must not leak into the round")

	game.endless_mode = true
	game.show_title()
	game.sim.finished = true
	game.title_restart_time = 0.01
	game.advance_title_preview(0.02)
	check(game.state == "ready" and game.title_exhibition and not game.sim.finished,
		"A completed title match automatically starts another exhibition")
	game.advance_title_preview()
	game.primary_action()
	check(game.sim.endless_mode and game.state == "countdown",
		"Starting during preview must preserve the selected game mode")
	check(not game.title_exhibition and game.sim.elapsed_time == 0.0,
		"Endless must also start fresh without pending backdrop work")
	print("Startup checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
