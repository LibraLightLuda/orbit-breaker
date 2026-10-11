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

func fixture() -> RunModel:
	var model := RunModel.new()
	model.reset(315)
	model._spawn_timer = 10000
	model._shot_timer = 10000
	model._hazard_timer = 10000
	model._encounter_timer = 10000
	return model

func run_checks() -> void:
	for layer in 4:
		var model := fixture()
		model.player = RunModel.CENTER + Vector2.RIGHT * (RunModel.ACTIVITY_RADIUS - RunModel.PLAYER_RADIUS + (layer - 0.5) * RunModel.LAYER_WIDTH) if layer > 0 else RunModel.CENTER
		var multiplier: float = [1.0, 1.25, 1.6, 2.1][layer]
		check(model.risk_multiplier() == multiplier, "reward tier %d" % layer)
		var enemy := model.spawn_enemy("chaser", RunModel.CENTER)
		model._kill_enemy(enemy)
		check(model.score == roundi(21 * multiplier) and model.gems[0].value == 1.0, "kill score uses pilot layer, XP is not multiplied before pickup")
		model.gems[0].pos = model.player
		model._collect_gems(0)
		check(is_equal_approx(model.xp, multiplier), "pickup multiplier applied once")
		check(model.effects.any(func(e: Dictionary) -> bool: return e.kind == "risk_xp" and is_equal_approx(Vector2(e.end).x, multiplier)), "every XP gain carries its actual region multiplier")
		if layer > 0:
			check(model.net_hull_rate() < 0, "risk reward requires actual hull exposure")
			var health := model.hp
			model.invulnerable = 100
			model._update_vitals(0.1)
			check(model.hp < health, "dash immunity cannot avoid outer reward cost")
			model.gems.clear()
			for i in 300:
				model.gems.append({"pos": RunModel.CENTER, "kind": "xp", "value": 1.0})
			var before := model.xp
			model._kill_enemy(model.spawn_enemy("chaser", RunModel.CENTER))
			check(is_equal_approx(model.xp - before, multiplier), "full gem buffer follows same multiplier")
			model.player = RunModel.CENTER
			model._grant_xp(10)
			check(is_equal_approx(model.xp, before + multiplier + 10), "return immediately removes bonus")
	var model := fixture()
	model._grant_xp(1)
	model.effects.back().ttl = 0.2
	model._grant_xp(2)
	check(model.effects.size() == 1 and model.effects[0].radius == 3 and model.effects[0].ttl == 1.1, "rapid gains aggregate and refresh without overlapping")
	model._risk_feedback("risk_score", 21)
	check(model.effects.size() == 2, "XP and score occupy separate feedback channels")
	model.player = RunModel.CENTER + Vector2(700, 0)
	model._grant_xp(1)
	check(is_equal_approx(model.effects.back().end.x, 1.6) and is_equal_approx(model.effects.back().radius, 1.6), "region transition preserves the multiplier of the gain")
	model._risk_feedback("risk_xp", 0)
	check(model.effects.size() == 3, "zero gain emits no visual cue")
	model.player = RunModel.CENTER
	model._grant_xp(4)
	check(model.effects.size() == 4 and model.effects.back().end.x == 1.0 and model.effects.back().radius == 4, "rapid return cannot reuse an older cue behind the current region")
	model = fixture()
	check(model._explore_at == 90, "exploration starts later")
	model.elapsed = 89.99
	model._update_expedition(0, model.player)
	check(model.part_drops.is_empty(), "no early exploration part")
	model.elapsed = 90
	model._update_expedition(0, model.player)
	check(model.part_drops.size() == 1 and model._explore_at == 195, "rare exploration cadence")
	var drop: Dictionary = model.part_drops[0]
	check(model.boundary_depth(drop.pos) * 3 > 1.7 and drop.locked, "part requires deeper second-layer expedition")
	for kind: String in ["elite", "boss"]:
		model = fixture()
		model._kill_enemy(model.spawn_enemy(kind, model.player))
		check(model.part_drops.is_empty() and model.items.size() == 1, "strong enemies retain supplies without easy parts")
	for grade: String in ["C", "B", "A"]:
		check(Expedition.mission("returns", grade).parts == (1 if grade == "A" else 0), "only high-rank mission gives a part")
	model = fixture()
	model._add_encounter("planet", RunModel.CENTER)
	var planet: Dictionary = model.hazards[0]
	planet.active = true
	model.player.x += float(planet.radius) + RunModel.PLAYER_RADIUS
	model._update_hazards(3)
	check(planet.hold == 3, "exact hull tangency counts inside defense circle")
	model.player.x += 0.01
	model._update_hazards(0.01)
	check(planet.hold == 0, "fully outside circle resets hold")
	model = fixture()
	var enemy := model.spawn_enemy("tank", RunModel.CENTER + Vector2(300, 0))
	enemy.hp *= 0.5
	var early: float = enemy.max_hp
	model.elapsed = 450
	model._scale_enemy(enemy)
	check(enemy.max_hp > early * 1.9 and is_equal_approx(enemy.hp / enemy.max_hp, 0.5), "living enemies strengthen while preserving damage fraction")
	var grown: float = enemy.hp
	model._scale_enemy(enemy)
	check(enemy.hp == grown, "pressure cannot compound per frame")
	model.collect_part("core")
	model._scale_enemy(enemy)
	check(enemy.hp > grown, "installed parts increase enemy resistance modestly")
	for lv in [10, 20, 30]:
		model = fixture()
		model.level = lv - 1
		model.xp = model.xp_needed
		model._check_level()
		check(model.level == lv and is_equal_approx(model.xp_needed, 9.0 + (lv - 1) * 4.0 + 0.7 * pow(maxi(0, lv - 10), 2)), "progressive level requirement")
	model = fixture()
	model.upgrades.repair = 5
	model.apply_item("repair", "A")
	model.elapsed = 480
	check(is_equal_approx(model.repair_efficiency(), 0.3), "late repair efficiency has a bounded floor")
	check(model.net_hull_rate() < 0, "maximum repair including A buff loses hull even during lull")
	model.hp = 10
	model.apply_item("heal", "A")
	check(is_equal_approx(model.hp, 31), "instant healing observes attrition efficiency")
	model.state = "upgrade"
	var elapsed := model.elapsed
	var health := model.hp
	model.step(1, Vector2.ZERO, false)
	check(model.elapsed == elapsed and model.hp == health, "pressure stops during upgrade")
	for sector: String in ["storm", "forge"]:
		var sizes: Array[float] = []
		for time in [0, 300, 600]:
			model = fixture()
			model.sector_id = sector
			model.elapsed = time
			model._hazard_timer = 0
			model._update_hazards(0.01)
			var h: Dictionary = model.hazards[0]
			sizes.append(minf(h.rect.size.x, h.rect.size.y) if sector == "storm" else float(h.radius))
			check(model.hazards.size() == (mini(5, 1 + floori(time / 120.0)) if sector == "storm" else (3 if time >= 300 else 2)), "hazard simultaneity grows within cap")
			check(model.hazards.all(func(v: Dictionary) -> bool: return not v.active and v.warn >= 1.4), "scaled hazards retain full warning")
		check(sizes[0] < sizes[1] and sizes[1] < sizes[2] and sizes[2] <= sizes[0] * 1.46, "hazard area grows moderately")
	await render_checks()
	print("FEEDBACK315 SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func render_checks() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound.set_muted(true)
	var path := "user://feedback315-%d.json" % Time.get_ticks_usec()
	game.records.load_data(path)
	game.run = fixture()
	game._resume()
	for id: String in Expedition.MISSION_IDS:
		game.run.mission = Expedition.mission(id, "A")
		game.run.mission.merge({"start": 60.0, "progress": 2.0, "status": "active"})
		var text: String = game.mission_progress_text(game.run)
		check(("2.0" in text) == (id == "outer"), "integer counters, fractional seconds only: " + id)
	game.run.mission.status = "success"
	game.run.mission.progress = game.run.mission.target
	game.run.elapsed = 480
	game.run.player = RunModel.CENTER + Vector2(700, 0)
	game.camera_offset = game._camera_target(game.run.player)
	game.run.sector_id = "storm"
	game.run._hazard_timer = 0
	game.run._update_hazards(0.01)
	game.run.spawn_enemy("boss", RunModel.CENTER + Vector2(950, -200))
	game.run.spawn_enemy("elite", RunModel.CENTER + Vector2(-950, 100))
	game.run.spawn_part(RunModel.CENTER + Vector2(720, -100), "explore", "shell")
	game.run.spawn_item(RunModel.CENTER + Vector2(-700, 100), "A", "heal")
	game.run._grant_xp(10)
	game.run._risk_feedback("risk_score", 160)
	game.run.current_speed = game.run.base_speed() * game.run.movement_multiplier(game.run.player)
	game._resume()
	for reduced: bool in [false, true]:
		game.records.data.reduced_motion = reduced
		game._update_hud()
		game.queue_redraw()
		await process_frame
		check("붕괴권 2" in game.hud.risk.text and "×" not in game.hud.risk.text and "수리 30%" in game.hud.vital_detail.text, "central region is compact; reward multiplier appears only with gains")
		check(game.hud.hp.position.x < 410 and game.hud.speed.position.x < 410 and game.hud.vitals.position.x < 410, "health, hull flow and thrust share the left instrument area")
		check(game.hud.time.position.x > 410 and game.hud.risk.position.x > 410 and game.hud.phase.get_rect().end.x <= 842 and game.hud.trait.get_rect().end.x <= 842, "time, region and status fit the central mission area")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var capture := root.get_texture().get_image()
			var scale := float(capture.get_width()) / 1280.0
			var pixel := capture.get_pixel(int(640 * scale), int(163 * scale))
			check(pixel.g > 0.75 and pixel.r > 0.5, "mission success bar is visible in the center")
			var score_pixel := capture.get_pixel(int(895 * scale), int(131 * scale))
			var xp_pixel := capture.get_pixel(int(895 * scale), int(163 * scale))
			check(score_pixel.r > 0.8 and xp_pixel.r > 0.8, "both reward lanes are visible despite camera displacement, including reduced motion")
			if "--capture" in OS.get_cmdline_user_args():
				DirAccess.make_dir_recursive_absolute("res://artifacts/candidate/feedback315")
				check(capture.save_png("res://artifacts/candidate/feedback315/%d-%s.png" % [capture.get_width(), "reduced" if reduced else "full"]) == OK, "save late reward and marker screen")
	game.run = fixture()
	game.run.current_speed = game.run.base_speed()
	game.run._grant_xp(2)
	game.run._risk_feedback("risk_score", 21)
	game._resume()
	check(game.hud.risk.text.ends_with("활동영역") and game.net_gauge > 0 and game.speed_gauge == 1.0, "safe region retains base reward cues and healthy instruments")
	game.queue_redraw()
	await process_frame
	if DisplayServer.get_name() != "headless" and "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var capture := root.get_texture().get_image()
		check(capture.save_png("res://artifacts/candidate/feedback315/%d-safe.png" % capture.get_width()) == OK, "save base reward HUD")
	game.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)
