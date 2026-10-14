class_name GhostReplay
extends RefCounted

const VERSION := 2
const MAGIC := "OBG2"
const STREAM_MAGIC := "OBC3"
const MAX_FILE_BYTES := 32_000_000
const MAX_JSON_BYTES := 256_000_000
# Visual snapshots survive later changes to combat simulation and support direct seeking.
const COLLECTIONS := {
	"enemies": [["kind", "chaser"], ["pos", Vector2.ZERO], ["radius", 13.0], ["hp", 0.0], ["max_hp", 1.0], ["angle", 0.0], ["warn", 0.0], ["flash", 0.0], ["slow_time", 0.0], ["stun_time", 0.0], ["phase", 1], ["flanker", false], ["spawn_layer", 0], ["elite_index", 1]],
	"shots": [["pos", Vector2.ZERO], ["velocity", Vector2.ZERO], ["radius", 5.0], ["friendly", true], ["kind", ""], ["damage", 0.0], ["ttl", 0.0]],
	"gems": [["pos", Vector2.ZERO], ["value", 1.0], ["kind", "xp"]],
	"items": [["pos", Vector2.ZERO], ["id", "heal"], ["grade", "C"], ["ttl", 0.0]],
	"effects": [["pos", Vector2.ZERO], ["kind", "hit"], ["radius", 1.0], ["ttl", 0.0], ["max_ttl", 1.0], ["end", Vector2.ZERO]],
	"hazards": [["kind", "blast"], ["pos", Vector2.ZERO], ["rect", Rect2()], ["radius", 1.0], ["warn", 0.0], ["ttl", 0.0], ["active", false], ["hold", 0.0]],
}
const LIMITS := {"enemies": 240, "shots": 240, "gems": 300, "items": 12, "effects": 180, "hazards": 6}
const SCALARS := [["max_hp", 100.0], ["level", 1], ["xp", 0.0], ["xp_needed", 9.0], ["kills", 0], ["dash_cooldown", 0.0], ["dash_recharge_total", 3.0], ["overdrive_meter", 0.0], ["overdrive_time", 0.0], ["focus_time", 0.0], ["slipstream_time", 0.0], ["guard_cooldown", 0.0], ["boundary_time", 0.0], ["guard_stacks", 1], ["axe_catches", 0]]
var _serial := 0
var _tracked: Dictionary = {}
var _events: Array = []
const MAX_FRAMES := 3002
var frames: Array = []
var _save_file: FileAccess
var _save_frames: Array = []
var _save_cursor := 0
var _save_path := ""
var _save_first: Array = []
var _save_previous := -1.0
var _save_json_bytes := 0
var save_ok := false
var _save_thread: Thread
var _background := false
var _discarding := false

func begin_discard(value: Array) -> void:
	_save_frames = value
	_discarding = true

func start_background() -> void:
	if OS.has_feature("web"):
		return
	_save_thread = Thread.new()
	_background = true
	if _save_thread.start(_write_all) != OK:
		_save_thread = null
		_background = false

func _write_all() -> void:
	while not write_slice():
		pass

func poll_write() -> bool:
	if _save_thread == null:
		return write_slice()
	if _save_thread.is_alive():
		return false
	_save_thread.wait_to_finish()
	_save_thread = null
	if save_ok:
		save_ok = DirAccess.rename_absolute(_save_path + ".tmp", _save_path) == OK
	return true

# Bounded chunks keep serialization, compression and object release off the terminal frame.
func begin_write(path: String, value: Array) -> bool:
	if value.is_empty() or value.size() > MAX_FRAMES or not valid([value[0]]):
		return false
	_save_file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if _save_file == null:
		return false
	_save_file.store_buffer(STREAM_MAGIC.to_ascii_buffer())
	_save_frames = value
	_save_first = value[0]
	_save_path = path
	_save_cursor = 0
	_save_previous = -1.0
	_save_json_bytes = 0
	save_ok = false
	return true

func write_slice(budget_us: int = 2000) -> bool:
	if _save_file == null and not _discarding:
		return true
	var started := Time.get_ticks_usec()
	if _discarding:
		while _save_cursor < _save_frames.size():
			_save_frames[_save_cursor] = null
			_save_cursor += 1
			if Time.get_ticks_usec() - started >= budget_us:
				return false
		_save_frames = []
		return true
	while _save_cursor < _save_frames.size():
		var end := mini(_save_cursor + (1 if OS.has_feature("web") else 4), _save_frames.size())
		var chunk := _save_frames.slice(_save_cursor, end)
		if not valid(chunk, float(chunk[0][0]), _save_previous):
			_abort_write()
			return true
		if chunk[0].size() == 14:
			for event: Array in chunk[0][13].events:
				if float(event[0]) < _save_previous:
					_abort_write()
					return true
		var raw := JSON.stringify(chunk).to_utf8_buffer()
		_save_json_bytes += raw.size()
		if _save_json_bytes > MAX_JSON_BYTES or raw.size() > 2_000_000:
			_abort_write()
			return true
		var bytes := raw.compress(FileAccess.COMPRESSION_GZIP)
		if _save_file.get_position() + bytes.size() + 8 > MAX_FILE_BYTES:
			_abort_write()
			return true
		_save_file.store_32(bytes.size())
		_save_file.store_buffer(bytes)
		_save_previous = float(chunk.back()[0])
		for i in range(_save_cursor, end):
			_save_frames[i] = null
		_save_cursor = end
		if _save_file.get_error() != OK:
			_abort_write()
			return true
		if Time.get_ticks_usec() - started >= budget_us:
			return false
	_save_file.store_32(0)
	_save_file.flush()
	var error := _save_file.get_error()
	_save_file.close()
	_save_file = null
	save_ok = error == OK and (_background or DirAccess.rename_absolute(_save_path + ".tmp", _save_path) == OK)
	_save_frames = []
	_save_first = []
	if not save_ok:
		DirAccess.remove_absolute(_save_path + ".tmp")
	return true

func cancel_write() -> void:
	if _save_thread != null:
		_save_thread.wait_to_finish()
		_save_thread = null
	_abort_write()

func _abort_write() -> void:
	if _save_file != null:
		_save_file.close()
	_save_file = null
	if not _save_path.is_empty():
		DirAccess.remove_absolute(_save_path + ".tmp")
	_save_frames = []
	_save_first = []
	save_ok = false

func capture(run: RunModel, force: bool = false) -> void:
	if not frames.is_empty() and run.elapsed < float(frames.back()[0]):
		return
	_track(run)
	if not frames.is_empty() and not force and run.elapsed - float(frames.back()[0]) < 0.2:
		return
	var frame := [snappedf(run.elapsed, 0.0001), snappedf(run.player.x, 0.01), snappedf(run.player.y, 0.01), run.facing.angle(), snappedf(run.hp, 0.01), run.ranked_score(), run.orbit_count, run.orbit_radius, run.orbit_angle, int(run.dash_time > 0), int(run.overdrive_time > 0), int(run.upgrades.get("blade", 0)), int(run.upgrades.get("frost", 0)), _world(run)]
	if force and not frames.is_empty() and float(frames.back()[0]) == float(frame[0]):
		frame[13].events = frames.back()[13].events + frame[13].events
		frames[frames.size() - 1] = frame
	elif frames.size() < MAX_FRAMES:
		frames.append(frame)
	_events = []

static func valid(value: Variant, first_time: float = 0.0, previous_time: float = -1.0) -> bool:
	if not value is Array or value.is_empty() or value.size() > MAX_FRAMES:
		return false
	var last := previous_time
	var width := 0
	for frame: Variant in value:
		if not frame is Array or not frame.size() in [13, 14] or (width != 0 and frame.size() != width):
			return false
		width = frame.size()
		for number: Variant in frame.slice(0, 13):
			if not (number is int or number is float) or not is_finite(float(number)):
				return false
		if width == 14:
			if not _valid_world(frame[13]):
				return false
			var event_time := last
			for event: Array in frame[13].events:
				if float(event[0]) < event_time or float(event[0]) > float(frame[0]):
					return false
				event_time = float(event[0])
		if float(frame[0]) <= last or float(frame[0]) > 600.01 or absf(float(frame[1])) > 10000 or absf(float(frame[2])) > 10000 or float(frame[6]) < 1 or float(frame[6]) > 12 or float(frame[7]) < 0 or float(frame[7]) > 200:
			return false
		last = float(frame[0])
	return float(value[0][0]) == first_time

static func write(path: String, value: Array) -> bool:
	if not valid(value):
		return false
	var version := VERSION if value[0].size() == 14 else 1
	var bytes := JSON.stringify({"version": version, "frames": value}).to_utf8_buffer()
	if bytes.size() > MAX_JSON_BYTES:
		return false
	if version == VERSION:
		bytes = MAGIC.to_ascii_buffer() + bytes.compress(FileAccess.COMPRESSION_GZIP)
	if bytes.size() > MAX_FILE_BYTES:
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and DirAccess.rename_absolute(path + ".tmp", path) == OK

static func read(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES:
		return []
	if file.get_length() >= 4 and file.get_buffer(4).get_string_from_ascii() == STREAM_MAGIC:
		return _read_stream(file)
	file.seek(0)
	var bytes := file.get_buffer(file.get_length())
	var compressed := bytes.size() >= 4 and bytes.slice(0, 4).get_string_from_ascii() == MAGIC
	if compressed:
		bytes = bytes.slice(4).decompress_dynamic(MAX_JSON_BYTES, FileAccess.COMPRESSION_GZIP)
	elif bytes.size() > 2_000_000:
		return []
	if bytes.is_empty():
		return []
	var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not value is Dictionary or not _number(value.get("version")) or (value.get("version") != 1 and value.get("version") != VERSION) or not valid(value.get("frames")):
		return []
	var expected_width := 14 if value.version == VERSION else 13
	if value.frames[0].size() != expected_width or compressed != (value.version == VERSION):
		return []
	return value.frames

static func _read_stream(file: FileAccess) -> Array:
	var result: Array = []
	var total := 0
	while file.get_position() + 4 <= file.get_length():
		var size := file.get_32()
		if size == 0:
			return result if file.get_position() == file.get_length() and valid(result) else []
		if size > MAX_FILE_BYTES or file.get_position() + size > file.get_length():
			return []
		if total >= MAX_JSON_BYTES:
			return []
		var bytes := file.get_buffer(size).decompress_dynamic(mini(2_000_000, MAX_JSON_BYTES - total), FileAccess.COMPRESSION_GZIP)
		total += bytes.size()
		if bytes.is_empty() or total > MAX_JSON_BYTES:
			return []
		var chunk: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if not chunk is Array or chunk.is_empty() or chunk.size() > 4 or result.size() + chunk.size() > MAX_FRAMES:
			return []
		result.append_array(chunk)
	return []

static func _frame_index(value: Array, time: float) -> int:
	var low := 0
	var high := value.size() - 1
	while low < high:
		var middle := (low + high + 1) / 2
		if float(value[middle][0]) <= time:
			low = middle
		else:
			high = middle - 1
	return low

static func sample_position(value: Array, time: float) -> Vector2:
	var index := _frame_index(value, time)
	var a: Array = value[index]
	var b: Array = value[mini(index + 1, value.size() - 1)]
	var weight := clampf((time - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])), 0.0, 1.0)
	return Vector2(a[1], a[2]).lerp(Vector2(b[1], b[2]), weight)

static func sample(value: Array, time: float) -> Array:
	var low := _frame_index(value, time)
	var a: Array = value[low]
	var b: Array = value[mini(low + 1, value.size() - 1)]
	var result := a.duplicate()
	var weight := clampf((time - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])), 0.0, 1.0)
	for index: int in [1, 2, 4]:
		result[index] = lerpf(float(a[index]), float(b[index]), weight)
	for index: int in [3, 8]:
		result[index] = lerp_angle(float(a[index]), float(b[index]), weight)
	if result.size() == 14:
		result[13] = _interpolate_world(a[13], b[13], weight, float(a[0]), float(b[0]), time)
	return result

func _world(run: RunModel) -> Dictionary:
	var result := {"values": [], "buffs": [], "upgrades": [], "evolutions": run.evolutions.duplicate(), "events": _events, "expedition": run.expedition_snapshot()}
	for spec: Array in SCALARS:
		result.values.append(_pack(run.get(spec[0])))
	for id: String in ItemCatalog.IDS:
		if run.buffs.has(id):
			var buff: Dictionary = run.buffs[id]
			result.buffs.append([id, buff.value, buff.ttl, buff.grade])
	for id: String in RunModel.UPGRADE_IDS:
		result.upgrades.append(int(run.upgrades.get(id, 0)))
	for key: String in COLLECTIONS:
		var rows: Array = []
		for entity: Dictionary in run.get(key):
			rows.append(_row(key, entity))
		result[key] = rows
	var statuses: Array = []
	for i in run.enemies.size():
		var enemy: Dictionary = run.enemies[i]
		if float(enemy.get("weakpoint", 0.0)) <= 0.0 and float(enemy.get("env_vulnerable", 0.0)) <= 0.0 and not bool(enemy.get("final_commander", false)): continue
		statuses.append([result.enemies[i][0], float(enemy.get("weakpoint", 0.0)), float(enemy.get("env_vulnerable", 0.0)), bool(enemy.get("final_commander", false)), float(enemy.get("relay_max", 0.0)), enemy.get("relays", []).duplicate(), _pack(enemy.get("relay_axis", Vector2.RIGHT))])
	result.combat = {"schema": 1, "branch": run.branch_id, "finale": run.finale_status, "finale_time": run.finale_success_at, "selected": run.finale_selected, "offered": run.finale_offered, "statuses": statuses}
	return result

static func _pack(value: Variant) -> Variant:
	if value is Vector2:
		return [snappedf(value.x, 0.01), snappedf(value.y, 0.01)]
	if value is Rect2:
		return [value.position.x, value.position.y, value.size.x, value.size.y]
	return snappedf(value, 0.001) if value is float else value

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= 10_000_000.0

static func _matches(value: Variant, example: Variant) -> bool:
	if example is Vector2 or example is Rect2:
		if not value is Array or value.size() != (2 if example is Vector2 else 4):
			return false
		for number: Variant in value:
			if not _number(number):
				return false
		return true
	if example is bool:
		return value is bool
	if example is String:
		return value is String and value.length() <= 32
	return _number(value)

static func _valid_world(value: Variant) -> bool:
	if value is Dictionary and value.has("combat") and not _valid_combat(value.combat): return false
	if not value is Dictionary or value.size() != COLLECTIONS.size() + ((6 if value.has("expedition") else 5) + (1 if value.has("combat") else 0)):
		return false
	if value.has("expedition") and not Expedition.valid_snapshot(value.expedition):
		return false
	if not value.get("values") is Array or not value.values.size() in [13, SCALARS.size()]:
		return false
	for i: int in range(value.values.size()):
		if not _matches(value.values[i], SCALARS[i][1]):
			return false
	if value.values.size() == SCALARS.size() and (float(value.values[13]) < 0 or float(value.values[13]) > 7 or float(value.values[14]) < 0 or float(value.values[14]) > 8):
		return false
	if float(value.values[0]) <= 0.0 or float(value.values[6]) <= 0.0:
		return false
	if not value.get("upgrades") is Array or not value.upgrades.size() in [14, RunModel.UPGRADE_IDS.size()]:
		return false
	for rank: Variant in value.upgrades:
		if not _number(rank) or float(rank) < 0.0 or float(rank) > 5.0:
			return false
	if not value.get("evolutions") is Array or value.evolutions.size() > GameContent.EVOLUTION_IDS.size():
		return false
	for id: Variant in value.evolutions:
		if not id is String or not id in GameContent.EVOLUTION_IDS:
			return false
	if not value.get("buffs") is Array or value.buffs.size() > ItemCatalog.IDS.size():
		return false
	var buffs_seen := {}
	for buff: Variant in value.buffs:
		if not buff is Array or buff.size() != 4 or not buff[0] is String or not buff[0] in ItemCatalog.IDS or buffs_seen.has(buff[0]) or not _number(buff[1]) or not _number(buff[2]) or not buff[3] in ItemCatalog.GRADES:
			return false
		buffs_seen[buff[0]] = true
	if not value.get("events") is Array or value.events.size() > 24_000:
		return false
	for event: Variant in value.events:
		if not event is Array or event.size() != 4 or not _number(event[0]) or float(event[0]) < 0.0 or float(event[0]) > 600.01 or not event[1] in COLLECTIONS or not event[2] is bool or not _valid_row(str(event[1]), event[3]):
			return false
	for key: String in COLLECTIONS:
		if not value.get(key) is Array or value[key].size() > int(LIMITS[key]):
			return false
		var seen := {}
		for row: Variant in value[key]:
			if not _valid_row(key, row) or seen.has(row[0]):
				return false
			seen[row[0]] = true
	return true

static func _interpolate_world(a: Dictionary, b: Dictionary, weight: float, start: float, end: float, time: float) -> Dictionary:
	var world := a.duplicate()
	if world.has("combat"):
		world.combat = a.combat.duplicate(true)
		if weight >= 1.0:
			world.combat = b.get("combat", {}).duplicate(true)
		else:
			for status: Array in world.combat.statuses:
				status[1] = maxf(0.0, float(status[1]) - (time - start))
				status[2] = maxf(0.0, float(status[2]) - (time - start))
	for key: String in COLLECTIONS:
		var next := {}
		for row: Array in b[key]:
			next[row[0]] = row
		var rows: Array = []
		for row: Array in a[key]:
			var copy := row.duplicate()
			if next.has(row[0]):
				var future: Array = next[row[0]]
				for i: int in range(COLLECTIONS[key].size()):
					if COLLECTIONS[key][i][1] is Vector2:
						copy[i + 1] = [lerpf(float(row[i + 1][0]), float(future[i + 1][0]), weight), lerpf(float(row[i + 1][1]), float(future[i + 1][1]), weight)]
			rows.append(copy)
		# Sparse lifecycle events retain objects that appear between regular snapshots.
		for event: Array in b.events:
			if event[1] != key or float(event[0]) <= start:
				continue
			var id: Variant = event[3][0]
			var index := -1
			for i: int in range(rows.size()):
				if rows[i][0] == id:
					index = i
					break
			if bool(event[2]) and float(event[0]) <= time and index < 0:
				rows.append(event[3].duplicate())
			elif not bool(event[2]) and float(event[0]) <= time and index >= 0:
				rows.remove_at(index)
		# A new object's flight begins at its own birth time, never at the prior snapshot.
		for event: Array in b.events:
			if event[1] != key or not bool(event[2]) or float(event[0]) > time or float(event[0]) <= start:
				continue
			var target: Array = next.get(event[3][0], event[3])
			var target_time := end
			for removed: Array in b.events:
				if removed[1] == key and not bool(removed[2]) and removed[3][0] == event[3][0]:
					target = removed[3]
					target_time = float(removed[0])
			for row: Array in rows:
				if row[0] == event[3][0]:
					var local_weight := clampf((time - float(event[0])) / maxf(0.0001, target_time - float(event[0])), 0.0, 1.0)
					for i: int in range(COLLECTIONS[key].size()):
						if COLLECTIONS[key][i][1] is Vector2:
							row[i + 1] = [lerpf(float(event[3][i + 1][0]), float(target[i + 1][0]), local_weight), lerpf(float(event[3][i + 1][1]), float(target[i + 1][1]), local_weight)]
		if rows.size() > int(LIMITS[key]):
			rows.resize(int(LIMITS[key]))
		world[key] = rows
	return world

static func restore(run: RunModel, frame: Array) -> void:
	run.elapsed = float(frame[0])
	run.player = Vector2(frame[1], frame[2])
	run.facing = Vector2.from_angle(float(frame[3]))
	run.hp = float(frame[4])
	run.score = int(frame[5])
	run.orbit_count = int(frame[6])
	run.orbit_radius = float(frame[7])
	run.orbit_angle = float(frame[8])
	run.dash_time = 0.2 if int(frame[9]) > 0 else 0.0
	var world: Dictionary = frame[13]
	run.restore_expedition(world.get("expedition", {}))
	for i: int in range(SCALARS.size()):
		run.set(SCALARS[i][0], world.values[i] if i < world.values.size() else SCALARS[i][1])
	run.upgrades.clear()
	for i: int in range(RunModel.UPGRADE_IDS.size()):
		run.upgrades[RunModel.UPGRADE_IDS[i]] = int(world.upgrades[i]) if i < world.upgrades.size() else 0
	run.evolutions.assign(world.evolutions)
	run.buffs.clear()
	for row: Array in world.buffs:
		run.buffs[row[0]] = {"value": row[1], "ttl": row[2], "grade": row[3]}
	for key: String in COLLECTIONS:
		var entities: Array[Dictionary] = []
		for row: Array in world[key]:
			var entity := {"_replay_id": row[0]}
			for i: int in range(COLLECTIONS[key].size()):
				var value: Variant = row[i + 1] if i + 1 < row.size() else _pack(COLLECTIONS[key][i][1])
				var example: Variant = COLLECTIONS[key][i][1]
				if example is Vector2:
					value = Vector2(value[0], value[1])
				elif example is Rect2:
					value = Rect2(value[0], value[1], value[2], value[3])
				entity[COLLECTIONS[key][i][0]] = value
			entities.append(entity)
		run.set(key, entities)
	_restore_combat(run, world.get("combat", {}))

func _row(key: String, entity: Dictionary) -> Array:
	var row: Array = [entity._replay_id]
	for spec: Array in COLLECTIONS[key]:
		row.append(_pack(entity.get(spec[0], spec[1])))
	return row

func _track(run: RunModel) -> void:
	for key: String in COLLECTIONS:
		if not _tracked.has(key):
			_tracked[key] = {}
		var previous: Dictionary = _tracked[key]
		var present := {}
		for entity: Dictionary in run.get(key):
			if not entity.has("_replay_id"):
				_serial += 1
				entity._replay_id = _serial
			var id: Variant = entity._replay_id
			present[id] = entity
			if not previous.has(id):
				_events.append([snappedf(run.elapsed, 0.0001), key, true, _row(key, entity)])
		for id: Variant in previous:
			if not present.has(id):
				_events.append([snappedf(run.elapsed, 0.0001), key, false, _row(key, previous[id])])
		_tracked[key] = present

static func _valid_row(key: String, row: Variant) -> bool:
	if not row is Array or (row.size() != COLLECTIONS[key].size() + 1 and not (key == "hazards" and row.size() == 8)) or not _number(row[0]) or float(row[0]) <= 0.0:
		return false
	for i: int in range(row.size() - 1):
		if not _matches(row[i + 1], COLLECTIONS[key][i][1]):
			return false
	if key == "enemies" and not row[1] in ["chaser", "runner", "tank", "shooter", "elite", "boss"]:
		return false
	return key != "items" or (row[2] in ItemCatalog.IDS and row[3] in ItemCatalog.GRADES)

static func _valid_combat(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 7 or value.get("schema") != 1: return false
	if not value.get("branch") is String or (value.branch != "" and not value.branch in GameContent.BRANCH_IDS): return false
	if not value.get("finale") is String or not value.finale in ["none", "preview", "declined", "active", "success", "failed"]: return false
	if not _number(value.get("finale_time")) or float(value.finale_time) < -1.0 or float(value.finale_time) >= 600.0: return false
	if value.finale == "success" and float(value.finale_time) < 540.0: return false
	if not value.get("selected") is bool or not value.get("offered") is bool or not value.get("statuses") is Array or value.statuses.size() > 240: return false
	var seen := {}
	for row: Variant in value.statuses:
		if not row is Array or row.size() != 7: return false
		for i: int in [0, 1, 2, 4]:
			if not _number(row[i]) or float(row[i]) < 0.0: return false
		if float(row[0]) <= 0.0 or float(row[0]) != floor(float(row[0])) or seen.has(row[0]) or float(row[1]) > 3.0 or float(row[2]) > 4.0 or not row[3] is bool: return false
		seen[row[0]] = true
		if not row[5] is Array or not row[5].size() in [0, 2] or not row[6] is Array or row[6].size() != 2: return false
		for hp: Variant in row[5]:
			if not _number(hp) or float(hp) < 0.0 or float(hp) > float(row[4]): return false
		for axis: Variant in row[6]:
			if not _number(axis) or absf(float(axis)) > 1.001: return false
		if bool(row[3]) and (row[5].size() != 2 or float(row[4]) <= 0.0): return false
	return true

static func _restore_combat(run: RunModel, value: Dictionary) -> void:
	run.branch_id = str(value.get("branch", ""))
	run.branch_pending = false
	run.finale_status = str(value.get("finale", "none"))
	run.finale_success_at = float(value.get("finale_time", -1.0))
	run.finale_selected = bool(value.get("selected", false))
	run.finale_offered = bool(value.get("offered", false))
	run.finale_boss_id = -1
	var by_id := {}
	for row: Array in value.get("statuses", []): by_id[row[0]] = row
	for enemy: Dictionary in run.enemies:
		var id := int(enemy.get("_replay_id", -1))
		if not by_id.has(id): continue
		var row: Array = by_id[id]
		enemy.weakpoint = float(row[1])
		enemy.env_vulnerable = float(row[2])
		enemy.final_commander = bool(row[3])
		if bool(row[3]):
			enemy.relay_max = float(row[4])
			enemy.relays = row[5].duplicate()
			enemy.relay_axis = Vector2(float(row[6][0]), float(row[6][1]))
