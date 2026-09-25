extends SceneTree
## Requires the local room server on port 8789, like multiplayer_loopback_test.gd.

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func wait_for_snapshot(game) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		if game.online_connected and not game.online_last_state.is_empty():
			return true
		await process_frame
	return false

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	game.bot_count = 0
	game.arena_width = 100
	game.show_title()
	game.connect_online("ws://127.0.0.1:8789", "REFACTOR")
	check(await wait_for_snapshot(game), "A local room sends a welcome and initial snapshot")
	if failures == 0:
		check(game.sim.riders.size() == 32 and game.arena.width == game.sim.arena_width,
			"A live snapshot replaces solo actors and arena geometry")
		game.show_title()
		check(game.state == "ready" and not game.online_connected and game.online_client.socket == null,
			"Leaving a live room resets the game and releases its socket")
		game.connect_online("ws://127.0.0.1:8789", "REFACTOR2")
		check(await wait_for_snapshot(game), "The client can immediately reconnect to another room")
		check(game.online_room_id == "REFACTOR2", "Reconnection uses the requested room")
	game.disconnect_online()
	check(game.state == "ready" and game.sim.riders.size() == 1 and game.arena.width == 100,
		"Disconnect restores a valid local exhibition with the chosen settings")
	game.queue_free()
	await process_frame
	print("ONLINE SESSION LOOPBACK: %d failures" % failures)
	quit(1 if failures else 0)
