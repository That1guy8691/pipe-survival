extends RefCounted
## Room lookup and lifecycle for the public queue and private join codes.

const Room = preload("res://scripts/online_room.gd")
const PUBLIC_ROOM_ID := "PUBLIC"
const MIN_PRIVATE_CODE_LENGTH := 4
const MAX_PRIVATE_CODE_LENGTH := 12

var rooms: Dictionary = {}

func public_room(mode: String = "endless", human_cap: int = Room.DEFAULT_HUMAN_CAP,
		actor_target: int = Room.DEFAULT_ACTOR_TARGET) -> Room:
	var key := PUBLIC_ROOM_ID
	if rooms.has(key):
		return rooms[key]
	var room := _new_room(key, "public", mode, human_cap, actor_target)
	rooms[key] = room
	return room

func create_private(code: String, mode: String = "endless",
		human_cap: int = Room.DEFAULT_HUMAN_CAP,
		actor_target: int = Room.DEFAULT_ACTOR_TARGET) -> Room:
	var normalized := normalize_code(code)
	if not is_valid_private_code(normalized) or rooms.has(normalized):
		return null
	var room := _new_room(normalized, "private", mode, human_cap, actor_target)
	rooms[normalized] = room
	return room

func find(code: String) -> Room:
	var normalized := normalize_code(code)
	return rooms.get(normalized, null)

func find_or_create_private(code: String, mode: String = "endless",
		human_cap: int = Room.DEFAULT_HUMAN_CAP,
		actor_target: int = Room.DEFAULT_ACTOR_TARGET) -> Room:
	var existing := find(code)
	if existing != null:
		return existing
	return create_private(code, mode, human_cap, actor_target)

func close_empty(code: String) -> bool:
	var normalized := normalize_code(code)
	if normalized == PUBLIC_ROOM_ID or not rooms.has(normalized):
		return false
	var room: Room = rooms[normalized]
	if room.human_count() > 0:
		return false
	rooms.erase(normalized)
	return true

func list_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for room: Room in rooms.values():
		result.append(room.snapshot())
	result.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.room_id) < str(b.room_id))
	return result

static func normalize_code(code: String) -> String:
	var normalized := code.strip_edges().to_upper()
	var filtered := ""
	for character in normalized:
		if character in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
			filtered += character
	return filtered.left(MAX_PRIVATE_CODE_LENGTH)

static func is_valid_private_code(code: String) -> bool:
	var normalized := normalize_code(code)
	return normalized.length() >= MIN_PRIVATE_CODE_LENGTH and normalized != PUBLIC_ROOM_ID

func _new_room(id: String, visibility: String, mode: String, human_cap: int,
		actor_target: int) -> Room:
	var room := Room.new()
	room.configure(id, visibility, mode, human_cap, actor_target)
	return room
