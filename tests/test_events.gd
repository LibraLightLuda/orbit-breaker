extends SceneTree

var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func fixture() -> RunModel:
	var model := RunModel.new()
	model.reset(311)
	model._hazard_timer = 10000.0
	model._spawn_timer = 10000.0
	model._shot_timer = 10000.0
	return model

func run_checks() -> void:
	_test_lanes()
	_test_schedule()
	_test_gravity()
	_test_planet()
	_test_damage()
	_test_replay()
	await _test_render()
	print("EVENT SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func _test_lanes() -> void:
	var model := fixture()
	for offset: Vector2 in [Vector2.ZERO, Vector2(750, 700), Vector2(-750, -700)]:
		model.player = RunModel.CENTER + offset
		for attempt in 12:
			model.hazards.clear()
			model._add_lane()
			var lane: Dictionary = model.hazards[0]
			var rect: Rect2 = lane.rect
			var vertical := rect.size.y > rect.size.x
			var outer_point: Vector2 = rect.get_center() + (Vector2(0, 850) if vertical else Vector2(850, 0))
			check(rect.has_point(outer_point), "lane covers outer third layer on both orientations")
			model.player = outer_point
			model.hp = 100
			model.invulnerable = 0
			lane.active = true
			model._update_hazards(0.01)
			check(model.hp == 87, "full-arena visual lane matches actual outer damage")
			check(model.effects.any(func(e: Dictionary) -> bool: return e.kind == "impact_lane"), "electric hit has a distinct cue")

func _test_schedule() -> void:
	var previous := 1000.0
	for difficulty: String in ["relaxed", "normal", "veteran", "cataclysm"]:
		var model := fixture()
		model.reset(311, difficulty)
		var interval := model._encounter_timer
		check(interval < previous, "harder mode schedules events more often")
		previous = interval
		var same := fixture()
		same.reset(311, difficulty)
		check(model.rng.state == same.rng.state and interval == same._encounter_timer, "event seed remains deterministic without consuming combat RNG")
	for sector: String in GameContent.SECTOR_IDS:
		var model := fixture()
		model.sector_id = sector
		model._encounter_timer = 0.0
		model._update_hazards(0.05)
		check(model.hazards.size() == 1 and model.hazards[0].warn == 10.0, "all sectors schedule a full ten-second telegraph")
		check(model.events.has("event_warning"), "scheduled event sounds an alarm")
	for kind: String in RunModel.ENCOUNTERS:
		var model := fixture()
		check(model._add_encounter(kind, RunModel.CENTER), "can schedule each event")
		var event: Dictionary = model.hazards[0]
		var position: Vector2 = event.pos
		model._update_hazards(9.99)
		check(not event.active and event.pos == position, "location stays fixed and event cannot start early")
		model.state = "upgrade"
		model.step(1.0, Vector2.RIGHT, false)
		model._update_hazards(1.0)
		check(not event.active and model.elapsed == 0.0, "upgrades pause warning and combat clocks")
		model.state = "playing"
		model._update_hazards(0.011)
		check(event.active and model.events.has("event_start"), "event activates after full warning with sound")
		check(not model._add_encounter("black_hole"), "common events do not overlap")
		model.reset(311)
		check(model.hazards.is_empty() and not model._planet_seen, "restart clears all encounter state")
	var full := fixture()
	for i in 6:
		full._add_blast(RunModel.CENTER, 60)
	full._encounter_timer = 0
	full._update_hazards(0.1)
	check(full.hazards.size() == 6 and not full._planet_seen, "capacity defers events without consuming the unique planet")

func _test_gravity() -> void:
	var model := fixture()
	model._add_encounter("black_hole", RunModel.CENTER)
	check(model.gravity_pull(RunModel.CENTER + Vector2(20, 0)) == Vector2.ZERO, "telegraphed black hole cannot pull")
	model.hazards[0].active = true
	var near := RunModel.CENTER + Vector2(25, 0)
	var far := RunModel.CENTER + Vector2(180, 0)
	check(model.gravity_pull(near).length() > model.gravity_pull(far).length(), "pull grows toward core")
	check(model.gravity_drag(near) < model.gravity_drag(far) and is_equal_approx(model.gravity_drag(RunModel.CENTER), 0.18), "core strongly slows ordinary thrust")
	check(model.gravity_pull(RunModel.CENTER).is_finite() and model.gravity_drag(RunModel.CENTER + Vector2(231, 0)) == 1.0, "core is finite and outside radius unaffected")
	model.player = near
	model.step(0.05, Vector2.RIGHT, false)
	check(model.player.x < near.x, "ordinary thrust cannot easily escape core")
	model.player = near
	model.dash_cooldown = 0
	model.step(0.05, Vector2.RIGHT, true)
	check(model.player.x > near.x, "outward dash still gives escape opportunity")
	model.player = far
	model.orbit_count = 0
	var enemy := model.spawn_enemy("chaser", near)
	model._update_enemies(0.05, model.player)
	check(Vector2(enemy.pos).x < near.x, "hostile target is pulled despite chasing outward")
	model.enemies.clear()
	for friendly: bool in [true, false]:
		model.shots.append({"pos": near, "velocity": Vector2(0, 80), "friendly": friendly, "radius": 4.0, "damage": 10.0, "ttl": 5.0})
	model._update_shots(0.05)
	check(model.shots.size() == 2 and model.shots.all(func(s: Dictionary) -> bool: return Vector2(s.velocity).x < 0), "both friendly and hostile projectiles bend inward")
	model._update_hazards(16.1)
	check(model.hazards.is_empty() and model.gravity_pull(near) == Vector2.ZERO, "expired black hole releases all objects")

func _test_planet() -> void:
	var model := fixture()
	model._add_encounter("planet", RunModel.CENTER)
	var planet: Dictionary = model.hazards[0]
	planet.active = true
	model._update_hazards(6)
	check(planet.hold == 6 and model.score == 0, "partial defense grants no reward")
	model.player += Vector2(159, 0)
	model._update_hazards(0.01)
	check(planet.hold == 0, "leaving defense radius resets continuous hold")
	model.player = RunModel.CENTER
	model._update_hazards(11.99)
	check(model.score == 0, "defense cannot complete early")
	model._update_hazards(0.02)
	check(model.score == 5000 and model.xp == 45 and model.items.size() == 1, "successful hold pays large score XP and item once")
	check(model.items[0].grade == "A" and model.items[0].id == "power", "defense reward is guaranteed A-grade offensive core")
	check(model.hazards.is_empty() and not model._add_encounter("planet"), "completed planet cannot recur this run")
	model._update_hazards(0.1)
	check(model.score == 5000, "reward cannot be farmed after completion")
	model = fixture()
	model._add_encounter("planet")
	model.hazards[0].active = true
	model.player = RunModel.CENTER + Vector2(600, 0)
	model._update_hazards(30.1)
	check(model.score == 0 and not model._add_encounter("planet"), "failed defense expires without reward or retry")

func _test_damage() -> void:
	for kind: String in ["meteor", "flare"]:
		var model := fixture()
		model._add_encounter(kind, RunModel.CENTER)
		var hazard: Dictionary = model.hazards[0]
		model.player = RunModel.meteor_points(hazard)[0] if kind == "meteor" else RunModel.CENTER + Vector2(160, 0)
		model._update_hazards(1.0)
		check(model.hp == 100, "event telegraph deals no damage")
		hazard.active = true
		if kind == "flare":
			hazard.ttl = 1.5
		model._update_hazards(0.01)
		check(model.hp < 100 and model.effects.any(func(e: Dictionary) -> bool: return e.kind == "impact_" + kind), "event damage has its own hit feedback")
		var health := model.hp
		model._update_hazards(0.01)
		check(model.hp == health, "event respects existing combat immunity")
		model = fixture()
		model._add_encounter(kind, RunModel.CENTER)
		model.hazards[0].active = true
		model.player += Vector2(400, 0)
		model._update_hazards(0.01)
		check(model.hp == 100, "outside event area stays safe")
	var model := fixture()
	model.player += Vector2(650, 0)
	model.step(0.01, Vector2.ZERO, false)
	check(model.effects.any(func(e: Dictionary) -> bool: return e.kind == "impact_boundary"), "outer-layer damage gets feedback without changing hull economics")

func _test_replay() -> void:
	var model := fixture()
	model._add_encounter("planet")
	model.hazards[0].hold = 4.5
	var ghost := GhostReplay.new()
	ghost.capture(model)
	check(GhostReplay.valid(ghost.frames), "new event snapshot validates")
	var replay := fixture()
	GhostReplay.restore(replay, ghost.frames[0])
	check(replay.hazards[0].hold == 4.5 and replay.hazards[0].kind == "planet", "replay preserves event kind and defense progress")
	var legacy := ghost.frames.duplicate(true)
	legacy[0][13].hazards[0].pop_back()
	for event: Array in legacy[0][13].events:
		if event[1] == "hazards":
			event[3].pop_back()
	check(GhostReplay.valid(legacy), "existing shorter hazard snapshots stay readable")
	GhostReplay.restore(replay, legacy[0])
	check(replay.hazards[0].hold == 0.0, "legacy hazards receive default defense progress")

func _test_render() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://test_events_%d.json" % Time.get_ticks_usec())
	game.sound.set_muted(true)
	await process_frame
	game._start_run()
	game.set_physics_process(false)
	for reduced: bool in [false, true]:
		game.records.data.reduced_motion = reduced
		for kind: String in RunModel.ENCOUNTERS:
			game.run = fixture()
			game.run._add_encounter(kind, RunModel.CENTER + Vector2(100, 30))
			for active: bool in [false, true]:
				game.run.hazards[0].active = active
				game.run.hazards[0].hold = 7.0
				game.run.hazards[0].ttl = float(RunModel.ENCOUNTERS[kind].duration) * 0.5
				game.run.take_damage(5.0, kind if kind in ["meteor", "flare"] else "combat", game.run.player + Vector2(70, 0))
				var target: Dictionary = game.run.spawn_enemy("tank", RunModel.CENTER + Vector2(160, -60))
				game.run._hit_enemy(target, 10)
				game.run.shots.append({"pos": RunModel.CENTER + Vector2(150, 80), "velocity": Vector2(-120, -60), "friendly": false, "radius": 7.0})
				game._update_hud()
				check(str(RunModel.ENCOUNTERS[kind].name) in game.hud.phase.text and "s" in game.hud.phase.text, "central status keeps event identity and remaining time")
				game.queue_redraw()
				await process_frame
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					var capture := root.get_texture().get_image()
					var scale := float(capture.get_width()) / 1280.0
					var hint_pixels := 0
					for x in range(int(438 * scale), int(716 * scale)):
						for y in range(int(78 * scale), int(99 * scale)):
							var color := capture.get_pixel(x, y)
							if color.r > 0.4 and color.g > 0.4 and color.b > 0.4:
								hint_pixels += 1
					check(hint_pixels > 20, "central event status remains visible over existing toast")
					if "--capture" in OS.get_cmdline_user_args():
						var folder := "res://artifacts/candidate/events-small" if "--capture-small" in OS.get_cmdline_user_args() else "res://artifacts/candidate/events"
						DirAccess.make_dir_recursive_absolute(folder)
						check(capture.save_png("%s/%s-%s-%s.png" % [folder, kind, "active" if active else "warning", "reduced" if reduced else "full"]) == OK, "event screenshot saved")
				check(game.run.hazards.size() == 1, "event scene draws at both effect settings")
	game.camera_offset = Vector2(1200, 0)
	game.run.player = RunModel.CENTER + Vector2(1200, 0)
	game.toast_time = 0
	game.queue_redraw()
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var capture := root.get_texture().get_image()
		var scale := float(capture.get_width()) / 1280.0
		var arrow_pixels := 0
		for x in range(int(32 * scale), int(65 * scale)):
			for y in range(int(370 * scale), int(420 * scale)):
				var color := capture.get_pixel(x, y)
				if color.r > 0.85 and color.g > 0.55 and color.b < 0.65:
					arrow_pixels += 1
		check(arrow_pixels > 10, "offscreen event keeps a visible direction marker")
		if "--capture" in OS.get_cmdline_user_args():
			var suffix := "-small" if "--capture-small" in OS.get_cmdline_user_args() else ""
			check(capture.save_png("res://artifacts/candidate/event-offscreen%s.png" % suffix) == OK, "offscreen event screenshot saved")
	game.queue_free()
	await process_frame
