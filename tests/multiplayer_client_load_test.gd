extends SceneTree

const Client = preload("res://scripts/multiplayer_client.gd")

func _initialize() -> void:
	var client := Client.new()
	root.add_child(client)
	print("MULTIPLAYER CLIENT: loaded")
	quit()
