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
	model.reset(312)
	model._spawn_timer = 10000
	model._shot_timer = 10000
	model._encounter_timer = 10000
	model._explore_at = 10000
	return model

func assign(model: RunModel, id: String, grade: String = "C") -> void:
	model.mission = Expedition.mission(id, grade)
	model.mission.merge({"start": 60.0, "status": "active", "progress": 0.0})
	model.elapsed = 60
	model._next_mission_at = 120

func run_checks() -> void:
	_test_dash()
	_test_missions()
	_test_parts()
	_test_save_replay()
	await _test_ui()
	print("EXPEDITION SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func _test_dash() -> void:
	for frame_dt: float in [0.05, 1.0 / 60.0, 0.03]:
		for offset: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(900, 0), Vector2(0, -1)]:
			var model := fixture()
			var start := model.player
			var aim := offset.normalized() if offset != Vector2.ZERO else model.facing
			model.step(frame_dt, Vector2.ZERO, true, offset)
			while model.dash_time > 0.000001:
				model.step(minf(frame_dt, model.dash_time), Vector2.ZERO, false, -aim)
			check(model.player.distance_to(start + aim * 188.0) < 0.01, "fixed 188px dash near/far/zero across frame rates")
		var locked := fixture()
		locked.step(frame_dt, Vector2.ZERO, true, Vector2.UP)
		locked.step(frame_dt, Vector2.LEFT, false, Vector2.LEFT)
		check(locked.facing == Vector2.UP and absf(locked.player.x - RunModel.CENTER.x) < 0.01, "steering cannot rotate an active dash")
	var a := fixture()
	var b := fixture()
	a.elapsed = 50
	a._tick_mission_clock()
	a.spawn_part(a.player, "elite")
	check(a.rng.randi() == b.rng.randi() and a.item_rng.randi() == b.item_rng.randi(), "mission and parts preserve combat and item RNG")

func _test_missions() -> void:
	var model := fixture()
	model.elapsed = 49.99
	model._tick_mission_clock()
	check(model.mission.is_empty(), "no premature disclosure")
	model.elapsed = 50
	model._tick_mission_clock()
	var first := str(model.mission.id)
	check(model.mission.status == "preview" and model.mission.start == 60, "ten second preview at 00:50")
	model._mission_add(first, 100)
	check(model.mission.progress == 0, "preview actions never count")
	model.elapsed = 60
	model._tick_mission_clock()
	check(model.mission.status == "active", "minute starts mission")
	model.state = "upgrade"
	model.step(1, Vector2.ZERO, true)
	check(model.elapsed == 60 and model.mission.progress == 0, "upgrade freezes schedule")
	model.state = "playing"
	model.elapsed = 110
	model._tick_mission_clock()
	check(model.mission.status == "preview" and model.mission.start == 120 and model.mission.id != first and model.mission_result.size() == 3, "deadline resolves and next mission preview fills ten second rest")
	for id: String in Expedition.MISSION_IDS:
		for grade: String in ["C", "B", "A"]:
			model = fixture()
			assign(model, id, grade)
			var info := Expedition.mission(id, grade)
			if id == "survive":
				model._mission_add(id, int(info.target) - 1)
				model.elapsed = 110
				model._tick_mission_clock()
			elif id == "outer":
				model.player = RunModel.CENTER + Vector2(510, 0)
				model._mission_add(id, info.target)
				check(model.mission.status == "active", "outer objective requires safe return")
				model.player = RunModel.CENTER
				model._update_expedition(0.01, model.player)
			else:
				model._mission_add(id, info.target)
			var rewards := model.part_drops.size() + int(model.parts.core) + int(model.parts.drive) + int(model.parts.shell)
			check(model.missions_completed == 1 and model.mission_bonus_choices == info.upgrades and rewards == info.parts, "tiered reward " + id + grade)
			model._finish_mission(true)
			check(model.missions_completed == 1 and model.part_drops.size() + int(model.parts.core) + int(model.parts.drive) + int(model.parts.shell) == rewards, "completion pays once " + id + grade)
			var hp := model.hp
			var xp := model.xp
			for i in int(info.upgrades):
				model._check_level()
				check(model.state == "upgrade" and model.upgrade_source == "mission" and model.level == 1, "bonus upgrade independent of XP level")
				model.mission_bonus_choices = maxi(0, model.mission_bonus_choices)
				# Choose an actual offered upgrade; keep the next credit for the following loop.
				var pending := model.mission_bonus_choices
				model.mission_bonus_choices = 0
				check(model.choose_upgrade(str(model.get_upgrade_choices()[0])), "bonus uses existing valid three choices")
				model.mission_bonus_choices = pending
			check(model.xp == xp and model.hp >= hp, "mission reward cannot consume XP or inflict damage")
	model = fixture()
	assign(model, "survive", "A")
	model.take_damage(1)
	model.invulnerable = 0
	model.take_damage(1)
	check(model.mission.status == "failed" and model.missions_completed == 0 and model.mission_bonus_choices == 0, "strict less-than hits fails at threshold")
	model = fixture()
	assign(model, "chaser", "A")
	model._mission_add("chaser", model.mission.target)
	model.xp = model.xp_needed
	model._check_level()
	for i in 3:
		check(model.upgrade_source == "mission" and model.state == "upgrade" and model.level == 1, "A reward automatically chains three choices")
		check(model.choose_upgrade(str(model.get_upgrade_choices()[0])), "choose next chained reward")
	check(model.level == 2 and model.state == "upgrade" and model.upgrade_source == "level" and model.xp == 0, "normal XP upgrade follows bonus choices without loss")
	model = fixture()
	assign(model, "chaser")
	model.elapsed = 110
	model._mission_add("chaser", 100)
	check(model.missions_completed == 0, "deadline hit cannot sneak into old objective")
	model = fixture()
	assign(model, "survive")
	model._finish_run("combat")
	check(model.mission.status == "failed", "death fails pending survival")
	model = fixture()
	assign(model, "survive")
	model.elapsed = 109.99
	model.player = RunModel.CENTER + Vector2(690, 0)
	model.hp = 0.001
	model.step(0.02, Vector2.ZERO, false)
	check(model.state == "lost" and model.missions_completed == 0, "lethal deadline frame cannot award survival before applying damage")
	model = fixture()
	assign(model, "chaser")
	model.mission.target = 1
	var enemy := model.spawn_enemy("chaser", model.player + Vector2(200, 0))
	model._kill_enemy(enemy)
	check(model.missions_completed == 1, "real enemy kill hooks objective")

func _test_parts() -> void:
	var model := fixture()
	model.elapsed = 25
	model._explore_at = 25
	model._update_expedition(0.01, model.player)
	check(model.part_drops.size() == 1 and model.boundary_layer(model.part_drops[0].pos) == 2, "exploration drop starts in second layer")
	var point: Vector2 = model.part_drops[0].pos
	model.player = RunModel.CENTER + (point - RunModel.CENTER).normalized() * (RunModel.ACTIVITY_RADIUS - RunModel.PLAYER_RADIUS + RunModel.LAYER_WIDTH - 1)
	model.part_drops[0].pos = model.player
	model._update_expedition(0.01, model.player)
	check(model.part_drops.size() == 1 and model.parts.core == 0 and model.parts.drive == 0 and model.parts.shell == 0, "first layer cannot collect locked exploration reward")
	model.player = point
	model.part_drops[0].pos = point
	model._update_expedition(0.01, model.player)
	check(model.part_drops.is_empty() and model.pending_tech.size() == 1, "direct second layer entry unlocks pickup")
	model = fixture()
	model.spawn_part(model.player + Vector2(80, 0), "mission", "drive")
	var start := model.player
	model.player += Vector2(188, 0)
	model._update_expedition(0.01, start)
	check(model.parts.drive == 1 and model.part_drops.is_empty(), "dash swept path collects parts exactly once")
	for recipe: String in Expedition.RECIPE_IDS:
		model = fixture()
		for id: String in Expedition.recipe(recipe).needs:
			check(model.collect_part(id), "valid part pickup")
		check(model.hull_rank(recipe) == 1 and recipe in model.hull_forms, "first recipe tier " + recipe)
		for id: String in Expedition.recipe(recipe).needs:
			model.collect_part(id)
		check(model.hull_rank(recipe) == 2, "second recipe tier " + recipe)
	model = fixture()
	var power := model._power()
	var speed := model.base_speed()
	model.collect_part("core")
	model.collect_part("drive")
	check(model._power() > power and model.base_speed() == speed + 8, "individual part stats apply immediately")
	model.collect_part("shell")
	var enemy := model.spawn_enemy("tank", model.player + Vector2(240, 0))
	model._fire_player_shot()
	check(model.shots.size() == 2, "battery actually fires two shots")
	model.shots.append({"pos": model.player, "friendly": false})
	model._barrier_timer = 0
	model._update_expedition(0.01, model.player)
	check(model.shots.all(func(s: Dictionary) -> bool: return s.friendly), "aegis removes actual enemy projectiles")
	enemy.pos = model.player + Vector2(90, 0)
	var hp: float = enemy.hp
	model.step(0.01, Vector2.ZERO, true)
	check(float(enemy.hp) < hp, "lancer dash creates damaging shockwave")
	model = fixture()
	model.collect_part("shell")
	model.take_damage(10)
	check(is_equal_approx(model.hp, model.max_hp - 9.6), "armor changes combat damage")
	check(not model.collect_part("bad"), "invalid part rejected")
	model.state = "upgrade"
	check(not model.collect_part("core"), "no paused pickup")
	model.reset(312)
	check(model.parts.core == 0 and model.part_drops.is_empty() and model.pending_tech.is_empty() and model.mission.is_empty(), "new run resets all temporary progression")

func _test_save_replay() -> void:
	var path := "user://expedition-test-%d.json" % Time.get_ticks_usec()
	var store := SaveStore.new()
	store.load_data(path)
	store.data.best_score = 9876
	store.data.muted = true
	var model := fixture()
	for id: String in Expedition.PART_IDS:
		model.collect_part(id)
	assign(model, "returns")
	model._mission_add("returns", 1)
	check(store.record_tech(model.pending_tech), "immediate discovery saves")
	var reload := SaveStore.new()
	reload.load_data(path)
	check(reload.data.discovered_parts.size() == 3 and reload.data.discovered_hulls.size() == 4 and reload.data.best_score == 9876 and reload.data.muted, "new discoveries preserve old settings and scores")
	check("part_types" in reload.data.achievements and "hull_trinity" in reload.data.achievements and "missions_0" in reload.data.achievements, "new achievements grant persistent points")
	check(reload.record_run(100, 60, false, model.run_stats) and reload.data.achievement_progress.missions == 1, "result does not double count immediate missions")
	var broken := SaveStore.new()
	broken.load_data("user://missing-tech-%d/save.json" % Time.get_ticks_usec())
	check(not broken.record_tech(model.pending_tech) and broken.data.discovered_parts.is_empty(), "failed atomic save rolls back research")
	var ghost := GhostReplay.new()
	model.elapsed = 0
	ghost.capture(model, true)
	check(GhostReplay.valid(ghost.frames), "new ghost fields validate")
	var restored := fixture()
	GhostReplay.restore(restored, ghost.frames[0])
	check(restored.parts == model.parts and restored.part_drops.size() == model.part_drops.size() and restored.mission.id == model.mission.id and restored.pending_tech.is_empty(), "ghost restores progression visuals without awarding items")
	var old: Array = ghost.frames.duplicate(true)
	old[0][13].erase("expedition")
	check(GhostReplay.valid(old), "pre-expedition world ghosts still validate")
	GhostReplay.restore(restored, old[0])
	check(restored.parts.core == 0 and restored.mission.is_empty(), "legacy ghost clears new visuals")
	var invalid: Array = ghost.frames.duplicate(true)
	invalid[0][13].expedition.parts[0] = INF
	check(not GhostReplay.valid(invalid), "corrupt progression rejected")
	check(GhostReplay.write(path + ".ghost", ghost.frames), "new ghost serializes")
	check(GhostReplay.read(path + ".ghost").size() == 1, "new ghost JSON round trip")
	for suffix: String in ["", ".bak", ".tmp", ".ghost"]:
		DirAccess.remove_absolute(path + suffix)

func _test_ui() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound.set_muted(true)
	var path := "user://expedition-ui-%d.json" % Time.get_ticks_usec()
	game.records.load_data(path)
	game.run.reset(312)
	game._resume()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.get_global_transform_with_canvas() * (game.run.player + Vector2(0, 1))
	game._unhandled_input(click)
	check(game.dash_queued and game.dash_aim == Vector2.DOWN, "near click aims despite movement deadzone")
	click.position = game.get_global_transform_with_canvas() * game.run.player
	game._unhandled_input(click)
	check(game.dash_aim.is_zero_approx(), "exact center click safely falls back to facing")
	game.camera_offset = Vector2(200, -80)
	click.position = game.get_global_transform_with_canvas() * (game.run.player - game.camera_offset + Vector2(1, 0))
	game._unhandled_input(click)
	check(game.dash_aim == Vector2.RIGHT, "camera-correct cursor aim")
	game.camera_offset = Vector2.ZERO
	for id: String in Expedition.PART_IDS:
		game.run.collect_part(id)
	game.run.spawn_part(RunModel.CENTER + Vector2(650, 0), "explore", "drive")
	for id: String in Expedition.MISSION_IDS:
		for state: String in ["preview", "active", "success", "failed"]:
			assign(game.run, id, "A")
			game.run.mission.status = state
			game.run.mission.progress = 1
			game.run.elapsed = 55 if state == "preview" else 75
			await snapshot(game, id + "-" + state)
	game.records.record_tech(game.run.pending_tech)
	game.codex_tab = "tech"
	game._open_arsenal("pause")
	for child: Node in game.ui.get_children():
		if child is Control and child.name != "Shade":
			check(child.get_rect().end.x <= 1280 and child.get_rect().end.y <= 720, "tech codex controls fit base viewport: %s %s" % [child.get_rect(), child.get("text")])
	await snapshot(game, "tech-codex")
	game._close_arsenal()
	check(game.screen == "playing" and not game.dash_queued, "codex resumes safely")
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)
	game.queue_free()
	await process_frame

func snapshot(game: Node, label: String) -> void:
	# Desktop focus loss can pause a visual fixture while the user works in another app.
	for attempt in 3:
		if label != "tech-codex" and game.screen == "pause":
			game._resume()
		if game.screen == "playing":
			game._update_hud()
		game.queue_redraw()
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		if label == "tech-codex" or game.screen == "playing":
			break
	if DisplayServer.get_name() != "headless":
		var capture := root.get_texture().get_image()
		check(not capture.is_empty(), "mission UI renders " + label)
		if label.ends_with("success"):
			var scale := float(capture.get_width()) / 1280.0
			var pixel := capture.get_pixel(int(640 * scale), int(163 * scale))
			check(pixel.g > 0.75 and pixel.r > 0.5, "success progress bar is visibly filled: " + label)
		if "--capture" in OS.get_cmdline_user_args():
			var folder := "res://artifacts/candidate/expedition-small" if "--capture-small" in OS.get_cmdline_user_args() else "res://artifacts/candidate/expedition"
			DirAccess.make_dir_recursive_absolute(folder)
			check(capture.save_png(folder + "/" + label + ".png") == OK, "save mission visual " + label)
