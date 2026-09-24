extends SceneTree

const Client = preload("res://scripts/multiplayer_client.gd")
var received: Dictionary = {}
var clients: Array[Node] = []
var failed := false

func _initialize() -> void:
	_create_client("PUBLIC", "Public Pilot", Color("56eddf"))
	_create_client("FRIENDS", "Private Pilot", Color("ffb65a"))
	create_timer(5.0).timeout.connect(func(): _fail("TIMEOUT"))

func _create_client(room_id: String, player_name: String, color: Color) -> void:
	var client := Client.new()
	clients.append(client)
	root.add_child(client)
	client.connected_to_room.connect(func(message: Dictionary): _on_welcome(player_name, message))
	client.connection_failed.connect(func(reason: String): _fail(reason))
	client.connect_to_room("ws://127.0.0.1:8789", room_id, player_name, color)

func _on_welcome(player_name: String, message: Dictionary) -> void:
	if failed:
		return
	received[player_name] = message
	if received.size() < 2:
		return
	var public_room: Dictionary = received["Public Pilot"].room
	var private_room: Dictionary = received["Private Pilot"].room
	if public_room.room_id != "PUBLIC" or private_room.room_id != "FRIENDS":
		_fail("ROOM_ID_MISMATCH")
		return
	print("MULTIPLAYER MULTIROOM: public=%s private=%s" % [public_room.room_id, private_room.room_id])
	quit()

func _fail(reason: String) -> void:
	if failed:
		return
	failed = true
	push_error("Multiroom loopback failed: " + reason)
	quit(1)
