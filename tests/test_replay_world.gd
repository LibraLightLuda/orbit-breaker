extends SceneTree

var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAILED: " + message)

func fixture() -> RunModel:
	var model := RunModel.new()
	model.reset(371, "veteran", "scout", "storm")
	model.spawn_enemy("elite", model.player + Vector2(200, -70))
	model.spawn_enemy("shooter", model.player + Vector2(-130, 90))
	model.spawn_enemy("boss", model.player + Vector2(280, 100))
	model.enemies[0].stun_time = 2.0
	model.enemies[1].warn = 0.7
	model.shots.append({"pos": model.player + Vector2(60, 10), "velocity": Vector2(180, 0), "friendly": false, "radius": 7.0, "damage": 10.0, "ttl": 3.0})
	model._fire_player_shot()
	model.gems.append({"pos": model.player + Vector2(-180, 100), "value": 4.0, "kind": "xp"})
	model.gems.append({"pos": model.player + Vector2(-160, 120), "value": 20.0, "kind": "heal"})
	model.spawn_item(model.player + Vector2(170, 130), "A", "emp")
	model.spawn_item(model.player + Vector2(220, -130), "B", "heal")
	model.apply_item("frenzy", "A")
	model.apply_item("repair", "B")
	model._add_lane()
	model._add_blast(model.player + Vector2(-200, -70), 64)
	model._effect(model.player, "lightning", 7, 0.25, model.enemies[0].pos)
	model.upgrades.frost = 2
	model.evolutions.append("storm")
	model.level = 8
	model.dash_cooldown = 1.5
	model.slipstream_time = 1.4
	return model

func run_checks() -> void:
	_test_drift()
	_test_short_events()
	var model := fixture()
	var ghost := GhostReplay.new()
	ghost.capture(model)
	check(ghost.frames[0].size() == 14 and GhostReplay.valid(ghost.frames), "world frame validates")
	if not GhostReplay.valid(ghost.frames):
		quit(1)
		return
	for key: String in GhostReplay.COLLECTIONS:
		check(ghost.frames[0][13][key].size() == model.get(key).size(), "captures entire " + key)
	var first: Array = ghost.frames[0].duplicate(true)
	model.enemies[0].pos += Vector2(80, 40)
	model.enemies[0].hp -= 50
	model.items[0].pos += Vector2(-20, 0)
	model.gems.clear()
	model.elapsed = 0.4
	ghost.capture(model)
	check(ghost.frames[0] == first, "snapshots are detached from live mutation")
	var middle := GhostReplay.sample(ghost.frames, 0.2)
	check(is_equal_approx(float(middle[13].enemies[0][2][0]), float(first[13].enemies[0][2][0]) + 40), "stable enemy identity interpolates position")
	check(middle[13].gems.size() == 2 and GhostReplay.sample(ghost.frames, 0.4)[13].gems.is_empty(), "pickup removal appears at recorded time")
	model.enemies.remove_at(0)
	model.spawn_enemy("tank", model.player + Vector2(-300, -50))
	model.elapsed = 0.8
	ghost.capture(model)
	middle = GhostReplay.sample(ghost.frames, 0.6)
	check(middle[13].enemies[0][0] == first[13].enemies[0][0] and middle[13].enemies[0][2] == ghost.frames[1][13].enemies[0][2], "dead enemy cannot morph into newly spawned enemy")
	check(GhostReplay.sample(ghost.frames, 0.8)[13].enemies.back()[1] == "tank", "new hostile spawn restores after seek")
	var restored := RunModel.new()
	restored.reset(1, model.mode, model.ship_id, model.sector_id)
	GhostReplay.restore(restored, first)
	check(restored.enemies.size() == 3 and restored.items.size() == 2 and restored.gems.size() == 2 and restored.shots.size() == 2, "restores all battlefield entities")
	check(restored.enemies[0].pos == Vector2(first[13].enemies[0][2][0], first[13].enemies[0][2][1]) and restored.enemies[0].stun_time == 2, "restores positions and crowd control")
	check(restored.hazards[0].rect is Rect2 and restored.effects.back().end is Vector2, "restores lane geometry and lightning endpoint")
	check(restored.buffs.frenzy.value == 300 and restored.upgrades.frost == 2 and restored.evolutions == ["storm"], "restores buffs upgrades and evolution")
	check(restored.level == 8 and restored.dash_cooldown == 1.5 and is_equal_approx(restored.slipstream_time, 1.4), "restores pilot skill state")
	var before := GhostReplay.sample(ghost.frames, 0)
	GhostReplay.sample(ghost.frames, 0.7)
	check(GhostReplay.sample(ghost.frames, 0) == before, "backward seek cannot mutate recording")
	var legacy: Array = []
	for frame: Array in ghost.frames:
		legacy.append(frame.slice(0, 13))
	check(GhostReplay.valid(legacy) and GhostReplay.sample(legacy, 0.2).size() == 13, "legacy thirteen-number frames still play")
	for recording: Array in [ghost.frames, legacy]:
		for time: float in [-1.0, 0.0, 0.2, 0.4, 0.7, 0.8, 600.0]:
			var sample := GhostReplay.sample(recording, time)
			check(GhostReplay.sample_position(recording, time).is_equal_approx(Vector2(sample[1], sample[2])), "Position-only sampling matches world sampling across seeks and legacy frames")
	var path := "user://world_replay_test_%d.json" % Time.get_ticks_usec()
	check(GhostReplay.write(path, ghost.frames), "world replay writes compressed file atomically")
	var file := FileAccess.open(path, FileAccess.READ)
	check(file.get_buffer(4).get_string_from_ascii() == "OBG2", "new format has explicit compressed magic")
	file.close()
	var loaded := GhostReplay.read(path)
	check(loaded.size() == ghost.frames.size() and GhostReplay.valid(loaded), "world replay round trips through disk validation")
	GhostReplay.restore(restored, GhostReplay.sample(loaded, 0))
	check(restored.items[0].id == "emp" and restored.items[0].grade == "A" and restored.shots[0].velocity == Vector2(180, 0), "round trip preserves item identity grade and bullets")
	check(GhostReplay.write(path + ".legacy", legacy), "version one JSON writes")
	check(GhostReplay.read(path + ".legacy").size() == 3, "version one JSON file remains readable")
	for key: String in GhostReplay.COLLECTIONS:
		var bad := ghost.frames.duplicate(true)
		bad[0][13][key] = "invalid"
		check(not GhostReplay.valid(bad), "reject malformed collection " + key)
	var bad := ghost.frames.duplicate(true)
	bad[0][0] = {}
	check(not GhostReplay.valid(bad), "reject malformed snapshot time before any numeric conversion")
	bad = ghost.frames.duplicate(true)
	bad[0][13].enemies[0][1] = "unknown_enemy"
	check(not GhostReplay.valid(bad), "reject unknown enemy art identity")
	bad = ghost.frames.duplicate(true)
	bad[0][13].events[0][3][1] = "unknown_enemy"
	check(not GhostReplay.valid(bad), "reject unknown enemy identity in lifecycle events")
	bad = ghost.frames.duplicate(true)
	bad[0][13].enemies[0][2][0] = INF
	check(not GhostReplay.valid(bad), "reject nonfinite entity coordinate")
	bad = ghost.frames.duplicate(true)
	bad[0][13].items[0][2] = "unknown_item"
	check(not GhostReplay.valid(bad), "reject unknown item identity")
	bad = ghost.frames.duplicate(true)
	bad[0][13].items[0][3] = "S"
	check(not GhostReplay.valid(bad), "reject unknown grade")
	bad = ghost.frames.duplicate(true)
	bad[0][13].enemies[1][0] = bad[0][13].enemies[0][0]
	check(not GhostReplay.valid(bad), "reject duplicate entity identity")
	bad = ghost.frames.duplicate(true)
	bad[0][13].hazards[0][3] = [1, 2]
	check(not GhostReplay.valid(bad), "reject malformed geometry")
	bad = ghost.frames.duplicate(true)
	bad[0][13].values[0] = 0
	check(not GhostReplay.valid(bad), "reject zero maximum hull")
	bad = ghost.frames.duplicate(true)
	bad[0][13].buffs[0][3] = "S"
	check(not GhostReplay.valid(bad), "reject malformed buff")
	bad = ghost.frames.duplicate(true)
	bad[1] = legacy[1]
	check(not GhostReplay.valid(bad), "reject mixed legacy and world frames")
	model.hp = 1
	ghost.capture(model, true)
	check(ghost.frames.size() == 3 and ghost.frames.back()[4] == 1, "same-time terminal capture replaces final state without duplicate time")
	bad = ghost.frames.duplicate(true)
	bad[1][13].events[0][0] = 599.0
	check(not GhostReplay.valid(bad), "reject lifecycle events outside snapshot interval")
	_test_capacity(path)
	await _test_ui(loaded, legacy)
	for suffix: String in ["", ".legacy", ".capacity", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("REPLAY WORLD SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func _test_drift() -> void:
	var model := RunModel.new()
	model.reset(371)
	model._spawn_timer = 1000
	var start := RunModel.CENTER + Vector2(RunModel.ACTIVITY_RADIUS + 100, 0)
	model.spawn_item(start, "A", "power")
	model.gems.append({"pos": start, "value": 5, "kind": "xp"})
	var saved_rng := model.rng.state
	model._update_items(1)
	model._collect_gems(1)
	check(is_equal_approx(start.distance_to(model.items[0].pos), 18), "boundary item drifts eighteen pixels per second")
	check(is_equal_approx(start.distance_to(model.gems[0].pos), RunModel.XP_DRIFT_SPEED) and model.rng.state == saved_rng, "XP drifts more slowly without changing combat RNG")
	check(model.items[0].grade == "A" and model.items[0].ttl == 34 and model.items_collected == 0 and model.xp == 0, "drift preserves grade lifetime and requires actual collection")
	var gem_position: Vector2 = model.gems[0].pos
	var position: Vector2 = model.items[0].pos
	model.state = "upgrade"
	model.step(0.05, Vector2.ZERO, false)
	check(model.items[0].pos == position and model.gems[0].pos == gem_position, "pause freezes all loot drift")
	model.state = "playing"
	model._update_items(20)
	model._collect_gems(20)
	check(model.boundary_layer(model.items[0].pos) == 0 and model.boundary_layer(model.gems[0].pos) > 0, "supply reaches safety while XP remains an exploration reward")
	position = model.items[0].pos
	model._update_items(1)
	check(model.items[0].pos == position, "drift settles inside safety without oscillation")
	for angle: float in [0.0, PI / 2, PI, PI * 1.5]:
		var outer := RunModel.CENTER + Vector2.from_angle(angle) * (RunModel.ACTIVITY_RADIUS + RunModel.BOUNDARY_BUFFER)
		var moved := model._drift_loot(outer, 0.05)
		check(absf(outer.distance_to(moved) - 0.9) < 0.001 and moved.distance_to(RunModel.CENTER) < outer.distance_to(RunModel.CENTER), "drift follows radial center direction")
	check(model._drift_loot(RunModel.CENTER, 1) == RunModel.CENTER, "central loot stays still")
	model = RunModel.new()
	model.reset(371)
	model.player += Vector2(150, 0)
	model.gems.append({"pos": model.player + Vector2(60, 0), "value": 5, "kind": "xp"})
	model._collect_gems(0.15)
	check(model.gems.is_empty() and model.xp == 5, "existing magnet collection remains active")

func _test_capacity(path: String) -> void:
	var model := fixture()
	for i: int in range(20):
		model.spawn_enemy("tank", model.player + Vector2(i * 10, -150))
	for i: int in range(40):
		model.gems.append({"pos": model.player + Vector2(i * 8, 180), "value": 1, "kind": "xp"})
	var ghost := GhostReplay.new()
	ghost.capture(model)
	var recording: Array = []
	var quiet_world: Dictionary = ghost.frames[0][13].duplicate()
	quiet_world.events = []
	for i: int in range(3001):
		var frame: Array = ghost.frames[0].duplicate()
		frame[0] = float(i) * 0.2
		if i > 0:
			frame[13] = quiet_world
		recording.append(frame)
	check(GhostReplay.valid(recording), "full ten-minute world recording fits frame bounds")
	var started := Time.get_ticks_msec()
	check(GhostReplay.write(path + ".capacity", recording), "full ten-minute recording compresses and writes")
	var loaded := GhostReplay.read(path + ".capacity")
	check(loaded.size() == 3001 and loaded.back()[0] == 600.0, "full duration compressed replay reloads")
	var file := FileAccess.open(path + ".capacity", FileAccess.READ)
	print("REPLAY CAPACITY: 600s, 3001 frames, 23 enemies, 42 gems; %d bytes; write/read %dms" % [file.get_length(), Time.get_ticks_msec() - started])
	file.close()

func _test_ui(frames: Array, legacy: Array) -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var path := "user://world_ui_test_%d.json" % Time.get_ticks_usec()
	game.records.load_data(path)
	game.sound.set_muted(true)
	check(game.records.record_run(3700, 1, false, {"name": "전장 기록", "mode": "veteran", "ship": "scout", "sector": "storm", "ghost_frames": frames}), "full replay links to saved ranking")
	var entry: Dictionary = game.records.data.leaderboard[0]
	var before := JSON.stringify(game.records.data)
	game._show_replay(entry)
	game.replay_time = 0.2
	game.replay_paused = true
	var cached: Array = game._sample_replay()
	check(is_same(cached, game._sample_replay()), "unchanged replay time reuses the whole-world sample")
	game.replay_time = 0.4
	check(not is_same(cached, game._sample_replay()), "seeking invalidates the cached world sample")
	game.replay_time = 0.2
	cached = game._sample_replay()
	game.replay_frames = game.replay_frames.duplicate(true)
	check(not is_same(cached, game._sample_replay()), "replacing a recording at the same time invalidates the cache")
	await snapshot(game, "replay-full-world")
	check(game.replay_run.enemies.size() == 3 and game.replay_run.items.size() == 2 and game.replay_run.gems.size() == 2, "spectator renderer restores battlefield")
	check(game.replay_run.ship_id == "scout" and game.replay_run.sector_id == "storm", "spectator uses recorded loadout")
	var model_before: Vector2 = game.run.player
	game._physics_process(0.1)
	check(game.replay_time == 0.2 and game.run.player == model_before and JSON.stringify(game.records.data) == before, "spectator pause cannot simulate or award items achievements or scores")
	game.replay_slider.value = 0.8
	await snapshot(game, "replay-seek-spawn")
	check(game.replay_run.enemies.back().kind == "tank" and game.replay_run.gems.is_empty(), "timeline seek restores spawn and pickup removal")
	game.replay_slider.value = 0
	await snapshot(game, "replay-seek-back")
	check(game.replay_run.gems.size() == 2 and game.replay_run.enemies[0].kind == "elite", "backward timeline restores removed objects")
	game.replay_paused = false
	game.replay_speed = 4
	game._physics_process(0.1)
	check(is_equal_approx(game.replay_time, 0.4), "world replay supports four-times playback")
	check(GhostReplay.write(game.records.ghost_path(entry.ghost), legacy), "legacy fixture writes")
	game._show_replay(entry)
	await snapshot(game, "replay-legacy-compatible")
	check(game.screen == "replay" and game.replay_frames[0].size() == 13, "legacy ranking replay remains available")
	var files := [path, path + ".bak", game.records.ghost_path(entry.ghost)]
	game.queue_free()
	await process_frame
	for filename: String in files:
		if FileAccess.file_exists(filename):
			DirAccess.remove_absolute(filename)

func snapshot(game: Node2D, label: String) -> void:
	game.queue_redraw()
	await process_frame
	if DisplayServer.get_name() == "headless":
		if game.replay_frames[0].size() == 14:
			GhostReplay.restore(game.replay_run, GhostReplay.sample(game.replay_frames, game.replay_time))
	elif "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var folder := "res://artifacts/candidate/small" if "--capture-small" in OS.get_cmdline_user_args() else "res://artifacts/candidate"
		DirAccess.make_dir_recursive_absolute(folder)
		check(root.get_texture().get_image().save_png(folder + "/" + label + ".png") == OK, "capture " + label)

func _test_short_events() -> void:
	var model := RunModel.new()
	model.reset(371)
	var ghost := GhostReplay.new()
	ghost.capture(model)
	model.elapsed = 0.05
	var enemy := model.spawn_enemy("runner", model.player + Vector2(100, 0))
	model.spawn_item(model.player + Vector2(80, 0), "A", "heal")
	ghost.capture(model)
	model.elapsed = 0.1
	enemy.pos += Vector2(20, 0)
	model.enemies.clear()
	model.items.clear()
	ghost.capture(model)
	model.elapsed = 0.25
	ghost.capture(model)
	check(ghost.frames.size() == 2 and GhostReplay.valid(ghost.frames), "short-lived events do not require more full snapshots")
	check(GhostReplay.sample(ghost.frames, 0.025)[13].enemies.is_empty(), "no enemy before recorded spawn")
	var frame := GhostReplay.sample(ghost.frames, 0.075)
	check(frame[13].enemies.size() == 1 and frame[13].items.size() == 1, "sub-sample enemy and item appearances are retained")
	check(is_equal_approx(float(frame[13].enemies[0][2][0]), model.player.x + 110), "short-lived enemy movement interpolates over its own lifetime")
	check(GhostReplay.sample(ghost.frames, 0.15)[13].enemies.is_empty() and GhostReplay.sample(ghost.frames, 0.15)[13].items.is_empty(), "short-lived removals use recorded time")
