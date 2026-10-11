extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _init() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	_test_late_game()
	_test_evolutions()
	_test_collision()
	_test_stream()
	await _test_result()
	print("FEEDBACK SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func _test_late_game() -> void:
	var model := RunModel.new()
	model.reset(380)
	model.boss_spawned = true
	model.boss_defeated = true
	model.upgrades.repair = 3
	model.elapsed = 359.99
	model.step(0.02, Vector2.ZERO, false)
	var boss: Dictionary = model.enemies.filter(func(e: Dictionary) -> bool: return e.kind == "boss")[0]
	check(boss.boss_wave == 1 and is_equal_approx(float(boss.max_hp) / model.enemy_strength(), 4860.0), "first pursuit boss has 35 percent more HP before shared pressure")
	for i in 10:
		model.step(0.01, Vector2.ZERO, false)
	check(model.enemies.filter(func(e: Dictionary) -> bool: return e.kind == "boss").size() == 1, "pursuit does not repeat before its next scheduled wave")
	model.elapsed = 390.0
	var pressure := model.decay_rate()
	model.hp = 50.0
	var scheduled := model.next_boss_at
	boss.hp = 0.0
	model._update_enemies(0.01, model.player)
	check(model.bosses_killed == 1 and model.relief_until == 415.0 and model.next_boss_at == scheduled, "boss kill grants relief without postponing scheduled reinforcements")
	check(is_equal_approx(model.decay_rate(), pressure * 0.55) and model.hp == 50.0, "boss reward relieves decay without free healing")
	check(model.score >= 2400 and model.xp >= 45.0, "boss kill rewards offensive score and upgrade experience")
	model.elapsed = 449.99
	model.state = "playing"
	model.step(0.02, Vector2.ZERO, false)
	boss = model.enemies.filter(func(e: Dictionary) -> bool: return e.kind == "boss")[0]
	check(boss.boss_wave == 2 and float(boss.max_hp) > 4860.0, "second pursuit scales further")
	model.elapsed = 480.0
	var lull := model.decay_rate()
	model.elapsed = 500.0
	check(lull < model.decay_rate() * 0.6, "twenty-second periodic lull ends at exact boundary")
	model.elapsed = 480.0
	model.state = "upgrade"
	model.step(1.0, Vector2.ZERO, false)
	check(model.elapsed == 480.0, "upgrade freezes lull and pursuit clocks")
	model.state = "playing"
	model.max_hp = 1000000.0
	model.hp = model.max_hp
	model.elapsed = 599.99
	model.survival_cleared = true
	model.step(0.02, Vector2.ZERO, false)
	check(model.state == "won" and model.hp == 0.0 and model.end_reason == "collapse", "ten-minute forced end survives relaxed decay")
	model.reset(380)
	check(model.bosses_killed == 0 and model.relief_until == 0.0 and model.next_boss_at == 330.0, "restart clears pursuit state")

func _test_evolutions() -> void:
	var model := RunModel.new()
	model.reset(381)
	model.upgrades = {"rapid": 5, "power": 3}
	model._check_evolutions()
	var target := model.spawn_enemy("boss", model.player + Vector2(300, 0))
	model._fire_player_shot()
	check(model.evolution_mastery("rail") == 2 and model.shots[0].pierce == 5, "rail mastery adds real penetration")
	check(float(model.shots[0].damage) > 19.0 * model._power() * 1.6, "rail mastery increases actual damage")
	model.reset(381)
	model.upgrades = {"pulse": 5, "magnet": 2}
	model._check_evolutions()
	target = model.spawn_enemy("boss", model.player + Vector2(260, 0))
	model.shots.append({"pos": model.player, "friendly": false})
	model.shots.append({"pos": model.player + Vector2(500, 0), "friendly": false})
	model.shots.append({"pos": model.player, "friendly": true})
	model._update_weapons(0.01)
	check(model.shots.size() == 2 and float(target.hp) < float(target.max_hp), "nova destroys only hostile shots inside radius and damages targets")
	check(is_equal_approx(model._pulse_timer, 4.3 * 0.76), "nova mastery reduces cooldown")
	model.reset(381)
	model.upgrades = {"frost": 5, "orbit_range": 2}
	model._check_evolutions()
	target = model.spawn_enemy("boss", model.orbit_position(0))
	model._update_enemies(0.001, model.player)
	check(model.evolution_mastery("blizzard") == 2 and float(target.slow_factor) <= 0.16 and float(target.slow_time) > 3.0, "blizzard mastery affects actual slowing duration and factor")
	for id: String in ["frost", "missile", "chain", "pulse"]:
		check(RunModel.upgrade_info(id).cap == 5, "weapon retains post-evolution levels " + id)
	model.upgrades.orbit = 1
	for i in 30:
		model.state = "upgrade"
		model._choices.clear()
		var choices := model.get_upgrade_choices()
		check(choices.size() == 3 and (choices.has("repair") or choices.has("vitality") or choices.has("restore")) and (choices.has("orbit_range") or choices.has("orbit") or choices.has("power")), "choices keep recovery and reachable evolution")

func _test_collision() -> void:
	var model := RunModel.new()
	model.reset(382)
	model.player = Vector2(-400, -400)
	for x in range(-3, 4):
		for y in range(-3, 4):
			model.spawn_enemy("tank", Vector2(x * 128 + 0.1, y * 128 - 0.1))
	for index in model.enemies.size():
		var enemy: Dictionary = model.enemies[index]
		var previous_hp: float = enemy.hp
		model.shots.append({"pos": Vector2(enemy.pos) - Vector2(100, 0), "velocity": Vector2(2000, 0), "friendly": true, "radius": 5.0, "damage": 1.0, "ttl": 1.0})
		model._update_shots(0.05)
		check(float(enemy.hp) == previous_hp - 1.0, "swept collision spans negative coordinates and cell edges")
	model.reset(382)
	model.upgrades = {"rapid": 3, "power": 3}
	model._check_evolutions()
	for i in 3:
		model.spawn_enemy("tank", model.player + Vector2(20 + i * 25, 0))
	model._fire_player_shot()
	model._update_shots(0.1)
	check(model.shots.is_empty() and model.enemies.all(func(e: Dictionary) -> bool: return float(e.hp) < float(e.max_hp)), "rail sweeps three distinct targets in one update")
	model.reset(382)
	var enemy := model.spawn_enemy("boss", model.player + Vector2(200, 0))
	model.shots.append({"pos": enemy.pos, "velocity": Vector2.ZERO, "friendly": true, "radius": 5.0, "damage": 1.0, "ttl": 1.0, "pierce": 3, "hit_ids": []})
	model._update_shots(0.01)
	var hp: float = enemy.hp
	model._update_shots(0.01)
	check(enemy.hp == hp, "piercing shot cannot hit same enemy twice")

func _test_stream() -> void:
	var model := RunModel.new()
	model.reset(383)
	var ghost := GhostReplay.new()
	for i in 41:
		model.elapsed = i * 0.2
		model.player.x += 1
		ghost.capture(model, true)
	var expected := ghost.frames.duplicate(true)
	var path := "user://feedback-stream.json"
	var writer := GhostReplay.new()
	check(writer.begin_write(path, ghost.frames), "chunk writer starts without serializing whole replay")
	check(not FileAccess.file_exists(path), "incomplete replay never published")
	var slices := 0
	while not writer.write_slice(1):
		slices += 1
	check(slices >= 10 and writer.save_ok, "writer yields across frames and completes atomically")
	var loaded := GhostReplay.read(path)
	check(loaded == JSON.parse_string(JSON.stringify(expected)), "chunked replay round trips through JSON precision")
	var file := FileAccess.open(path, FileAccess.READ)
	var bytes := file.get_buffer(file.get_length() - 4)
	file.close()
	file = FileAccess.open(path + ".broken", FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	check(GhostReplay.read(path + ".broken").is_empty(), "missing commit marker rejects interrupted replay")
	writer = GhostReplay.new()
	check(writer.begin_write(path + ".cancel", expected.duplicate(true)), "cancel fixture starts")
	writer.write_slice(1)
	writer.cancel_write()
	check(not FileAccess.file_exists(path + ".cancel.tmp") and not writer.save_ok, "cancel removes partial file")
	var invalid: Array = expected.duplicate(true)
	invalid[8][0] = -1.0
	writer = GhostReplay.new()
	check(writer.begin_write(path + ".invalid", invalid), "invalid later frame reaches worker validation")
	writer.start_background()
	while not writer.poll_write():
		OS.delay_usec(1000)
	check(not writer.save_ok and not FileAccess.file_exists(path + ".invalid.tmp"), "worker validation failure cleans up without waiting on itself")
	writer = GhostReplay.new()
	var discarded := expected.duplicate(true)
	writer.begin_discard(discarded)
	writer.start_background()
	while not writer.poll_write():
		OS.delay_usec(1000)
	check(discarded.all(func(frame: Variant) -> bool: return frame == null), "non-record replay memory releases in background")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".broken")

func _test_result() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://feedback-result.json")
	game.sound.set_muted(true)
	game.run.reset(384)
	game.ghost = GhostReplay.new()
	for i in 31:
		game.run.elapsed = i * 0.2
		game.ghost.capture(game.run, true)
	game.run.state = "lost"
	game.run.score = 1234
	var started := Time.get_ticks_usec()
	game._show_result()
	print("RESULT TRANSITION: %.3fms; %d queued ghost" % [(Time.get_ticks_usec() - started) / 1000.0, game.ghost_jobs.size()])
	check(game.saved_result and game.records.data.runs == 1 and game.ghost_jobs.size() == 1, "score commits immediately and ghost is deferred")
	game._show_result()
	check(game.records.data.runs == 1 and game.ghost_jobs.size() == 1, "result redisplay cannot double save")
	game._start_run()
	check(game.screen == "playing", "retry remains available during ghost saving")
	while not game.ghost_jobs.is_empty():
		game._poll_ghost_save()
		await process_frame
	var entry: Dictionary = game.records.data.leaderboard[0]
	check(not entry.ghost.is_empty() and game.records.load_ghost(entry).size() == 31, "completed ghost attaches to original ranking after retry")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		game._open_arsenal("pause")
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var folder := "res://artifacts/candidate/small" if "--capture-small" in OS.get_cmdline_user_args() else "res://artifacts/candidate"
		check(root.get_texture().get_image().save_png(folder + "/feedback-six-evolutions.png") == OK, "six evolutions render at target size")
	var path := "user://feedback-result.json"
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)
	DirAccess.remove_absolute(game.records.ghost_path(entry.ghost))
	game.queue_free()
	await process_frame
	await process_frame
