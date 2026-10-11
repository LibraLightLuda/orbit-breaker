extends SceneTree

var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run_checks")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FEEDBACK318: " + label)

func fresh(ship: String = "striker", sector: String = "ring") -> RunModel:
	var m := RunModel.new()
	m.reset(318, "normal", ship, sector)
	m._spawn_timer = 1000
	m._supply_timer = 1000
	m._encounter_timer = 1000
	m._explore_at = 1000
	m._next_mission_at = 1000
	return m

func run_checks() -> void:
	_test_loot()
	_test_items()
	_test_traits()
	_test_evolutions()
	_test_maps()
	_test_replay()
	await _test_ui()
	print("FEEDBACK318 SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func _test_loot() -> void:
	var m := fresh()
	var at := RunModel.CENTER + Vector2(RunModel.ACTIVITY_RADIUS + 100, 0)
	m.spawn_item(at, "A", "insight")
	m.items[0].ttl = 10.1
	m._update_items(0.2)
	check(m.loot_notices.size() == 1 and m.loot_notices[0].contains("10초"), "item warns once at ten seconds")
	m._update_items(0.1)
	check(m.loot_notices.size() == 1, "warning does not repeat")
	m.items[0].ttl = 0.01
	m._update_items(0.1)
	check(m.items.is_empty() and m.loot_notices.back().contains("보급 소멸"), "expired item removed and announced")
	m.spawn_part(at, "mission", "core")
	m.part_drops[0].ttl = 10.1
	m._update_expedition(0.2, m.player)
	check(m.loot_notices.back().contains("파츠 소멸까지"), "parts warn too")
	m.part_drops[0].ttl = 0.01
	m._update_expedition(0.1, m.player)
	check(m.part_drops.is_empty() and m.loot_notices.back().contains("파츠 소멸"), "parts expire and announce")
	m.gems.append({"pos": at, "value": 1.0, "kind": "xp"})
	m._collect_gems(1.0)
	check(is_equal_approx(at.distance_to(m.gems[0].pos), 5.0), "XP inward drift is five pixels per second")
	m.spawn_item(at, "C", "heal")
	var ttl: float = m.items[0].ttl
	m.state = "upgrade"
	m.step(0.05, Vector2.ZERO, false)
	check(m.items[0].ttl == ttl, "loot lifetime freezes during choice")

func _test_items() -> void:
	for grade: String in ItemCatalog.GRADES:
		for id: String in ["insight", "bounty", "shield", "haste"]:
			var m := fresh()
			check(m.apply_item(id, grade), "new item applies " + id + grade)
			check(m.buffs.has(id), "new item tracks lifetime " + id + grade)
	var m := fresh()
	m.apply_item("insight", "A")
	m._grant_xp(10)
	check(m.xp == 20, "experience boost applied once")
	m.apply_item("bounty", "A")
	check(m._grant_score(100) == 220 and m.score == 220, "all score grants amplified once")
	m.apply_item("shield", "A")
	m.hp = 50
	m.elapsed = 500
	m._update_vitals(0.05)
	check(m.hp > 50 and m.buff_value("shield") < 100, "shield absorbs natural collapse while regen continues")
	m.player += Vector2(RunModel.ACTIVITY_RADIUS + 100, 0)
	m.boundary_time = 2
	var shield := m.buff_value("shield")
	m._update_vitals(0.05)
	check(m.buff_value("shield") < shield, "shield absorbs outside damage")
	m.hp = 50
	m.take_damage(30)
	check(m.hp == 50, "shield absorbs combat damage")
	m.buffs.shield.value = 3
	m.apply_item("shield", "C")
	check(m.buff_value("shield") == 3, "lower shield grade cannot refill depleted A shield")
	check(m._absorb_damage(10) == 7 and not m.buffs.has("shield"), "damage overflow reaches hull")
	m.apply_item("shield", "A")
	m.hp = 100
	m.elapsed = 600
	m._update_vitals(0.01)
	check(m.state == "lost" and m.hp == 0, "shield cannot bypass hard ten-minute collapse")
	m = fresh()
	m.apply_item("haste", "A")
	m.dash_cooldown = 2
	m.step(0.05, Vector2.ZERO, false)
	check(is_equal_approx(m.dash_cooldown, 1.9125), "haste speeds ongoing recharge")
	m._update_items(20)
	check(m.buffs.is_empty(), "new buffs expire")

func _test_traits() -> void:
	var straight := fresh()
	var fast := fresh()
	var turning := fresh()
	for m: RunModel in [straight, fast, turning]:
		m.focus_time = 1.2
	fast.apply_item("speed", "A")
	straight.step(0.05, Vector2.RIGHT, false)
	fast.step(0.05, Vector2.RIGHT, false)
	turning.step(0.05, Vector2.LEFT, false)
	check(fast.focus_time < straight.focus_time and turning.focus_time < straight.focus_time, "speed and turn drain focus faster")
	check(is_equal_approx(fresh().focus_bonus(), 0.08), "striker damage floor is eight percent")
	var memory := fresh()
	memory.upgrades.focus_memory = 1
	memory.focus_time = 1.2
	memory.step(0.05, Vector2.RIGHT, false)
	check(memory.focus_time > straight.focus_time, "inertia part prolongs charge")
	for ship: String in GameContent.SHIP_IDS:
		var m := fresh(ship)
		m.parts = {"core": 3, "drive": 3, "shell": 3}
		for id: String in RunModel.SHIP_PARTS:
			var spec: Array = RunModel.SHIP_PARTS[id]
			check(m.upgrade_available(id) == (ship == spec[0] and spec[2] == ""), "exclusive part owner and order " + ship + id)
			if spec[0] == ship and spec[2] != "":
				m.upgrades[spec[2]] = 1
				check(m.upgrade_available(id), "second part unlocks sequentially " + id)
		m.state = "upgrade"
		check(m.get_upgrade_choices().any(func(id: String) -> bool: return RunModel.SHIP_PARTS.has(id)), "available exclusive part is offered " + ship)
	var scout := fresh("scout")
	scout.upgrades.scout_drive = 3
	var start := scout.player
	for i in 4:
		scout.step(0.05, Vector2.ZERO, i == 0, Vector2.RIGHT)
	check(is_equal_approx(scout.player.distance_to(start), 188 * 1.45), "scout part extends actual dash distance")
	var bastion := fresh("bastion")
	bastion.upgrades.guard_reserve = 3
	check(bastion.guard_capacity() == 4, "reserve raises shield capacity")
	bastion.elapsed = 360
	check(bastion.guard_capacity() == 7, "surviving grows reserve capacity to seven")
	bastion.guard_cooldown = 0.01
	bastion.step(0.05, Vector2.ZERO, false)
	check(bastion.guard_stacks == 2, "ready time accumulates shield stack")

func _test_evolutions() -> void:
	check(GameContent.EVOLUTION_IDS.size() == 12, "twelve evolution catalog")
	for id: String in GameContent.EVOLUTION_IDS.slice(6):
		var info := GameContent.evolution_info(id)
		var m := fresh(str(info.get("ship", "striker")))
		m.upgrades = info.requirements.duplicate()
		m.elapsed = float(info.after) - 1
		m._check_evolutions()
		check(not m.evolutions.has(id), "late gate waits " + id)
		m.elapsed = float(info.after)
		m._check_evolutions()
		check(m.evolutions.has(id), "late gate unlocks " + id)
		if info.has("ship"):
			m.ship_id = "scout" if info.ship == "striker" else "striker"
			m.evolutions.clear()
			m._check_evolutions()
			check(not m.evolutions.has(id), "wrong ship cannot evolve " + id)
	var m := fresh()
	m.evolutions.assign(["sentry", "minefield", "hatchet", "ellipse"])
	var e := m.spawn_enemy("boss", m.player + Vector2(60, 0))
	e.speed = 0
	var before: float = e.hp
	m._update_weapons(0.01)
	m._update_shots(0.7)
	check(e.hp < before, "installed turret and mine deal real damage")
	check(not m.shots.any(func(s: Dictionary) -> bool: return s.get("kind", "") == "mine"), "triggered mine consumed")
	check(is_equal_approx(m.orbit_position(0).distance_to(m.player), m.orbit_radius * 1.8), "ellipse long axis")
	m.orbit_angle = PI / 2
	check(is_equal_approx(m.orbit_position(0).distance_to(m.player), m.orbit_radius * 0.7), "ellipse short axis")
	m.shots.clear()
	m.shots.append({"kind": "axe", "pos": m.player + Vector2(20, 0), "velocity": Vector2.ZERO, "radius": 12.0, "friendly": true, "damage": 58.0, "ttl": 3.0, "pierce": 64, "hit_ids": []})
	m._update_shots(0.05)
	check(m.axe_catches == 1 and m.shots.is_empty(), "returning axe catches at swept player contact")
	m._axe_timer = 0
	m._update_evolved_weapons(0.01)
	var axe: Dictionary = m.shots.filter(func(s: Dictionary) -> bool: return s.get("kind", "") == "axe")[0]
	check(is_equal_approx(float(axe.damage), 58 * 1.15), "caught axe makes next throw stronger")
	axe.pos = m.player + Vector2(5000, 0)
	axe.ttl = 0.01
	m._update_shots(0.05)
	check(m.axe_catches == 0, "missed axe resets chain")
	m = fresh("scout")
	m.evolutions.append("wake")
	e = m.spawn_enemy("boss", m.player)
	before = e.hp
	m.step(0.05, Vector2.ZERO, true, Vector2.RIGHT)
	check(m.shots.any(func(s: Dictionary) -> bool: return s.get("kind", "") == "wake") and e.hp < before, "scout dash installs damaging wake")
	m = fresh("bastion")
	m.evolutions.append("citadel")
	e = m.spawn_enemy("boss", m.player + Vector2(180, 0))
	before = e.hp
	m.take_damage(10)
	check(e.hp < before, "citadel extends real counterattack range")
	m = fresh()
	for i in 30:
		m._deploy("mine", m.player, 18, 13)
	check(m.shots.size() == 8, "mine count bounded")
	m._update_shots(19)
	check(m.shots.is_empty(), "untriggered installations expire")

func _test_maps() -> void:
	var ring := fresh("striker", "ring")
	var forge := fresh("bastion", "forge")
	ring.elapsed = 480
	forge.elapsed = 480
	check(is_equal_approx(forge.decay_rate() / ring.decay_rate(), 1.65), "forge adds 65 percent collapse at eight minutes")
	var storm := fresh("scout", "storm")
	storm.elapsed = 500
	storm._hazard_timer = 0
	storm._update_hazards(0.01)
	check(storm.hazards.size() == 5 and storm._hazard_timer < 7, "storm progresses to five frequent global lanes")
	check(storm.hazards.all(func(h: Dictionary) -> bool: return float(h.warn) > 1.4), "storm retains readable warning")
	var e := ring.spawn_enemy("chaser", ring.player + Vector2(300, 0))
	var other := forge.spawn_enemy("chaser", forge.player + Vector2(300, 0))
	check(float(e.speed) > float(other.speed), "ring common enemies more agile")
	storm.invulnerable = 0.34
	var hp := storm.hp
	storm.take_damage(100, "lane")
	check(storm.hp == hp, "dash invulnerability avoids electricity")

func _test_replay() -> void:
	var m := fresh("bastion")
	m.upgrades.guard_reserve = 2
	m.guard_stacks = 3
	m.axe_catches = 4
	m.apply_item("shield", "A")
	m.evolutions.append("minefield")
	m._deploy("mine", m.player, 18, 13)
	var ghost := GhostReplay.new()
	ghost.capture(m, true)
	check(GhostReplay.valid(ghost.frames), "new replay frame validates")
	var restored := fresh("bastion")
	GhostReplay.restore(restored, ghost.frames[0])
	check(restored.guard_stacks == 3 and restored.axe_catches == 4 and restored.buffs.has("shield") and restored.shots[0].kind == "mine", "new state roundtrips")
	var old: Array = ghost.frames.duplicate(true)
	old[0][13].values.resize(13)
	old[0][13].upgrades.resize(14)
	check(GhostReplay.valid(old), "legacy scalar and upgrade arrays still validate")
	GhostReplay.restore(restored, old[0])
	check(restored.guard_stacks == 1 and restored.upgrades.guard_reserve == 0, "legacy fields get safe defaults")
	var bad: Array = ghost.frames.duplicate(true)
	bad[0][13].values[14] = 9
	check(not GhostReplay.valid(bad), "replay rejects out-of-range catch stacks")
	old[0][13].upgrades.resize(15)
	check(not GhostReplay.valid(old), "unsupported partial schemas rejected")

func _test_ui() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound.set_muted(true)
	game.records.load_data("user://test318_%d.json" % Time.get_ticks_usec())
	check(game.TOAST_ALPHA == 0.06, "acquisition toast background six percent")
	for page in 2:
		game.arsenal_page = page
		game.codex_tab = "weapons"
		game._open_arsenal("menu")
		await capture(game, "evolutions-%d" % page)
		game.item_page = page
		game.codex_tab = "items"
		game._open_arsenal("menu")
		await capture(game, "items-%d" % page)
	game.tech_page = 1
	game.codex_tab = "tech"
	game._open_arsenal("menu")
	await capture(game, "ship-parts")
	game.run = fresh()
	game._resume()
	game.toast = "학습 증폭기 · 경험치 획득 +100% · 12초"
	game.toast_time = 3
	for id: String in ["power", "speed", "rapid", "repair", "frenzy", "insight", "bounty", "shield", "haste"]:
		game.run.apply_item(id, "A")
	game.run.evolutions.assign(["sentry", "minefield", "hatchet", "ellipse"])
	game.run._deploy("sentry", game.run.player + Vector2(90, 70), 14, 14)
	game.run._deploy("mine", game.run.player + Vector2(-90, 70), 18, 13)
	await capture(game, "combat")
	game.queue_free()
	await process_frame

func capture(game: Node2D, label: String) -> void:
	for child: Node in game.ui.get_children():
		if child is Control and child.visible:
			check(child.get_rect().end.x <= 1280.1 and child.get_rect().end.y <= 720.1, "UI bounds " + label)
	game.queue_redraw()
	await process_frame
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var folder := "res://artifacts/candidate/feedback318-" + str(root.size.x)
		DirAccess.make_dir_recursive_absolute(folder)
		check(root.get_texture().get_image().save_png(folder + "/" + label + ".png") == OK, "capture " + label)
