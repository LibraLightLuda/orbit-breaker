extends SceneTree

const Model = preload("res://scripts/run_model.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_test_recovery_budget()
	_test_end_and_pause()
	_test_gravity_and_satellites()
	_test_boundary_buffer()
	_test_choices()
	print("SURVIVAL SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _test_boundary_buffer() -> void:
	var model := Model.new()
	var safe := Model.ARENA.grow(-Model.PLAYER_RADIUS)
	var outer := Model.FLIGHT_BOUNDS.grow(-Model.PLAYER_RADIUS)
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		model.reset(2)
		model.player = safe.get_center() + direction * safe.size * 0.5
		check(model.boundary_depth(model.player) == 0.0, "safe edge has no boundary damage")
		model.step(0.05, direction, false)
		check(model.boundary_depth(model.player) > 0.0, "all four edges allow buffer movement")
		model.player = outer.get_center() + direction * outer.size * 0.5
		check(is_equal_approx(model.boundary_depth(model.player), 1.0) and model.movement_multiplier(model.player) <= 0.08, "deep buffer has severe drag")
		model.step(0.05, direction, true)
		check(outer.grow(0.001).has_point(model.player), "outward dash respects final visible bounds")
		model.dash_time = 0.0
		model.dash_cooldown = 0.0
		model.step(0.05, -direction, true)
		check(model.boundary_depth(model.player) < 0.9 and model.current_speed > 900.0, "inward dash and current return from deep space without wall teleport")
	model.reset(2, "relaxed")
	model.player = Vector2(outer.end.x, safe.get_center().y)
	model.hp = 50.0
	model.invulnerable = 100.0
	model.overdrive_time = 100.0
	model._update_vitals(0.05)
	check(model.hp < 50.0, "boundary damage bypasses dash and overdrive immunity")
	var initial_damage: float = model.boundary_damage_rate()
	model.boundary_time = 5.0
	check(model.boundary_damage_rate() > initial_damage * 5.0, "sustained exposure escalates damage")
	var exposure: float = model.boundary_time
	var health: float = model.hp
	model.state = "upgrade"
	model.step(0.05, Vector2.RIGHT, false)
	check(model.boundary_time == exposure and model.hp == health, "selection freezes boundary exposure and damage")
	model.state = "playing"
	model.player = safe.get_center()
	check(model.boundary_damage_rate() == 0.0, "returning to safety immediately removes added damage")
	model._update_vitals(0.05)
	check(model.boundary_time == 0.0 and model.hp > health, "safe return clears exposure and allows recovery")
	model.player = outer.end - Vector2(0.001, 0.001)
	model.boundary_time = 10.0
	model.hp = 0.01
	model._update_vitals(0.05)
	check(model.state == "lost" and model.end_reason == "boundary" and model.hp == 0.0, "fatal boundary damage ends the run")
	model.reset(2)
	check(model.boundary_time == 0.0 and model.current_speed == 0.0, "restart clears exposure and speed")
	model.step(0.05, Vector2.RIGHT, false)
	check(is_equal_approx(model.current_speed, model.base_speed()), "actual movement speed is measured")
	model.step(0.05, Vector2.ZERO, false)
	check(model.current_speed == 0.0, "stopping clears actual movement speed")

func _test_recovery_budget() -> void:
	# No enemies: survival must require recovery even with perfect avoidance.
	for ship: String in ["striker", "scout", "bastion"]:
		for mode: String in ["normal", "relaxed"]:
			for option: String in ["none", "repair", "vitality", "restore"]:
				var model := Model.new()
				model.reset(9, mode, ship)
				if option == "repair":
					model.upgrades.repair = 1
				var chosen := option in ["none", "repair"]
				while model.state == "playing" and model.elapsed < 300.0:
					if not chosen and model.max_hp - model.hp >= (70.0 if option == "vitality" else 80.0):
						model.state = "upgrade"
						model._choices = [option]
						model.choose_upgrade(option)
						chosen = true
					model.elapsed += 0.05
					model._update_vitals(0.05)
				check(model.state == "lost" and model.elapsed < 300.0, "%s/%s/%s cannot reach five minutes with at most one recovery" % [ship, mode, option])
	var strong := Model.new()
	strong.reset(9, "normal", "striker")
	strong.upgrades.repair = 3
	while strong.state == "playing" and strong.elapsed < 300.0:
		strong.elapsed += 0.05
		strong._update_vitals(0.05)
	check(strong.state == "playing" and strong.hp > 50.0, "three repair picks support five minutes with perfect avoidance")
	strong.upgrades.repair = 5
	strong.elapsed = 360.0
	check(strong.decay_rate() > strong.regeneration_rate(), "six minute decay exceeds maximum regeneration")
	strong.elapsed = 600.0
	check(is_equal_approx(strong.decay_rate(), 51.25), "ten minute decay reaches 51.25 HP per second")
	strong.reset(9)
	strong.hp = 40.0
	strong._update_vitals(0.05)
	check(strong.hp > 40.0 and strong.regeneration_rate() == 1.0, "baseline regeneration starts immediately")

func _test_end_and_pause() -> void:
	var model := Model.new()
	model.reset(2)
	model.boss_spawned = true
	model.boss_defeated = true
	model.elapsed = 299.99
	model.step(0.02, Vector2.ZERO, false)
	check(model.state == "playing" and model.survival_cleared, "five minutes marks clear but does not end")
	var score: int = model.score
	model.step(0.02, Vector2.ZERO, false)
	check(model.score == score, "milestone reward happens once")
	model.state = "upgrade"
	var time: float = model.elapsed
	var health: float = model.hp
	model.step(0.05, Vector2.ONE, true)
	check(model.elapsed == time and model.hp == health, "selection pauses decay and time")
	model.state = "playing"
	model.elapsed = 599.99
	model.hp = 100000.0
	model.max_hp = 100000.0
	model.upgrades.repair = 100000
	model.invulnerable = 1000.0
	model.overdrive_time = 1000.0
	model.step(0.05, Vector2.ZERO, true)
	check(model.state == "won" and model.hp == 0.0 and model.elapsed == 600.0 and model.end_reason == "collapse", "ten minute hard limit defeats arbitrary healing and immunity")
	model.reset(2)
	model.elapsed = 400.0
	model.hp = 0.01
	model.invulnerable = 100.0
	model.overdrive_time = 100.0
	model.gems.append({"pos": model.player, "kind": "heal", "value": 100.0})
	model.step(0.05, Vector2.ZERO, true)
	check(model.state == "lost" and model.hp == 0.0, "decay ignores combat immunity and cannot revive")
	model.reset(2)
	check(not model.survival_cleared and model.end_reason == "" and model.duration == 600.0, "restart clears survival state")

func _test_gravity_and_satellites() -> void:
	var model := Model.new()
	model.reset(2)
	var center: Vector2 = model.player
	var edge := Vector2(Model.ARENA.end.x - Model.PLAYER_RADIUS, center.y)
	for time: float in [0.0, 150.0, 300.0, 450.0, 600.0]:
		model.elapsed = time
		check(model.movement_multiplier(center) == 1.0, "center remains full speed at %.0f" % time)
		check(is_equal_approx(model.movement_multiplier(edge), 1.0 - time / 1500.0), "edge speed floor at %.0f" % time)
		var middle: float = model.movement_multiplier(center.lerp(edge, 0.7))
		check(middle >= model.movement_multiplier(edge) and middle <= 1.0, "gravity changes smoothly at %.0f" % time)
	model.reset(2)
	model.state = "upgrade"
	model._choices = ["orbit_range"]
	model.choose_upgrade("orbit_range")
	check(is_equal_approx(model.orbit_position(0).distance_to(model.player), 85.0), "range choice expands actual orbit")
	model.upgrades.blade = 2
	var enemy: Dictionary = model.spawn_enemy("tank", model.orbit_position(0))
	enemy.speed = 0.0
	model._update_enemies(0.01, model.player)
	check(is_equal_approx(float(enemy.hp), 92.0 - 42.5), "blade rank two increases actual satellite hit damage")
	model.enemies.clear()
	model.upgrades.frost = 3
	enemy = model.spawn_enemy("tank", model.orbit_position(0))
	enemy.speed = 0.0
	model._update_enemies(0.01, model.player)
	check(model.orbit_kind(0) == "frost" and model.orbit_kind(1) == "blade", "satellite types coexist")
	check(is_equal_approx(float(enemy.slow_factor), 0.4) and is_equal_approx(float(enemy.slow_time), 1.9), "frost applies rank three slow and duration")
	enemy.pos = model.player + Vector2(300, 0)
	enemy.speed = 100.0
	var before: Vector2 = enemy.pos
	model._update_enemies(0.05, model.player)
	check(is_equal_approx(before.distance_to(enemy.pos), 2.0), "frost reduces actual enemy movement")
	enemy.slow_time = 0.01
	before = enemy.pos
	model._update_enemies(0.05, model.player)
	check(is_equal_approx(before.distance_to(enemy.pos), 5.0), "enemy speed returns when frost expires")

func _test_choices() -> void:
	var model := Model.new()
	model.reset(3)
	for i in range(100):
		model.state = "upgrade"
		model._choices.clear()
		var options: Array = model.get_upgrade_choices()
		check(options.has("repair") or options.has("vitality") or options.has("restore"), "recovery always offered %d" % i)
	model.upgrades.repair = 5
	model.upgrades.vitality = 4
	model._choices.clear()
	check(model.get_upgrade_choices().has("restore"), "repeatable repair offered when permanent recovery capped")
