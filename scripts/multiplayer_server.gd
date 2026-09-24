extends SceneTree
## Dedicated browser room server.
## Run with: Godot_v4.7-stable_win64_console.exe --headless --path . --script res://scripts/multiplayer_server.gd -- --port=8787

const Rules = preload("res://scripts/simulation.gd")
const Room = preload("res://scripts/online_room.gd")
const Protocol = preload("res://scripts/multiplayer_protocol.gd")
const RoomDirectory = preload("res://scripts/room_directory.gd")
const RoomRuntime = preload("res://scripts/multiplayer_room_runtime.gd")

const DEFAULT_PORT := 8787
const MAX_CONNECTIONS := 256
const MAX_PACKETS_PER_SECOND := 120
const PACKET_WINDOW_MS := 1000
const MAX_INBOUND_PACKET_BYTES := 4096

var port := DEFAULT_PORT
var validation_only := false
var tcp_server := TCPServer.new()
var directory := RoomDirectory.new()
var runtimes: Dictionary = {}
var clients: Dictionary = {}
var accumulator := 0.0
var next_connection_id := 1

func _initialize() -> void:
	_read_arguments()
	directory.public_room("endless", Room.DEFAULT_HUMAN_CAP, Room.MAX_ACTORS)
	if validation_only:
		print("MULTIPLAYER SERVER: configuration valid on port %d" % port)
		quit()
		return
	var error := tcp_server.listen(port)
	if error != OK:
		push_error("Could not listen on port %d (error %d)" % [port, error])
		quit(1)
		return
	print("PIPE room server listening on ws://127.0.0.1:%d" % port)

func _process(delta: float) -> bool:
	_accept_connections()
	for connection_id in clients.keys().duplicate():
		if clients.has(connection_id):
			_poll_client(int(connection_id))
	accumulator += delta
	while accumulator >= Rules.STEP_TIME:
		accumulator -= Rules.STEP_TIME
		_step_rooms()
	return false

func _accept_connections() -> void:
	while tcp_server.is_connection_available():
		var stream := tcp_server.take_connection()
		var socket := WebSocketPeer.new()
		var error := socket.accept_stream(stream)
		if error != OK:
			socket.close(-1)
			continue
		if clients.size() >= MAX_CONNECTIONS:
			socket.close(1008, "SERVER_FULL")
			continue
		var connection_id := next_connection_id
		next_connection_id += 1
		clients[connection_id] = {
			"socket": socket,
			"joined": false,
			"room_id": "",
			"packet_window_start": Time.get_ticks_msec(),
			"packet_count": 0,
		}

func _poll_client(connection_id: int) -> void:
	var client: Dictionary = clients[connection_id]
	var socket: WebSocketPeer = client.socket
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		_release_client(connection_id, "disconnect")
		return
	if state != WebSocketPeer.STATE_OPEN:
		return
	while socket.get_available_packet_count() > 0:
		var packet := socket.get_packet()
		if packet.size() > MAX_INBOUND_PACKET_BYTES:
			_reject_and_close(connection_id, "PACKET_TOO_LARGE", 1009)
			return
		if not _allow_packet(connection_id):
			_reject_and_close(connection_id, "RATE_LIMIT", 1008)
			return
		var message := Protocol.parse_packet(packet)
		if not message.is_empty():
			_handle_message(connection_id, message)
		else:
			_send(connection_id, {"type": "reject", "reason": "INVALID_PACKET"})

func _handle_message(connection_id: int, message: Dictionary) -> void:
	if int(message.get("version", -1)) != Protocol.VERSION:
		_reject_and_close(connection_id, "PROTOCOL_VERSION", 1002)
		return
	var client: Dictionary = clients.get(connection_id, {})
	var message_type := str(message.get("type", ""))
	match message_type:
		"join":
			_join_client(connection_id, client, message)
		"input":
			if bool(client.get("joined", false)):
				var runtime: RoomRuntime = runtimes.get(str(client.room_id), null)
				if runtime != null:
					runtime.receive_input(connection_id, str(message.get("turn", "")),
						bool(message.get("boost", false)))
		"leave":
			_release_client(connection_id, str(message.get("reason", "left")))
		"host":
			_host_control(connection_id, client, message)
		_:
			_send(connection_id, {"type": "reject", "reason": "INVALID_MESSAGE"})

func _join_client(connection_id: int, client: Dictionary, message: Dictionary) -> void:
	if bool(client.get("joined", false)):
		return
	var room := _room_for_request(str(message.get("room", "")))
	if room == null:
		_reject_and_close(connection_id, "INVALID_ROOM_CODE", 1008)
		return
	var runtime := _runtime_for(room)
	var result := runtime.join(connection_id, str(message.get("name", "PIP")),
		Protocol.parse_color(message.get("color", "")))
	if not bool(result.get("ok", false)):
		if room.visibility == "private" and room.human_count() == 0:
			_close_runtime(room.room_id)
		_reject_and_close(connection_id, str(result.get("reason", "JOIN_REJECTED")), 1008)
		return
	var member: Dictionary = result.member
	client["joined"] = true
	client["room_id"] = room.room_id
	clients[connection_id] = client
	_send(connection_id, {"type": "welcome", "room": room.snapshot(),
		"player": _serializable_member(member), "tick": runtime.sim.ticks})
	_broadcast_event(runtime, "joined", member)
	_broadcast_state(runtime, [], true)

func _host_control(connection_id: int, client: Dictionary, message: Dictionary) -> void:
	if not bool(client.get("joined", false)):
		return
	var runtime: RoomRuntime = runtimes.get(str(client.get("room_id", "")), null)
	if runtime == null or not runtime.room.is_host(connection_id):
		_send(connection_id, {"type": "reject", "reason": "NOT_HOST"})
		return
	var action := str(message.get("action", ""))
	if action == "lock":
		if not runtime.room.set_locked(connection_id, bool(message.get("locked", false))):
			_send(connection_id, {"type": "reject", "reason": "NOT_HOST"})
			return
		_broadcast_room_notice(runtime, "locked" if runtime.room.locked else "unlocked")
		_broadcast_state(runtime, [], true)
	elif action == "kick":
		var target_id := int(message.get("peer_id", -1))
		if target_id <= 0 or target_id == connection_id or not runtime.has_client(target_id):
			_send(connection_id, {"type": "reject", "reason": "INVALID_TARGET"})
			return
		_release_client(target_id, "kicked")

func _room_for_request(requested_id: String) -> Room:
	var raw_room_id := requested_id.strip_edges()
	var room_id := RoomDirectory.normalize_code(raw_room_id)
	if raw_room_id.is_empty():
		return directory.public_room()
	if room_id == RoomDirectory.PUBLIC_ROOM_ID:
		return directory.public_room() if raw_room_id.to_upper() == RoomDirectory.PUBLIC_ROOM_ID else null
	if room_id.is_empty():
		return null
	if not RoomDirectory.is_valid_private_code(room_id):
		return null
	return directory.find_or_create_private(room_id, "endless", Room.DEFAULT_HUMAN_CAP, Room.MAX_ACTORS)

func _runtime_for(room: Room) -> RoomRuntime:
	if runtimes.has(room.room_id):
		return runtimes[room.room_id]
	var runtime := RoomRuntime.new(room)
	runtimes[room.room_id] = runtime
	return runtime

func _step_rooms() -> void:
	for room_id in runtimes.keys().duplicate():
		var runtime: RoomRuntime = runtimes[room_id]
		var moves := runtime.step()
		_broadcast_state(runtime, moves)

func _release_client(connection_id: int, reason: String) -> void:
	if not clients.has(connection_id):
		return
	var safe_reason := reason.strip_edges().left(32)
	if safe_reason.is_empty():
		safe_reason = "left"
	var client: Dictionary = clients[connection_id]
	if bool(client.get("joined", false)):
		var room_id := str(client.get("room_id", ""))
		var runtime: RoomRuntime = runtimes.get(room_id, null)
		if runtime != null:
			var result := runtime.leave(connection_id, safe_reason)
			if bool(result.get("ok", false)):
				_broadcast_event(runtime, "left", result.member)
				_broadcast_state(runtime, [], true)
			if runtime.room.visibility == "private" and runtime.room.human_count() == 0:
				_close_runtime(room_id)
	clients.erase(connection_id)

func _allow_packet(connection_id: int) -> bool:
	if not clients.has(connection_id):
		return false
	var client: Dictionary = clients[connection_id]
	var now := Time.get_ticks_msec()
	var window_start := int(client.get("packet_window_start", now))
	var packet_count := int(client.get("packet_count", 0))
	if now - window_start >= PACKET_WINDOW_MS:
		window_start = now
		packet_count = 0
	packet_count += 1
	client["packet_window_start"] = window_start
	client["packet_count"] = packet_count
	clients[connection_id] = client
	return packet_count <= MAX_PACKETS_PER_SECOND

func _reject_and_close(connection_id: int, reason: String, close_code: int) -> void:
	if not clients.has(connection_id):
		return
	_send(connection_id, {"type": "reject", "reason": reason})
	var socket: WebSocketPeer = clients[connection_id].socket
	socket.close(close_code, reason)
	_release_client(connection_id, reason.to_lower())

func _close_runtime(room_id: String) -> void:
	runtimes.erase(room_id)
	directory.close_empty(room_id)

func _broadcast_state(runtime: RoomRuntime, moves: Array[Dictionary], full_snapshot: bool = false) -> void:
	var message := runtime.state_message(moves, full_snapshot)
	for connection_id in runtime.client_ids():
		_send_text(connection_id, message)

func _broadcast_event(runtime: RoomRuntime, event_name: String, member: Dictionary) -> void:
	var message := runtime.event_message(event_name, member)
	for connection_id in runtime.client_ids():
		_send_text(connection_id, message)

func _broadcast_room_notice(runtime: RoomRuntime, event_name: String) -> void:
	var message := JSON.stringify({"version": Protocol.VERSION, "type": "event",
		"event": event_name, "room": runtime.room.snapshot()})
	for connection_id in runtime.client_ids():
		_send_text(connection_id, message)

func _send(connection_id: int, message: Dictionary) -> void:
	_send_text(connection_id, JSON.stringify(message))

func _send_text(connection_id: int, message: String) -> void:
	if not clients.has(connection_id):
		return
	var socket: WebSocketPeer = clients[connection_id].socket
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(message)

func _serializable_member(member: Dictionary) -> Dictionary:
	var copy := member.duplicate()
	copy["color"] = Color(member.color).to_html(false)
	return copy

func _read_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--validate":
			validation_only = true
		elif str(argument).begins_with("--port="):
			port = clampi(int(str(argument).trim_prefix("--port=")), 1, 65535)
