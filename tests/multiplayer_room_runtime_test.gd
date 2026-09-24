extends SceneTree

const Room = preload("res://scripts/online_room.gd")
const Runtime = preload("res://scripts/multiplayer_room_runtime.gd")
const Protocol = preload("res://scripts/multiplayer_protocol.gd")
const Rules = preload("res://scripts/simulation.gd")
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
	var boost_room := Room.new()
	boost_room.configure("BOOST", "private", "endless", 8, 32)
	var boosted := Runtime.new(boost_room)
	boosted.join(303, "Boost", Color("56eddf"))
	for i in range(1, boosted.sim.riders.size()):
		boosted.sim.riders[i].alive = false
		boosted.sim.remove_rider_trail(i)
	var idle_half := boosted.step(Runtime.HALF_STEP_TIME)
	check(idle_half.is_empty() and boosted.sim.ticks == 0,
		"Normal movement waits for the full step")
	boosted.receive_input(303, "", true)
	boosted.receive_input(303, "", false, false)
	check(bool(boosted.inputs[303].boost), "A turn-only input preserves held boost")
	var fast_half := boosted.step(Runtime.HALF_STEP_TIME)
	check(fast_half.size() == 1 and boosted.sim.ticks == 1
		and boosted.sim.riders[0].boosting and boosted.sim.riders[0].pressure < 1.0,
		"Held boost moves on half steps and consumes pressure")
	var fast_next := boosted.step(Runtime.HALF_STEP_TIME)
	check(fast_next.size() == 1 and boosted.sim.ticks == 2,
		"Held boost advances twice during one normal movement interval")
	boosted.receive_input(303, "", false)
	var released := boosted.step(Runtime.HALF_STEP_TIME)
	var released_odd := boosted.step(Runtime.HALF_STEP_TIME)
	check(released.size() == 1 and released_odd.is_empty()
		and not boosted.sim.riders[0].boosting,
		"Releasing boost returns to normal movement cadence")
	boosted.sim.riders[0].alive = false
	boosted.sim.remove_rider_trail(0)
	for _i in range(20):
		boosted.step(Runtime.HALF_STEP_TIME)
	check(not boosted.sim.riders[0].alive,
		"An online human stays dead until requesting respawn")
	check(boosted.request_respawn(303), "A dead player can request respawn")
	boosted.step(Runtime.HALF_STEP_TIME)
	check(boosted.sim.riders[0].alive and boosted.state_changed,
		"The next room step respawns the requesting player")
	var score_sim := Rules.new()
	for is_endless in [false, true]:
		score_sim.endless_mode = is_endless
		score_sim.reset(7801, 1, 60)
		score_sim.riders[1].score = 120
		var outward: Vector3i = -score_sim.inlet_direction(score_sim.riders[1].cell)
		score_sim.riders[1].forward = outward
		var death_moves := score_sim.advance([score_sim.riders[0].forward, outward], [1])
		check(death_moves.size() == 1 and death_moves[0].died
			and score_sim.riders[1].score == 0,
			"A bot's score resets to zero on death in %s mode" %
			("Endless" if is_endless else "Survival"))
	print("MULTIPLAYER RUNTIME: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
