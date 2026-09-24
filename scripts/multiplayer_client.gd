extends Node
## Browser-safe WebSocket client. Gameplay presentation subscribes to these signals.

const Protocol = preload("res://scripts/multiplayer_protocol.gd")

signal connected_to_room(message: Dictionary)
signal state_received(message: Dictionary)
signal room_event(message: Dictionary)
signal connection_rejected(reason: String)
signal connection_failed(reason: String)
signal disconnected(reason: String)

var socket: WebSocketPeer
var url := ""
var _last_state := WebSocketPeer.STATE_CLOSED

func connect_to_room(server_url: String, room_id: String, player_name: String,
		player_color: Color = Color("56eddf")) -> Error:
	if socket != null and socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		return ERR_ALREADY_IN_USE
	url = server_url
	socket = WebSocketPeer.new()
	var error := socket.connect_to_url(server_url)
	if error != OK:
		socket = null
		connection_failed.emit("CONNECT_ERROR_%d" % error)
		return error
	set_meta("join_message", Protocol.join_message(player_name, player_color, room_id))
	_last_state = WebSocketPeer.STATE_CONNECTING
	set_process(true)
	return OK

func leave(reason: String = "left") -> void:
	if socket == null or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	socket.send_text(Protocol.leave_message(reason))

func send_turn(turn: String, sequence: int = 0) -> void:
	if socket == null or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	socket.send_text(Protocol.input_message(turn, false, sequence))

func send_boost(enabled: bool, sequence: int = 0) -> void:
	if socket == null or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	socket.send_text(Protocol.input_message("", enabled, sequence))

func close() -> void:
	if socket != null:
		socket.close()

func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	if socket == null:
		set_process(false)
		return
	socket.poll()
	var state := socket.get_ready_state()
	if state != _last_state:
		_last_state = state
		if state == WebSocketPeer.STATE_OPEN:
			var join_message: String = str(get_meta("join_message", ""))
			if not join_message.is_empty():
				socket.send_text(join_message)
				remove_meta("join_message")
		elif state == WebSocketPeer.STATE_CLOSED:
			disconnected.emit(socket.get_close_reason())
			set_process(false)
	if state != WebSocketPeer.STATE_OPEN:
		return
	while socket.get_available_packet_count() > 0:
		var message := Protocol.parse_packet(socket.get_packet())
		if message.is_empty():
			continue
		match str(message.get("type", "")):
			"welcome": connected_to_room.emit(message)
			"state": state_received.emit(message)
			"event": room_event.emit(message)
			"reject":
				var reason := str(message.get("reason", "REJECTED"))
				connection_rejected.emit(reason)
				socket.close(1008, reason)
