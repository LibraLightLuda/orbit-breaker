extends SceneTree

const Model = preload("res://scripts/run_model.gd")
const Content = preload("res://scripts/game_content.gd")

var checks := 0
var failures := 0

func _init() -> void:
	var relaxed_wins := {"ring": 0, "storm": 0, "forge": 0}
	for difficulty: String in Content.MODE_IDS:
		for sector_id: String in Content.SECTOR_IDS:
			for ship_id: String in Content.SHIP_IDS:
				var result := _run_case(ship_id, sector_id, difficulty)
				var label := "%s/%s/%s" % [ship_id, sector_id, difficulty]
				_check(bool(result.finite), label + " keeps finite state")
				_check(result.state in ["won", "lost"], label + " reaches a terminal state")
				_check(float(result.elapsed) <= 600.0, label + " ends within ten minutes")
				if difficulty == "relaxed" and result.state == "won":
					relaxed_wins[sector_id] += 1
	for sector_id: String in Content.SECTOR_IDS:
		_check(int(relaxed_wins[sector_id]) > 0, "at least one relaxed win in " + sector_id)
	print("BALANCE SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run_case(ship_id: String, sector_id: String, difficulty: String) -> Dictionary:
	# The pilot only moves, dashes, selects offered upgrades and uses charged overdrive.
	var model := Model.new()
	model.reset(7, difficulty, ship_id, sector_id)
	var iterations := 0
	var hits := 0
	var dashes := 0
	var overdrives := 0
	var boss_down_at := 0.0
	var finite := true
	while model.state not in ["won", "lost"] and iterations < 40000:
		iterations += 1
		if model.state == "upgrade":
			if not model.choose_upgrade(_choose_upgrade(model, ship_id)):
				break
			continue
		if model.overdrive_meter >= 100.0 and model.activate_overdrive():
			overdrives += 1
		var phase: float = model.elapsed * 0.48
		var target := Model.CENTER + Vector2.from_angle(phase) * 408.0
		var closest_enemy := 1000.0
		var avoid := Vector2.ZERO
		for enemy: Dictionary in model.enemies:
			var offset: Vector2 = model.player - Vector2(enemy.pos)
			var distance := offset.length()
			closest_enemy = minf(closest_enemy, distance - float(enemy.radius))
			if enemy.kind == "boss":
				target = Vector2(enemy.pos) + Vector2.from_angle(model.elapsed * 1.5) * 103.0
			if distance < 72.0 + float(enemy.radius):
				avoid += offset.normalized() * (1.0 - distance / (72.0 + float(enemy.radius))) * 1.4
		if not model.boss_spawned or model.boss_defeated:
			var best := 165.0
			for gem: Dictionary in model.gems:
				var distance: float = model.player.distance_to(gem.pos)
				if distance < best and _point_is_safe(model, gem.pos):
					target = gem.pos
					best = distance
		var bullet_close := false
		for shot: Dictionary in model.shots:
			if not bool(shot.friendly) and model.player.distance_to(shot.pos) < 65.0:
				bullet_close = true
				avoid += (model.player - Vector2(shot.pos)).normalized() * 0.35
		var hazard_avoid := _avoid_hazards(model)
		var move: Vector2 = (target - model.player).normalized() + avoid + hazard_avoid
		if model.player.distance_to(Model.CENTER) > Model.ACTIVITY_RADIUS - 70.0:
			move = (Model.CENTER - model.player).normalized() * 1.5 + avoid * 0.2
		model.step(1.0 / 60.0, move, closest_enemy < 45.0 or bullet_close or hazard_avoid.length() > 1.8)
		if model.events.has("hurt"): hits += 1
		if model.events.has("dash"): dashes += 1
		if model.events.has("boss_down"): boss_down_at = model.elapsed
		model.events.clear()
		if not model.player.is_finite() or not is_finite(model.hp) or not is_finite(model.elapsed):
			finite = false
			break
	print("BALANCE ship=%s sector=%s mode=%s seed=7 state=%s seconds=%.1f level=%d kills=%d hp=%.1f hits=%d dashes=%d overdrives=%d boss_down_at=%.1f" % [ship_id, sector_id, difficulty, model.state, model.elapsed, model.level, model.kills, model.hp, hits, dashes, overdrives, boss_down_at])
	return {"state": model.state, "finite": finite, "elapsed": model.elapsed}

func _choose_upgrade(model: RefCounted, ship_id: String) -> String:
	var choices: Array = model.get_upgrade_choices()
	if choices.is_empty():
		return ""
	if model.hp < model.max_hp * 0.5:
		for recovery: String in ["restore", "vitality", "repair"]:
			if choices.has(recovery):
				return recovery
	if choices.has("repair") and int(model.upgrades.get("repair", 0)) < (3 if model.elapsed < 240.0 else 5):
		return "repair"
	var build_order: Array = {
		"striker": ["missile", "dash"],
		"scout": ["chain", "rapid"],
		"bastion": ["orbit", "power", "pulse"]
	}[ship_id]
	for preferred: String in build_order + ["orbit", "power", "repair", "pulse", "missile", "chain", "vitality", "rapid", "speed", "dash", "magnet", "restore", "burst", "fortune"]:
		if choices.has(preferred):
			return preferred
	return str(choices[0])

func _point_is_safe(model: RefCounted, point: Vector2) -> bool:
	for enemy: Dictionary in model.enemies:
		if Vector2(enemy.pos).distance_to(point) < 65.0:
			return false
	for hazard: Dictionary in model.hazards:
		if hazard.kind == "lane" and Rect2(hazard.rect).grow(24.0).has_point(point):
			return false
		if hazard.kind == "blast" and Vector2(hazard.pos).distance_to(point) < float(hazard.radius) + 24.0:
			return false
	return true

func _avoid_hazards(model: RefCounted) -> Vector2:
	var avoid := Vector2.ZERO
	for hazard: Dictionary in model.hazards:
		if hazard.kind == "lane":
			var area := Rect2(hazard.rect).grow(45.0)
			if not area.has_point(model.player):
				continue
			var exits := [Vector2(area.position.x - model.player.x, 0.0), Vector2(area.end.x - model.player.x, 0.0), Vector2(0.0, area.position.y - model.player.y), Vector2(0.0, area.end.y - model.player.y)]
			var closest: Vector2 = exits[0]
			for exit_direction: Vector2 in exits:
				if exit_direction.length_squared() < closest.length_squared():
					closest = exit_direction
			avoid += closest.normalized() * 2.8
		else:
			var offset: Vector2 = model.player - Vector2(hazard.pos)
			var safe_distance := float(hazard.radius) + 75.0
			if offset.length() < safe_distance:
				avoid += (offset.normalized() if offset.length_squared() > 0.01 else Vector2.UP) * (1.0 - offset.length() / safe_distance) * 4.0
	return avoid
