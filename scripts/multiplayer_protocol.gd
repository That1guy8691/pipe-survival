extends RefCounted
## Small text protocol shared by the browser client and room server.

const VERSION := 1
const VALID_TURNS := ["up", "down", "left", "right"]

static func join_message(name: String, color: Color, room_id: String = "") -> String:
	return JSON.stringify({
		"version": VERSION,
		"type": "join",
		"room": room_id.strip_edges(),
		"name": name.strip_edges().left(18),
		"color": color.to_html(false),
	})

static func input_message(turn: String = "", boost: bool = false, sequence: int = 0) -> String:
	var message := {
		"version": VERSION,
		"type": "input",
		"boost": boost,
		"sequence": maxi(sequence, 0),
	}
	if turn in VALID_TURNS:
		message["turn"] = turn
	return JSON.stringify(message)

static func leave_message(reason: String = "left") -> String:
	return JSON.stringify({
		"version": VERSION,
		"type": "leave",
		"reason": reason.left(32),
	})

static func host_lock_message(locked: bool) -> String:
	return JSON.stringify({"version": VERSION, "type": "host", "action": "lock", "locked": locked})

static func host_kick_message(peer_id: int) -> String:
	return JSON.stringify({"version": VERSION, "type": "host", "action": "kick", "peer_id": peer_id})

static func parse_packet(packet: PackedByteArray) -> Dictionary:
	var value = JSON.parse_string(packet.get_string_from_utf8())
	if value is Dictionary:
		return value
	return {}

static func parse_color(value, fallback: Color = Color("56eddf")) -> Color:
	if value is String and not str(value).is_empty():
		return Color.from_string(str(value), fallback)
	return fallback

static func state_message(room_snapshot: Dictionary, tick: int, riders: Array[Dictionary],
		moves: Array[Dictionary] = [], history: Array = [], full_snapshot: bool = false,
		orbs: Dictionary = {}) -> String:
	var serialized_riders: Array[Dictionary] = []
	for i in range(riders.size()):
		var rider: Dictionary = riders[i]
		serialized_riders.append(_serialize_rider(i, rider))
	var serialized_moves: Array[Dictionary] = []
	for move: Dictionary in moves:
		serialized_moves.append(_serialize_move(move))
	var payload := {
		"version": VERSION,
		"type": "state",
		"tick": tick,
		"room": room_snapshot,
		"riders": serialized_riders,
		"moves": serialized_moves,
		"full_snapshot": full_snapshot,
		"orbs": _serialize_orbs(orbs),
	}
	if full_snapshot:
		var serialized_history: Array = []
		for rider_history in history:
			var serialized_rider_history: Array[Dictionary] = []
			for move in rider_history:
				serialized_rider_history.append(_serialize_move(move))
			serialized_history.append(serialized_rider_history)
		payload["history"] = serialized_history
	return JSON.stringify(payload)

static func _serialize_orbs(orbs: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell in orbs:
		if cell is Vector3i:
			result.append({"cell": _vector_array(cell), "points": int(orbs[cell])})
	return result

static func _serialize_rider(slot: int, rider: Dictionary) -> Dictionary:
	return {
		"slot": slot,
		"cell": _vector_array(rider.get("cell", Vector3i.ZERO)),
		"forward": _vector_array(rider.get("forward", Vector3i.FORWARD)),
		"up": _vector_array(rider.get("up", Vector3i.UP)),
		"source_cell": _vector_array(rider.get("source_cell", rider.get("cell", Vector3i.ZERO))),
		"source_forward": _vector_array(rider.get("source_forward", rider.get("forward", Vector3i.FORWARD))),
		"alive": bool(rider.get("alive", false)),
		"length": int(rider.get("length", 0)),
		"score": int(rider.get("score", 0)),
		"pressure": float(rider.get("pressure", 1.0)),
		"boosting": bool(rider.get("boosting", false)),
		"cause": str(rider.get("cause", "")),
		"orb_count": int(rider.get("orb_count", 0)),
		"eliminations": int(rider.get("eliminations", 0)),
		"combo_count": int(rider.get("combo_count", 0)),
		"combo_multiplier": float(rider.get("combo_multiplier", 1.0)),
		"combo_time": float(rider.get("combo_time", 0.0)),
		"name": str(rider.get("name", "PIP")),
		"color": Color(rider.get("color", Color("56eddf"))).to_html(false),
	}

static func _serialize_move(move: Dictionary) -> Dictionary:
	return {
		"id": int(move.get("id", -1)),
		"cell": _vector_array(move.get("cell", Vector3i.ZERO)),
		"target": _vector_array(move.get("target", Vector3i.ZERO)),
		"incoming": _vector_array(move.get("incoming", Vector3i.FORWARD)),
		"outgoing": _vector_array(move.get("outgoing", Vector3i.FORWARD)),
		"up": _vector_array(move.get("up", Vector3i.UP)),
		"died": bool(move.get("died", false)),
		"pipe_owner": int(move.get("pipe_owner", -1)),
	}

static func _vector_array(value: Vector3i) -> Array[int]:
	return [value.x, value.y, value.z]
