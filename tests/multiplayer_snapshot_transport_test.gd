extends SceneTree
## A grown room snapshot must cross a real WebSocket connection intact.

const Protocol = preload("res://scripts/multiplayer_protocol.gd")
const Runtime = preload("res://scripts/multiplayer_room_runtime.gd")
const PORT := 8790

var listener := TCPServer.new()
var client := WebSocketPeer.new()
var server: WebSocketPeer
var payload := ""
var sent := false
var started := 0

func _initialize() -> void:
	var room := Runtime.new()
	for i in range(513):
		room.trail_history[0].append({"id": 0,
			"cell": Vector3i(i % 30, i / 30 % 30, 2),
			"target": Vector3i((i + 1) % 30, i / 30 % 30, 2),
			"incoming": Vector3i.RIGHT, "outgoing": Vector3i.RIGHT,
			"up": Vector3i.UP})
	payload = room.state_message([], true)
	if payload.to_utf8_buffer().size() <= 65535:
		_fail("Snapshot did not exceed the default WebSocket buffer")
		return
	if listener.listen(PORT, "127.0.0.1") != OK:
		_fail("Could not open the local test port")
		return
	client.inbound_buffer_size = Protocol.MAX_STATE_BYTES
	if client.connect_to_url("ws://127.0.0.1:%d" % PORT) != OK:
		_fail("Could not connect the local test client")
		return
	started = Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if started == 0:
		return false
	if server == null and listener.is_connection_available():
		server = WebSocketPeer.new()
		server.outbound_buffer_size = Protocol.MAX_STATE_BYTES
		if server.accept_stream(listener.take_connection()) != OK:
			_fail("Could not accept the local WebSocket")
			return false
	if server != null:
		server.poll()
	client.poll()
	if server != null and server.get_ready_state() == WebSocketPeer.STATE_OPEN and not sent:
		if server.send_text(payload) != OK:
			_fail("Could not send the large room snapshot")
			return false
		sent = true
	if client.get_available_packet_count() > 0:
		var packet := client.get_packet()
		var state := Protocol.parse_packet(packet)
		if packet.size() != payload.to_utf8_buffer().size() or \
				state.get("history", []).size() != 32 or state.history[0].size() != 513:
			_fail("Large room snapshot arrived incomplete")
		else:
			print("MULTIPLAYER SNAPSHOT TRANSPORT: %d bytes received intact" % packet.size())
			quit()
	elif Time.get_ticks_msec() - started > 5000:
		_fail("Timed out waiting for the large room snapshot")
	return false

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
