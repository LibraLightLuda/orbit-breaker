class_name SoundBank
extends Node

const Catalog = preload("res://scripts/audio_catalog.gd")
const CUES: Dictionary = Catalog.CUES
const SAMPLE_RATE := 48000
const VOICE_LIMIT := 16
const ALIASES := {"shoot":"weapon_cannon", "hit":"enemy_hit_light", "hurt":"player_hurt", "dash":"ship_dash", "pickup":"loot_xp", "select":"ui_confirm", "level":"ui_upgrade_open", "win":"run_end_cleared", "lose":"run_end_lost", "boss":"boss_arrive", "event_warning":"event_warn_black_hole", "event_start":"event_active_black_hole", "hazard_start":"hazard_strike_blast", "boundary_hit":"warn_boundary_deep", "combat_branch":"growth_weapon", "combat_core_open":"boss_phase", "combat_relay_down":"enemy_destroy_elite", "combat_final_offer":"mission_preview", "combat_final_start":"boss_arrive", "combat_final_success":"planet_success"}
const FAMILIES := {"power":"power", "rapid":"power", "frenzy":"power", "speed":"drive", "haste":"drive", "repair":"repair", "heal":"repair", "stun":"stun", "emp":"emp", "insight":"data", "bounty":"bounty", "shield":"shield"}

var muted := false
var _music_enabled := true
var _voices: Array[AudioStreamPlayer2D] = []
var _sounds: Dictionary = {}
var _last_played: Dictionary = {}
var _variants: Dictionary = {}
var _music: AudioStreamPlayer
var _stems: Array[AudioStreamPlayer] = []
var _ambience: AudioStreamPlayer
var _engine: AudioStreamPlayer
var _decay: AudioStreamPlayer
var _tracks: Dictionary = {}
var _view := "menu"
var _sector := "ring"
var _camera := Vector2.ZERO
var _active := false
var _battle_context := false
var _clock := 0.0
var _duck := 0.0
var _phase := 0
var _boss := false
var _powered := false
var _volumes := Vector3.ONE
var _hull_stage := 0
var _hull_candidate := 0
var _hull_wait := 0.0
var _hull_pulse := 0.0
var _decay_stage := 0
var _decay_candidate := 0
var _decay_wait := 0.0
var _layer := 0
var _layer_candidate := 0
var _layer_wait := 0.0
var _final_at := -1
var _previous_dash := 0.0
var _previous_overdrive := 0.0
var _previous_meter := 0.0
var _previous_guard := 0
var _previous_focus := 0.0
var _mission_key := ""
var _mission_bits := 0
var _mission_deadline := false
var _move_volume := -70.0
var _tick_volume := -70.0
var _pending: Array[Dictionary] = []
var played_counts: Dictionary = {}
var dropped := 0
var enabled := true

func _ready() -> void:
	_initialize()

func _initialize() -> void:
	if not _voices.is_empty(): return
	for bus: String in ["Music", "Ambience", "Combat", "Feedback", "UI", "Warnings"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	# All streams are ready before combat; no first-use synthesis or loading.
	for cue: String in CUES:
		var streams: Array[AudioStream] = []
		for path: String in CUES[cue].paths: streams.append(load(path))
		_sounds[cue] = streams
	for key: String in Catalog.TRACKS:
		var stream: AudioStreamOggVorbis = load(Catalog.TRACKS[key].path)
		stream.loop = true
		_tracks[key] = stream
	for i in VOICE_LIMIT:
		var voice := AudioStreamPlayer2D.new()
		voice.max_distance = 2400.0
		voice.attenuation = 1.0
		voice.panning_strength = 0.65
		voice.set_meta("priority", 9)
		add_child(voice)
		_voices.append(voice)
	_music = _loop_player("mus_menu", "Music")
	for key: String in ["mus_battle_bed", "mus_battle_drive", "mus_battle_pressure"]:
		_stems.append(_loop_player(key, "Music"))
	_ambience = _loop_player("amb_ring", "Ambience")
	_engine = _loop_player("ship_drive", "Ambience")
	_decay = _loop_player("warn_decay_bed", "Warnings")
	set_volumes(1, 1, 1)
	if AudioServer.get_bus_effect_count(0) == 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(0, limiter)

func _loop_player(key: String, bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = _tracks[key]
	player.bus = bus
	player.volume_db = -70.0
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
	return player

func start_music() -> void:
	if not is_inside_tree(): return
	_initialize()
	_sync_loops()

func begin_run(sector: String) -> void:
	_sector = sector
	_hull_stage = 0
	_hull_candidate = 0
	_hull_wait = 0
	_hull_pulse = 0
	_decay_stage = 0
	_decay_candidate = 0
	_decay_wait = 0
	_layer = 0
	_layer_candidate = 0
	_layer_wait = 0
	_final_at = -1
	_previous_dash = 0
	_previous_meter = 0
	_previous_overdrive = 0
	_previous_guard = 1
	_previous_focus = 0
	_phase = 0
	_boss = false
	_mission_key = ""
	_mission_bits = 0
	_pending.clear()
	_last_played.clear()
	if not is_inside_tree(): return
	for player in _stems: player.stop()
	_ambience.stop()
	_ambience.stream = _tracks["amb_" + sector]

func set_screen(view: String) -> void:
	if view == _view: return
	var previous := _view
	_view = view
	_active = view == "playing"
	_battle_context = view in ["playing", "pause", "upgrade", "branch"] or (view == "arsenal" and previous in ["playing", "pause", "upgrade", "branch", "arsenal"] and _battle_context)
	_pending.clear()
	for voice in _voices:
		if voice.bus not in ["UI", "Feedback"]: voice.stop()
	if view == "upgrade": play("ui_upgrade_open")
	elif view == "pause": play("ui_pause_open")
	elif view == "playing" and previous in ["pause", "arsenal"]: play("ui_pause_close")
	if previous == "playing" and view != "playing":
		_move_volume = -70
		_tick_volume = -70
	_sync_loops()

func _sync_loops() -> void:
	if _music == null: return
	var battle := _battle_context
	var music_ok := not muted and _music_enabled
	if music_ok and not battle:
		if not _music.playing: _music.play()
	else: _music.stop()
	for player in _stems:
		if music_ok and battle:
			if not player.has_stream_playback(): player.play()
			player.stream_paused = not _active
		else: player.stop()
	for player in [_ambience, _engine, _decay]:
		if not muted and _active:
			if not player.has_stream_playback(): player.play()
			player.stream_paused = false
		elif muted: player.stop()
		else: player.stream_paused = true

func stop_all() -> void:
	for voice in _voices: voice.stop()
	for player in [_music, _ambience, _engine, _decay] + _stems:
		if is_instance_valid(player): player.stop()
	_pending.clear()

func _exit_tree() -> void:
	stop_all()
	for voice in _voices: voice.stream = null
	for player in [_music, _ambience, _engine, _decay] + _stems:
		if is_instance_valid(player): player.stream = null
	_sounds.clear()
	_tracks.clear()

func set_muted(value: bool) -> void:
	muted = value
	_pending.clear()
	if muted:
		for voice in _voices: voice.stop()
	else: _hull_pulse = 0
	if is_inside_tree():
		AudioServer.set_bus_mute(0, muted or _volumes.x == 0)
		_sync_loops()

func set_music_enabled(value: bool) -> void:
	_music_enabled = value
	if is_inside_tree(): _sync_loops()

func set_volumes(master: float, music: float, effects: float) -> void:
	_volumes = Vector3(clampf(master,0,1), clampf(music,0,1), clampf(effects,0,1))
	if _voices.is_empty(): return
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(.00001, _volumes.x)) - 3.0)
	AudioServer.set_bus_mute(0, muted or _volumes.x == 0)
	for bus: String in ["Music", "Ambience", "Combat", "Feedback", "UI", "Warnings"]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(.00001, _volumes.y if bus == "Music" else _volumes.z)))
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), (_volumes.y if bus == "Music" else _volumes.z) == 0)

func play(cue: String, at: Vector2 = Vector2.INF) -> bool:
	if not is_inside_tree() or muted or not enabled: return false
	cue = str(ALIASES.get(cue, cue))
	if not CUES.has(cue): return false
	var spec: Dictionary = CUES[cue]
	if cue in ["ui_achievement", "ui_discovery"] and _clock-float(_last_played.get("_progress",-100.0)) < .5: return false
	if int(spec.priority) >= 2 and _hull_stage >= 2 and (cue.begins_with("loot_xp") or cue.begins_with("loot_expire") or cue in ["mission_progress", "ship_dash_ready", "ship_focus_ready", "ship_guard_ready"]): return false
	if _clock - float(_last_played.get(cue, -100.0)) < float(spec.interval): return false
	var first := 0 if spec.bus == "Warnings" else (2 if spec.bus == "UI" else 3)
	var last := 2 if spec.bus == "Warnings" else (3 if spec.bus == "UI" else VOICE_LIMIT)
	if cue == "warn_hull_critical": last = 1
	elif spec.bus == "Warnings" and (cue.begins_with("hazard_") or cue.begins_with("event_")): first = 1
	var chosen: AudioStreamPlayer2D
	for i in range(first, last):
		if not _voices[i].playing:
			chosen = _voices[i]
			break
	if chosen == null:
		if spec.bus == "UI" and cue != "ui_focus": chosen = _voices[2]
	if chosen == null:
		for i in range(first, last):
			var old_priority := int(_voices[i].get_meta("priority", 9))
			if old_priority >= int(spec.priority) and (chosen == null or old_priority > int(chosen.get_meta("priority", 9))): chosen = _voices[i]
	if chosen == null:
		dropped += 1
		return false
	chosen.stop()
	var variants: Array = _sounds[cue]
	var index := int(_variants.get(cue, 0)) % variants.size()
	_variants[cue] = index + 1
	chosen.stream = variants[index]
	chosen.bus = str(spec.bus)
	chosen.volume_db = float(spec.gain)
	chosen.pitch_scale = .94 if _powered and cue in ["weapon_cannon", "weapon_rail"] else 1.0
	if _powered and cue in ["weapon_cannon", "weapon_rail"]: chosen.volume_db += 1.5
	chosen.position = Vector2(640, 360) if not at.is_finite() else at - _camera
	chosen.panning_strength = 0.0 if not at.is_finite() else 0.65
	chosen.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	chosen.set_meta("priority", int(spec.priority))
	chosen.set_meta("cue", cue)
	chosen.play()
	_last_played[cue] = _clock
	if cue in ["ui_achievement", "ui_discovery"]: _last_played["_progress"] = _clock
	played_counts[cue] = int(played_counts.get(cue, 0)) + 1
	if int(spec.priority) <= 1: _duck = maxf(_duck, .65)
	elif int(spec.priority) == 2: _duck = maxf(_duck, .3)
	return true

func consume(model: RunModel, camera: Vector2) -> void:
	_camera = camera
	_powered = model.overdrive_time > 0
	var queue: Array[Dictionary] = []
	for source: String in model.audio_events:
		var cue := str(ALIASES.get(source, source))
		if source.begins_with("loot_item_"):
			var fields := source.trim_prefix("loot_item_").split("_")
			cue = "loot_item_" + str(FAMILIES[fields[0]]) + "_" + fields[1]
		queue.append({"cue":cue,"at":model.audio_events[source]})
	var hull_ii := model.audio_events.has("growth_hull_II")
	model.audio_events.clear()
	if model.state in ["won", "lost"]: return
	var common := {"dash":"ship_dash", "pickup":"loot_xp", "heal":"loot_heal", "overdrive":"ship_overdrive_start", "evolution":"growth_weapon", "milestone":"run_breakthrough", "boss":"boss_arrive", "elite":"enemy_attack_charge", "mission_preview":"mission_preview", "mission_start":"mission_start", "mission_failed":"mission_failed", "part_spawn":"loot_part_spawn", "event_reward":"planet_success", "event_end":"planet_end"}
	for event: String in model.events:
		var cue := str(common.get(event, ""))
		if event == "mission_success": cue = "mission_success_" + str(model.mission.get("grade", "C"))
		if not cue.is_empty(): queue.append({"cue":cue,"at":Vector2.INF})
	queue.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(CUES[a.cue].priority) < int(CUES[b.cue].priority))
	var fanfare := false
	var part_played := false
	for event in queue:
		if event.cue == "growth_hull_I" and hull_ii: continue
		if str(event.cue) in ["loot_part_core", "loot_part_drive", "loot_part_shell"]:
			if not part_played: play(event.cue)
			part_played = true
			continue
		var spec: Dictionary = CUES[event.cue]
		if spec.bus == "Feedback" and int(spec.priority) == 2 and not str(event.cue).begins_with("loot_part_spawn"):
			if fanfare:
				if _pending.size() < 2 and str(event.cue).begins_with("growth_"): _pending.append({"cue":event.cue,"due":_clock+.35,"expires":_clock+.8})
				continue
			fanfare = true
		play(event.cue, event.at)

func update_state(view: String, model: RunModel, delta: float, camera: Vector2) -> void:
	set_screen(view)
	_camera = camera
	if view != "playing" or model.state != "playing": return
	var dt := minf(delta, .05)
	_phase = 0 if model.elapsed < 50 else (1 if model.elapsed < 150 else (2 if model.elapsed < 300 else (3 if model.elapsed < 480 else 4)))
	_boss = model.enemies.any(func(e: Dictionary) -> bool: return e.kind == "boss" and float(e.hp) > 0)
	var h := model.hp / maxf(1, model.max_hp)
	var target := 3 if h <= .07 else (2 if h <= .15 else (1 if h <= .30 else 0))
	if _hull_stage == 3 and h < .10: target = 3
	elif _hull_stage >= 2 and h < .20: target = maxi(target, 2)
	elif _hull_stage >= 1 and h < .36: target = maxi(target, 1)
	if target != _hull_candidate:
		_hull_candidate = target
		_hull_wait = 0
	_hull_wait += dt
	var wait := (0.0 if target == 3 else (.2 if target == 2 else .4)) if target > _hull_stage else 1.5
	if target != _hull_stage and _hull_wait >= wait:
		_hull_stage = target
		_hull_pulse = 0
	_hull_pulse -= dt
	if _hull_stage > 0 and _hull_pulse <= 0:
		play("warn_hull_low" if _hull_stage == 1 else "warn_hull_critical")
		_hull_pulse = [0.0, 3.0, 1.2, .75][_hull_stage]
	var d := model.decay_rate() / maxf(1, model.max_hp)
	var decay_target := 2 if d >= .04 else (1 if d >= .02 else 0)
	if _decay_stage == 2 and d >= .034: decay_target = 2
	elif _decay_stage == 1 and d >= .017: decay_target = maxi(decay_target,1)
	if decay_target != _decay_candidate:
		_decay_candidate = decay_target
		_decay_wait = 0
	_decay_wait += dt
	if decay_target != _decay_stage and _decay_wait >= (.8 if decay_target > _decay_stage else 2.0):
		if decay_target > _decay_stage: play("warn_decay_rise")
		_decay_stage = decay_target
	var layer := model.boundary_layer(model.player)
	if layer != _layer_candidate:
		_layer_candidate = layer
		_layer_wait = 0
	_layer_wait += dt
	if layer != _layer and _layer_wait >= (.6 if layer == 0 else .3):
		play("warn_boundary_return" if layer == 0 else ("warn_boundary_enter" if layer == 1 else "warn_boundary_deep"))
		_layer = layer
	var final_tick := 590 if model.elapsed >= 590 and model.elapsed < 597 else floori(model.elapsed)
	if model.elapsed >= 590 and final_tick != _final_at:
		play("warn_final_collapse" if _final_at < 590 else "event_countdown")
		_final_at = final_tick
	if _previous_dash > 0 and model.dash_cooldown <= 0: play("ship_dash_ready")
	if _previous_meter < 100 and model.overdrive_meter >= 100: play("ship_overdrive_ready")
	if _previous_overdrive > 0 and model.overdrive_time <= 0: play("ship_overdrive_end")
	if model.guard_stacks > _previous_guard and model.ship_id == "bastion": play("ship_guard_ready")
	if _previous_focus < 1.2 and model.focus_time >= 1.2 and model.ship_id == "striker": play("ship_focus_ready")
	_previous_dash = model.dash_cooldown
	_previous_meter = model.overdrive_meter
	_previous_overdrive = model.overdrive_time
	_previous_guard = model.guard_stacks
	_previous_focus = model.focus_time
	_update_mission(model)
	_move_volume = lerpf(-60,-24,clampf(model.current_speed/maxf(1,model.base_speed()),0,1))
	_tick_volume = -70 if _decay_stage == 0 else (-12 if _decay_stage == 2 else -19)
	if model.net_hull_rate() >= 0: _tick_volume -= 5
	if _hull_stage >= 2: _tick_volume -= 9
	_decay.pitch_scale = clampf(d/.04, .5, 1.0)

func _update_mission(model: RunModel) -> void:
	if model.mission.is_empty() or str(model.mission.status) != "active": return
	var key := str(model.mission.id) + str(model.mission.get("start", 0))
	if key != _mission_key:
		_mission_key = key
		_mission_bits = 0
		_mission_deadline = false
	var progress := float(model.mission.get("progress", 0)) / maxf(1, float(model.mission.get("target",1)))
	if model.mission.id == "survive": progress = (model.elapsed-float(model.mission.start))/50.0
	for bit in [1,2]:
		if (_mission_bits & bit) == 0 and progress >= (.5 if bit == 1 else .8):
			_mission_bits |= bit
			play("mission_progress")
	if float(model.mission.get("start",INF))+50.0-model.elapsed <= 10 and not _mission_deadline:
		_mission_deadline = true
		play("mission_deadline")

func _process(delta: float) -> void:
	_clock += delta
	_duck = maxf(0,_duck-delta)
	if _music == null: return
	var mix_duck := -4.0 if _duck > 0 else 0.0
	var danger_duck := -3.0 if _hull_stage >= 2 and _active else 0.0
	_fade(_music, -2.0, delta, 1.0)
	var drive: float = [-12.0,-6.0,-3.0,0.0,0.0][_phase]
	var pressure: float = [-70.0,-18.0,-12.0,-6.0,-3.0][_phase]
	if _boss:
		drive = 0
		pressure = maxf(pressure,-3)
	if _decay_stage > 0: pressure = maxf(pressure, -3 if _decay_stage == 2 else -9)
	_fade(_stems[0], mix_duck+danger_duck, delta, .8)
	_fade(_stems[1], drive+mix_duck+danger_duck, delta, 2.0)
	_fade(_stems[2], pressure+mix_duck+danger_duck, delta, 2.0)
	_fade(_ambience, -4.0, delta, .2)
	_fade(_engine, _move_volume, delta, .15)
	_fade(_decay, _tick_volume, delta, .3)
	if _active:
		for i in range(_pending.size()-1,-1,-1):
			var event: Dictionary = _pending[i]
			if _clock > float(event.expires): _pending.remove_at(i)
			elif _clock >= float(event.due):
				play(str(event.cue))
				_pending.remove_at(i)
	for bus: String in ["Combat", "Ambience"]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(.00001,_volumes.z)) + ((-3.0 if bus == "Combat" else -6.0) if _duck > 0 else 0.0))

func _fade(player: AudioStreamPlayer, target: float, delta: float, seconds: float) -> void:
	player.volume_db = lerpf(player.volume_db, target, 1.0-exp(-delta*5.0/seconds))

func active_voices() -> int:
	var count := 0
	for voice in _voices: count += int(voice.playing)
	return count
