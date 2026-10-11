class_name SaveStore
extends RefCounted

const DEFAULTS: Dictionary = {
	"best_score": 0, "best_time": 0.0, "wins": 0, "runs": 0,
	"muted": false, "music": true, "reduced_motion": false,
	"total_kills": 0, "best_level": 0, "unlocked_medals": [],
	"recent_runs": [], "best_by_loadout": {},
	"player_name": "파일럿", "leaderboard": [], "achievement_progress": {}, "achievements": [],
	"cleared_modes": [], "discovered_items": [], "discovered_parts": [], "discovered_hulls": [],
}
const MISSION_IDS: Array[String] = ["first_run", "hunter", "survivor", "elite", "evolved", "victory"]
const SHIP_IDS: Array[String] = ["striker", "scout", "bastion"]
const SECTOR_IDS: Array[String] = ["ring", "storm", "forge"]
const MODE_IDS: Array[String] = ["normal", "relaxed", "veteran", "cataclysm"]
const SAVE_PATH: String = "user://profile/records_v2.json"

var data: Dictionary = DEFAULTS.duplicate(true)
var newly_unlocked: Array[String] = []
var new_achievements: Array[String] = []
var _path: String = SAVE_PATH
var storage_error := ""
var _migration_source := ""


static func mission_info(id: String) -> Dictionary:
	match id:
		"first_run":
			return {"id": id, "name": "첫 출격", "description": "한 번의 출격을 마치세요.", "target": 1}
		"hunter":
			return {"id": id, "name": "궤도 사냥꾼", "description": "누적 100기의 적을 처치하세요.", "target": 100}
		"survivor":
			return {"id": id, "name": "생존 전문가", "description": "한 번의 출격에서 180초 동안 생존하세요.", "target": 180}
		"elite":
			return {"id": id, "name": "정예 격파", "description": "정예 적을 1기 처치하세요.", "target": 1}
		"evolved":
			return {"id": id, "name": "한계 돌파", "description": "무기를 한 번 진화시키세요.", "target": 1}
		"victory":
			return {"id": id, "name": "궤도 수호자", "description": "최종 보스를 격파하고 승리하세요.", "target": 1}
	return {}


func load_data(path: String = SAVE_PATH) -> void:
	_path = path
	data = DEFAULTS.duplicate(true)
	newly_unlocked.clear()
	storage_error = ""
	_migration_source = ""
	if path == SAVE_PATH:
		var old_root := OS.get_data_dir().path_join("Godot/app_userdata/Orbit Breaker · 오빗 브레이커")
		_migrate_profile(path, [old_root.path_join("records_v2.json"), "user://records_v2.json", old_root.path_join("records.json"), "user://records.json"])
	var loaded: Variant = _load_source(path if storage_error.is_empty() else _migration_source)
	if loaded is Dictionary:
		data = _validated(loaded)
		_award_achievements()
	new_achievements.clear()


func save_data() -> bool:
	if not storage_error.is_empty():
		return false
	if _path == SAVE_PATH and DirAccess.make_dir_recursive_absolute(_path.get_base_dir()) != OK:
		return false
	var cleaned: Dictionary = _validated(data)
	var temporary: String = _path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(cleaned, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK or _read_json(temporary) == null:
		return false
	# A malformed primary must never overwrite the last recoverable backup.
	if _read_json(_path) != null:
		if DirAccess.copy_absolute(_path, _path + ".bak") != OK:
			return false
	if DirAccess.rename_absolute(temporary, _path) != OK:
		return false
	data = cleaned
	return true

func _migrate_profile(destination: String, sources: Array[String]) -> bool:
	if FileAccess.file_exists(destination) or FileAccess.file_exists(destination + ".bak"):
		return true
	for source: String in sources:
		if not FileAccess.file_exists(source) and not FileAccess.file_exists(source + ".bak"):
			continue
		_migration_source = source
		var loaded: Variant = _load_source(source)
		if loaded == null:
			storage_error = "기존 기록 손상 · 원본을 보존했습니다"
			return false
		if DirAccess.make_dir_recursive_absolute(destination.get_base_dir()) != OK or not DirAccess.dir_exists_absolute(destination.get_base_dir()):
			storage_error = "프로필 폴더 생성 실패 · 원본을 보존했습니다"
			return false
		# Commit records after verified ghost copies, so a failed import stays retryable.
		for metadata: Variant in [loaded, _read_json(source + ".bak")]:
			if not metadata is Dictionary or not metadata.get("leaderboard") is Array:
				continue
			for entry: Variant in metadata.leaderboard:
				if not entry is Dictionary:
					continue
				var id := _ghost_id(entry.get("ghost"))
				var old_ghost := source + ".ghost-" + id + ".json"
				var new_ghost := destination + ".ghost-" + id + ".json"
				if not id.is_empty() and FileAccess.file_exists(old_ghost):
					if DirAccess.copy_absolute(old_ghost, new_ghost) != OK or FileAccess.get_sha256(old_ghost) != FileAccess.get_sha256(new_ghost):
						storage_error = "고스트 복사 실패 · 원본을 보존했습니다"
						return false
		var primary := source if _read_json(source) != null else source + ".bak"
		for suffix: String in [".bak", ""]:
			var origin := source + ".bak" if suffix == ".bak" and _read_json(source + ".bak") != null else primary
			var temporary := destination + suffix + ".tmp"
			if DirAccess.copy_absolute(origin, temporary) != OK or FileAccess.get_sha256(origin) != FileAccess.get_sha256(temporary) or DirAccess.rename_absolute(temporary, destination + suffix) != OK:
				storage_error = "기록 복사 실패 · 원본을 보존했습니다"
				return false
		return true
	return true


func record_run(score: int, time: float, won: bool, details: Dictionary = {}) -> bool:
	data = _validated(data)
	var before := data.duplicate(true)
	newly_unlocked.clear()
	new_achievements.clear()
	var entry: Dictionary = _run_entry(score, time, won, details)
	entry.name = clean_name(details.get("name", data.player_name))
	data["best_score"] = maxi(int(data["best_score"]), int(entry["score"]))
	data["best_time"] = maxf(float(data["best_time"]), float(entry["time"]))
	data["runs"] = mini(int(data["runs"]) + 1, 1_000_000_000)
	if won:
		data["wins"] = mini(int(data["wins"]) + 1, int(data["runs"]))
	data["total_kills"] = mini(int(data["total_kills"]) + int(entry["kills"]), 1_000_000_000)
	data["best_level"] = maxi(int(data["best_level"]), int(entry["level"]))
	data["recent_runs"].push_front(entry)
	if data["recent_runs"].size() > 8:
		data["recent_runs"].resize(8)
	var loadout_key: String = "%s|%s|%s" % [entry["ship"], entry["sector"], entry["mode"]]
	data["best_by_loadout"][loadout_key] = maxi(int(data["best_by_loadout"].get(loadout_key, 0)), int(entry["score"]))
	var completed: Dictionary = {
		"first_run": true, "hunter": int(data["total_kills"]) >= 100,
		"survivor": float(data["best_time"]) >= 180.0,
		"elite": _integer(details.get("elites")) >= 1,
		"evolved": not entry["evolutions"].is_empty(), "victory": won,
	}
	for id: String in MISSION_IDS:
		if completed[id] and not id in data["unlocked_medals"]:
			data["unlocked_medals"].append(id)
			newly_unlocked.append(id)
	if won and not entry.mode in data.cleared_modes:
		data.cleared_modes.append(entry.mode)
	var progress: Dictionary = data.achievement_progress
	for key: String in ["dashes", "overdrives", "returns", "elites"]:
		progress[key] = mini(int(progress.get(key, 0)) + _integer(details.get(key)), 1_000_000_000)
	progress.combo = maxi(int(progress.get("combo", 0)), _integer(details.get("combo")))
	if won:
		for key: String in ["ship_" + str(entry.ship), "sector_" + str(entry.sector), str(entry.mode)]:
			progress[key] = 1
	if not entry.evolutions.is_empty():
		progress.evolved = 1
	var upgrades: Variant = details.get("upgrades", {})
	if upgrades is Dictionary and time >= 180.0:
		for key: String in ["blade", "frost", "missile", "chain"]:
			if _integer(upgrades.get(key)) >= 3:
				progress[key] = 1
	_award_achievements()
	# Keep one personal best per name and difficulty, ten names per difficulty.
	var previous: Array = data.leaderboard.duplicate(true)
	var better := true
	for old: Dictionary in previous:
		if old.name == entry.name and old.mode == entry.mode:
			better = _rank_before(entry, old)
	if better:
		data.leaderboard = data.leaderboard.filter(func(old: Dictionary) -> bool: return old.name != entry.name or old.mode != entry.mode)
		data.leaderboard.append(entry.duplicate(true))
		data.leaderboard = _ranked(data.leaderboard)
		for ranked: Dictionary in data.leaderboard:
			if ranked.name == entry.name and ranked.mode == entry.mode:
				var frames: Variant = details.get("ghost_frames")
				if frames is Array and not frames.is_empty():
					var id := Crypto.new().generate_random_bytes(16).hex_encode()
					if GhostReplay.write(ghost_path(id), frames):
						ranked.ghost = id
	if not save_data():
		data = before
		newly_unlocked.clear()
		new_achievements.clear()
		_prune_ghosts()
		return false
	_prune_ghosts()
	return true


func attach_ghost(entry: Dictionary, id: String) -> bool:
	var linked := false
	for ranked: Dictionary in data.leaderboard:
		if ranked.name == entry.name and ranked.mode == entry.mode and ranked.score == entry.score and ranked.time == entry.time:
			var previous: String = ranked.ghost
			ranked.ghost = id
			if not save_data():
				ranked.ghost = previous
				return false
			linked = true
			break
	if linked:
		_prune_ghosts()
	return linked

func ghost_candidate(score: int, time: float, name: String, difficulty: String) -> Dictionary:
	for entry: Dictionary in data.leaderboard:
		if entry.name == name and entry.mode == difficulty and entry.score == score and is_equal_approx(float(entry.time), time):
			return entry.duplicate(true)
	return {}

func _load_source(path: String, legacy_path: String = "") -> Variant:
	var loaded: Variant = _read_json(path)
	if loaded == null:
		loaded = _read_json(path + ".bak")
	# Import only on first use; corrupt v2 files must not silently roll back to v1.
	if loaded != null or legacy_path.is_empty() or FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
		return loaded
	loaded = _read_json(legacy_path)
	return loaded if loaded != null else _read_json(legacy_path + ".bak")


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 65_536:
		return null
	var parser: JSON = JSON.new()
	var result: Error = parser.parse(file.get_as_text())
	file.close()
	if result != OK or not parser.data is Dictionary:
		return null
	return parser.data


func _validated(source: Dictionary) -> Dictionary:
	var result: Dictionary = DEFAULTS.duplicate(true)
	for pair: Array in [["discovered_parts", Expedition.PART_IDS], ["discovered_hulls", Expedition.RECIPE_IDS]]:
		var known: Variant = source.get(pair[0])
		if known is Array:
			for id: String in pair[1]:
				if id in known:
					result[pair[0]].append(id)
	result.player_name = clean_name(source.get("player_name"))
	var discovered: Variant = source.get("discovered_items")
	if discovered is Array:
		for id: String in ItemCatalog.IDS:
			if id in discovered:
				result.discovered_items.append(id)
	var progress: Variant = source.get("achievement_progress")
	var achievements: Variant = source.get("achievements")
	for item: Dictionary in Achievements.catalog():
		if progress is Dictionary:
			result.achievement_progress[item.stat] = _integer(progress.get(item.stat))
		if achievements is Array and item.id in achievements:
			result.achievements.append(item.id)
	var cleared: Variant = source.get("cleared_modes")
	if cleared is Array:
		for mode: String in MODE_IDS:
			if mode in cleared:
				result.cleared_modes.append(mode)
	for key: String in ["best_score", "runs", "wins", "total_kills"]:
		result[key] = _integer(source.get(key))
	result["best_level"] = _integer(source.get("best_level"), 1000)
	result["best_time"] = _duration(source.get("best_time"))
	for key: String in ["muted", "music", "reduced_motion"]:
		if source.get(key) is bool:
			result[key] = source[key]
	result["wins"] = mini(int(result["wins"]), int(result["runs"]))
	var medals: Variant = source.get("unlocked_medals")
	if medals is Array:
		for i: int in range(mini(medals.size(), 64)):
			var id: Variant = medals[i]
			if id is String and id in MISSION_IDS and not id in result["unlocked_medals"]:
				result["unlocked_medals"].append(id)
	var inferred: Dictionary = {
		"first_run": int(result["runs"]) > 0, "victory": int(result["wins"]) > 0,
		"survivor": float(result["best_time"]) >= 180.0, "hunter": int(result["total_kills"]) >= 100,
	}
	for id: String in inferred:
		if inferred[id] and not id in result["unlocked_medals"]:
			result["unlocked_medals"].append(id)
	var history: Variant = source.get("recent_runs")
	if history is Array:
		for i: int in range(mini(history.size(), 8)):
			var entry: Variant = history[i]
			if not entry is Dictionary or not _is_number(entry.get("score")) or not _is_number(entry.get("time")) or not entry.get("won") is bool:
				continue
			if not entry.get("ship") is String or not entry.get("sector") is String or not entry.get("mode") is String:
				continue
			if not entry.get("ship") in SHIP_IDS or not entry.get("sector") in SECTOR_IDS or not entry.get("mode") in MODE_IDS:
				continue
			result["recent_runs"].append(_run_entry(_integer(entry["score"]), _duration(entry["time"]), entry["won"], entry))
			if entry.won and not entry.mode in result.cleared_modes:
				result.cleared_modes.append(entry.mode)
	var ranking: Variant = source.get("leaderboard")
	if ranking is Array:
		for entry: Variant in ranking.slice(0, 40):
			if entry is Dictionary and entry.get("mode") in MODE_IDS and _is_number(entry.get("score")) and _is_number(entry.get("time")) and entry.get("won") is bool:
				result.leaderboard.append(_run_entry(_integer(entry.score), _duration(entry.time), entry.won, entry))
		result.leaderboard = _ranked(result.leaderboard)
	var best: Variant = source.get("best_by_loadout")
	if best is Dictionary:
		for ship: String in SHIP_IDS:
			for sector: String in SECTOR_IDS:
				for mode: String in MODE_IDS:
					var key: String = "%s|%s|%s" % [ship, sector, mode]
					if _is_number(best.get(key)):
						result["best_by_loadout"][key] = _integer(best[key])
	return result


func _run_entry(score: int, time: float, won: bool, details: Dictionary) -> Dictionary:
	return {
		"name": clean_name(details.get("name", data.player_name)),
		"ghost": _ghost_id(details.get("ghost")), "rules": "3.1",
		"score": clampi(score, 0, 1_000_000_000), "time": _duration(time), "won": won,
		"ship": details.get("ship") if details.get("ship") is String and details.get("ship") in SHIP_IDS else "striker",
		"sector": details.get("sector") if details.get("sector") is String and details.get("sector") in SECTOR_IDS else "ring",
		"mode": details.get("mode") if details.get("mode") is String and details.get("mode") in MODE_IDS else "normal",
		"kills": _integer(details.get("kills")), "level": maxi(_integer(details.get("level"), 1000), 1),
		"evolutions": _evolutions(details.get("evolutions")),
	}


func _evolutions(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for i: int in range(mini(value.size(), 64)):
			var id: Variant = value[i]
			if id is String and not id.is_empty() and id.length() <= 48 and id.is_valid_identifier() and not id in result:
				result.append(id)
				if result.size() == GameContent.EVOLUTION_IDS.size():
					break
	return result


func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _integer(value: Variant, maximum: int = 1_000_000_000) -> int:
	return int(clampf(float(value), 0.0, float(maximum))) if _is_number(value) else 0


func _duration(value: Variant) -> float:
	return clampf(float(value), 0.0, 86_400.0) if _is_number(value) else 0.0

static func clean_name(value: Variant) -> String:
	if not value is String:
		return "파일럿"
	var result := ""
	for character: String in value:
		var code := character.unicode_at(0)
		if code >= 32 and code != 127 and not (code >= 0x200b and code <= 0x200f) and not (code >= 0x202a and code <= 0x202e) and not (code >= 0x2060 and code <= 0x206f):
			result += character
	result = result.strip_edges().left(16)
	return result if not result.is_empty() else "파일럿"

func available_modes() -> Array[String]:
	var result: Array[String] = ["normal", "relaxed"]
	if "normal" in data.cleared_modes:
		result.append("veteran")
	if "veteran" in data.cleared_modes:
		result.append("cataclysm")
	return result

func _award_achievements() -> void:
	var progress: Dictionary = data.achievement_progress
	for pair: Array in [["runs", "runs"], ["kills", "total_kills"], ["wins", "wins"], ["time", "best_time"]]:
		progress[pair[0]] = int(data[pair[1]])
	if "evolved" in data.unlocked_medals:
		progress.evolved = 1
	for item: Dictionary in Achievements.catalog():
		if int(progress.get(item.stat, 0)) >= int(item.target) and not item.id in data.achievements:
			data.achievements.append(item.id)
			new_achievements.append(item.id)

static func _rank_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a.score) != int(b.score):
		return int(a.score) > int(b.score)
	if float(a.time) != float(b.time):
		return float(a.time) > float(b.time)
	return str(a.name) < str(b.name)

func _ranked(entries: Array) -> Array:
	entries.sort_custom(_rank_before)
	var result: Array = []
	var seen := {}
	var counts := {}
	for entry: Dictionary in entries:
		var key: String = str(entry.name) + "|" + str(entry.mode)
		if not seen.has(key) and int(counts.get(entry.mode, 0)) < 10:
			result.append(entry)
			seen[key] = true
			counts[entry.mode] = int(counts.get(entry.mode, 0)) + 1
	return result

func _ghost_id(value: Variant) -> String:
	if not value is String or value.length() != 32 or not value.is_valid_hex_number(false):
		return ""
	return value.to_lower()

func ghost_path(id: String) -> String:
	return (_path if storage_error.is_empty() else _migration_source) + ".ghost-" + _ghost_id(id) + ".json"

func record_live_achievements(details: Dictionary) -> bool:
	var before: Array = data.achievements.duplicate()
	var progress: Dictionary = data.achievement_progress.duplicate()
	progress.kills = int(data.total_kills) + _integer(details.get("kills"))
	progress.time = maxi(int(data.best_time), int(details.get("elapsed", 0)))
	progress.combo = maxi(int(progress.get("combo", 0)), _integer(details.get("combo")))
	for key: String in ["dashes", "overdrives", "returns", "elites"]:
		progress[key] = int(progress.get(key, 0)) + _integer(details.get(key))
	if not _evolutions(details.get("evolutions")).is_empty():
		progress.evolved = 1
	if float(details.get("elapsed", 0)) >= 180.0 and details.get("upgrades") is Dictionary:
		for key: String in ["blade", "frost", "missile", "chain"]:
			if _integer(details.upgrades.get(key)) >= 3:
				progress[key] = 1
	for item: Dictionary in Achievements.catalog():
		if int(progress.get(item.stat, 0)) >= int(item.target) and not item.id in data.achievements:
			data.achievements.append(item.id)
	if data.achievements == before or save_data():
		return true
	data.achievements = before
	return false

func load_ghost(entry: Dictionary) -> Array:
	var id := _ghost_id(entry.get("ghost"))
	return GhostReplay.read(ghost_path(id)) if not id.is_empty() and FileAccess.file_exists(ghost_path(id)) else []

func _prune_ghosts() -> void:
	var keep: Array = []
	for source: Variant in [data, _read_json(_path + ".bak")]:
		if source is Dictionary and source.get("leaderboard") is Array:
			for entry: Variant in source.leaderboard:
				if entry is Dictionary:
					keep.append(ghost_path(_ghost_id(entry.get("ghost"))).get_file())
	var directory := DirAccess.open(_path.get_base_dir())
	if directory == null:
		return
	var prefix := _path.get_file() + ".ghost-"
	for filename: String in directory.get_files():
		if filename.begins_with(prefix) and filename.ends_with(".json") and not filename in keep:
			var id := filename.trim_prefix(prefix).trim_suffix(".json")
			if not _ghost_id(id).is_empty():
				directory.remove(filename)

func record_items(pickups: Array[Dictionary]) -> bool:
	var before := data.duplicate(true)
	var previous_notices := new_achievements.duplicate()
	for pickup: Dictionary in pickups:
		if not pickup.get("id") in ItemCatalog.IDS or not pickup.get("grade") in ItemCatalog.GRADES:
			continue
		if not pickup.id in data.discovered_items:
			data.discovered_items.append(pickup.id)
		var progress: Dictionary = data.achievement_progress
		progress.items = mini(int(progress.get("items", 0)) + 1, 1_000_000_000)
		if pickup.grade == "A":
			progress.items_a = mini(int(progress.get("items_a", 0)) + 1, 1_000_000_000)
		if pickup.get("risky") == true:
			progress.items_risky = mini(int(progress.get("items_risky", 0)) + 1, 1_000_000_000)
	data.achievement_progress.item_types = data.discovered_items.size()
	_award_achievements()
	if save_data():
		return true
	data = before
	new_achievements = previous_notices
	return false

func record_tech(pickups: Array[Dictionary]) -> bool:
	var before := data.duplicate(true)
	var previous_notices := new_achievements.duplicate()
	var progress: Dictionary = data.achievement_progress
	for pickup: Dictionary in pickups:
		var id: String = str(pickup.get("id", ""))
		match pickup.get("kind"):
			"mission":
				if id in Expedition.MISSION_IDS:
					progress.missions = mini(int(progress.get("missions", 0)) + 1, 1_000_000_000)
			"part":
				if id in Expedition.PART_IDS:
					if not id in data.discovered_parts:
						data.discovered_parts.append(id)
					progress.parts = mini(int(progress.get("parts", 0)) + 1, 1_000_000_000)
			"hull":
				if id in Expedition.RECIPE_IDS:
					if not id in data.discovered_hulls:
						data.discovered_hulls.append(id)
					progress["hull_" + id] = 1
	progress.part_types = data.discovered_parts.size()
	_award_achievements()
	if save_data():
		return true
	data = before
	new_achievements = previous_notices
	return false
