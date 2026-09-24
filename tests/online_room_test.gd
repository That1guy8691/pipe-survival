extends SceneTree

const Room = preload("res://scripts/online_room.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	var room := Room.new()
	room.configure("ABCD", "public", "endless", 2, 32)
	check(room.visibility == "public" and room.mode == "endless", "Room keeps public Endless settings")
	check(room.human_cap == 2 and room.actor_target == 32 and room.bot_count == 32,
		"A new room fills its actor target with bots before humans join")
	var first := room.join(11, "Pilot", Color("56eddf"))
	var second := room.join(12, "Pilot", Color("ffb65a"))
	check(bool(first.ok) and bool(second.ok), "Two human players can join an open room")
	check(first.member.slot != second.member.slot and first.member.name != second.member.name,
		"Players receive distinct actor slots and display names")
	check(first.member.peer_id == room.host_peer_id and room.is_host(first.member.peer_id),
		"The first public player becomes the room host")
	check(room.human_count() == 2 and room.free_human_slots() == 0 and room.bot_count == 30,
		"Human joins replace bot slots while preserving the 32-actor target")
	var full := room.join(13, "Late", Color.WHITE)
	check(not bool(full.ok) and full.reason == "ROOM_FULL", "The room enforces its human cap")
	room.start_match()
	var moderated := Room.new()
	moderated.configure("LOCK", "public", "endless", 8, 32)
	moderated.join(41, "Host")
	check(moderated.set_locked(41, true) and moderated.locked, "The host can lock a room for moderation")
	var locked_join := moderated.join(42, "Blocked", Color.WHITE)
	check(not bool(locked_join.ok) and locked_join.reason == "ROOM_LOCKED",
		"Locked rooms reject new human joins")
	moderated.set_locked(41, false)
	var rejected_survival := Room.new()
	rejected_survival.configure("SURV", "private", "survival", 8, 16)
	check(bool(rejected_survival.join(1, "Host").ok), "A Survival host can join before the match")
	rejected_survival.start_match()
	check(not bool(rejected_survival.join(2, "Late").ok)
		and rejected_survival.join(2, "Late").reason == "MATCH_IN_PROGRESS",
		"Survival rejects late joins after the round starts")
	var late := room.join(13, "Late", Color("aa8cff"))
	check(not bool(late.ok), "An Endless room still rejects joins while its human cap is full")
	var left := room.leave(11, "quit")
	check(bool(left.ok) and left.member.leave_reason == "quit" and room.human_count() == 1,
		"Leaving removes the member and frees the slot")
	check(room.host_peer_id == 12 and room.is_host(12), "Host ownership transfers when the host leaves")
	var rejoined := room.join(13, "Pilot", Color("82df8b"))
	check(bool(rejoined.ok) and rejoined.member.slot == first.member.slot,
		"Endless admits a replacement player into the freed actor slot")
	check(room.snapshot().members.size() == 2 and room.snapshot().bot_count == 30,
		"Room snapshots expose current humans and replacement bots")
	check(not room.set_human_cap(1) and room.human_cap == 2,
		"The human cap cannot be lowered below current membership")
	room.set_human_cap(10)
	check(room.human_cap == 10 and room.free_human_slots() == 8,
		"The early access cap can expand to ten humans")
	print("ONLINE ROOM: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
