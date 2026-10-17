extends Node

signal completed(frames: Array, metadata: Dictionary)
signal failed(reason: String)

var request := HTTPRequest.new()
var base := ""
var run_id := ""
var manifest: Dictionary = {}
var cache: Dictionary = {}
var pending := -1
var wanted := 0
var focus := 0
var last_frame: Array = []
var announced := false

func _ready() -> void:
	add_child(request)
	request.timeout = 15.0
	request.body_size_limit = 1048576
	request.accept_gzip = not OS.has_feature("web")
	request.request_completed.connect(_received)

func load_replay(url: String, id: String, metadata: Dictionary) -> void:
	if metadata.get("status") != "complete" or metadata.get("version") != 1 or not metadata.get("chunks") is Array or metadata.chunks.is_empty() or metadata.chunks.size() > 301:
		failed.emit("지원하지 않거나 불완전한 고스트입니다.")
		return
	var total := 0
	var end := -1.0
	for chunk: Variant in metadata.chunks:
		if not chunk is Dictionary or not chunk.has_all(["sha256", "bytes", "start", "end"]) or int(chunk.bytes) <= 0 or int(chunk.bytes) > 1048576 or float(chunk.start) <= end or float(chunk.end) < float(chunk.start) or float(chunk.end) > 600.01:
			failed.emit("고스트 청크 명세가 손상되었습니다.")
			return
		total += int(chunk.bytes)
		end = float(chunk.end)
	if total > 67108864:
		failed.emit("고스트 크기 초과")
		return
	base = url
	run_id = id
	manifest = metadata
	fetch_chunk(0)

func fetch_chunk(index: int) -> void:
	if pending >= 0 or cache.has(index) or index < 0 or index >= manifest.chunks.size(): return
	pending = index
	var error := request.request(base + "/v1/replays/" + run_id + "/" + str(index) + ".json.gz")
	if error != OK:
		pending = -1
		failed.emit("고스트 연결 실패")

func _received(result: int, status: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	var index := pending
	pending = -1
	if result != HTTPRequest.RESULT_SUCCESS or status != 200 or bytes.size() != int(manifest.chunks[index].bytes):
		failed.emit("고스트 다운로드 실패")
		return
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	if hash.finish().hex_encode() != str(manifest.chunks[index].sha256):
		failed.emit("고스트 해시가 일치하지 않습니다.")
		return
	var raw := bytes.decompress_dynamic(4194304, FileAccess.COMPRESSION_GZIP)
	var value: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not value is Dictionary or value.get("version") != 1 or not value.get("frames") is Array or value.frames.is_empty() or value.frames.size() > 12:
		failed.emit("고스트 형식 오류")
		return
	var tracks: Array = []
	for player in manifest.ships.size(): tracks.append([])
	for entry: Variant in value.frames:
		if not entry is Dictionary or not entry.get("players") is Array or entry.players.size() != tracks.size():
			failed.emit("고스트 플레이어 정보 오류")
			return
		for player in tracks.size():
			if entry.players[player] is Array: GhostReplay.align_online_event_times(entry.players[player])
			tracks[player].append(entry.players[player])
	for track: Array in tracks:
		if not track[0] is Array or track[0].is_empty():
			failed.emit("고스트 상태 검증 실패")
			return
		if not GhostReplay.valid(track, float(track[0][0])) or absf(float(track[0][0]) - float(manifest.chunks[index].start)) > 0.0001 or absf(float(track.back()[0]) - float(manifest.chunks[index].end)) > 0.0001:
			failed.emit("고스트 상태 검증 실패")
			return
	cache[index] = tracks
	for key: Variant in cache.keys():
		if abs(int(key) - wanted) > 1: cache.erase(key)
	if not announced:
		announced = true
		last_frame = tracks[0][0]
		var last := last_frame.duplicate(true)
		last[0] = float(manifest.chunks.back().end)
		completed.emit([last_frame, last], manifest)
	if not cache.has(wanted): fetch_chunk(wanted)
	elif not cache.has(wanted + 1): fetch_chunk(wanted + 1)

func chunk_at(time: float) -> int:
	for i in manifest.chunks.size():
		if time <= float(manifest.chunks[i].end): return i
	return manifest.chunks.size() - 1

func ready_for(time: float) -> bool:
	if manifest.is_empty(): return false
	wanted = chunk_at(time)
	if not cache.has(wanted):
		fetch_chunk(wanted)
		return false
	return true

func sample(time: float) -> Array:
	if not ready_for(time): return last_frame
	var frames: Array = cache[wanted][focus].duplicate()
	if cache.has(wanted + 1): frames.append(cache[wanted + 1][focus][0])
	last_frame = GhostReplay.sample(frames, time)
	fetch_chunk(wanted + 1)
	return last_frame
