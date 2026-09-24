extends SceneTree
## Online turns must not fill the local motion queue and block later inputs.

class RecordingClient:
	extends "res://scripts/multiplayer_client.gd"
	var sent_turns: Array[String] = []

	func send_turn(turn: String, _sequence: int = 0) -> void:
		sent_turns.append(turn)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.automated = true
	root.add_child(game)
	game.set_process(false)
	game.state = "playing"
	game.online_mode = true
	game.online_connected = true
	game.online_player_slot = 0
	game.turn_queue.clear()
	var original_client = game.online_client
	var recorder := RecordingClient.new()
	game.online_client = recorder
	var turns: Array[String] = ["left", "right", "up", "down"]
	for turn in turns:
		game.queue_turn(turn)
	if not game.turn_queue.is_empty() or recorder.sent_turns != turns:
		push_error("Online steering must send every turn without filling the local queue")
		quit(1)
		return
	game.online_mode = false
	game.online_connected = false
	game.queue_turn("left")
	if game.turn_queue != ["left"]:
		push_error("Solo turns must still use the local motion queue")
		quit(1)
		return
	game.online_client = original_client
	recorder.free()
	print("MULTIPLAYER INPUT: four online turns sent; solo queue still works")
	quit()
