extends SceneTree
## Real viewport touch events exercise steering, camera gestures, and menu transitions.

var game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	root.push_input(event, true)

func drag(index: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	root.push_input(event, true)

func pointer(button: Control, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event, true)

func run() -> void:
	root.size = Vector2i(1280, 800)
	game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	game.set_process(false)
	game.start_round(821)
	game.state = "playing"
	game.hud.touch_ui_enabled = true
	await process_frame
	game.hud._process(0.0)
	var bounds: Vector2 = game.hud.size
	var left := bounds * Vector2(0.2, 0.7)
	var right := bounds * Vector2(0.7, 0.55)
	touch(0, left, true)
	drag(0, left + Vector2(80, 0), Vector2(80, 0))
	check(game.turn_queue == ["right"], "A joystick drag queues a pipe-relative turn")
	drag(0, left + Vector2(90, 0), Vector2(10, 0))
	check(game.turn_queue == ["right"], "Holding the same joystick direction does not repeat turns")
	drag(0, left, Vector2(-90, 0))
	drag(0, left + Vector2(80, 0), Vector2(80, 0))
	drag(0, left + Vector2(0, -80), Vector2(-80, -80))
	game.turn_queue.pop_front()
	game.hud._process(0.0)
	check(game.turn_queue == ["right", "up"], "A pending joystick direction fills the next free queue slot")
	touch(0, left, false)
	game.turn_queue.clear()
	game.camera.view = game.camera.View.OVERVIEW
	touch(1, right, true)
	var yaw_before: float = game.camera.yaw
	drag(1, right + Vector2(30, 0), Vector2(30, 0))
	check(not is_equal_approx(game.camera.yaw, yaw_before), "Dragging the arena orbits the camera")
	touch(2, right + Vector2(120, 0), true)
	var zoom_before: float = game.camera.distance
	drag(2, right + Vector2(160, 0), Vector2(40, 0))
	check(game.camera.distance < zoom_before, "Spreading two camera touches zooms in")
	touch(1, right, false)
	touch(2, right, false)

	game.toggle_pause()
	game.hud.open_retro_page("options")
	game.hud._process(0.0)
	yaw_before = game.camera.yaw
	touch(3, right, true)
	drag(3, right + Vector2(30, 0), Vector2(30, 0))
	check(is_equal_approx(game.camera.yaw, yaw_before), "Touching a paused options page cannot orbit the arena")
	touch(3, right, false)
	game.hud.close_menu_page()
	game.primary_action()
	game.hud._process(0.0)
	touch(4, right, true)
	game.show_title()
	game.hud._process(0.0)
	game.start_round(821)
	game.state = "playing"
	game.hud._process(0.0)
	touch(5, left, true)
	drag(5, left + Vector2(80, 0), Vector2(80, 0))
	check(game.turn_queue == ["right"], "An interrupted camera gesture cannot block steering in the next round")
	touch(4, right, false)
	touch(5, left, false)
	game.turn_queue.clear()
	pointer(game.hud.touch_controls.touch_boost, true)
	check(game.boost_held, "The extracted Boost button still controls the player's boost")
	game.toggle_pause()
	game.hud._process(0.0)
	check(not game.boost_held, "Pausing cancels a held touch boost")
	pointer(game.hud.touch_controls.touch_boost, false)
	game.primary_action()
	game.hud._process(0.0)
	touch(6, right, true)
	game.get_window().focus_exited.emit()
	touch(7, left, true)
	drag(7, left + Vector2(80, 0), Vector2(80, 0))
	check(game.turn_queue == ["right"], "Focus loss releases camera touches so steering can resume")
	touch(7, left, false)
	touch(8, right, true)
	game.start_round(821)
	game.hud._process(0.0)
	touch(9, left, true)
	drag(9, left + Vector2(80, 0), Vector2(80, 0))
	check(game.turn_queue == ["right"], "Restart clears unfinished gestures before the new countdown")
	touch(9, left, false)
	game.queue_free()
	await process_frame
	print("TOUCH CONTROLS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
