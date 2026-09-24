extends RefCounted
## Server-owned room membership for browser multiplayer.
## Gameplay state stays in simulation.gd; this class owns who may occupy it.

signal member_joined(member: Dictionary)
signal member_left(member: Dictionary)

const MAX_ACTORS := 32
const MIN_HUMAN_CAP := 2
const DEFAULT_HUMAN_CAP := 8
const EARLY_ACCESS_HUMAN_CAP := 10
const MAX_HUMAN_CAP := MAX_ACTORS
const DEFAULT_ACTOR_TARGET := MAX_ACTORS

var room_id := ""
var visibility := "private"
var mode := "endless"
var human_cap := DEFAULT_HUMAN_CAP
var actor_target := DEFAULT_ACTOR_TARGET
var match_started := false
var host_peer_id := -1
var locked := false
var members: Dictionary = {}
var slot_owners: Dictionary = {}
var bot_count := 0
var _join_sequence := 0

func configure(new_room_id: String, new_visibility: String = "private",
		new_mode: String = "endless", new_human_cap: int = DEFAULT_HUMAN_CAP,
		new_actor_target: int = DEFAULT_ACTOR_TARGET) -> void:
	room_id = new_room_id.strip_edges()
	visibility = "public" if new_visibility.to_lower() == "public" else "private"
	mode = "survival" if new_mode.to_lower() == "survival" else "endless"
	human_cap = clampi(new_human_cap, MIN_HUMAN_CAP, MAX_HUMAN_CAP)
	actor_target = clampi(new_actor_target, human_cap, MAX_ACTORS)
	match_started = false
	host_peer_id = -1
	locked = false
	members.clear()
	slot_owners.clear()
	bot_count = actor_target
	_join_sequence = 0

func start_match() -> void:
	match_started = true

func stop_match() -> void:
	match_started = false

func human_count() -> int:
	return members.size()

func free_human_slots() -> int:
	return maxi(human_cap - human_count(), 0)

func actor_count() -> int:
	return human_count() + bot_count

func can_join(peer_id: int) -> bool:
	if peer_id <= 0 or members.has(peer_id) or human_count() >= human_cap:
		return false
	if locked and peer_id != host_peer_id:
		return false
	return not match_started or mode == "endless"

func join(peer_id: int, requested_name: String, color: Color = Color("56eddf")) -> Dictionary:
	if peer_id <= 0:
		return {"ok": false, "reason": "INVALID_PEER"}
	if members.has(peer_id):
		return {"ok": false, "reason": "ALREADY_JOINED"}
	if human_count() >= human_cap:
		return {"ok": false, "reason": "ROOM_FULL"}
	if locked and peer_id != host_peer_id:
		return {"ok": false, "reason": "ROOM_LOCKED"}
	if match_started and mode != "endless":
		return {"ok": false, "reason": "MATCH_IN_PROGRESS"}
	var slot := _next_slot()
	if slot < 0:
		return {"ok": false, "reason": "ACTOR_CAPACITY"}
	var member := {
		"peer_id": peer_id,
		"slot": slot,
		"name": _unique_name(requested_name),
		"color": color,
		"joined_order": _join_sequence,
		"connected": true,
	}
	_join_sequence += 1
	members[peer_id] = member
	slot_owners[slot] = peer_id
	if host_peer_id < 0:
		host_peer_id = peer_id
	bot_count = maxi(actor_target - human_count(), 0)
	member_joined.emit(member.duplicate())
	return {"ok": true, "member": member.duplicate()}

func leave(peer_id: int, reason: String = "left") -> Dictionary:
	if not members.has(peer_id):
		return {"ok": false, "reason": "NOT_JOINED"}
	var member: Dictionary = members[peer_id].duplicate()
	member["connected"] = false
	member["leave_reason"] = reason
	members.erase(peer_id)
	slot_owners.erase(int(member.slot))
	if host_peer_id == peer_id:
		host_peer_id = -1
		for candidate: Dictionary in members.values():
			if host_peer_id < 0 or int(candidate.joined_order) < int(members[host_peer_id].joined_order):
				host_peer_id = int(candidate.peer_id)
	bot_count = maxi(actor_target - human_count(), 0)
	member_left.emit(member.duplicate())
	return {"ok": true, "member": member}

func is_host(peer_id: int) -> bool:
	return peer_id > 0 and peer_id == host_peer_id

func set_locked(peer_id: int, should_lock: bool) -> bool:
	if not is_host(peer_id):
		return false
	locked = should_lock
	return true

func kick(peer_id: int, target_peer_id: int) -> Dictionary:
	if not is_host(peer_id) or target_peer_id == host_peer_id:
		return {"ok": false, "reason": "NOT_HOST"}
	return leave(target_peer_id, "kicked")

func set_human_cap(new_cap: int) -> bool:
	if new_cap < human_count():
		return false
	var clamped := clampi(new_cap, MIN_HUMAN_CAP, MAX_HUMAN_CAP)
	human_cap = clamped
	actor_target = maxi(actor_target, human_cap)
	bot_count = maxi(actor_target - human_count(), 0)
	return true

func set_actor_target(new_target: int) -> void:
	actor_target = clampi(new_target, human_cap, MAX_ACTORS)
	bot_count = maxi(actor_target - human_count(), 0)

func snapshot() -> Dictionary:
	var player_list: Array[Dictionary] = []
	for peer_id in members:
		var member: Dictionary = members[peer_id].duplicate()
		member["color"] = Color(member.color).to_html(false)
		player_list.append(member)
	player_list.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.joined_order) < int(b.joined_order))
	return {
		"room_id": room_id,
		"visibility": visibility,
		"mode": mode,
		"human_cap": human_cap,
		"actor_target": actor_target,
		"human_count": human_count(),
		"bot_count": bot_count,
		"match_started": match_started,
		"host_peer_id": host_peer_id,
		"locked": locked,
		"members": player_list,
	}

func _next_slot() -> int:
	for slot in range(MAX_ACTORS):
		if not slot_owners.has(slot):
			return slot
	return -1

func _unique_name(requested_name: String) -> String:
	var base := requested_name.strip_edges().left(18)
	if base.is_empty():
		base = "PIP"
	var candidate := base
	var suffix := 2
	while _name_taken(candidate):
		var suffix_text := " %d" % suffix
		candidate = base.left(18 - suffix_text.length()) + suffix_text
		suffix += 1
	return candidate

func _name_taken(candidate: String) -> bool:
	for member: Dictionary in members.values():
		if str(member.name).to_lower() == candidate.to_lower():
			return true
	return false
