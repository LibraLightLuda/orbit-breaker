class_name OrbitMatchServer
extends SceneTree

const World = preload("res://scripts/online_world.gd")
const PROTOCOL := 2
var configuration: Dictionary
var listener := TCPServer.new()
var peers: Array[Dictionary] = []
var slots: Array[Dictionary] = []
var world: RefCounted
var recorders: Array[GhostReplay] = []
var started := false
var ended := false
var born := Time.get_ticks_msec()
var started_at := ""
var started_ms := 0
var seed_value := 0
var accumulator := 0.0
var snapshot_clock := 0.0
var replay_clock := 0.0
var chunk_clock := 0.0
var chunk_frames: Array = []
var chunk_manifest: Array = []
var replay_bytes := 0
var replay_failed := false
var last_recorded_time := -1.0
var finish_clock := 0.0
var manual_pause := 0.0
var pause_total := 0.0
var completed_result: Dictionary = {}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--config")
	if index < 0 or index + 1 >= args.size():
		push_error("Missing match configuration")
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(Marshalls.base64_to_utf8(args[index + 1]))
	if not parsed is Dictionary or not parsed.has_all(["id", "code", "port", "directory", "mode", "difficulty", "sector"]):
		quit(1)
		return
	configuration = parsed
	if listener.listen(int(configuration.port), "127.0.0.1") != OK:
		quit(1)
		return
	for i in (2 if configuration.mode == "coop" else 1):
		slots.append({"peer": null, "resume": "", "nickname": "파일럿", "ship": "striker", "ready": false, "connected": false, "disconnect_used": 0.0, "last_seq": -1, "applied_seq": -1, "last_input": 0, "pending": {}, "input": {}, "pause": false})
	print("ONLINE_SERVER_READY")

func reply(peer: Dictionary, value: Dictionary) -> void:
	if peer.socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if value.get("type") == "state" and peer.socket.get_current_outbound_buffered_amount() > 131072: return
		peer.socket.send_text(JSON.stringify(value))

func broadcast(value: Dictionary) -> void:
	for peer in peers:
		if int(peer.slot) >= 0: reply(peer, value)

func _process(delta: float) -> bool:
	while listener.is_connection_available():
		var stream := listener.take_connection()
		if peers.size() >= 6:
			stream.disconnect_from_host()
			continue
		var socket := WebSocketPeer.new()
		socket.inbound_buffer_size = 32768
		socket.outbound_buffer_size = 2097152
		if socket.accept_stream(stream) == OK: peers.append({"socket": socket, "slot": -1, "last": Time.get_ticks_msec(), "window": Time.get_ticks_msec(), "count": 0})
	for peer in peers.duplicate():
		peer.socket.poll()
		if peer.socket.get_ready_state() == WebSocketPeer.STATE_CLOSED or Time.get_ticks_msec() - int(peer.last) > 10000:
			if int(peer.slot) >= 0 and slots[int(peer.slot)].peer == peer:
				slots[int(peer.slot)].connected = false
				if not started:
					slots[int(peer.slot)].resume = ""
					slots[int(peer.slot)].ready = false
					slots[int(peer.slot)].nickname = "대기 중"
					slots[int(peer.slot)].peer = null
			peers.erase(peer)
			if not started: lobby()
			continue
		while peer.socket.get_available_packet_count() > 0:
			var bytes: PackedByteArray = peer.socket.get_packet()
			if bytes.size() > 8192:
				peer.socket.close(1009)
				break
			if Time.get_ticks_msec() - int(peer.window) >= 1000:
				peer.window = Time.get_ticks_msec()
				peer.count = 0
			peer.count += 1
			if int(peer.count) > 120:
				peer.socket.close(1008)
				break
			var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
			if value is Dictionary:
				peer.last = Time.get_ticks_msec()
				handle(peer, value)
	if ended:
		finish_clock += delta
		if finish_clock > 30.0:
			if world != null: world.dispose()
			quit()
		return false
	if not started:
		if Time.get_ticks_msec() - born > 600000: quit()
		return false
	if Time.get_ticks_msec() - started_ms > 1800000:
		abort("경기 시간 제한")
		return false
	var disconnected := false
	for slot in slots:
		if not bool(slot.connected):
			disconnected = true
			slot.disconnect_used += delta
			if float(slot.disconnect_used) >= 30.0:
				abort("동료 재접속 시간 초과")
				return false
	if disconnected:
		accumulator = 0.0
		broadcast({"type": "status", "phase": "reconnecting"})
		return false
	if manual_pause > 0.0:
		manual_pause -= delta
		accumulator = 0.0
		broadcast({"type": "status", "phase": "paused", "remaining": manual_pause})
		return false
	accumulator += delta
	if accumulator > 0.25:
		abort("서버 처리 지연으로 경기 중단")
		return false
	while accumulator >= 1.0 / 60.0:
		var inputs: Array = []
		for slot in slots:
			inputs.append(consume_input(slot))
		world.step(1.0 / 60.0, inputs)
		accumulator -= 1.0 / 60.0
		if world.phase in ["won", "lost"]:
			capture(true)
			complete()
			return false
	snapshot_clock += delta
	replay_clock += delta
	chunk_clock += delta
	if snapshot_clock >= 0.05:
		snapshot_clock = fmod(snapshot_clock, 0.05)
		capture(replay_clock >= 0.2)
		if replay_clock >= 0.2: replay_clock = fmod(replay_clock, 0.2)

	return false

func handle(peer: Dictionary, value: Dictionary) -> void:
	var kind := str(value.get("type", ""))
	if kind == "hello":
		if value.get("protocol") != PROTOCOL or int(peer.slot) >= 0:
			peer.socket.close(1008)
			return
		var index := -1
		for i in slots.size():
			if not str(value.get("resume", "")).is_empty() and value.resume == slots[i].resume: index = i
		if index < 0 and not started:
			for i in slots.size():
				if slots[i].resume == "":
					index = i
					break
		if index < 0:
			reply(peer, {"type": "error", "message": "방이 가득 찼거나 이미 시작했습니다."})
			peer.socket.close(1008)
			return
		var slot: Dictionary = slots[index]
		if slot.peer != null and slot.peer != peer: slot.peer.socket.close()
		if slot.resume == "":
			slot.resume = Crypto.new().generate_random_bytes(16).hex_encode()
			slot.nickname = SaveStore.clean_name(value.get("nickname"))
			slot.ship = str(value.get("ship")) if str(value.get("ship")) in GameContent.SHIP_IDS else "striker"
		slot.peer = peer
		slot.connected = true
		peer.slot = index
		reply(peer, {"type": "hello", "slot": index, "resume": slot.resume, "code": configuration.code, "sequence": slot.last_seq})
		if ended and not completed_result.is_empty(): reply(peer, {"type": "result", "result": completed_result})
		elif ended: reply(peer, {"type": "error", "message": "경기가 중단되었습니다."})
		elif started: send_begin(peer)
		else: lobby()
		return
	if int(peer.slot) < 0: return
	var slot: Dictionary = slots[int(peer.slot)]
	match kind:
		"ready":
			if not started:
				slot.ready = bool(value.get("ready", false))
				lobby()
				if slots.all(func(p: Dictionary) -> bool: return p.ready and p.connected): begin()
		"input":
			if not started or ended or not value.get("seq") is float and not value.get("seq") is int: return
			var seq := int(value.seq)
			if float(seq) != float(value.seq): return
			if seq <= int(slot.last_seq) or seq > 2147483647: return
			slot.last_seq = seq
			slot.last_input = Time.get_ticks_msec()
			slot.input = {"move": vector(value.get("move")), "aim": vector(value.get("aim"))}
			for button in ["dash", "overdrive"]:
				if value.get(button) == true and not slot.pending.has(button):
					slot.pending[button] = {"id": seq, "aim": slot.input.aim}
		"choice":
			if started and not ended and (value.get("revision") is int or value.get("revision") is float) and is_finite(float(value.revision)):
				var revision := int(value.revision)
				if float(revision) == float(value.revision): world.choose(int(peer.slot), str(value.get("id", "")), revision)
		"finale":
			if started and not ended:
				if slots.size() == 1: world.model.select_finale(value.get("accept") == true)
				else: world.actors[int(peer.slot)].final_vote = value.get("accept") == true
		"pause":
			slot.pause = value.get("accept") == true
			if not slot.pause: manual_pause = 0.0
			elif started and pause_total < 60.0 and slots.all(func(p: Dictionary) -> bool: return p.pause):
				manual_pause = minf(30.0, 60.0 - pause_total)
				pause_total += manual_pause
				for participant in slots: participant.pause = false
			else: broadcast({"type": "pause_request", "slot": peer.slot})

func consume_input(slot: Dictionary) -> Dictionary:
	var input: Dictionary = slot.input.duplicate()
	if Time.get_ticks_msec() - int(slot.last_input) > 250:
		input = {}
	else:
		for button: String in slot.pending:
			input[button] = true
			if button == "dash": input.aim = slot.pending[button].aim
	slot.pending.clear()
	slot.applied_seq = slot.last_seq
	return input

func vector(value: Variant) -> Vector2:
	if not value is Array or value.size() != 2: return Vector2.ZERO
	for number: Variant in value:
		if not (number is int or number is float) or not is_finite(float(number)): return Vector2.ZERO
	return Vector2(float(value[0]), float(value[1])).limit_length(1.0)

func lobby() -> void:
	var players: Array = []
	for slot in slots: players.append({"nickname": slot.nickname, "ship": slot.ship, "ready": slot.ready, "connected": slot.connected})
	broadcast({"type": "lobby", "players": players, "code": configuration.code})

func begin() -> void:
	world = World.new()
	seed_value = int(Crypto.new().generate_random_bytes(4).hex_encode().hex_to_int()) % 2147483646 + 1
	world.reset(seed_value, str(configuration.difficulty), slots.map(func(p: Dictionary) -> String: return p.ship), str(configuration.sector))
	world.model.audio_enabled = true
	for i in slots.size(): recorders.append(GhostReplay.new())
	started_at = Time.get_datetime_string_from_system(true) + "Z"
	started_ms = Time.get_ticks_msec()
	started = true
	for peer in peers:
		if int(peer.slot) >= 0: send_begin(peer)
	capture(true)

func send_begin(peer: Dictionary) -> void:
	reply(peer, {"type": "begin", "seed": seed_value, "ships": slots.map(func(p: Dictionary) -> String: return p.ship), "difficulty": configuration.difficulty, "sector": configuration.sector, "mode": configuration.mode})

func capture(record: bool) -> void:
	var frames: Array = []
	var players: Array = []
	world.save_actor()
	for i in slots.size():
		world.select_actor(i)
		var model: RunModel = world.model
		frames.append(recorders[i].snapshot_current(model))
		players.append({"position": [model.player.x, model.player.y], "facing": model.facing.angle(), "hp": model.hp, "max_hp": model.max_hp, "ship": model.ship_id, "life": world.actors[i].life, "rescue": world.actors[i].rescue})
		if record: recorders[i]._events = []
	if record and not replay_failed:
		if world.model.elapsed > last_recorded_time:
			chunk_frames.append({"time": frames[0][0], "players": frames})
			last_recorded_time = world.model.elapsed
			if world.model.elapsed - float(chunk_frames.front().time) >= 2.0: flush_chunk()
	for peer in peers:
		var index := int(peer.slot)
		if index < 0: continue
		world.select_actor(index)
		var model: RunModel = world.model
		var offered: Array = world.choices(index)
		reply(peer, {"type": "state", "tick": world.sequence, "ack": slots[index].applied_seq, "motion": {"dash_time": model.dash_time, "dash_direction": [model._dash_direction.x, model._dash_direction.y]}, "frame": frames[index], "players": players, "phase": world.phase, "state": model.state, "choices": offered, "choice_revision": world.actors[index].choice_revision, "score": model.score, "team_score": world.team_score(), "speed": model.current_speed, "finale_offered": model.finale_offered, "finale_selected": model.finale_selected, "events": model.events.duplicate(), "audio": pack_audio(model.audio_events)})
	for i in slots.size():
		world.select_actor(i)
		world.model.events.clear()
		world.model.audio_events.clear()

func pack_audio(value: Dictionary) -> Dictionary:
	var result := {}
	for key: String in value:
		var at: Vector2 = value[key]
		result[key] = [at.x, at.y] if at.is_finite() else []
	return result

func flush_chunk() -> void:
	if chunk_frames.is_empty() or replay_failed: return
	var bytes := JSON.stringify({"version": 1, "frames": chunk_frames}).to_utf8_buffer()
	var compressed := bytes.compress(FileAccess.COMPRESSION_GZIP)
	if bytes.size() > 4194304 or compressed.size() > 1048576 or replay_bytes + compressed.size() > 67108864:
		replay_failed = true
		chunk_frames.clear()
		return
	var directory := str(configuration.directory).path_join(str(configuration.id) + ".replay")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		replay_failed = true
		return
	var file := FileAccess.open(directory.path_join(str(chunk_manifest.size()) + ".json.gz"), FileAccess.WRITE)
	if file == null:
		replay_failed = true
		return
	file.store_buffer(compressed)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if not ok:
		replay_failed = true
		return
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(compressed)
	chunk_manifest.append({"sha256": hash.finish().hex_encode(), "bytes": compressed.size(), "start": chunk_frames.front().time, "end": chunk_frames.back().time})
	replay_bytes += compressed.size()
	chunk_frames.clear()

func complete() -> void:
	flush_chunk()
	var names: Array[String] = []
	for slot in slots: names.append(slot.nickname)
	var rules := "coop-v1" if slots.size() == 2 else "online-solo-v1"
	var value := {"id": configuration.id, "nickname": " + ".join(names), "score": world.team_score(), "ticks": roundi(world.model.elapsed * 60.0), "mode": configuration.mode, "difficulty": configuration.difficulty, "sector": configuration.sector, "ships": slots.map(func(p: Dictionary) -> String: return p.ship), "rules": rules, "started_at": started_at, "finished_at": Time.get_datetime_string_from_system(true) + "Z", "replay": {"version": 1, "rules": rules, "status": "failed" if replay_failed else "complete", "chunks": chunk_manifest, "seed": seed_value, "ships": slots.map(func(p: Dictionary) -> String: return p.ship), "difficulty": configuration.difficulty, "sector": configuration.sector}}
	var path := str(configuration.directory).path_join(str(configuration.id) + ".result.json")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		abort("결과 저장 실패")
		return
	file.store_string(JSON.stringify(value))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if not ok or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		abort("결과 보존 실패")
		return
	print("ONLINE_RESULT_READY")
	completed_result = value
	broadcast({"type": "result", "result": value})
	ended = true

func abort(reason: String) -> void:
	broadcast({"type": "error", "message": reason})
	ended = true
	if world != null: world.phase = "aborted"

func _finalize() -> void:
	if world != null: world.dispose()
