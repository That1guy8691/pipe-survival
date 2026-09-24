extends SceneTree

const Room = preload("res://scripts/online_room.gd")
const Runtime = preload("res://scripts/multiplayer_room_runtime.gd")
const Protocol = preload("res://scripts/multiplayer_protocol.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	var public_room := Room.new()
	public_room.configure("PUBLIC", "public", "endless", 8, 32)
	var first := Runtime.new(public_room)
	var second_room := Room.new()
	second_room.configure("FRIENDS", "private", "endless", 8, 32)
	var second := Runtime.new(second_room)
	var first_join := first.join(101, "Pilot", Color("56eddf"))
	var second_join := second.join(202, "Pilot", Color("ffb65a"))
	check(bool(first_join.ok) and bool(second_join.ok),
		"Independent room runtimes accept members")
	check(first.room.room_id == "PUBLIC" and second.room.room_id == "FRIENDS"
		and first_join.member.slot == 0 and second_join.member.slot == 0,
		"Room runtimes keep separate room and slot state")
	var first_tick := first.step()
	var second_tick := second.step()
	check(first.sim.ticks == 1 and second.sim.ticks == 1
		and not first_tick.is_empty() and not second_tick.is_empty(),
		"Each runtime advances its own authoritative simulation")
	var state := Protocol.parse_packet(first.state_message(first_tick).to_utf8_buffer())
	check(state.type == "state" and state.room.room_id == "PUBLIC"
		and state.tick == first.sim.ticks and state.riders.size() == 32,
		"Runtime state messages include room identity and all actor snapshots")
	var long_trail: Array = first.trail_history[0]
	long_trail.clear()
	for i in range(513):
		long_trail.append({"id": 0, "cell": Vector3i(i % 30, i / 30 % 30, 2),
			"target": Vector3i((i + 1) % 30, i / 30 % 30, 2),
			"incoming": Vector3i.RIGHT, "outgoing": Vector3i.RIGHT, "up": Vector3i.UP})
	var full_state := Protocol.parse_packet(first.state_message([], true).to_utf8_buffer())
	check(full_state.history[0].size() == 513,
		"Full snapshots retain trails beyond 512 segments so occupied cells stay visible")
	var left := first.leave(101, "quit")
	check(bool(left.ok) and first.room.human_count() == 0 and first.client_ids().is_empty(),
		"Leaving a runtime returns its slot to the bot pool")
	check(second.room.human_count() == 1 and second.client_ids().size() == 1,
		"A second room remains unaffected by another room leaving")
	print("MULTIPLAYER RUNTIME: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
