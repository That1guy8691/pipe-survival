extends SceneTree

const Directory = preload("res://scripts/room_directory.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	var directory := Directory.new()
	var public_a = directory.public_room()
	var public_b = directory.public_room()
	check(public_a == public_b and public_a.room_id == "PUBLIC" and public_a.visibility == "public",
		"Public matchmaking reuses one room")
	var private_a = directory.create_private(" ab-12 ", "endless", 10, 32)
	check(private_a != null and private_a.room_id == "AB12" and private_a.visibility == "private",
		"Private codes normalize into stable room ids")
	check(directory.find("ab12") == private_a and directory.create_private("AB12") == null,
		"Private rooms are case-insensitive and cannot be duplicated")
	check(directory.create_private("ABC") == null and not Directory.is_valid_private_code("!!!"),
		"Private room codes require a normalized four-character minimum")
	var private_b = directory.find_or_create_private(" FRIENDS ")
	check(private_b != null and directory.find("friends") == private_b,
		"A new private code creates a room on first use")
	check(directory.list_snapshots().size() == 3, "Room listing exposes public and private rooms")
	check(not directory.close_empty("AB12") or directory.find("AB12") == null,
		"An empty private room can be closed")
	var occupied = directory.find("friends")
	occupied.join(1, "Host")
	check(not directory.close_empty("friends"), "An occupied private room stays open")
	occupied.leave(1)
	check(directory.close_empty("friends") and directory.find("friends") == null,
		"A private room closes after its last player leaves")
	check(Directory.normalize_code(" A-b_c! 123 ") == "ABC123", "Room code filtering removes unsafe characters")
	print("ROOM DIRECTORY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
