class_name RunModel
extends RefCounted

const Content = preload("res://scripts/game_content.gd")
const CENTER := Vector2(640, 386)
const ACTIVITY_RADIUS := sqrt(1136.0 * 516.0 * 2.0 / PI)
const ARENA := Rect2(CENTER - Vector2.ONE * ACTIVITY_RADIUS, Vector2.ONE * ACTIVITY_RADIUS * 2.0)
const PLAYER_RADIUS := 13.0
const LAYER_WIDTH := 180.0
const BOUNDARY_BUFFER := LAYER_WIDTH * 3.0
const FLIGHT_BOUNDS := Rect2(ARENA.position - Vector2.ONE * BOUNDARY_BUFFER, ARENA.size + Vector2.ONE * BOUNDARY_BUFFER * 2.0)
const UPGRADE_IDS := ["orbit", "orbit_range", "blade", "frost", "power", "rapid", "magnet", "speed", "vitality", "dash", "repair", "missile", "chain", "pulse"]

var state := "playing"
var elapsed := 0.0
var duration := 600.0
var survival_cleared := false
var end_reason := ""
var player := ARENA.get_center()
var facing := Vector2.RIGHT
var current_speed := 0.0
var boundary_time := 0.0
var hp := 100.0
var max_hp := 100.0
var level := 1
var xp := 0.0
var xp_needed := 9.0
var kills := 0
var score := 0
var combo := 0
var dash_cooldown := 0.0
var dash_time := 0.0
var dash_recharge_total := 3.0
var enemies: Array[Dictionary] = []
var gems: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var orbit_angle := 0.0
var orbit_count := 3
var orbit_radius := 63.0
var upgrades: Dictionary = {}
var events: Array[String] = []
var boss_spawned := false
var boss_defeated := false
var invulnerable := 0.0
var mode := "normal"
var ship_id := "striker"
var sector_id := "ring"
var overdrive_meter := 0.0
var overdrive_time := 0.0
var hazards: Array[Dictionary] = []
var event_title := ""
var event_remaining := 0.0
var elites_killed := 0
var evolutions: Array[String] = []
var run_stats: Dictionary = {}
var rng := RandomNumberGenerator.new()
var _spawn_timer := 0.5
var _shot_timer := 0.25
var _combo_timer := 0.0
var _dash_id := 0
var _choices: Array = []
var _ship: Dictionary = Content.ship_info("striker")
var _elite_stage := 0
var _hazard_timer := 22.0
var _missile_timer := 0.0
var _chain_timer := 0.0
var _pulse_timer := 0.0
var _overdrives := 0
var boundary_returns := 0
var _outside := false
var peak_combo := 0
var firing_heat := 0
var firing_heat_time := 0.0
var slipstream_time := 0.0
var guard_cooldown := 0.0

func reset(seed_value: int = 0, difficulty: String = "normal", selected_ship: String = "striker", selected_sector: String = "ring") -> void:
	mode = difficulty if difficulty in Content.MODE_IDS else "normal"
	_ship = Content.ship_info(selected_ship)
	ship_id = str(_ship.id)
	sector_id = str(Content.sector_info(selected_sector).id)
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	state = "playing"
	elapsed = 0.0
	duration = 600.0
	survival_cleared = false
	end_reason = ""
	player = ARENA.get_center()
	facing = Vector2.RIGHT
	current_speed = 0.0
	boundary_time = 0.0
	max_hp = float(_ship.hp) + (50.0 if mode == "relaxed" else 0.0)
	hp = max_hp
	level = 1
	xp = 0.0
	xp_needed = 9.0
	kills = 0
	score = 0
	combo = 0
	dash_cooldown = 0.0
	dash_time = 0.0
	dash_recharge_total = float(_ship.dash)
	enemies.clear()
	gems.clear()
	shots.clear()
	effects.clear()
	events.clear()
	upgrades.clear()
	orbit_angle = 0.0
	orbit_count = int(_ship.orbits)
	orbit_radius = 63.0
	boss_spawned = false
	boss_defeated = false
	invulnerable = 0.0
	_spawn_timer = 0.5
	_shot_timer = 0.25
	_combo_timer = 0.0
	_dash_id = 0
	_choices.clear()
	overdrive_meter = 0.0
	overdrive_time = 0.0
	hazards.clear()
	event_title = ""
	event_remaining = 0.0
	elites_killed = 0
	evolutions.clear()
	_elite_stage = 0
	_hazard_timer = 22.0
	_missile_timer = 0.0
	_chain_timer = 0.0
	_pulse_timer = 0.0
	_overdrives = 0
	boundary_returns = 0
	_outside = false
	peak_combo = 0
	firing_heat = 0
	firing_heat_time = 0.0
	slipstream_time = 0.0
	guard_cooldown = 0.0
	_update_run_stats()

static func upgrade_info(id: String) -> Dictionary:
	var catalog := {
		"orbit": ["위성 증설", "회전 위성 +1 · 방어 범위 확대", 5],
		"orbit_range": ["확장 궤도", "위성 궤도 반경 +22 · 더 먼 적을 요격", 3],
		"blade": ["절삭 위성", "일반 위성을 칼날로 전환 · 단계마다 위성 피해 +35%", 3],
		"frost": ["빙결 위성", "위성 3기당 1기 빙결형 · 적 감속 40/50/60% · 지속 1.1/1.5/1.9초", 3],
		"power": ["고출력 코어", "모든 무기 피해 +25%", 5],
		"rapid": ["속사 회로", "자동 사격 속도 +24%", 5],
		"magnet": ["중력 수집기", "경험치 수집 거리 +38", 4],
		"speed": ["추진기 강화", "이동 속도 +28 · 위성 회전 가속", 4],
		"vitality": ["선체 보강", "최대 체력 +35 · 체력 70 회복", 4],
		"dash": ["점멸 충전", "대시 재사용 -0.35초 · 대시 피해 +15", 4],
		"repair": ["자가 수리", "초당 체력 재생 +1.25 · 기본 재생 1.00", 5],
		"missile": ["유도탄 포드", "자동 유도탄 · 강화마다 폭발 피해와 범위 증가", 3],
		"chain": ["연쇄 번개", "주변 적 사이를 잇는 번개 · 강화마다 연결과 피해 증가", 3],
		"pulse": ["충격파 장치", "주변 적을 밀어내는 충격파 · 강화마다 범위와 피해 증가", 3],
		"restore": ["긴급 정비", "체력 80 회복", 0],
		"burst": ["청소 펄스", "화면의 모든 적에게 피해 100", 0],
		"fortune": ["보너스 회수", "점수 +1,000 · 체력 15 회복", 0],
	}
	if not catalog.has(id):
		return {}
	var data: Array = catalog[id]
	return {"id": id, "name": data[0], "description": data[1], "cap": data[2]}

static func evolution_info(id: String) -> Dictionary:
	return Content.evolution_info(id)

func get_upgrade_choices() -> Array:
	if state != "upgrade":
		return []
	if not _choices.is_empty():
		return _choices.duplicate()
	var available: Array = []
	for id: String in UPGRADE_IDS:
		if int(upgrades.get(id, 0)) < int(upgrade_info(id).cap):
			available.append(id)
	for fallback: String in ["restore", "burst", "fortune"]:
		if available.size() < 3:
			available.append(fallback)
	var recovery: Array = []
	for id: String in ["repair", "vitality"]:
		if available.has(id):
			recovery.append(id)
	var recovery_id: String = "restore" if recovery.is_empty() else str(recovery[rng.randi_range(0, recovery.size() - 1)])
	_choices.append(recovery_id)
	available.erase(recovery_id)
	while _choices.size() < 3:
		var index := rng.randi_range(0, available.size() - 1)
		_choices.append(available.pop_at(index))
	var swap_index := rng.randi_range(0, 2)
	var first: String = _choices[0]
	_choices[0] = _choices[swap_index]
	_choices[swap_index] = first
	return _choices.duplicate()

func choose_upgrade(id: String) -> bool:
	if state != "upgrade" or not get_upgrade_choices().has(id):
		return false
	upgrades[id] = int(upgrades.get(id, 0)) + 1
	match id:
		"orbit":
			orbit_count += 1
			orbit_radius += 4.0
		"orbit_range":
			orbit_radius += 22.0
		"vitality":
			max_hp += 35.0
			hp = minf(max_hp, hp + 70.0)
		"restore":
			hp = minf(max_hp, hp + 80.0)
		"burst":
			for enemy: Dictionary in enemies:
				_hit_enemy(enemy, 100.0)
		"fortune":
			score += 1000
			hp = minf(max_hp, hp + 15.0)
	_choices.clear()
	state = "playing"
	events.append("upgrade")
	_check_evolutions()
	_check_level()
	_update_run_stats()
	return true

func step(delta: float, move: Vector2, dash_pressed: bool) -> void:
	if state != "playing" or delta <= 0.0:
		return
	var dt := minf(delta, 0.05)
	elapsed = minf(duration, elapsed + dt)
	_update_vitals(dt)
	if state != "playing":
		return
	overdrive_time = maxf(0.0, overdrive_time - dt)
	firing_heat_time = maxf(0.0, firing_heat_time - dt)
	if firing_heat_time <= 0.0:
		firing_heat = 0
	slipstream_time = maxf(0.0, slipstream_time - dt)
	guard_cooldown = maxf(0.0, guard_cooldown - dt)
	event_remaining = maxf(0.0, event_remaining - dt)
	dash_cooldown = maxf(0.0, dash_cooldown - dt)
	dash_time = maxf(0.0, dash_time - dt)
	invulnerable = maxf(0.0, invulnerable - dt)
	_combo_timer = maxf(0.0, _combo_timer - dt)
	if _combo_timer <= 0.0:
		combo = 0
	var direction := move.limit_length(1.0)
	if direction.length_squared() > 0.01:
		facing = direction.normalized()
	if dash_pressed and dash_cooldown <= 0.0:
		dash_time = 0.20
		if ship_id == "scout":
			slipstream_time = 1.6
		dash_cooldown = maxf(0.8, float(_ship.dash) - float(upgrades.get("dash", 0)) * 0.35)
		dash_recharge_total = dash_cooldown
		invulnerable = 0.34
		_dash_id += 1
		_effect(player, "dash", 55.0, 0.25)
		events.append("dash")
	var old_position := player
	var speed := base_speed() * movement_multiplier(player) * (1.35 if slipstream_time > 0.0 else 1.0)
	# Let an inward dash escape the buffer even at maximum drag.
	var dash_speed := 940.0 * (boundary_drag(player) if boundary_depth(player + facing) > boundary_depth(player) else 1.0)
	player += (facing * dash_speed if dash_time > 0.0 else direction * speed) * dt
	# A continuous inward current overcomes even a dash before deep space; no wall clamp.
	player += boundary_current(player) * dt
	if boundary_depth(player) > 0.08:
		_outside = true
	elif boundary_depth(player) == 0.0 and _outside:
		boundary_returns += 1
		_outside = false
	current_speed = player.distance_to(old_position) / dt
	orbit_angle = fmod(orbit_angle + dt * (3.5 + float(upgrades.get("speed", 0)) * 0.3), TAU)
	_spawn_timer -= dt
	if _spawn_timer <= 0.0:
		_spawn_timer = maxf(0.19, 0.92 - elapsed * 0.0023) / float(Content.mode_info(mode).spawn)
		if enemies.size() < 157:
			spawn_enemy(_spawn_kind())
	if _elite_stage < 2 and elapsed >= 90.0 * float(_elite_stage + 1):
		_elite_stage += 1
		var elite := spawn_enemy("elite")
		elite.elite_index = _elite_stage
		if _elite_stage == 2:
			elite.hp *= 1.6
			elite.max_hp = elite.hp
		_announce("심우주 침공 · " + ("돌격 정예 접근 중" if _elite_stage == 1 else "포격 정예 접근 중"), "elite")
	if elapsed >= 240.0 and not boss_spawned:
		boss_spawned = true
		spawn_enemy("boss")
		_announce("심우주 침공 경보 · 최종 지휘체 접근 중", "boss")
	_shot_timer -= dt
	if _shot_timer <= 0.0:
		_fire_player_shot()
		_shot_timer = 0.68 / ((1.0 + float(upgrades.get("rapid", 0)) * 0.24) * (1.45 if overdrive_time > 0.0 else 1.0))
	_update_weapons(dt)
	_update_enemies(dt, old_position)
	_update_shots(dt)
	_update_hazards(dt)
	if state != "playing":
		_update_run_stats()
		return
	_collect_gems(dt)
	for i in range(effects.size() - 1, -1, -1):
		effects[i].ttl -= dt
		if float(effects[i].ttl) <= 0.0:
			effects.remove_at(i)
	if elapsed >= 300.0 and boss_defeated and not survival_cleared:
		survival_cleared = true
		score += 2500 + int(hp * 10.0)
		_announce("5분 돌파! 붕괴 가속 · 한계까지 생존하세요", "milestone")
	_check_level()
	_update_run_stats()

func regeneration_rate() -> float:
	return 1.0 + float(upgrades.get("repair", 0)) * 1.25

func decay_rate() -> float:
	if elapsed <= 300.0:
		return 0.25 + 6.0 * pow(elapsed / 300.0, 2.0)
	var overtime := elapsed - 300.0
	return 6.25 + 0.045 * overtime + 0.00035 * overtime * overtime

func _update_vitals(dt: float) -> void:
	boundary_time = boundary_time + dt if boundary_depth(player) > 0.0 else 0.0
	# Environmental decay bypasses combat invulnerability and damage reduction.
	hp = clampf(hp + net_hull_rate() * dt, 0.0, max_hp)
	if elapsed >= duration:
		hp = 0.0
		_finish_run("collapse")
	elif hp <= 0.0:
		_finish_run("boundary" if boundary_damage_rate() > 0.0 else "decay")

func boundary_depth(position: Vector2) -> float:
	return clampf((position.distance_to(CENTER) - (ACTIVITY_RADIUS - PLAYER_RADIUS)) / BOUNDARY_BUFFER, 0.0, 1.0)

func boundary_layer(position: Vector2) -> int:
	var excess := position.distance_to(CENTER) - (ACTIVITY_RADIUS - PLAYER_RADIUS)
	return 0 if excess <= 0.0 else mini(3, ceili(excess / LAYER_WIDTH))

func dash_charge() -> float:
	return clampf(1.0 - dash_cooldown / maxf(0.01, dash_recharge_total), 0.0, 1.0)

func boundary_drag(position: Vector2) -> float:
	var layer_depth := boundary_depth(position) * 3.0
	if layer_depth <= 1.0:
		return lerpf(1.0, 0.9, smoothstep(0.0, 1.0, layer_depth))
	if layer_depth <= 2.0:
		return lerpf(0.9, 0.6, smoothstep(0.0, 1.0, layer_depth - 1.0))
	return lerpf(0.6, 0.06, smoothstep(0.0, 1.0, layer_depth - 2.0))

func boundary_current(position: Vector2) -> Vector2:
	var distance := maxf(0.0, position.distance_to(CENTER) - (ACTIVITY_RADIUS - PLAYER_RADIUS))
	return (CENTER - position).normalized() * 1800.0 * pow(distance / BOUNDARY_BUFFER, 3.0)

func ranked_score() -> int:
	return int(score * float(Content.mode_info(mode).score))

func boundary_damage_rate() -> float:
	var depth := boundary_depth(player) * 3.0
	if depth <= 1.0:
		return depth * (4.0 + 0.25 * boundary_time)
	if depth <= 2.0:
		return lerpf(4.0, 100.0, pow(depth - 1.0, 0.5)) + boundary_time * 2.0
	return 100.0 + 240.0 * (depth - 2.0) + 20.0 * boundary_time

func net_hull_rate() -> float:
	return regeneration_rate() - decay_rate() - boundary_damage_rate()

func base_speed() -> float:
	return float(_ship.speed) + float(upgrades.get("speed", 0)) * 28.0

func _finish_run(reason: String) -> void:
	end_reason = reason
	state = "won" if survival_cleared else "lost"
	events.append(state)
	_update_run_stats()

func movement_multiplier(position: Vector2) -> float:
	var offset := position.distance_to(CENTER) / (ACTIVITY_RADIUS - PLAYER_RADIUS)
	var edge := clampf((offset - 0.25) / 0.75, 0.0, 1.0)
	edge = edge * edge * (3.0 - 2.0 * edge)
	var floor_speed := lerpf(1.0, 0.8, clampf(elapsed / 300.0, 0.0, 1.0)) if elapsed <= 300.0 else lerpf(0.8, 0.6, clampf((elapsed - 300.0) / 300.0, 0.0, 1.0))
	return lerpf(1.0, floor_speed, edge) * boundary_drag(position)

func orbit_position(index: int) -> Vector2:
	return player + Vector2.from_angle(orbit_angle + TAU * float(index) / float(orbit_count)) * orbit_radius

func orbit_kind(index: int) -> String:
	if int(upgrades.get("frost", 0)) > 0 and index % 3 == 0:
		return "frost"
	return "blade" if int(upgrades.get("blade", 0)) > 0 else "normal"

func _spawn_kind() -> String:
	var roll := rng.randf()
	if elapsed > 80.0 and roll < 0.17:
		return "shooter"
	if elapsed > 45.0 and roll < 0.34:
		return "tank"
	if elapsed > 20.0 and roll < 0.59:
		return "runner"
	return "chaser"

func spawn_enemy(kind: String, position: Vector2 = Vector2.INF) -> Dictionary:
	var point := position
	var spawn_layer := 0
	if not point.is_finite():
		spawn_layer = 4 if kind in ["elite", "boss"] else (3 if kind == "shooter" else (2 if kind == "tank" else rng.randi_range(1, 2)))
		var radius := ACTIVITY_RADIUS + (spawn_layer - 1) * LAYER_WIDTH + rng.randf_range(40.0, 130.0)
		point = CENTER + Vector2.from_angle(rng.randf_range(0.0, TAU)) * radius
		if point.distance_to(player) < 180.0:
			point = CENTER - (point - CENTER)
		_effect(point, "arrival", 36.0 if spawn_layer < 4 else 70.0, 1.4)
	var stats: Array = {
		"chaser": [23.0, 62.0, 13.0, 10.0, 1.0],
		"runner": [18.0, 115.0, 10.0, 9.0, 1.0],
		"tank": [92.0, 37.0, 21.0, 16.0, 4.0],
		"shooter": [45.0, 50.0, 16.0, 10.0, 3.0],
		"elite": [360.0, 67.0, 27.0, 18.0, 16.0],
		"boss": [3600.0, 44.0, 39.0, 24.0, 30.0],
	}.get(kind, [23.0, 62.0, 13.0, 10.0, 1.0])
	var health := float(stats[0]) * (1.0 if kind == "boss" else 1.0 + elapsed * 0.0022)
	health *= float(Content.mode_info(mode).health)
	var enemy := {"pos": point, "hp": health, "max_hp": health, "speed": float(stats[1]) * (0.8 if mode == "relaxed" else 1.0), "radius": float(stats[2]), "damage": float(stats[3]), "value": float(stats[4]), "kind": kind, "flash": 0.0, "angle": 0.0, "orbit_timer": 0.0, "shot_timer": rng.randf_range(1.7, 3.0), "warn": 0.0, "aim": Vector2.RIGHT, "dash_id": -1, "elite_index": 1, "charge_time": 0.0, "phase": 1}
	enemies.append(enemy)
	enemy.spawn_layer = spawn_layer
	if spawn_layer == 4:
		_announce("심우주 침공 경보 · " + ("지휘체" if kind == "boss" else "정예") + " 접근 중", "invasion")
	enemy.speed *= float(Content.mode_info(mode).speed)
	return enemy

func _update_enemies(dt: float, old_position: Vector2) -> void:
	var power := _power()
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		if float(enemy.hp) <= 0.0:
			_kill_enemy(enemy)
			enemies.remove_at(i)
			continue
		enemy.flash = maxf(0.0, float(enemy.flash) - dt)
		enemy.orbit_timer = maxf(0.0, float(enemy.orbit_timer) - dt)
		var toward: Vector2 = player - Vector2(enemy.pos)
		var direction := toward.normalized()
		enemy.angle = direction.angle()
		var movement := direction
		if enemy.kind == "boss" and int(enemy.phase) == 1 and float(enemy.hp) <= float(enemy.max_hp) * 0.5 and float(enemy.hp) > 0.0:
			enemy.phase = 2
			enemy.shot_timer = 0.8
			_announce("지휘체 격앙 · 탄막 강화", "phase")
		if enemy.kind == "shooter" and toward.length() < 265.0:
			movement = -direction * 0.35 if toward.length() < 190.0 else Vector2.ZERO
		if float(enemy.warn) > 0.0:
			enemy.warn = maxf(0.0, float(enemy.warn) - dt)
			movement *= 0.2
			if float(enemy.warn) <= 0.0:
				_fire_enemy_shots(enemy)
		elif enemy.kind == "shooter" or enemy.kind == "boss" or enemy.kind == "elite":
			enemy.shot_timer -= dt
			if float(enemy.shot_timer) <= 0.0:
				enemy.warn = 1.1 if enemy.kind == "elite" else 0.70
				enemy.aim = direction
				enemy.shot_timer = (1.35 if int(enemy.phase) == 2 else 1.8) if enemy.kind == "boss" else 3.5
		if float(enemy.charge_time) > 0.0:
			enemy.charge_time = maxf(0.0, float(enemy.charge_time) - dt)
			movement = Vector2(enemy.aim) * 4.5
		enemy.slow_time = maxf(0.0, float(enemy.get("slow_time", 0.0)) - dt)
		enemy.pos += movement * float(enemy.speed) * (0.7 if int(enemy.get("spawn_layer", 0)) == 4 and Vector2(enemy.pos).distance_to(CENTER) > ACTIVITY_RADIUS else 1.0) * (float(enemy.get("slow_factor", 1.0)) if float(enemy.slow_time) > 0.0 else 1.0) * dt
		if dash_time > 0.0 and int(enemy.dash_id) != _dash_id:
			var closest := Geometry2D.get_closest_point_to_segment(enemy.pos, old_position, player)
			if closest.distance_to(enemy.pos) < float(enemy.radius) + 28.0:
				enemy.dash_id = _dash_id
				_hit_enemy(enemy, (52.0 + float(upgrades.get("dash", 0)) * 15.0) * power * (1.75 if ship_id == "scout" else 1.0))
		if float(enemy.orbit_timer) <= 0.0:
			for j in orbit_count:
				var orb := orbit_position(j)
				if orb.distance_to(enemy.pos) <= float(enemy.radius) + (17.0 if evolutions.has("superorbit") else 10.0):
					var kind := orbit_kind(j)
					_hit_enemy(enemy, 25.0 * power * (1.6 if evolutions.has("superorbit") else 1.0) * (1.0 + 0.35 * float(upgrades.get("blade", 0))) * (0.8 if kind == "frost" else 1.0))
					if kind == "frost":
						var rank := float(upgrades.get("frost", 0))
						enemy.slow_time = 0.7 + 0.4 * rank
						enemy.slow_factor = 0.7 - 0.1 * rank
					enemy.orbit_timer = 0.23 if evolutions.has("superorbit") else 0.28
					break
		if float(enemy.hp) <= 0.0:
			_kill_enemy(enemy)
			enemies.remove_at(i)
		elif player.distance_to(enemy.pos) < PLAYER_RADIUS + float(enemy.radius):
			take_damage(float(enemy.damage))
			if state != "playing":
				return
			if enemy.kind != "boss" and enemy.kind != "elite":
				enemy.pos -= direction * 12.0

func _fire_player_shot() -> void:
	var nearest: Dictionary = {}
	var distance := 740.0
	for enemy: Dictionary in enemies:
		var candidate := player.distance_to(enemy.pos)
		if candidate < distance and float(enemy.hp) > 0.0:
			nearest = enemy
			distance = candidate
	if nearest.is_empty() or shots.size() >= 240:
		return
	var direction := (Vector2(nearest.pos) - player).normalized()
	shots.append({"pos": player, "velocity": direction * 590.0, "friendly": true, "radius": 5.0, "damage": 19.0 * _power(), "ttl": 1.45})
	if ship_id == "striker":
		firing_heat = mini(5, firing_heat + 1)
		firing_heat_time = 2.0
	events.append("shot")

func _fire_enemy_shots(enemy: Dictionary) -> void:
	if enemy.kind == "elite" and int(enemy.elite_index) == 1:
		enemy.charge_time = 0.6
		return
	if shots.size() >= 220:
		return
	var is_boss: bool = enemy.kind == "boss"
	var phase: int = int(enemy.phase)
	var count := (12 if phase == 2 else 9) if is_boss else (5 if enemy.kind == "elite" else 1)
	if is_boss and sector_id != "ring":
		count = (9 if phase == 2 else 5) if sector_id == "storm" else (7 if phase == 2 else 3)
		if sector_id == "forge":
			_add_blast(player, 64.0)
			if phase == 2:
				_add_blast(player + facing * 100.0, 60.0)
	for i in count:
		if shots.size() >= 240:
			break
		var angle := TAU * float(i) / float(count) if is_boss and sector_id == "ring" else (float(i) - float(count - 1) * 0.5) * 0.23
		var direction: Vector2 = Vector2(enemy.aim).rotated(angle)
		shots.append({"pos": Vector2(enemy.pos) + direction * float(enemy.radius), "velocity": direction * (148.0 if is_boss else 185.0) * (0.82 if mode == "relaxed" else 1.0), "friendly": false, "radius": 7.0, "damage": 13.0 if is_boss else 10.0, "ttl": 5.0})
	_effect(enemy.pos, "fire", float(enemy.radius) + 10.0, 0.25)

func _update_shots(dt: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var shot: Dictionary = shots[i]
		var previous: Vector2 = shot.pos
		if shot.get("kind", "") == "missile":
			var target := _nearest_enemy(shot.pos, 700.0)
			if not target.is_empty():
				shot.velocity = Vector2(shot.velocity).move_toward((Vector2(target.pos) - Vector2(shot.pos)).normalized() * 350.0, 1700.0 * dt)
		shot.pos += Vector2(shot.velocity) * dt
		shot.ttl -= dt
		if bool(shot.friendly):
			for enemy: Dictionary in enemies:
				var closest := Geometry2D.get_closest_point_to_segment(enemy.pos, previous, shot.pos)
				if float(enemy.hp) > 0.0 and closest.distance_to(enemy.pos) < float(enemy.radius) + float(shot.radius):
					if shot.get("kind", "") == "missile":
						for splash: Dictionary in enemies:
							if Vector2(splash.pos).distance_to(enemy.pos) < float(shot.blast_radius) + float(splash.radius):
								_hit_enemy(splash, float(shot.damage))
						_effect(enemy.pos, "pulse", float(shot.blast_radius), 0.30)
					else:
						_hit_enemy(enemy, float(shot.damage))
					shot.ttl = 0.0
					break
		else:
			var closest := Geometry2D.get_closest_point_to_segment(player, previous, shot.pos)
			if closest.distance_to(player) < PLAYER_RADIUS + float(shot.radius):
				take_damage(float(shot.damage))
				shot.ttl = 0.0
		if float(shot.ttl) <= 0.0:
			shots.remove_at(i)

func take_damage(amount: float) -> void:
	if state != "playing" or invulnerable > 0.0 or amount <= 0.0:
		return
	if ship_id == "bastion" and guard_cooldown <= 0.0:
		amount *= 0.4
		guard_cooldown = 8.0
		for enemy: Dictionary in enemies:
			if float(enemy.hp) > 0.0 and player.distance_to(enemy.pos) <= 125.0 + float(enemy.radius):
				_hit_enemy(enemy, 40.0 * _power())
				enemy.pos += (Vector2(enemy.pos) - player).normalized() * 45.0
		_effect(player, "guard", 125.0, 0.35)
	firing_heat = 0
	firing_heat_time = 0.0
	hp = maxf(0.0, hp - amount * (0.75 if mode == "relaxed" else 1.0) * float(Content.mode_info(mode).damage) * (0.55 if overdrive_time > 0.0 else 1.0))
	invulnerable = 0.70
	combo = 0
	_effect(player, "hurt", 32.0, 0.3)
	events.append("hurt")
	if hp <= 0.0:
		_finish_run("combat")

func _hit_enemy(enemy: Dictionary, damage: float) -> void:
	if float(enemy.hp) <= 0.0:
		return
	enemy.hp -= damage
	enemy.flash = 0.12
	_effect(enemy.pos, "hit", 16.0, 0.14)

func _kill_enemy(enemy: Dictionary) -> void:
	kills += 1
	if overdrive_time <= 0.0:
		overdrive_meter = minf(100.0, overdrive_meter + (12.0 if enemy.kind == "elite" or enemy.kind == "boss" else 2.0))
	combo += 1
	peak_combo = maxi(peak_combo, combo)
	_combo_timer = 2.5
	score += int(float(enemy.value) * 20.0) + mini(combo, 30)
	var point: Vector2 = enemy.pos
	if gems.size() < 300:
		gems.append({"pos": point, "value": float(enemy.value), "kind": "xp"})
	else:
		xp += float(enemy.value)
	if enemy.kind == "boss":
		boss_defeated = true
		events.append("boss_down")
	elif enemy.kind == "elite":
		elites_killed += 1
		xp += 12.0
		score += 500
		_announce("정예 격파 · 경험치 +12 · 점수 +500", "elite_down")
	_effect(enemy.pos, "death", float(enemy.radius) * 1.7, 0.35)
	events.append("kill")

func _collect_gems(dt: float) -> void:
	var magnet := 86.0 + float(upgrades.get("magnet", 0)) * 38.0
	for i in range(gems.size() - 1, -1, -1):
		var gem: Dictionary = gems[i]
		var distance := player.distance_to(gem.pos)
		if distance < magnet:
			gem.pos = Vector2(gem.pos).move_toward(player, (300.0 + 2.0 * (magnet - distance)) * dt)
		if player.distance_to(gem.pos) < 19.0:
			if gem.get("kind", "xp") == "heal":
				hp = minf(max_hp, hp + float(gem.value))
				events.append("heal")
			else:
				xp += float(gem.value)
				events.append("pickup")
			gems.remove_at(i)

func _check_level() -> void:
	if xp < xp_needed:
		return
	xp -= xp_needed
	level += 1
	xp_needed = 9.0 + float(level - 1) * 4.0
	state = "upgrade"
	_choices.clear()
	get_upgrade_choices()
	events.append("level")

func activate_overdrive() -> bool:
	if state != "playing" or overdrive_meter < 100.0 or overdrive_time > 0.0:
		return false
	overdrive_meter = 0.0
	overdrive_time = 6.0
	_overdrives += 1
	_effect(player, "pulse", 135.0, 0.6)
	_announce("오버드라이브 · 화력 강화 / 받는 피해 감소", "overdrive")
	_update_run_stats()
	return true

func _power() -> float:
	return float(_ship.power) * (1.0 + float(upgrades.get("power", 0)) * 0.25) * (1.45 if overdrive_time > 0.0 else 1.0) * (1.0 + firing_heat * 0.08 if ship_id == "striker" else 1.0)

func _check_evolutions() -> void:
	for id: String in Content.EVOLUTION_IDS:
		if evolutions.has(id):
			continue
		var info := evolution_info(id)
		var ready := true
		for required: String in info.requirements:
			if int(upgrades.get(required, 0)) < int(info.requirements[required]):
				ready = false
		if ready:
			evolutions.append(id)
			_effect(player, "pulse", 155.0, 0.7)
			_announce("무기 진화 · " + str(info.name), "evolution")

func _nearest_enemy(origin: Vector2, distance: float, excluded: Array[Dictionary] = []) -> Dictionary:
	var nearest: Dictionary = {}
	for enemy: Dictionary in enemies:
		var candidate := origin.distance_to(enemy.pos)
		if float(enemy.hp) > 0.0 and candidate < distance and not excluded.has(enemy):
			nearest = enemy
			distance = candidate
	return nearest

func _update_weapons(dt: float) -> void:
	var missile_rank := int(upgrades.get("missile", 0))
	var chain_rank := int(upgrades.get("chain", 0))
	var pulse_rank := int(upgrades.get("pulse", 0))
	_missile_timer -= dt
	_chain_timer -= dt
	_pulse_timer -= dt
	if missile_rank > 0 and _missile_timer <= 0.0:
		_missile_timer = 2.8
		var target := _nearest_enemy(player, 720.0)
		if not target.is_empty():
			var count := 3 if evolutions.has("salvo") else 1
			for i in count:
				if shots.size() >= 240:
					break
				var direction := (Vector2(target.pos) - player).normalized().rotated((float(i) - float(count - 1) * 0.5) * 0.4)
				shots.append({"pos": player, "velocity": direction * 350.0, "friendly": true, "radius": 8.0, "damage": (40.0 + 18.0 * missile_rank) * _power(), "ttl": 3.0, "kind": "missile", "blast_radius": 38.0 + float(missile_rank) * 10.0 + (25.0 if count == 3 else 0.0)})
				_effect(player, "missile", 8.0, 0.18, player + direction * 38.0)
	if chain_rank > 0 and _chain_timer <= 0.0:
		_chain_timer = 2.2
		var cursor := player
		var visited: Array[Dictionary] = []
		var count := 2 + chain_rank + (3 if evolutions.has("storm") else 0)
		for i in count:
			var target := _nearest_enemy(cursor, 335.0 if i == 0 else 190.0, visited)
			if target.is_empty():
				break
			_hit_enemy(target, (15.0 + 10.0 * chain_rank) * _power() * (1.4 if evolutions.has("storm") else 1.0))
			_effect(cursor, "lightning", 7.0, 0.25, target.pos)
			visited.append(target)
			cursor = target.pos
	if pulse_rank > 0 and _pulse_timer <= 0.0:
		_pulse_timer = 4.3
		var radius := 125.0 + float(pulse_rank) * 25.0
		_effect(player, "pulse", radius, 0.55)
		for enemy: Dictionary in enemies:
			if player.distance_to(enemy.pos) < radius + float(enemy.radius):
				_hit_enemy(enemy, (12.0 + float(pulse_rank) * 8.0) * _power())
				if enemy.kind != "boss":
					enemy.pos += (Vector2(enemy.pos) - player).normalized() * 36.0

func _add_blast(position: Vector2, radius: float) -> void:
	if hazards.size() >= 6:
		return
	var point := CENTER + (position - CENTER).limit_length(ACTIVITY_RADIUS - radius)
	hazards.append({"kind": "blast", "pos": point, "radius": radius, "rect": Rect2(), "warn": 1.6, "ttl": 0.35, "active": false})

func _add_lane() -> void:
	if hazards.size() >= 6:
		return
	var vertical := rng.randf() < 0.5
	var width := 62.0 if mode == "relaxed" else 74.0
	var offset := clampf((player.x - CENTER.x) if vertical else (player.y - CENTER.y), -ACTIVITY_RADIUS + width, ACTIVITY_RADIUS - width)
	var half_length := sqrt(ACTIVITY_RADIUS * ACTIVITY_RADIUS - pow(absf(offset) + width * 0.5, 2.0))
	var rect := Rect2(CENTER + Vector2(offset - width * 0.5, -half_length), Vector2(width, half_length * 2.0)) if vertical else Rect2(CENTER + Vector2(-half_length, offset - width * 0.5), Vector2(half_length * 2.0, width))
	hazards.append({"kind": "lane", "pos": rect.get_center(), "radius": 0.0, "rect": rect, "warn": 1.5, "ttl": 1.1, "active": false})

func _update_hazards(dt: float) -> void:
	if state != "playing":
		return
	_hazard_timer -= dt
	if sector_id != "ring" and _hazard_timer <= 0.0:
		_hazard_timer = 12.0 if sector_id == "storm" else 14.0
		if sector_id == "storm":
			_add_lane()
		else:
			_add_blast(player, 72.0)
			_add_blast(CENTER + Vector2.from_angle(rng.randf_range(0.0, TAU)) * sqrt(rng.randf()) * (ACTIVITY_RADIUS - 68.0), 68.0)
		_announce("전기 통로 충전 · 표시 구역 이탈" if sector_id == "storm" else "포격 경보 · 노란 예고 원 이탈", "hazard")
	for i in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[i]
		if not bool(hazard.active):
			hazard.warn = maxf(0.0, float(hazard.warn) - dt)
			if float(hazard.warn) <= 0.0:
				hazard.active = true
			continue
		hazard.ttl -= dt
		var overlaps: bool = Rect2(hazard.rect).grow(PLAYER_RADIUS * 0.65).has_point(player) if hazard.kind == "lane" else player.distance_to(hazard.pos) < float(hazard.radius) + PLAYER_RADIUS
		if overlaps:
			take_damage(13.0 if hazard.kind == "lane" else 20.0)
		if float(hazard.ttl) <= 0.0:
			hazards.remove_at(i)

func _announce(title: String, event: String) -> void:
	event_title = title
	event_remaining = 3.3
	events.append(event)

func _update_run_stats() -> void:
	run_stats = {"kills": kills, "score": ranked_score(), "time": elapsed, "winner": state == "won", "level": level, "elites": elites_killed, "ship": ship_id, "sector": sector_id, "mode": mode, "evolutions": evolutions.duplicate(), "overdrives": _overdrives, "dashes": _dash_id, "returns": boundary_returns, "combo": peak_combo, "upgrades": upgrades.duplicate()}

func _effect(position: Vector2, kind: String, radius: float, lifetime: float, end: Vector2 = Vector2.INF) -> void:
	if effects.size() < 180:
		var effect := {"pos": position, "kind": kind, "ttl": lifetime, "max_ttl": lifetime, "radius": radius}
		if end.is_finite():
			effect["end"] = end
		effects.append(effect)
