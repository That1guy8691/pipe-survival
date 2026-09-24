extends SceneTree

const Protocol = preload("res://scripts/multiplayer_protocol.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	var join := Protocol.parse_packet(Protocol.join_message("  Pilot  ", Color("ff6e91"), "ROOM" ).to_utf8_buffer())
	check(join.type == "join" and join.version == Protocol.VERSION and join.room == "ROOM",
		"Join messages carry the protocol version and room code")
	check(join.name == "Pilot" and join.color == "ff6e91", "Join messages normalize player identity")
	var input := Protocol.parse_packet(Protocol.input_message("left", true, 7).to_utf8_buffer())
	check(input.type == "input" and input.turn == "left" and input.boost and input.sequence == 7,
		"Input messages carry validated steering and boost intent")
	var invalid_input := Protocol.parse_packet(Protocol.input_message("spin").to_utf8_buffer())
	check(invalid_input.type == "input" and not invalid_input.has("turn"),
		"Unknown steering commands are omitted from the wire format")
	var leave := Protocol.parse_packet(Protocol.leave_message("quit").to_utf8_buffer())
	check(leave.type == "leave" and leave.reason == "quit", "Leave messages carry a bounded reason")
	var riders: Array[Dictionary] = [{
		"cell": Vector3i(1, 2, 3), "forward": Vector3i.RIGHT, "up": Vector3i.UP,
		"source_cell": Vector3i(1, 2, 3), "source_forward": Vector3i.RIGHT,
		"alive": true, "length": 4, "score": 15, "pressure": 0.8,
		"name": "Pilot", "color": Color("56eddf")
	}]
	var history: Array = [[{"id": 0, "cell": Vector3i(1, 2, 3), "target": Vector3i(2, 2, 3),
		"incoming": Vector3i.RIGHT, "outgoing": Vector3i.RIGHT, "up": Vector3i.UP}]]
	var state := Protocol.parse_packet(Protocol.state_message({"room_id": "ROOM"}, 9, riders,
		[], history, true).to_utf8_buffer())
	check(state.type == "state" and state.tick == 9 and state.riders.size() == 1,
		"State messages include room tick and rider snapshots")
	check(state.riders[0].cell[0] == 1 and state.riders[0].cell[1] == 2
		and state.riders[0].cell[2] == 3 and state.riders[0].color == "56eddf"
		and is_equal_approx(float(state.riders[0].pressure), 0.8),
		"State messages serialize grid cells and colors for browser clients")
	check(bool(state.full_snapshot) and state.history.size() == 1 and state.history[0].size() == 1,
		"Full snapshots include authoritative trail history")
	print("MULTIPLAYER PROTOCOL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
