extends SceneTree

const Model = preload("res://scripts/run_model.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_test_reset_and_movement()
	_test_dash_and_damage()
	_test_pickups_and_upgrades()
	_test_combat_and_boss()
	_test_seed_and_limits()
	print("MODEL SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)

func _test_reset_and_movement() -> void:
	var model := Model.new()
	model.reset(123)
	check(model.state == "playing" and model.hp == 100.0, "normal reset")
	model.player = Vector2(1193, 629)
	model.step(0.05, Vector2.ONE, false)
	check(model.player.x > 1195.0 and model.player.y > 631.0 and Model.FLIGHT_BOUNDS.has_point(model.player), "movement crosses old edge into buffer")
	model.player = Vector2(86, 142)
	model.step(0.05, -Vector2.ONE, false)
	check(model.player.x < 85.0 and model.player.y < 141.0 and Model.FLIGHT_BOUNDS.has_point(model.player), "movement crosses opposite edge into buffer")
	model.reset(123, "relaxed")
	check(model.hp == 150.0 and model.enemies.is_empty() and model.level == 1, "clean relaxed restart")
	model.reset(123)
	check(model.upgrades.is_empty() and model.score == 0 and model.elapsed == 0.0, "clean normal restart")

func _test_dash_and_damage() -> void:
	var model := Model.new()
	model.reset(2)
	var origin: Vector2 = model.player
	model.step(0.05, Vector2.RIGHT, true)
	check(model.player.x - origin.x > 40.0 and model.dash_cooldown > 2.9, "dash movement and cooldown")
	model.take_damage(20.0)
	check(model.hp == model.max_hp, "dash invulnerability")
	var cooldown: float = model.dash_cooldown
	model.step(0.05, Vector2.RIGHT, true)
	check(model.dash_cooldown < cooldown, "cooldown prevents repeat dash")
	model.invulnerable = 0.0
	model.take_damage(20.0)
	model.take_damage(20.0)
	check(model.hp == 80.0, "damage grace prevents duplicate hit")
	model.reset(2, "relaxed")
	model.take_damage(20.0)
	check(model.hp == 135.0, "relaxed incoming damage reduction")
	model.invulnerable = 0.0
	model.upgrades["repair"] = 3
	model.gems.append({"pos": model.player, "value": 12.0, "kind": "heal"})
	model.take_damage(1000.0)
	model.step(0.01, Vector2.ZERO, false)
	check(model.state == "lost" and model.hp == 0.0, "fatal damage cannot be healed back to life")

func _test_pickups_and_upgrades() -> void:
	var model := Model.new()
	model.reset(3)
	model.hp = 50.0
	model.gems.append({"pos": model.player, "value": 60.0, "kind": "xp"})
	model.step(0.01, Vector2.ZERO, false)
	check(model.state == "upgrade" and model.level == 2 and is_equal_approx(model.hp, 50.0075), "XP levels without free healing")
	var choices: Array = model.get_upgrade_choices()
	check(choices.size() == 3 and choices[0] != choices[1] and choices[1] != choices[2] and choices[0] != choices[2], "three unique choices")
	check(choices == model.get_upgrade_choices(), "choices remain stable")
	var before: float = model.elapsed
	var position: Vector2 = model.player
	model.step(0.05, Vector2.RIGHT, true)
	check(model.elapsed == before and model.player == position, "upgrade pauses simulation")
	check(not model.choose_upgrade("invalid"), "reject forged upgrade id")
	check(model.choose_upgrade(str(choices[0])), "accept offered upgrade")
	check(model.state == "upgrade" and model.level == 3, "queued level-ups retained")
	var guard := 0
	while model.state == "upgrade" and guard < 20:
		model.choose_upgrade(str(model.get_upgrade_choices()[0]))
		guard += 1
	check(model.state == "playing" and model.xp < model.xp_needed, "queued level-ups finish")
	model.state = "upgrade"
	model._choices.clear()
	for id: String in model.UPGRADE_IDS:
		model.upgrades[id] = int(Model.upgrade_info(id).cap)
	choices = model.get_upgrade_choices()
	check(choices.size() == 3 and choices.has("restore") and choices.has("burst") and choices.has("fortune"), "all capped upgrades use safe consumables")
	check(model.choose_upgrade("restore"), "consumable upgrade accepted")
	model.reset(3)
	model.hp = 60.0
	model.gems.append({"pos": model.player, "value": 12.0, "kind": "heal"})
	model.step(0.01, Vector2.ZERO, false)
	check(is_equal_approx(model.hp, 72.0075) and model.xp == 0.0, "legacy healing pickup does not grant XP")
	model.state = "upgrade"
	model._choices = ["orbit", "power", "vitality"]
	model.choose_upgrade("orbit")
	check(model.orbit_count == 4 and model.orbit_radius == 67.0, "orbit upgrade applies")
	model.state = "upgrade"
	model._choices = ["orbit", "power", "vitality"]
	model.choose_upgrade("vitality")
	check(model.max_hp == 135.0 and model.hp == 135.0, "vitality upgrade raises and restores HP")
	model.state = "upgrade"
	model._choices = ["orbit", "power", "vitality"]
	model.choose_upgrade("power")
	model.spawn_enemy("tank", model.player + Vector2(300.0, 0.0))
	model._fire_player_shot()
	check(is_equal_approx(float(model.shots[-1].damage), 23.75), "power upgrade increases shot damage")

func _test_combat_and_boss() -> void:
	var model := Model.new()
	model.reset(4)
	model.spawn_enemy("chaser", model.player + Vector2(55.0, 0.0))
	model.step(0.01, Vector2.ZERO, false)
	check(model.kills == 1 and model.gems.size() >= 1 and model.score > 0, "orbit kills and drops XP")
	model.reset(4)
	model.spawn_enemy("tank", model.player + Vector2(40.0, 0.0))
	model.step(0.05, Vector2.RIGHT, true)
	check(model.enemies.is_empty() or float(model.enemies[0].hp) < 50.0, "dash deals damage")
	model.reset(4)
	model.elapsed = 239.99
	model.step(0.02, Vector2.ZERO, false)
	check(model.boss_spawned and model.enemies.any(func(e: Dictionary) -> bool: return e.kind == "boss"), "final boss spawns")
	model.elapsed = 300.0
	model.step(0.01, Vector2.ZERO, false)
	check(model.state == "playing", "clock alone cannot win")
	for enemy: Dictionary in model.enemies:
		if enemy.kind == "boss":
			enemy.hp = 0.0
	model.step(0.01, Vector2.ZERO, false)
	check(model.boss_defeated and model.survival_cleared and model.state == "playing", "five minute milestone keeps combat running")
	var score: int = model.score
	model.step(0.05, Vector2.ZERO, false)
	check(model.score == score, "milestone cannot award twice")
	model.reset(4)
	model.take_damage(1000.0)
	model.step(0.01, Vector2.ZERO, false)
	check(model.state == "lost", "zero HP loses")

func _test_seed_and_limits() -> void:
	var a := Model.new()
	var b := Model.new()
	a.reset(900)
	b.reset(900)
	for i in 180:
		a.step(1.0 / 60.0, Vector2.ZERO, false)
		b.step(1.0 / 60.0, Vector2.ZERO, false)
	check(a.enemies == b.enemies and a.shots == b.shots, "seeded runs reproducible")
	for i in 500:
		a._effect(a.player, "hit", 1.0, 1.0)
	check(a.effects.size() <= 180, "effects bounded")
	a.reset(900)
	for i in 3600:
		if a.state == "upgrade":
			a.choose_upgrade(str(a.get_upgrade_choices()[0]))
		a.hp = a.max_hp
		a.step(0.05, Vector2.from_angle(float(i) * 0.007), i % 65 == 0)
		a.events.clear()
	check(a.enemies.size() <= 161 and a.gems.size() <= 300 and a.shots.size() <= 240, "long simulation remains bounded")
