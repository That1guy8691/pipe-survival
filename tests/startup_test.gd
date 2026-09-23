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
	check(game.sim.elapsed_time == 0.0, "Startup must not pre-simulate the title backdrop")
	game.primary_action()
	check(game.state == "countdown", "Start must work before the first backdrop step")
	check(game.title_preview_steps_left == 0, "Starting must cancel pending backdrop work")
	check(game.sim.elapsed_time == 0.0, "Starting must create a fresh round")

	for auto in [false, true]:
		game.set_auto_mode(auto)
		game.bot_count = 31
		game.show_title()
		game.advance_title_preview()
		check(game.state == "ready", "Backdrop simulation must keep the menu open")
		check(is_equal_approx(game.sim.elapsed_time, game.Rules.STEP_TIME),
			"A preview update must only advance one step")
		check(game.motion.autoplay == auto, "Preview work must preserve the selected driver")
		game.primary_action()
		game._process(0.01)
		check(game.state == "countdown" and game.sim.elapsed_time == 0.0,
			"Interrupted preview work must not advance the new round")
		check(game.sim.occupied.size() == 32, "Preview trails must not leak into the round")

		game.show_title()
		for step in range(game.TITLE_PREVIEW_STEPS):
			game.advance_title_preview()
		check(game.title_preview_steps_left == 0, "Backdrop work must finish")
		check(game.state == "ready", "A finished backdrop must not show match results")
		var final_time: float = game.sim.elapsed_time
		game.advance_title_preview()
		check(game.sim.elapsed_time == final_time, "Completed preview must stop simulating")

	game.endless_mode = true
	game.show_title()
	game.advance_title_preview()
	game.primary_action()
	check(game.sim.endless_mode and game.state == "countdown",
		"Starting during preview must preserve the selected game mode")
	check(game.title_preview_steps_left == 0 and game.sim.elapsed_time == 0.0,
		"Endless must also start fresh without pending backdrop work")
	print("Startup checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
