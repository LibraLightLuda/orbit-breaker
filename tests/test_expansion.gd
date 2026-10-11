extends SceneTree

const Model = preload("res://scripts/run_model.gd")
const Content = preload("res://scripts/game_content.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_test_catalog_and_ships()
	_test_overdrive()
	_test_weapons_and_evolutions()
	_test_hazards()
	_test_elites_and_boss_patterns()
	_test_restart_and_limits()
	print("EXPANSION SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)

func _test_catalog_and_ships() -> void:
	check(Content.SHIP_IDS.size() == 3 and Content.SECTOR_IDS.size() == 3, "three ships and three sectors")
	for id: String in Content.SHIP_IDS:
		var info: Dictionary = Content.ship_info(id)
		check(info.id == id and info.color is Color and not str(info.description).is_empty(), "complete ship " + id)
	for id: String in Content.SECTOR_IDS:
		var info: Dictionary = Content.sector_info(id)
		check(info.id == id and info.color is Color and not str(info.description).is_empty(), "complete sector " + id)
	var striker := Model.new()
	var scout := Model.new()
	var bastion := Model.new()
	striker.reset(9)
	scout.reset(9, "normal", "scout", "storm")
	bastion.reset(9, "normal", "bastion", "forge")
	check(striker.hp == 100.0 and striker.orbit_count == 3, "default striker retained")
	check(scout.hp == 80.0 and bastion.hp == 140.0 and bastion.orbit_count == 4, "distinct ship durability and orbit count")
	striker.step(0.05, Vector2.RIGHT, false)
	scout.step(0.05, Vector2.RIGHT, false)
	bastion.step(0.05, Vector2.RIGHT, false)
	check(scout.player.x > striker.player.x and striker.player.x > bastion.player.x, "ship movement differences apply")
	striker.step(0.01, Vector2.RIGHT, true)
	scout.step(0.01, Vector2.RIGHT, true)
	bastion.step(0.01, Vector2.RIGHT, true)
	check(scout.dash_cooldown < striker.dash_cooldown and striker.dash_cooldown < bastion.dash_cooldown, "ship dash differences apply")
	scout.reset(9, "relaxed", "scout", "storm")
	check(scout.hp == 130.0 and scout.sector_id == "storm", "relaxed ship bonus retains sector")
	striker.reset(9, "bad", "bad", "bad")
	check(striker.ship_id == "striker" and striker.sector_id == "ring" and striker.mode == "normal", "invalid catalog values safely fall back")

func _test_overdrive() -> void:
	var model := Model.new()
	model.reset(11)
	check(not model.activate_overdrive(), "overdrive requires charge")
	model.overdrive_meter = 98.0
	var enemy: Dictionary = model.spawn_enemy("chaser", model.player + Vector2(55.0, 0.0))
	model.step(0.01, Vector2.ZERO, false)
	check(model.overdrive_meter == 100.0, "kills fill capped charge")
	model.state = "upgrade"
	check(not model.activate_overdrive(), "overdrive cannot activate during upgrade")
	model.state = "playing"
	check(model.activate_overdrive() and model.overdrive_time == 6.0 and model.overdrive_meter == 0.0, "charged activation consumes meter")
	check(not model.activate_overdrive(), "active overdrive cannot retrigger")
	model.take_damage(20.0)
	check(is_equal_approx(model.hp, 89.0), "overdrive reduces damage rather than grants invulnerability")
	enemy = model.spawn_enemy("tank", model.player + Vector2(300.0, 0.0))
	model._fire_player_shot()
	check(is_equal_approx(float(model.shots[-1].damage), 27.55 * (1.0 + model.focus_bonus())), "overdrive increases weapon damage")
	model.step(0.05, Vector2.ZERO, false)
	check(model.overdrive_time < 6.0, "overdrive duration advances")
	model.state = "upgrade"
	var timer: float = model.overdrive_time
	model.step(0.05, Vector2.ZERO, false)
	check(model.overdrive_time == timer, "upgrade pauses overdrive duration")
	check(model.run_stats.overdrives == 1, "overdrive usage appears in run stats")

func _test_weapons_and_evolutions() -> void:
	var model := Model.new()
	model.reset(12)
	model.upgrades.missile = 1
	model.spawn_enemy("tank", model.player + Vector2(260.0, 0.0))
	model._update_weapons(0.01)
	check(model.shots.size() == 1 and model.shots[0].kind == "missile", "missile module creates homing projectile")
	var before: float = model.enemies[0].hp
	for i in 80:
		model._update_shots(1.0 / 60.0)
	check(float(model.enemies[0].hp) < before, "missile deals actual impact damage")
	model.reset(12)
	model.upgrades.chain = 1
	var first: Dictionary = model.spawn_enemy("tank", model.player + Vector2(230.0, 0.0))
	var second: Dictionary = model.spawn_enemy("tank", model.player + Vector2(330.0, 0.0))
	model._update_weapons(0.01)
	check(float(first.hp) == 67.0 and float(second.hp) == 67.0, "chain strikes two separate enemies once each")
	check(model.effects.any(func(e: Dictionary) -> bool: return e.kind == "lightning" and e.has("end")), "chain produces renderable segments")
	model.reset(12)
	model.upgrades.pulse = 1
	first = model.spawn_enemy("tank", model.player + Vector2(100.0, 0.0))
	model._update_weapons(0.01)
	check(float(first.hp) == 72.0 and Vector2(first.pos).distance_to(model.player) > 130.0, "pulse damages and pushes nearby enemies")
	for id: String in Content.EVOLUTION_IDS:
		var info: Dictionary = Content.evolution_info(id)
		model.reset(12, "normal", str(info.get("ship", "striker")))
		model.elapsed = float(info.get("after", 0.0))
		var requirements: Dictionary = info.requirements
		var trigger := str(requirements.keys()[-1])
		for required: String in requirements:
			model.upgrades[required] = int(requirements[required])
		model.upgrades[trigger] -= 1
		model._check_evolutions()
		check(model.evolutions.is_empty(), "evolution waits for all requirements " + id)
		model.state = "upgrade"
		model._choices = [trigger, "restore", "fortune"]
		model.choose_upgrade(trigger)
		check(model.evolutions.has(id) and model.events.has("evolution"), "chosen threshold automatically evolves " + id)
		model._check_evolutions()
		check(model.evolutions.count(id) == 1, "evolution applies only once " + id)
	model.reset(12)
	model.upgrades.missile = 3
	model.upgrades.dash = 2
	model._check_evolutions()
	model.spawn_enemy("boss", model.player + Vector2(300.0, 0.0))
	model._update_weapons(0.01)
	check(model.shots.size() == 3 and float(model.shots[0].blast_radius) == 93.0, "salvo evolution changes missile count and blast")

func _test_hazards() -> void:
	for sector: String in ["storm", "forge"]:
		var model := Model.new()
		model.reset(13, "normal", "striker", sector)
		model._hazard_timer = 0.0
		model._update_hazards(0.01)
		check(not model.hazards.is_empty(), "sector hazard spawns " + sector)
		var hazard: Dictionary = model.hazards[0]
		check(not bool(hazard.active) and float(hazard.warn) >= 1.0 and model.hp == 100.0, "hazard warns harmlessly " + sector)
		for i in 170:
			model._update_hazards(0.01)
		check(model.hp < 100.0, "active hazard damages its marked location " + sector)
		for i in 200:
			model._update_hazards(0.01)
		check(model.hazards.is_empty(), "hazards expire " + sector)
	var safe := Model.new()
	safe.reset(13, "normal", "striker", "forge")
	safe._add_blast(safe.player, 72.0)
	safe.player += Vector2(250.0, 0.0)
	for i in 230:
		safe._update_hazards(0.01)
	check(safe.hp == 100.0, "leaving blast warning prevents damage")
	safe.reset(13)
	safe._hazard_timer = 0.0
	safe._update_hazards(0.05)
	check(safe.hazards.is_empty(), "ring has no ambient hazards")
	for i in 40:
		safe._add_blast(safe.player, 60.0)
	check(safe.hazards.size() == 6, "hazard count capped")
	var snapshot: Array = safe.hazards.duplicate(true)
	safe.state = "upgrade"
	safe.step(0.05, Vector2.ZERO, false)
	check(safe.hazards == snapshot, "upgrade pauses hazards")

func _test_elites_and_boss_patterns() -> void:
	var model := Model.new()
	model.reset(14)
	model.elapsed = 89.99
	model.step(0.02, Vector2.ZERO, false)
	var elite: Dictionary = model.enemies.filter(func(e: Dictionary) -> bool: return e.kind == "elite")[0]
	check(int(elite.elite_index) == 1 and model.events.has("elite"), "first elite at ninety seconds")
	model._fire_enemy_shots(elite)
	check(float(elite.charge_time) > 0.0, "first elite uses charge behavior")
	model.hp = 40.0
	elite.hp = 0.0
	model.step(0.01, Vector2.ZERO, false)
	check(model.elites_killed == 1 and model.hp < 41.0 and model.events.has("elite_down"), "elite rewards XP without free recovery")
	model.state = "playing"
	model.elapsed = 179.99
	model.step(0.02, Vector2.ZERO, false)
	elite = model.enemies.filter(func(e: Dictionary) -> bool: return e.kind == "elite")[0]
	model.shots.clear()
	model._fire_enemy_shots(elite)
	check(int(elite.elite_index) == 2 and model.shots.size() == 5, "second elite uses spread fire")
	for sector: String in Content.SECTOR_IDS:
		model.reset(14, "normal", "striker", sector)
		var boss: Dictionary = model.spawn_enemy("boss", model.player + Vector2(310.0, 0.0))
		boss.aim = Vector2.LEFT
		model._fire_enemy_shots(boss)
		var expected := 9 if sector == "ring" else (5 if sector == "storm" else 3)
		check(model.shots.size() == expected, "sector boss attack pattern " + sector)
		boss.hp = float(boss.max_hp) * 0.49
		model._update_enemies(0.01, model.player)
		check(int(boss.phase) == 2 and model.events.has("phase"), "half HP boss phase " + sector)
		model.shots.clear()
		model._fire_enemy_shots(boss)
		check(model.shots.size() > expected, "second phase intensifies pattern " + sector)
		if sector == "forge":
			check(not model.hazards.is_empty() and float(model.hazards[0].warn) >= 1.0, "forge boss artillery is telegraphed")

func _test_restart_and_limits() -> void:
	var model := Model.new()
	model.reset(15, "relaxed", "bastion", "forge")
	model.overdrive_meter = 100.0
	model.activate_overdrive()
	model.evolutions.append("salvo")
	model._add_blast(model.player, 70.0)
	model.elites_killed = 2
	model.reset(15)
	check(model.ship_id == "striker" and model.sector_id == "ring" and model.hazards.is_empty() and model.evolutions.is_empty() and model.elites_killed == 0, "restart clears expansion selections and state")
	check(model.overdrive_time == 0.0 and model.overdrive_meter == 0.0 and model.run_stats.overdrives == 0, "restart clears overdrive history")
	model.upgrades.missile = 3
	model.upgrades.chain = 3
	model.upgrades.pulse = 3
	model.upgrades.dash = 2
	model.upgrades.rapid = 2
	model._check_evolutions()
	model.spawn_enemy("boss", model.player + Vector2(300.0, 0.0))
	for i in 200:
		model._missile_timer = 0.0
		model._update_weapons(0.01)
	check(model.shots.size() <= 240 and model.effects.size() <= 180, "expanded weapons preserve object bounds")
	model.take_damage(10000.0)
	check(model.run_stats.winner == false and model.run_stats.ship == "striker", "terminal stats match actual run")
