extends RefCounted

const FIELDS := ["state", "end_reason", "player", "facing", "current_speed", "boundary_time", "hp", "max_hp", "level", "xp", "xp_needed", "kills", "score", "combo", "dash_cooldown", "dash_time", "dash_recharge_total", "orbit_angle", "orbit_count", "orbit_radius", "upgrades", "invulnerable", "ship_id", "overdrive_meter", "overdrive_time", "evolutions", "run_stats", "_shot_timer", "_combo_timer", "_dash_id", "_choices", "_ship", "_missile_timer", "_chain_timer", "_pulse_timer", "_overdrives", "boundary_returns", "_outside", "peak_combo", "buffs", "pending_items", "items_collected", "focus_time", "slipstream_time", "guard_cooldown", "_orbit_positions", "_boundary_feedback", "mission_rng", "mission", "mission_result", "missions_completed", "mission_bonus_choices", "upgrade_source", "parts", "pending_tech", "hull_forms", "_next_mission_at", "_last_mission", "_barrier_timer", "_dash_direction", "guard_stacks", "axe_catches", "_sentry_timer", "_mine_timer", "_axe_timer", "_wake_timer", "loot_notices", "audio_events", "events", "branch_id", "branch_pending"]
var model := RunModel.new()
var actors: Array[Dictionary] = []
var active := 0
var granting_xp := false
var phase := "playing"
var sequence := 0

func reset(seed_value: int, difficulty: String, ships: Array, sector: String) -> void:
	model.online_world = null
	actors.clear()
	active = 0
	phase = "playing"
	sequence = 0
	model = RunModel.new()
	model.reset(seed_value, difficulty, str(ships[0]), sector)
	for i in ships.size():
		var source := RunModel.new()
		source.reset(seed_value, difficulty, str(ships[i]), sector)
		var actor := {"life": "alive", "rescued": false, "down_left": 0.0, "rescue": 0.0, "previous": source.player, "final_vote": false, "choice_left": 0.0, "choice_revision": 0, "offered_key": ""}
		for key: String in FIELDS:
			actor[key] = source.get(key)
		if ships.size() > 1: actor.player += Vector2(-28 if i == 0 else 28, 0)
		actors.append(actor)
	for key: String in FIELDS: model.set(key, actors[0][key])
	if actors.size() > 1:
		model.online_world = self
		model._mode = model._mode.duplicate()
		model._mode.spawn *= 1.2

func save_actor() -> void:
	if actors[active].life != "alive": model.hp = 0.0
	for key: String in FIELDS: actors[active][key] = model.get(key)

func select_actor(index: int) -> void:
	if index == active: return
	save_actor()
	active = index
	for key: String in FIELDS: model.set(key, actors[index][key])

func alive() -> Array[int]:
	var result: Array[int] = []
	for i in actors.size():
		if actors[i].life == "alive": result.append(i)
	return result

func choose(index: int, id: String, revision: int) -> bool:
	if revision < 1 or revision != int(actors[index].choice_revision): return false
	select_actor(index)
	var ok: bool = model.choose_branch(id) if model.state == "branch" else model.choose_upgrade(id)
	save_actor()
	if ok:
		actors[index].choice_left = 0.0
		actors[index].offered_key = ""
	return ok

func choices(index: int) -> Array:
	select_actor(index)
	var result: Array = []
	if model.state == "branch":
		result = GameContent.BRANCH_IDS.filter(func(id: String) -> bool: return GameContent.branch_info(id).ship == model.ship_id)
	elif model.state == "upgrade":
		result = model.get_upgrade_choices().map(func(value: Variant) -> String: return str(value.id) if value is Dictionary else str(value))
	if not result.is_empty():
		var key := JSON.stringify([model.state,model.level,model.mission_bonus_choices,model.upgrade_source,result])
		if key != str(actors[index].offered_key):
			actors[index].offered_key = key
			actors[index].choice_revision += 1
	return result

func step(dt: float, inputs: Array) -> void:
	if phase in ["won", "lost", "aborted"]: return
	save_actor()
	var selecting := false
	for i in alive():
		if actors[i].state in ["upgrade", "branch"]:
			selecting = true
			var available := choices(i)
			if actors[i].choice_left <= 0.0: actors[i].choice_left = 15.0 if model.state == "branch" else 20.0
			actors[i].choice_left -= dt
			if actors[i].choice_left <= 0.0 and not available.is_empty():
				choose(i, "restore" if available.has("restore") else str(available[0]), int(actors[i].choice_revision))
	if selecting:
		phase = "selection"
		return
	phase = "playing"
	sequence += 1
	if actors.size() == 1:
		var input: Dictionary = inputs[0]
		if input.get("overdrive", false): model.activate_overdrive()
		if input.has("finale"): model.select_finale(bool(input.finale))
		model.step(dt, input.get("move", Vector2.ZERO), input.get("dash", false), input.get("aim", Vector2.ZERO))
		save_actor()
		if model.state in ["won", "lost"]: phase = model.state
		return
	var previous_elapsed := model.elapsed
	model.elapsed = minf(model.duration, model.elapsed + dt)
	var live := alive()
	if live.is_empty():
		finish()
		return
	select_actor(live[0])
	model._update_items(dt)
	for i in live:
		select_actor(i)
		if i != live[0]: model._update_buffs(dt)
		model._update_vitals(dt)
		if model.hp <= 0.0:
			knocked_down()
			continue
		model._tick_mission_clock()
		if (previous_elapsed < 240.0 and model.elapsed >= 240.0) or (previous_elapsed < 300.0 and model.elapsed >= 300.0): model._check_evolutions()
		actors[i].previous = model.player
		var input: Dictionary = inputs[i]
		if input.get("overdrive", false): model.activate_overdrive()
		if input.has("finale"): actors[i].final_vote = bool(input.finale)
		model._step_player(dt, input.get("move", Vector2.ZERO), input.get("dash", false), input.get("aim", Vector2.ZERO))
		model._orbit_positions.clear()
		for j in model.orbit_count: model._orbit_positions.append(model.orbit_position(j))
		model._step_weapons(dt)
		stamp_shots(i)
		save_actor()
	live = alive()
	if live.is_empty():
		finish()
		return
	select_actor(live[0])
	model.finale_selected = actors.all(func(a: Dictionary) -> bool: return bool(a.final_vote))
	model._tick_finale()
	model._step_spawns(dt)
	model._update_enemies(dt, actors[active].previous)
	model._update_shots(dt)
	model._update_hazards(dt)
	model._finish_deaths()
	collect_loot(dt)
	for i in alive():
		select_actor(i)
		if model.boundary_layer(model.player) > 0:
			model._mission_add("outer", dt)
		elif not model.mission.is_empty() and model.mission.status == "active" and model.mission.id == "outer" and float(model.mission.progress) >= float(model.mission.target):
			model._finish_mission(true)
		var aegis := model.hull_rank("aegis")
		if aegis > 0:
			model._barrier_timer -= dt
			if model._barrier_timer <= 0.0:
				model._barrier_timer = 5.0 if aegis == 1 else 3.5
				var radius := 110.0 if aegis == 1 else 150.0
				model.shots = model.shots.filter(func(s: Dictionary) -> bool: return bool(s.friendly) or model.player.distance_to(s.pos) > radius)
				model._effect(model.player, "guard", radius, 0.5)
		model.dash_time = maxf(0.0, model.dash_time - dt)
		if model.elapsed >= 300.0 and model.boss_defeated and not model.survival_cleared:
			model.survival_cleared = true
			model._grant_score(2500 + int(model.hp * 10.0))
		model._check_level()
		model._update_run_stats()
		save_actor()
	for i in range(model.effects.size() - 1, -1, -1):
		model.effects[i].ttl -= dt
		if float(model.effects[i].ttl) <= 0.0: model.effects.remove_at(i)
	update_rescue(dt)
	if model.elapsed >= model.duration or alive().is_empty(): finish()

func stamp_shots(owner: int) -> void:
	for shot: Dictionary in model.shots:
		if bool(shot.friendly) and not shot.has("owner"): shot.owner = owner

func nearest(at: Vector2) -> int:
	save_actor()
	var found := active
	var distance := INF
	for i in alive():
		var candidate: float = Vector2(actors[i].player).distance_squared_to(at)
		if candidate < distance:
			distance = candidate
			found = i
	return found

func select_enemy_actor(enemy: Dictionary) -> Vector2:
	var index: int = int(enemy.get("target", nearest(enemy.pos))) if float(enemy.warn) > 0.0 or float(enemy.charge_time) > 0.0 else nearest(enemy.pos)
	if not index in alive(): index = nearest(enemy.pos)
	enemy.target = index
	select_actor(index)
	return actors[index].previous

func select_shot_actor(shot: Dictionary, dt: float) -> void:
	if bool(shot.friendly):
		select_actor(clampi(int(shot.get("owner", 0)), 0, actors.size() - 1))
	else:
		var target := nearest(shot.pos)
		var distance := INF
		for i in alive():
			var point := Geometry2D.get_closest_point_to_segment(actors[i].player, shot.pos, Vector2(shot.pos) + Vector2(shot.velocity) * dt)
			var candidate: float = point.distance_squared_to(actors[i].player)
			if candidate < distance:
				distance = candidate
				target = i
		select_actor(target)

func enemy_contacts(enemy: Dictionary, dt: float) -> void:
	var timers: Dictionary = enemy.get("actor_orbits", {})
	var dashes: Dictionary = enemy.get("actor_dashes", {})
	for i in alive():
		select_actor(i)
		enemy.orbit_timer = maxf(0.0, float(timers.get(i, 0.0)) - dt)
		enemy.dash_id = int(dashes.get(i, -1))
		model._attack_enemy_contact(enemy, actors[i].previous, model._power())
		timers[i] = enemy.orbit_timer
		dashes[i] = enemy.dash_id
		if float(enemy.hp) > 0.0 and model.player.distance_to(enemy.pos) < RunModel.PLAYER_RADIUS + float(enemy.radius):
			model.take_damage(float(enemy.damage), "combat", enemy.pos)
			if model.hp <= 0.0: knocked_down()
		enemy.actor_orbits = timers
		enemy.actor_dashes = dashes

func enemy_spawned(enemy: Dictionary) -> void:
	enemy.hp *= 1.6
	enemy.max_hp *= 1.6
	for attempt in 16:
		if actors.all(func(a: Dictionary) -> bool: return Vector2(a.player).distance_to(enemy.pos) >= 180.0): break
		enemy.pos = RunModel.CENTER + (Vector2(enemy.pos) - RunModel.CENTER).rotated(PI / 8.0)

func enemy_damaged(enemy: Dictionary) -> void:
	enemy.last_owner = active
	var hits: Dictionary = enemy.get("contributors", {})
	hits[active] = model.elapsed
	enemy.contributors = hits

func enemy_killed(enemy: Dictionary) -> void:
	var owner := clampi(int(enemy.get("last_owner", active)), 0, actors.size() - 1)
	for key: Variant in enemy.get("contributors", {}):
		var index := int(key)
		if index != owner and model.elapsed - float(enemy.contributors[key]) <= 5.0:
			select_actor(index)
			model._mission_add(str(enemy.kind), 1.0)
	select_actor(owner)

func enemy_strength() -> float:
	save_actor()
	var equipment := 0.0
	for actor: Dictionary in actors:
		for value: Variant in actor.parts.values(): equipment += float(value)
	return 1.0 + 1.8 * pow(clampf((model.elapsed - 150.0) / 450.0, 0.0, 1.0), 1.4) + minf(0.45, equipment / actors.size() * 0.025)

func grant_xp(amount: float) -> void:
	var owner := active
	granting_xp = true
	for i in alive():
		select_actor(i)
		model._grant_xp(amount)
	select_actor(owner)
	granting_xp = false

func hazard_contact(hazard: Dictionary) -> void:
	for i in alive():
		select_actor(i)
		var overlaps: bool = Rect2(hazard.rect).grow(RunModel.PLAYER_RADIUS * 0.65).has_point(model.player) if hazard.kind == "lane" else model.player.distance_to(hazard.pos) < float(hazard.radius) + RunModel.PLAYER_RADIUS
		if overlaps:
			model.take_damage((13.0 if hazard.kind == "lane" else 20.0) * (1.0 + 0.25 * model.hazard_pressure()), str(hazard.kind), hazard.pos)
			if model.hp <= 0.0: knocked_down()

func encounter_contact(hazard: Dictionary, dt: float, previous_ttl: float) -> void:
	if hazard.kind == "planet":
		select_actor(nearest(hazard.pos))
		var before := model.xp
		model._update_encounter(hazard, dt, previous_ttl)
		if model.xp > before:
			var amount := model.xp - before
			for i in alive():
				if i != active: actors[i].xp += amount
	else:
		for i in alive():
			select_actor(i)
			model._update_encounter(hazard, dt, previous_ttl)
			if model.hp <= 0.0: knocked_down()

func collect_loot(dt: float) -> void:
	for i in range(model.gems.size() - 1, -1, -1):
		var gem: Dictionary = model.gems[i]
		gem.pos = model._drift_loot(gem.pos, dt, RunModel.XP_DRIFT_SPEED)
		select_actor(nearest(gem.pos))
		var magnet := 86.0 + float(model.upgrades.get("magnet", 0)) * 38.0
		var distance := model.player.distance_to(gem.pos)
		if distance < magnet: gem.pos = Vector2(gem.pos).move_toward(model.player, (300.0 + 2.0 * (magnet - distance)) * dt)
		if model.player.distance_to(gem.pos) < 19.0:
			if gem.get("kind", "xp") == "heal": model.hp = minf(model.max_hp, model.hp + float(gem.value) * model.repair_efficiency())
			else: grant_xp(float(gem.value))
			model.gems.remove_at(i)
	for i in range(model.items.size() - 1, -1, -1):
		var item: Dictionary = model.items[i]
		var winner := collector(item.pos)
		if winner >= 0:
			select_actor(winner)
			model.apply_item(str(item.id), str(item.grade), model.boundary_layer(item.pos) > 0)
			model.items.remove_at(i)
	for i in range(model.part_drops.size() - 1, -1, -1):
		var drop: Dictionary = model.part_drops[i]
		drop.ttl -= dt
		var winner := collector(drop.pos, bool(drop.locked), int(drop.get("owner", -1)))
		if winner >= 0:
			for recipient in ([winner] if drop.get("source", "") == "mission" else range(actors.size())):
				select_actor(recipient)
				model.collect_part(str(drop.id))
			model.part_drops.remove_at(i)
		elif float(drop.ttl) <= 0.0: model.part_drops.remove_at(i)
	if model.elapsed >= model._explore_at:
		model._explore_at = model.elapsed + 105.0
		if not model.part_drops.any(func(p: Dictionary) -> bool: return bool(p.locked)):
			var outward := (model.player - RunModel.CENTER).normalized() if model.player != RunModel.CENTER else model.facing
			model.spawn_part(RunModel.CENTER + outward.rotated(model.mission_rng.randf_range(-0.65, 0.65)) * (RunModel.ACTIVITY_RADIUS - RunModel.PLAYER_RADIUS + RunModel.LAYER_WIDTH * 1.8), "explore")

func collector(at: Vector2, locked: bool = false, owner: int = -1) -> int:
	save_actor()
	var winner := -1
	var distance := INF
	for i in alive():
		if owner >= 0 and owner != i: continue
		if locked and model.boundary_layer(actors[i].player) < 2: continue
		var candidate: float = Geometry2D.get_closest_point_to_segment(at, actors[i].previous, actors[i].player).distance_to(at)
		if candidate <= 30.0 and candidate < distance:
			distance = candidate
			winner = i
	return winner

func knocked_down() -> void:
	actors[active].life = "dead" if bool(actors[active].rescued) else "down"
	actors[active].down_left = 15.0
	model.state = "playing"
	if model.finale_status == "failed" and model.finale_boss_id >= 0 and model.elapsed < model.duration: model.finale_status = "active"
	save_actor()

func update_rescue(dt: float) -> void:
	save_actor()
	for i in actors.size():
		var actor: Dictionary = actors[i]
		if actor.life != "down": continue
		actor.down_left -= dt
		var helper := -1
		for j in alive():
			if Vector2(actors[j].player).distance_to(actor.player) <= 64.0 and float(actors[j].dash_time) <= 0.0 and float(actors[j].invulnerable) <= 0.0: helper = j
		actor.rescue = float(actor.rescue) + dt if helper >= 0 else 0.0
		if float(actor.rescue) >= 3.0:
			actor.life = "alive"
			actor.rescued = true
			actor.hp = float(actor.max_hp) * 0.3
			actor.invulnerable = 2.0
		elif float(actor.down_left) <= 0.0: actor.life = "dead"
	for key: String in FIELDS: model.set(key, actors[active][key])

func finish() -> void:
	phase = "won" if model.survival_cleared else "lost"
	for i in actors.size():
		select_actor(i)
		model._finish_run("collapse" if model.elapsed >= model.duration else "combat")
		save_actor()

func team_score() -> int:
	save_actor()
	var result := 0
	for actor: Dictionary in actors: result += int(float(actor.score) * float(model._mode.score))
	return result

func dispose() -> void:
	model.online_world = null
