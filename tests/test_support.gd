extends SceneTree

const SaveScript = preload("res://scripts/save_store.gd")
const SoundScript = preload("res://scripts/sound_bank.gd")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_saves()
	_test_progression()
	_test_save_versions()
	await _test_audio()
	print("SUPPORT TESTS: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)


func _write(path: String, contents: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "Test fixture opens")
	if file != null:
		file.store_string(contents)
		file.close()


func _test_saves() -> void:
	# Unique fixtures are retained; this test never modifies actual player records.
	var path: String = "user://test_support_%d_%d.json" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var save = SaveScript.new()
	save.load_data(path)
	_check(save.data == SaveScript.DEFAULTS, "Missing save uses defaults")
	save.data["muted"] = true
	save.data["music"] = false
	save.data["reduced_motion"] = true
	_check(save.record_run(750, 80.5, false), "First run saves")
	var reloaded = SaveScript.new()
	reloaded.load_data(path)
	_check(reloaded.data["best_score"] == 750 and reloaded.data["best_time"] == 80.5, "Score and time round trip")
	_check(reloaded.data["runs"] == 1 and reloaded.data["wins"] == 0, "Loss counts once")
	_check(reloaded.data["muted"] and not reloaded.data["music"] and reloaded.data["reduced_motion"], "Settings round trip")
	_check(save.record_run(1400, 300.0, true), "Existing save can be replaced")
	reloaded.load_data(path)
	_check(reloaded.data["best_score"] == 1400 and reloaded.data["runs"] == 2 and reloaded.data["wins"] == 1, "Win updates records")
	_write(path, "{broken JSON")
	reloaded.load_data(path)
	_check(reloaded.data["best_score"] == 750 and reloaded.data["runs"] == 1, "Malformed primary recovers previous backup")
	_check(reloaded.save_data(), "Recovered save replaces corrupt primary")
	_write(path, "[]")
	reloaded.load_data(path)
	_check(reloaded.data["best_score"] == 750, "Recovery save preserves valid backup")
	var raw: Dictionary = {
		"best_score": -3, "best_time": 999999999.0, "runs": 2.7,
		"wins": 99999999999.0, "muted": "false", "music": 1,
		"reduced_motion": true, "unknown": "ignored",
	}
	_write(path, JSON.stringify(raw))
	reloaded.load_data(path)
	_check(reloaded.data["best_score"] == 0 and reloaded.data["best_time"] == 86400.0, "Numeric values clamp safely")
	_check(reloaded.data["runs"] == 2 and reloaded.data["wins"] == 2, "Counts normalize and wins cannot exceed runs")
	_check(not reloaded.data["muted"] and reloaded.data["music"] and reloaded.data["reduced_motion"], "Wrong setting types do not coerce")
	_check(not reloaded.data.has("unknown"), "Unknown fields are excluded")
	reloaded.data["best_score"] = "999"
	reloaded.data["best_time"] = NAN
	reloaded.data["runs"] = INF
	_check(reloaded.save_data(), "Invalid in-memory fields sanitize before saving")
	_check(reloaded.data["best_score"] == 0 and reloaded.data["best_time"] == 0.0 and reloaded.data["runs"] == 0, "Nonfinite and string numeric values rejected")
	_check(reloaded.record_run(-500, -20.0, false), "Negative inputs save safely")
	_check(reloaded.data["best_score"] == 0 and reloaded.data["best_time"] == 0.0 and reloaded.data["runs"] == 1, "Negative run values clamp")
	var unavailable = SaveScript.new()
	unavailable.load_data(path + "_missing/records.json")
	_check(not unavailable.save_data(), "Unavailable destination returns failure")
	var malformed_path: String = path + ".malformed"
	_write(malformed_path, "null")
	var malformed = SaveScript.new()
	malformed.load_data(malformed_path)
	_check(malformed.data == SaveScript.DEFAULTS, "Malformed save without backup uses defaults")


func _test_progression() -> void:
	var path: String = "user://test_progression_%d_%d.json" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var save = SaveScript.new()
	var independent = SaveScript.new()
	save.data["unlocked_medals"].append("elite")
	save.data["recent_runs"].append({"score": 1})
	save.data["best_by_loadout"]["striker|ring|normal"] = 1
	_check(independent.data["unlocked_medals"].is_empty() and independent.data["recent_runs"].is_empty() and independent.data["best_by_loadout"].is_empty(), "Nested defaults are independent across stores")
	_check(SaveScript.DEFAULTS["unlocked_medals"].is_empty(), "Mutation never changes default collections")
	save.load_data(path)
	var details: Dictionary = {"ship": "scout", "sector": "storm", "mode": "normal", "kills": 60, "level": 5, "elites": 0, "evolutions": [], "overdrives": 2}
	_check(save.record_run(400, 110.0, false, details), "Detailed normal run saves")
	_check(save.newly_unlocked == ["first_run"], "First run announces its medal once")
	_check(save.data["total_kills"] == 60 and save.data["best_level"] == 5, "Detailed run tracks kills and level")
	details["mode"] = "relaxed"
	details["kills"] = 40
	details["level"] = 9
	details["elites"] = 1
	details["evolutions"] = ["pulse_nova", "pulse_nova", 17, {}, "bad value", ""]
	_check(save.record_run(900, 200.0, true, details), "Detailed relaxed win saves")
	_check(save.data["unlocked_medals"].size() == 6 and save.newly_unlocked == ["hunter", "survivor", "elite", "evolved", "victory"], "All six goals unlock from their actual conditions")
	_check(save.data["total_kills"] == 100 and save.data["best_level"] == 9, "Kills accumulate and highest level persists")
	_check(save.data["best_by_loadout"]["scout|storm|normal"] == 400 and save.data["best_by_loadout"]["scout|storm|relaxed"] == 900, "Relaxed and normal scores stay separate")
	_check(save.data["recent_runs"][0]["evolutions"] == ["pulse_nova"], "Evolution identifiers deduplicate and reject bad types")
	_check(save.data["recent_runs"][0]["mode"] == "relaxed" and save.data["recent_runs"][1]["mode"] == "normal", "Recent runs are newest first")
	details["evolutions"].append("later_mutation")
	_check(save.data["recent_runs"][0]["evolutions"] == ["pulse_nova"], "Caller mutation cannot change stored history")
	details["mode"] = "normal"
	details["kills"] = 0
	_check(save.record_run(200, 40.0, false, details), "A replay saves")
	_check(save.newly_unlocked.is_empty() and save.data["unlocked_medals"].size() == 6, "Previously earned medals never announce twice")
	_check(save.data["best_by_loadout"]["scout|storm|normal"] == 400, "A lower score does not replace a loadout best")
	for i: int in range(10):
		_check(save.record_run(1000 + i, 30.0, false, {"ship": "bastion", "sector": "forge", "mode": "normal"}), "History run %d saves" % i)
	_check(save.data["recent_runs"].size() == 8 and save.data["recent_runs"][0]["score"] == 1009 and save.data["recent_runs"][7]["score"] == 1002, "History retains only eight newest runs")
	var reloaded = SaveScript.new()
	reloaded.load_data(path)
	_check(reloaded.data == save.data and reloaded.newly_unlocked.is_empty(), "Progression round trip preserves data without new announcements")
	for id: String in SaveScript.MISSION_IDS:
		var info: Dictionary = SaveScript.mission_info(id)
		_check(info.get("id") == id and info.get("name") is String and info.get("description") is String and int(info.get("target", 0)) > 0, "Mission %s exposes display metadata" % id)
	_check(SaveScript.mission_info("not_a_mission").is_empty(), "Unknown mission metadata fails closed")
	var old: Dictionary = {"best_score": 777, "best_time": 250.5, "runs": 4, "wins": 1, "muted": true, "music": false, "reduced_motion": true}
	_write(path, JSON.stringify(old))
	reloaded.load_data(path)
	_check(reloaded.data["best_score"] == 777 and reloaded.data["runs"] == 4 and reloaded.data["wins"] == 1 and reloaded.data["best_time"] == 250.5, "Old save migration preserves all records")
	_check(reloaded.data["muted"] and not reloaded.data["music"] and reloaded.data["reduced_motion"], "Old save migration preserves settings")
	_check(reloaded.data["unlocked_medals"].size() == 3 and "first_run" in reloaded.data["unlocked_medals"] and "survivor" in reloaded.data["unlocked_medals"] and "victory" in reloaded.data["unlocked_medals"], "Old records infer only supported medals")
	_check(reloaded.data["total_kills"] == 0 and reloaded.data["best_level"] == 0 and reloaded.data["recent_runs"].is_empty() and reloaded.data["best_by_loadout"].is_empty(), "Migration does not invent old run details")
	_check(reloaded.newly_unlocked.is_empty() and reloaded.save_data(), "Migrated records can save without announcing historical medals")
	var valid_entry: Dictionary = {"score": 100, "time": 10.0, "won": false, "ship": "striker", "sector": "ring", "mode": "normal", "kills": "many", "level": -4, "evolutions": ["valid", "valid", [], "bad id"], "unexpected": {"nested": "discard"}}
	var malformed: Dictionary = {
		"total_kills": "100", "best_level": 999999.0,
		"unlocked_medals": ["elite", "elite", "bogus", 123, {}],
		"recent_runs": [null, {}, {"score": "100", "time": 10, "won": true}, {"score": 100, "time": 10, "won": true, "ship": {"bad": 1}, "sector": "ring", "mode": "normal"}, valid_entry],
		"best_by_loadout": {"striker|ring|normal": 300.5, "striker|ring|relaxed": "900", "bogus|ring|normal": 9000, "striker|ring|normal|extra": 9999, "scout|forge|normal": -5},
	}
	_write(path, JSON.stringify(malformed))
	reloaded.load_data(path)
	_check(reloaded.data["total_kills"] == 0 and reloaded.data["best_level"] == 1000, "Progression values validate and clamp")
	_check(reloaded.data["unlocked_medals"] == ["elite"], "Medals reject unknown IDs, types and duplicates")
	_check(reloaded.data["recent_runs"].size() == 1, "Malformed nested history rows are rejected")
	_check(reloaded.data["recent_runs"][0]["kills"] == 0 and reloaded.data["recent_runs"][0]["level"] == 1 and reloaded.data["recent_runs"][0]["evolutions"] == ["valid"] and not reloaded.data["recent_runs"][0].has("unexpected"), "Nested history fields normalize without preserving arbitrary keys")
	_check(reloaded.data["best_by_loadout"].size() == 2 and reloaded.data["best_by_loadout"]["striker|ring|normal"] == 300 and reloaded.data["best_by_loadout"]["scout|forge|normal"] == 0, "Loadout records accept only known combinations and numeric scores")
	var large_history: Array = []
	var large_evolutions: Array = []
	for i: int in range(80):
		large_history.append(valid_entry.duplicate(true))
		large_evolutions.append("evolution_%d" % i)
	large_history[0]["evolutions"] = large_evolutions
	malformed["recent_runs"] = large_history
	_write(path, JSON.stringify(malformed))
	reloaded.load_data(path)
	_check(reloaded.data["recent_runs"].size() == 8 and reloaded.data["recent_runs"][0]["evolutions"].size() == 8, "History and nested evolution arrays stay bounded on load")
	_check(reloaded.record_run(10, 1.0, false, {"ship": [], "sector": {}, "mode": false, "kills": INF, "level": NAN, "elites": "1", "evolutions": "nova"}), "Malformed run details remain safe")
	var newest: Dictionary = reloaded.data["recent_runs"][0]
	_check(newest["ship"] == "striker" and newest["sector"] == "ring" and newest["mode"] == "normal" and newest["kills"] == 0 and newest["level"] == 1 and newest["evolutions"].is_empty(), "Malformed details use safe known defaults")
	malformed["recent_runs"] = {"wrong": "type"}
	malformed["best_by_loadout"] = []
	malformed["unlocked_medals"] = "victory"
	_write(path, JSON.stringify(malformed))
	reloaded.load_data(path)
	_check(reloaded.data["recent_runs"].is_empty() and reloaded.data["best_by_loadout"].is_empty() and reloaded.data["unlocked_medals"].is_empty(), "Wrong container types do not coerce")


func _test_save_versions() -> void:
	var prefix: String = "user://test_versions_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var legacy_path: String = prefix + "_legacy.json"
	var current_path: String = prefix + "_v2.json"
	var legacy: Dictionary = {"best_score": 640, "best_time": 205.0, "runs": 3, "wins": 1, "muted": true, "music": false, "reduced_motion": true}
	var expected_legacy: Variant = JSON.parse_string(JSON.stringify(legacy))
	var store = SaveScript.new()
	_check(store._path == "user://records_v2.json", "Default writes use isolated v2 records")
	_write(legacy_path, JSON.stringify(legacy))
	store.load_data(current_path)
	_check(store.data == SaveScript.DEFAULTS, "Custom paths do not import real player records")
	var imported: Variant = store._load_source(current_path, legacy_path)
	_check(imported == expected_legacy, "Absent v2 files import legacy primary")
	store.data = store._validated(imported)
	_check(store.data["best_score"] == 640 and store.data["muted"] and store.data["unlocked_medals"].size() == 3, "Version import preserves records, settings and inferred medals")
	_check(store.save_data(), "Imported data saves to v2 destination")
	_check(FileAccess.get_file_as_string(legacy_path) == JSON.stringify(legacy) and FileAccess.file_exists(current_path), "Saving imported data preserves original legacy file")
	_write(current_path, JSON.stringify({"best_score": 900, "runs": 4}))
	_check(store._load_source(current_path, legacy_path)["best_score"] == 900, "Existing v2 primary takes precedence over legacy")
	_write(current_path + ".bak", JSON.stringify({"best_score": 800, "runs": 4}))
	_write(current_path, "{broken")
	_check(store._load_source(current_path, legacy_path)["best_score"] == 800, "Valid v2 backup takes precedence over legacy")
	var damaged_path: String = prefix + "_damaged.json"
	_write(damaged_path, "{broken")
	_check(store._load_source(damaged_path, legacy_path) == null, "Corrupt v2 primary without backup never rolls back to legacy")
	var damaged_backup_path: String = prefix + "_damaged_backup.json"
	_write(damaged_backup_path + ".bak", "{broken")
	_check(store._load_source(damaged_backup_path, legacy_path) == null, "Existing corrupt v2 backup also prevents a legacy rollback")
	var legacy_backup_path: String = prefix + "_legacy_backup.json"
	_write(legacy_backup_path + ".bak", JSON.stringify(legacy))
	_check(store._load_source(prefix + "_fresh.json", legacy_backup_path) == expected_legacy, "First import recovers legacy backup if primary is missing")
	_write(legacy_backup_path, "{broken")
	_check(store._load_source(prefix + "_fresh.json", legacy_backup_path) == expected_legacy, "First import recovers legacy backup if primary is malformed")
	_check(store._load_source(prefix + "_missing.json", prefix + "_missing_legacy.json") == null, "Fresh installation without legacy records stays empty")


func _test_audio() -> void:
	var audio = SoundScript.new()
	audio.play("select")
	audio.start_music()
	audio.set_muted(true)
	audio.set_music_enabled(false)
	_check(audio.get_child_count() == 0, "Calls before scene-tree entry are safe")
	root.add_child(audio)
	_check(audio._voices.size() == SoundScript.VOICE_LIMIT, "Exactly ten effect voices allocated")
	audio.set_muted(false)
	_check(not audio._music.playing, "Music stays disabled after unmuting")
	audio.play("unknown")
	_check(audio._sounds.is_empty(), "Unknown cues ignored safely")
	audio.play("shoot")
	var first_play: int = int(audio._last_played["shoot"])
	for i: int in range(50):
		audio.play("shoot")
	_check(_playing_voices(audio) == 1 and audio._last_played["shoot"] == first_play, "Noisy cue burst is rate limited")
	for cue: String in SoundScript.CUES:
		audio.play(cue)
	_check(_playing_voices(audio) <= SoundScript.VOICE_LIMIT, "All cues respect simultaneous-voice cap")
	_check(audio._sounds.size() == SoundScript.CUES.size(), "Every requested cue generates a WAV")
	for cue: String in audio._sounds:
		var stream: AudioStreamWAV = audio._sounds[cue]
		_check(stream.data.size() > 0 and stream.mix_rate == SoundScript.SAMPLE_RATE and stream.format == AudioStreamWAV.FORMAT_16_BITS, "Cue %s is valid PCM" % cue)
	audio.set_music_enabled(true)
	var music: AudioStreamWAV = audio._music.stream
	_check(music != null and audio._music.playing, "Music starts on demand")
	_check(music.data.size() == 8 * SoundScript.SAMPLE_RATE * 2, "Music contains eight seconds of PCM")
	_check(music.loop_mode == AudioStreamWAV.LOOP_FORWARD and music.loop_end == 8 * SoundScript.SAMPLE_RATE, "Music loops over full buffer")
	_check(music.data.decode_s16(0) == 0 and absi(music.data.decode_s16(music.data.size() - 2)) < 100, "Music boundary fades avoid loop clicks")
	await create_timer(0.15).timeout
	audio.set_muted(true)
	_check(_playing_voices(audio) == 0 and not audio._music.playing, "Mute stops music and all effects")
	audio.play("hit")
	_check(_playing_voices(audio) == 0, "Muted effects remain silent")
	await create_timer(0.15).timeout
	audio.set_muted(false)
	_check(audio._music.playing, "Unmute resumes enabled music")
	await create_timer(0.15).timeout
	audio.set_music_enabled(false)
	_check(not audio._music.playing, "Music setting stops only background track")
	# Players clear stopped playback references on their next internal update.
	await create_timer(0.15).timeout
	audio.free()


func _playing_voices(audio: Node) -> int:
	var count: int = 0
	for voice: AudioStreamPlayer in audio._voices:
		if voice.playing:
			count += 1
	return count
