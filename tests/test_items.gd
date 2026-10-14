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

func fresh() -> RunModel:
	var model := RunModel.new()
	model.reset(361)
	model._spawn_timer = 1000
	return model

func run_checks() -> void:
	_test_striker_items()
	_test_effects()
	_test_drops()
	_test_store()
	await _test_ui()
	print("ITEM SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func _test_striker_items() -> void:
	var model := fresh()
	model.focus_time = 1.2
	for i in 30:
		model.step(0.05, Vector2.RIGHT, false)
	check(model.focus_time > 0.6 and model.focus_time < 1.2, "moving retains a longer partial charge")
	model.spawn_enemy("boss", model.player + Vector2(300, 0))
	model._fire_player_shot()
	check(is_equal_approx(float(model.shots.back().damage), 19 * (1.0 + model.focus_bonus())), "cannon uses continuous focus bonus")
	var before := model.focus_time
	model.step(0.05, Vector2.RIGHT, true)
	check(model.focus_time < before, "fast dash drains focus")
	model.state = "upgrade"
	before = model.focus_time
	model.step(0.05, Vector2.RIGHT, false)
	check(model.focus_time == before, "pause preserves partial focus")
	model.state = "playing"
	model.dash_time = 0
	model.enemies.clear()
	model.player = RunModel.CENTER
	for i in 150:
		model.player = RunModel.CENTER
		model.step(0.05, Vector2.from_angle(i * 0.02), false)
	check(model.focus_time > 0.05 and model.focus_bonus() >= 0.08, "continuous movement retains an amplified floor")
	model.focus_time = 0
	for i in 12:
		model.step(0.05, Vector2.ZERO, false)
	check(is_equal_approx(model.focus_time, 0.6), "stopping recharges partial focus")
	model.apply_item("power", "A")
	model.spawn_enemy("boss", model.player + Vector2(300, 0))
	model._fire_player_shot()
	check(is_equal_approx(float(model.shots.back().damage), 19 * 2 * (1.0 + model.focus_bonus())), "focus stacks with power item")
	model.apply_item("speed", "A")
	check(model.base_speed() == 327 and model.slipstream_time == 0, "propulsion item remains independent of scout wake")

func _test_effects() -> void:
	for id: String in ItemCatalog.IDS:
		var previous := 0.0
		for grade: String in ItemCatalog.GRADES:
			var info := ItemCatalog.info(id, grade)
			check(float(info.value) > previous and not str(info.description).is_empty(), "grade power and description " + id + grade)
			previous = float(info.value)
			var model := fresh()
			model.hp = 10
			check(model.apply_item(id, grade), "accept effect " + id + grade)
			check(model.items_collected == 1 and model.pending_items.size() == 1, "record pickup " + id + grade)
			if id == "heal":
				check(is_equal_approx(model.hp, 10 + info.value), "percentage instant healing " + grade)
			elif info.duration > 0:
				check(model.buff_value(id) == info.value and model.buffs[id].ttl == info.duration, "timed effect " + id + grade)
	var model := fresh()
	check(not model.apply_item("bad", "A") and not model.apply_item("heal", "S"), "invalid effects rejected")
	model.state = "upgrade"
	check(not model.apply_item("heal", "A"), "no pickup activation while paused")
	model.state = "playing"
	model.apply_item("power", "A")
	check(model._power() == 2.0, "all weapon power doubles")
	model.apply_item("speed", "A")
	check(model.base_speed() == 327.0, "speed buff scales normal movement")
	model.apply_item("repair", "A")
	check(model.regeneration_rate() == 11.0, "regen buff participates in hull economics")
	model._update_items(2)
	model.apply_item("power", "C")
	check(model.buffs.power.value == 100 and model.buffs.power.ttl == 8, "weaker pickup cannot dilute or extend stronger buff")
	model.apply_item("power", "A")
	check(model.buffs.power.value == 100 and model.buffs.power.ttl == 10, "same grade refreshes without stacking")
	model.state = "upgrade"
	model.step(0.05, Vector2.ZERO, false)
	check(model.buffs.power.ttl == 10, "upgrade freezes effect time")
	model.state = "playing"
	model._update_items(10)
	check(model.buffs.is_empty() and model._power() == 1 and model.regeneration_rate() == 1, "effects expire back to base values")
	model.apply_item("rapid", "A")
	model.apply_item("frenzy", "A")
	model._shot_timer = 0
	model.step(0.01, Vector2.ZERO, false)
	check(is_equal_approx(model._shot_timer, 0.68 / 4), "A frenzy is +300 percent attack speed and does not stack rapid")
	model.hp = model.max_hp - 1
	model.apply_item("heal", "A")
	check(model.hp == model.max_hp, "heal clamps at max hull")
	model = fresh()
	var near := model.spawn_enemy("shooter", model.player + Vector2(200, 0))
	near.warn = 0.01
	var boss := model.spawn_enemy("boss", model.player + Vector2(400, 0))
	var far := model.spawn_enemy("tank", model.player + Vector2(700, 0))
	model.apply_item("stun", "A")
	check(near.stun_time == 4 and is_equal_approx(float(boss.stun_time), 1.4) and not far.has("stun_time"), "stun radius and strong enemy resistance")
	var point: Vector2 = near.pos
	model._update_enemies(0.05, model.player)
	check(near.pos == point and near.warn == 0.01 and model.shots.is_empty(), "stun freezes enemy movement and firing windup")
	near.stun_time = 0
	model._update_enemies(0.05, model.player)
	check(near.pos != point and not model.shots.is_empty(), "enemy resumes movement and firing after stun")
	model = fresh()
	near = model.spawn_enemy("tank", model.player + Vector2(200, 0))
	far = model.spawn_enemy("tank", model.player + Vector2(600, 0))
	model.shots.append({"friendly": false, "pos": model.player})
	model.shots.append({"friendly": true, "pos": model.player})
	model.shots.append({"friendly": false, "pos": model.player + Vector2(600, 0)})
	model.apply_item("emp", "B")
	check(near.hp < 0 and far.hp == far.max_hp, "EMP damage is local")
	check(model.shots.size() == 2 and model.shots[0].friendly and not model.shots[1].friendly, "EMP removes only nearby hostile bullets")
	model = fresh()
	model.spawn_item(model.player + Vector2(40, 0), "A", "heal")
	var start := model.player
	model.player += Vector2(80, 0)
	model._collect_items(start)
	check(model.items.is_empty() and model.items_collected == 1, "swept collection cannot miss pickup during dash")
	model._collect_items(start)
	check(model.items_collected == 1, "pickup cannot fire twice")
	model.reset(361)
	check(model.items.is_empty() and model.buffs.is_empty() and model.pending_items.is_empty() and model.items_collected == 0, "new run clears temporary items and effects")

func _test_drops() -> void:
	var model := fresh()
	model._supply_timer = 0.01
	model._update_items(0.05)
	check(model.items.size() == 1 and model.items[0].ttl == 35, "timed rare supply arrives")
	model.state = "upgrade"
	model.step(0.05, Vector2.ZERO, false)
	check(model.items[0].ttl == 35, "pause freezes pickup lifetime")
	model.state = "playing"
	model._update_items(35)
	check(model.items.is_empty(), "uncollected pickup expires")
	var safe_a := 0
	var risky_a := 0
	var safe_c := 0
	for i: int in range(2000):
		var safe := model.roll_item_grade(0)
		var risky := model.roll_item_grade(2)
		safe_a += int(safe == "A")
		safe_c += int(safe == "C")
		risky_a += int(risky == "A")
		if risky == "C":
			check(false, "deep boundary never spawns C")
	check(safe_a > 0 and safe_a < 80 and safe_c > 1400 and risky_a > 600, "rare safe A and strongly improved risky grades")
	model.items.clear()
	for kind: String in ["elite", "boss"]:
		var enemy := model.spawn_enemy(kind, model.player)
		model._hit_enemy(enemy, 10000)
		model._update_enemies(0.01, model.player)
		check(model.items.size() == (1 if kind == "elite" else 2), "guaranteed strong enemy drop " + kind)
		check(model.items.back().grade in (["A"] if kind == "boss" else ["B", "A"]), "strong enemy minimum grade " + kind)
	for i: int in range(20):
		model.spawn_item(model.player, "C", "speed")
	model._kill_enemy(model.spawn_enemy("boss", model.player))
	check(model.items.size() == 12 and model.items.back().grade == "A", "field cap preserves guaranteed boss reward")
	model.items.clear()
	model.spawn_item(RunModel.CENTER + Vector2(5000, 0), "A", "power")
	check(model.boundary_layer(model.items[0].pos) == 2, "unreachable strong enemy drop moves to accessible second boundary")
	var regular := fresh()
	for i: int in range(500):
		regular._kill_enemy(regular.spawn_enemy("chaser", regular.player))
	check(regular.items.size() <= 1, "regular kill drop cooldown prevents farming floods")
	var a := fresh()
	var b := fresh()
	a.spawn_item(a.player, "A")
	check(a.rng.randi() == b.rng.randi(), "item RNG cannot perturb combat RNG")

func _test_store() -> void:
	var store := SaveStore.new()
	var path := "user://items_test_%d.json" % Time.get_ticks_usec()
	store.load_data(path)
	check(store.data.discovered_items.is_empty(), "existing saves default to unknown codex")
	store.data.best_score = 12345
	store.data.muted = true
	var pickups: Array[Dictionary] = []
	for id: String in ItemCatalog.IDS:
		pickups.append({"id": id, "grade": "A", "risky": true})
	check(store.record_items(pickups), "pickup discovery saves immediately")
	check(store.data.discovered_items.size() == ItemCatalog.IDS.size() and store.data.achievement_progress.items == ItemCatalog.IDS.size(), "discover all eight types and count pickups")
	check("item_types" in store.data.achievements and "items_a_1" in store.data.achievements and "items_risky_1" in store.data.achievements, "codex and grade and danger achievements awarded")
	var reloaded := SaveStore.new()
	reloaded.load_data(path)
	check(reloaded.data.discovered_items == store.data.discovered_items and reloaded.data.best_score == 12345 and reloaded.data.muted, "restart preserves discovery and existing record settings")
	check(reloaded.record_items([{"id": "power", "grade": "C", "risky": false}]), "repeat pickup saves")
	check(reloaded.data.discovered_items.size() == ItemCatalog.IDS.size() and reloaded.data.achievement_progress.items == ItemCatalog.IDS.size() + 1 and reloaded.data.achievement_progress.items_a == ItemCatalog.IDS.size(), "repeat discovery is unique but counts acquisition")
	var validated := store._validated({"discovered_items": ["power", "power", "invalid", 3], "achievement_progress": {"items": -3}})
	check(validated.discovered_items == ["power"] and validated.achievement_progress.items == 0, "malformed discovery validates and deduplicates")
	check(store._validated({"discovered_items": {"power": true}}).discovered_items.is_empty(), "malformed discovery container rejected")
	var failed := SaveStore.new()
	failed.load_data("user://missing_item_dir_%d/records.json" % Time.get_ticks_usec())
	check(not failed.record_items(pickups) and failed.data.discovered_items.is_empty() and failed.data.achievements.is_empty(), "failed write rolls back discoveries and awards")
	check(Achievements.catalog().size() == 62, "existing achievements plus final operation medal")
	check(store.record_run(100, 1, false) and store.data.achievement_progress.items == ItemCatalog.IDS.size(), "run result does not double count immediate pickups")
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func _test_ui() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var path := "user://items_ui_%d.json" % Time.get_ticks_usec()
	game.records.load_data(path)
	game.sound.set_muted(true)
	game.codex_tab = "items"
	game._open_arsenal("menu")
	var unknown := 0
	for child: Node in game.ui.get_children():
		if child is Label:
			unknown += int(child.text == "???")
	check(unknown == 8 and game.screen == "arsenal", "all eight unknown cards hide names and effects")
	await snapshot(game, "items-unknown")
	var pickups: Array[Dictionary] = []
	for id: String in ItemCatalog.IDS:
		pickups.append({"id": id, "grade": "A", "risky": true})
	game.records.record_items(pickups)
	game._open_arsenal("menu")
	await process_frame
	unknown = 0
	for child: Node in game.ui.get_children():
		if child is Label:
			unknown += int(child.text == "???")
		if child is Control:
			check(child.get_rect().end.x <= 1280 and child.get_rect().end.y <= 720, "codex bounds %s %s" % [child.get_rect(), child.get("text")])
	check(unknown == 0, "discovered cards reveal effects")
	await snapshot(game, "items-discovered")
	game.run.reset(361)
	game._resume()
	for id: String in ["power", "speed", "rapid", "repair", "frenzy"]:
		game.run.apply_item(id, "A")
	for i: int in range(8):
		game.run.spawn_item(game.run.player + Vector2(-250 + i * 65, 130), ItemCatalog.GRADES[i % 3], ItemCatalog.IDS[i])
	game._update_hud()
	await snapshot(game, "items-field-and-buffs")
	var time: float = game.run.buffs.power.ttl
	game._open_arsenal("pause")
	game._physics_process(0.05)
	check(game.run.buffs.power.ttl == time, "codex pauses actual combat effect timers")
	await snapshot(game, "items-paused-codex")
	game._close_arsenal()
	check(game.screen == "playing", "codex returns to combat")
	game.records_tab = "missions"
	game.achievement_page = 0
	game._show_records()
	await snapshot(game, "items-achievements")
	game.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func snapshot(game: Node2D, label: String) -> void:
	game.queue_redraw()
	await process_frame
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var folder := "res://artifacts/candidate/small" if "--capture-small" in OS.get_cmdline_user_args() else "res://artifacts/candidate"
		DirAccess.make_dir_recursive_absolute(folder)
		check(root.get_texture().get_image().save_png(folder + "/" + label + ".png") == OK, "capture " + label)
