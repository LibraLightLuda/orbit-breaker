extends Node

signal message(value: Dictionary)
signal failed(reason: String)
signal response(value: Dictionary)

const Config = preload("res://scripts/online_config.gd")
var socket := WebSocketPeer.new()
var request := HTTPRequest.new()
var base_url := ""
var room: Dictionary = {}
var hello: Dictionary = {}
var slot := -1
var resume_key := ""
var sequence := 0
var opened := false
var connected := false
var heartbeat := 0.0
var retry_left := 0.0
var retry_window := 0.0
var recovery := HTTPRequest.new()
var recovering := false
var features: Dictionary = {"combat": false}
var session_path := "user://online_session_v2.json"

func _ready() -> void:
	base_url = Config.service_url()
	add_child(request)
	request.timeout = 20.0
	# Browser fetch already decodes HTTP content encoding.
	request.accept_gzip = not OS.has_feature("web")
	request.request_completed.connect(_completed)
	add_child(recovery)
	recovery.timeout = 5.0
	recovery.accept_gzip = not OS.has_feature("web")
	recovery.request_completed.connect(_recovered)
	call_deferred("restore_session")

func restore_session() -> void:
	if not FileAccess.file_exists(session_path): return
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(session_path))
	if not saved is Dictionary or saved.get("base") != base_url or float(saved.get("expires", 0)) < Time.get_unix_time_from_system(): return
	if not saved.get("room") is Dictionary or not saved.get("resume") is String: return
	room = saved.room
	resume_key = saved.resume
	hello = {"type": "hello", "protocol": Config.PROTOCOL}
	_connect()

func _save_session() -> void:
	var file := FileAccess.open(session_path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"base": base_url, "room": room, "resume": resume_key, "expires": Time.get_unix_time_from_system() + 1800.0}))

func recover_result() -> void:
	if recovering or room.get("id", "").is_empty(): return
	recovering = recovery.request(base_url + "/v1/runs/" + str(room.id)) == OK

func _recovered(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	recovering = false
	if result != HTTPRequest.RESULT_SUCCESS or status != 200: return
	var value: Variant = JSON.parse_string(body.get_string_from_utf8())
	if value is Dictionary and value.get("id") == room.get("id") and value.get("verification") == "server":
		message.emit({"type": "result", "result": value})

func api(path: String, value: Variant = null) -> void:
	if base_url.is_empty():
		failed.emit("온라인 서버가 아직 설정되지 않았습니다.")
		return
	if request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		failed.emit("요청 처리 중입니다. 잠시 기다려 주세요.")
		return
	var code := request.request(base_url + path, ["Content-Type: application/json"], HTTPClient.METHOD_GET if value == null else HTTPClient.METHOD_POST, "" if value == null else JSON.stringify(value))
	if code != OK: failed.emit("온라인 서비스에 연결하지 못했습니다.")

func _completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var value: Variant = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or not value is Dictionary:
		failed.emit("온라인 서비스 응답을 받지 못했습니다.")
	elif status < 200 or status >= 300:
		failed.emit(str(value.get("error", "요청을 처리하지 못했습니다.")))
	else:
		response.emit(value)

func join(value: Dictionary, nickname: String, ship: String) -> void:
	if value.get("protocol") != Config.PROTOCOL:
		failed.emit("게임 버전이 서버와 맞지 않습니다. 최신 버전으로 업데이트하세요.")
		return
	leave()
	room = value
	hello = {"type": "hello", "protocol": Config.PROTOCOL, "nickname": nickname, "ship": ship}
	_connect()

func _connect() -> void:
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 2097152
	socket.outbound_buffer_size = 131072
	opened = false
	if socket.connect_to_url(str(room.websocket)) != OK: failed.emit("전투 서버 연결 실패")

func send(value: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN: socket.send_text(JSON.stringify(value))

func input(move: Vector2, dash: bool, aim: Vector2, overdrive: bool) -> void:
	sequence += 1
	send({"type": "input", "seq": sequence, "move": [move.x, move.y], "dash": dash, "aim": [aim.x, aim.y], "overdrive": overdrive})

func _process(delta: float) -> void:
	if room.is_empty(): return
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if not opened:
			opened = true
			var value := hello.duplicate()
			if not resume_key.is_empty(): value.resume = resume_key
			send(value)
		heartbeat += delta
		if heartbeat >= 1.0:
			heartbeat = 0.0
			send({"type": "ping"})
		while socket.get_available_packet_count() > 0:
			var bytes := socket.get_packet()
			if bytes.size() > 1048576:
				leave()
				failed.emit("전투 상태가 허용 크기를 초과했습니다.")
				return
			var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
			if not value is Dictionary: continue
			if value.get("type") == "hello":
				slot = int(value.slot)
				resume_key = str(value.resume)
				connected = true
				retry_window = 0.0
				sequence = maxi(sequence, int(value.get("sequence", 0)))
				_save_session()
			message.emit(value)
	elif socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		connected = false
		if resume_key.is_empty():
			room = {}
			failed.emit("전투 서버에 연결하지 못했습니다.")
			return
		retry_window += delta
		retry_left -= delta
		if retry_window >= 30.0:
			leave()
			failed.emit("재접속 시간이 초과되어 경기가 중단되었습니다.")
		elif retry_left <= 0.0:
			retry_left = 1.0
			recover_result()
			_connect()

func leave() -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN: socket.close()
	room = {}
	resume_key = ""
	slot = -1
	sequence = 0
	connected = false
	heartbeat = 0.0
	retry_left = 0.0
	retry_window = 0.0
	recovering = false
	if is_instance_valid(recovery): recovery.cancel_request()
	if FileAccess.file_exists(session_path): DirAccess.remove_absolute(session_path)
