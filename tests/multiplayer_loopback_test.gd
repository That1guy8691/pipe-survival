extends SceneTree

const Client = preload("res://scripts/multiplayer_client.gd")
var client
var finished := false

func _initialize() -> void:
	client = Client.new()
	root.add_child(client)
	client.connected_to_room.connect(_on_welcome)
	client.connection_failed.connect(_on_failure)
	client.disconnected.connect(_on_disconnect)
	var error: Error = client.connect_to_room("ws://127.0.0.1:8789", "PIPE", "Loopback", Color("56eddf"))
	if error != OK:
		_on_failure("CONNECT_ERROR_%d" % error)
		return
	create_timer(5.0).timeout.connect(func():
		if not finished:
			_on_failure("TIMEOUT"))

func _on_welcome(message: Dictionary) -> void:
	finished = true
	print("MULTIPLAYER LOOPBACK: joined slot=%s" % message.get("player", {}).get("slot", -1))
	quit()

func _on_failure(reason: String) -> void:
	if finished:
		return
	finished = true
	push_error("Loopback failed: " + reason)
	quit(1)

func _on_disconnect(reason: String) -> void:
	if not finished:
		_on_failure("DISCONNECTED_" + reason)
