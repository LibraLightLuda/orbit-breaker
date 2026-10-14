class_name RunModel
extends RefCounted

const Content = preload("res://scripts/game_content.gd")
const CENTER := Vector2(640, 386)
const WORLD_SCALE := 0.8
const ACTIVITY_RADIUS := sqrt(1136.0 * 516.0 * 2.0 / PI) * WORLD_SCALE
const ARENA := Rect2(CENTER - Vector2.ONE * ACTIVITY_RADIUS, Vector2.ONE * ACTIVITY_RADIUS * 2.0)
const PLAYER_RADIUS := 13.0
const LOOT_DRIFT_SPEED := 18.0
const XP_DRIFT_SPEED := 5.0
const LAYER_WIDTH := 180.0 * WORLD_SCALE
const BOUNDARY_BUFFER := LAYER_WIDTH * 3.0
const FLIGHT_BOUNDS := Rect2(ARENA.position - Vector2.ONE * BOUNDARY_BUFFER, ARENA.size + Vector2.ONE * BOUNDARY_BUFFER * 2.0)
const UPGRADE_IDS := ["orbit", "orbit_range", "blade", "frost", "power", "rapid", "magnet", "speed", "vitality", "dash", "repair", "missile", "chain", "pulse", "focus_amp", "focus_memory", "scout_lance", "scout_drive", "guard_reserve", "guard_pulse"]
const SHIP_PARTS := {"focus_amp": ["striker", "core", ""], "focus_memory": ["striker", "shell", "focus_amp"], "scout_lance": ["scout", "core", ""], "scout_drive": ["scout", "drive", "scout_lance"], "guard_reserve": ["bastion", "shell", ""], "guard_pulse": ["bastion", "core", "guard_reserve"]}
const ENCOUNTERS := {
	"black_hole": {"name": "블랙홀", "hint": "중심 접근 금지 · 돌진으로 중력권 탈출", "radius": 230.0, "duration": 16.0},
	"planet": {"name": "행성 방어", "hint": "방어 원 안에서 연속 12초 생존 · 이탈 시 초기화", "radius": 145.0, "duration": 30.0},
	"meteor": {"name": "유성우", "hint": "표시된 다섯 낙하지점 사이로 회피", "radius": 200.0, "duration": 8.0},
	"flare": {"name": "태양 플레어", "hint": "퍼지는 충격파를 돌진 무적으로 통과", "radius": 320.0, "duration": 3.0},
}

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
var items: Array[Dictionary] = []
var buffs: Dictionary = {}
var pending_items: Array[Dictionary] = []
var item_rng := RandomNumberGenerator.new()
var _supply_timer := 48.0
var _drop_cooldown := 0.0
var items_collected := 0
var focus_time := 0.0
var slipstream_time := 0.0
var guard_cooldown := 0.0
var bosses_killed := 0
var next_boss_at := 330.0
var _next_elite_at := 300.0
var relief_until := 0.0
var _boss_wave := 0
var _mode: Dictionary = Content.mode_info("normal")
var _orbit_positions: Array[Vector2] = []
var _shot_grid: Dictionary = {}
var _collision_radius := 39.0
var collision_candidates := 0
var _enemy_serial := 0
var encounter_rng := RandomNumberGenerator.new()
var _encounter_timer := 0.0
var _planet_seen := false
var _last_encounter := ""
var _boundary_feedback := 0.0
var mission_rng := RandomNumberGenerator.new()
var mission: Dictionary = {}
var mission_result: Array = []
var missions_completed := 0
var mission_bonus_choices := 0
var upgrade_source := "level"
var parts: Dictionary = {}
var part_drops: Array[Dictionary] = []
var pending_tech: Array[Dictionary] = []
var hull_forms: Array[String] = []
var _next_mission_at := 60.0
var _last_mission := ""
var _explore_at := 90.0
var _barrier_timer := 5.0
var _dash_direction := Vector2.RIGHT
var guard_stacks := 1
var axe_catches := 0
var _sentry_timer := 0.0
var _mine_timer := 0.0
var _axe_timer := 0.0
var _wake_timer := 0.0
var loot_notices: Array[String] = []
var audio_events: Dictionary = {}
var audio_enabled := false

func _audio(cue: String, at: Vector2 = Vector2.INF) -> void:
	# Presentation-only, one nearest event per family per frame; no game RNG.
	if not audio_enabled: return
	if not audio_events.has(cue) or (at.is_finite() and at.distance_squared_to(player) < Vector2(audio_events[cue]).distance_squared_to(player)):
		audio_events[cue] = at

func reset(seed_value: int = 0, difficulty: String = "normal", selected_ship: String = "striker", selected_sector: String = "ring") -> void:
	mode = difficulty if difficulty in Content.MODE_IDS else "normal"
	_mode = Content.mode_info(mode)
	bosses_killed = 0
	next_boss_at = 330.0
	_next_elite_at = 300.0
	relief_until = 0.0
	_boss_wave = 0
	_shot_grid.clear()
	_enemy_serial = 0
	_ship = Content.ship_info(selected_ship)
	ship_id = str(_ship.id)
	sector_id = str(Content.sector_info(selected_sector).id)
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	item_rng.seed = rng.seed + 361
	encounter_rng.seed = rng.seed + 719
	mission_rng.seed = rng.seed + 1217
	mission.clear()
	mission_result.clear()
	missions_completed = 0
	mission_bonus_choices = 0
	upgrade_source = "level"
	parts = {"core": 0, "drive": 0, "shell": 0}
	part_drops.clear()
	pending_tech.clear()
	hull_forms.clear()
	_next_mission_at = 60.0
	_last_mission = ""
	_explore_at = 90.0
	_barrier_timer = 5.0
	_dash_direction = Vector2.RIGHT
	_encounter_timer = encounter_interval()
	_planet_seen = false
	_last_encounter = ""
	_boundary_feedback = 0.0
	items.clear()
	buffs.clear()
	pending_items.clear()
	_supply_timer = 48.0
	_drop_cooldown = 0.0
	items_collected = 0
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
	audio_events.clear()
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
	focus_time = 0.0
	slipstream_time = 0.0
	guard_cooldown = 0.0
	guard_stacks = 1
	axe_catches = 0
	_sentry_timer = 0.0
	_mine_timer = 0.0
	_axe_timer = 0.0
	_wake_timer = 0.0
	loot_notices.clear()
	_update_run_stats()

static func upgrade_info(id: String) -> Dictionary:
	var catalog := {
		"orbit": ["위성 증설", "회전 위성 +1 · 방어 범위 확대", 5],
		"orbit_range": ["확장 궤도", "위성 궤도 반경 +22 · 더 먼 적을 요격", 3],
		"blade": ["절삭 위성", "일반 위성을 칼날로 전환 · 단계마다 위성 피해 +35%", 3],
		"frost": ["빙결 위성", "위성 3기당 1기 빙결형 · 단계마다 감속/지속 증가 · Lv.4~5 진화 숙련", 5],
		"power": ["고출력 코어", "모든 무기 피해 +25%", 5],
		"rapid": ["속사 회로", "자동 사격 속도 +24%", 5],
		"magnet": ["중력 수집기", "경험치 수집 거리 +38", 4],
		"speed": ["추진기 강화", "이동 속도 +28 · 위성 회전 가속", 4],
		"vitality": ["선체 보강", "최대 체력 +35 · 체력 70 회복", 4],
		"dash": ["점멸 충전", "대시 재사용 -0.35초 · 대시 피해 +15", 4],
		"repair": ["자가 수리", "초당 체력 재생 +1.25 · 기본 재생 1.00", 5],
		"missile": ["유도탄 포드", "자동 유도탄 · 폭발 피해/범위 증가 · Lv.4~5 진화 숙련", 5],
		"chain": ["연쇄 번개", "연결 수/피해 증가 · Lv.4~5 진화 숙련", 5],
		"pulse": ["충격파 장치", "범위/피해 증가 · Lv.4~5 진화 숙련", 5],
		"focus_amp": ["전용 · 조준 증폭", "스트라이커 · 화력 파츠 단계별1/2/3개 · 최대/이동 증폭 +8%p", 3],
		"focus_memory": ["전용 · 관성 기억", "조준 증폭1 이후 · 장갑 파츠 단계별1/2/3개 · 증폭 유지시간 +35%", 3],
		"scout_lance": ["전용 · 돌파 탄두", "스카우트 · 화력 파츠 단계별1/2/3개 · 돌진 피해 +25%", 3],
		"scout_drive": ["전용 · 장거리 점멸", "돌파 탄두1 이후 · 추진 파츠 단계별1/2/3개 · 돌진 거리 +15%", 3],
		"guard_reserve": ["전용 · 축적 방벽", "배스천 · 장갑 파츠 단계별1/2/3개 · 방벽 용량 증가/120초마다 추가 축적", 3],
		"guard_pulse": ["전용 · 반격 증폭", "축적 방벽1 이후 · 화력 파츠 단계별1/2/3개 · 반격 피해 +35%", 3],
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

func upgrade_available(id: String) -> bool:
	if int(upgrades.get(id, 0)) >= int(upgrade_info(id).cap):
		return false
	if not SHIP_PARTS.has(id):
		return true
	var spec: Array = SHIP_PARTS[id]
	return ship_id == spec[0] and int(parts.get(spec[1], 0)) > int(upgrades.get(id, 0)) and (spec[2] == "" or int(upgrades.get(spec[2], 0)) > 0)

func get_upgrade_choices() -> Array:
	if state != "upgrade":
		return []
	if not _choices.is_empty():
		return _choices.duplicate()
	var available: Array = []
	for id: String in UPGRADE_IDS:
		if upgrade_available(id):
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
	# Keep a reachable evolution or its mastery available alongside recovery.
	var linked: Array = []
	for id: String in available:
		for evolution_id: String in Content.EVOLUTION_IDS:
			var info := evolution_info(evolution_id)
			if str(info.get("ship", ship_id)) != ship_id:
				continue
			if evolutions.has(evolution_id):
				if id == str(info.mastery):
					linked.append(id)
			elif info.requirements.has(id):
				for required: String in info.requirements:
					if int(upgrades.get(required, 0)) > 0:
						linked.append(id)
						break
	if not linked.is_empty():
		var linked_id: String = linked[rng.randi_range(0, linked.size() - 1)]
		_choices.append(linked_id)
		available.erase(linked_id)
	while _choices.size() < 3:
		var exclusive: Array = available.filter(func(id: String) -> bool: return SHIP_PARTS.has(id))
		if not exclusive.is_empty():
			var id: String = exclusive[rng.randi_range(0, exclusive.size() - 1)]
			_choices.append(id)
			available.erase(id)
			continue
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
			hp = minf(max_hp, hp + 70.0 * repair_efficiency())
		"restore":
			hp = minf(max_hp, hp + 80.0 * repair_efficiency())
		"burst":
			for enemy: Dictionary in enemies:
				_hit_enemy(enemy, 100.0)
		"fortune":
			_grant_score(1000)
			hp = minf(max_hp, hp + 15.0 * repair_efficiency())
	_choices.clear()
	state = "playing"
	events.append("upgrade")
	_check_evolutions()
	_check_level()
	_update_run_stats()
	return true

func step(delta: float, move: Vector2, dash_pressed: bool, dash_aim: Vector2 = Vector2.ZERO) -> void:
	if state != "playing" or delta <= 0.0:
		return
	var dt := minf(delta, 0.05)
	var previous_elapsed := elapsed
	elapsed = minf(duration, elapsed + dt)
	if (previous_elapsed < 240.0 and elapsed >= 240.0) or (previous_elapsed < 300.0 and elapsed >= 300.0):
		_check_evolutions()
	_update_items(dt)
	_update_vitals(dt)
	if state != "playing":
		return
	_tick_mission_clock()
	overdrive_time = maxf(0.0, overdrive_time - dt)
	slipstream_time = maxf(0.0, slipstream_time - dt)
	guard_cooldown = maxf(0.0, guard_cooldown - dt)
	if ship_id == "bastion" and guard_cooldown <= 0.0 and guard_stacks < guard_capacity():
		guard_stacks += 1
		guard_cooldown = 8.0 if guard_stacks < guard_capacity() else 0.0
	event_remaining = maxf(0.0, event_remaining - dt)
	dash_cooldown = maxf(0.0, dash_cooldown - dt * (1.0 + buff_value("haste") / 100.0))
	if dash_pressed and dash_cooldown > 0.0: _audio("ui_denied")
	invulnerable = maxf(0.0, invulnerable - dt)
	_combo_timer = maxf(0.0, _combo_timer - dt)
	if _combo_timer <= 0.0:
		combo = 0
	var direction := move.limit_length(1.0)
	var turn := absf(facing.angle_to(direction.normalized())) / PI if direction.length_squared() > 0.01 else 0.0
	if dash_time <= 0.0 and direction.length_squared() > 0.01:
		facing = direction.normalized()
	if dash_pressed and dash_cooldown <= 0.0:
		dash_time = 0.20
		_dash_direction = dash_aim.normalized() if not dash_aim.is_zero_approx() else facing
		facing = _dash_direction
		if ship_id == "scout":
			slipstream_time = 1.6
		dash_cooldown = maxf(0.8, float(_ship.dash) - float(upgrades.get("dash", 0)) * 0.35)
		dash_recharge_total = dash_cooldown
		invulnerable = 0.34
		_dash_id += 1
		_effect(player, "dash", 55.0, 0.25)
		events.append("dash")
		var lancer := hull_rank("lancer")
		if lancer > 0:
			var radius := 85.0 + 30.0 * lancer
			_effect(player, "pulse", radius, 0.4)
			for enemy: Dictionary in enemies:
				if player.distance_to(enemy.pos) <= radius + float(enemy.radius):
					_hit_enemy(enemy, (25.0 + 20.0 * lancer) * _power())
	if ship_id == "striker":
		if direction.length_squared() <= 0.01 and dash_time <= 0.0:
			focus_time = minf(1.2, focus_time + dt)
		else:
			var pace := 940.0 / 218.0 if dash_time > 0.0 else direction.length() * base_speed() / 218.0
			var floor_focus := 0.32 / (maxf(1.0, pace) * (1.0 + 2.0 * turn))
			focus_time = move_toward(focus_time, floor_focus, dt * (0.10 + 0.16 * pace * pace + 0.60 * turn) / (1.0 + 0.35 * int(upgrades.get("focus_memory", 0))))
	var old_position := player
	var speed := base_speed() * movement_multiplier(player) * (1.35 if slipstream_time > 0.0 else 1.0) * gravity_drag(player)
	# Consume the last partial frame exactly; cursor distance never changes the 188px thrust.
	var dash_dt := minf(dt, dash_time)
	player += _dash_direction * 940.0 * dash_distance_multiplier() * dash_dt + direction * speed * (dt - dash_dt)
	_wake_timer = maxf(0.0, _wake_timer - dt)
	if dash_dt > 0.0 and evolutions.has("wake") and _wake_timer <= 0.0:
		_deploy("wake", old_position, 2.4, 44.0)
		_wake_timer = 0.04
	if dash_dt > 0.0:
		facing = _dash_direction
	player += gravity_pull(player) * dt
	# A continuous inward current overcomes even a dash before deep space; no wall clamp.
	player += boundary_current(player) * dt
	if boundary_depth(player) > 0.08:
		_outside = true
	elif boundary_depth(player) == 0.0 and _outside:
		boundary_returns += 1
		_mission_add("returns", 1.0)
		_outside = false
	current_speed = player.distance_to(old_position) / dt
	orbit_angle = fmod(orbit_angle + dt * (3.5 + float(upgrades.get("speed", 0)) * 0.3), TAU)
	_spawn_timer -= dt
	if _spawn_timer <= 0.0:
		_spawn_timer = maxf(0.19, 0.92 - elapsed * 0.0023) / (1.8 * float(_mode.spawn) * (1.15 if sector_id == "ring" else 1.0))
		if enemies.size() < 236:
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
	if elapsed >= _next_elite_at:
		_next_elite_at = elapsed + maxf(20.0, 35.0 - (elapsed - 300.0) * 0.05)
		if enemies.filter(func(e: Dictionary) -> bool: return e.kind == "elite" and float(e.hp) > 0.0).size() < 2:
			_elite_stage += 1
			var elite := spawn_enemy("elite")
			elite.elite_index = 1 if _elite_stage % 2 == 1 else 2
			elite.hp *= 1.25 + 0.25 * floorf((elapsed - 300.0) / 60.0)
			elite.max_hp = elite.hp
			elite.speed *= 1.18 if int(elite.elite_index) == 1 else 0.9
			_announce("증원 정예 · " + ("돌격형" if int(elite.elite_index) == 1 else "포격형"), "elite")
	if elapsed >= next_boss_at and enemies.filter(func(e: Dictionary) -> bool: return e.kind == "boss" and float(e.hp) > 0.0).size() < 2:
		_boss_wave += 1
		var boss := spawn_enemy("boss")
		boss.boss_wave = _boss_wave
		boss.hp *= 1.0 + 0.35 * _boss_wave
		boss.max_hp = boss.hp
		boss.speed *= 1.0 + 0.08 * _boss_wave
		boss.damage *= 1.0 + 0.12 * _boss_wave
		next_boss_at = elapsed + maxf(35.0, 50.0 - (elapsed - 300.0) * 0.05)
		_announce("추격 지휘체 %d · 격파 시 붕괴 완화 / 점수 보상" % _boss_wave, "boss")
	_shot_timer -= dt
	if _shot_timer <= 0.0:
		_fire_player_shot()
		_shot_timer = 0.68 / ((1.0 + float(upgrades.get("rapid", 0)) * 0.24) * (1.45 if overdrive_time > 0.0 else 1.0) * (1.0 + maxf(buff_value("rapid"), buff_value("frenzy")) / 100.0))
	_update_weapons(dt)
	_update_enemies(dt, old_position)
	_update_shots(dt)
	_update_hazards(dt)
	if state != "playing":
		_update_run_stats()
		return
	_collect_items(old_position)
	_update_expedition(dt, old_position)
	_collect_gems(dt)
	dash_time = maxf(0.0, dash_time - dt)
	for i in range(effects.size() - 1, -1, -1):
		effects[i].ttl -= dt
		if float(effects[i].ttl) <= 0.0:
			effects.remove_at(i)
	if elapsed >= 300.0 and boss_defeated and not survival_cleared:
		survival_cleared = true
		_grant_score(2500 + int(hp * 10.0))
		_announce("5분 돌파! 정예·지휘체 증원 가속 · 주기적 붕괴 완화", "milestone")
	_check_level()
	_update_run_stats()

func regeneration_rate() -> float:
	return (1.0 + float(upgrades.get("repair", 0)) * 1.25 + buff_value("repair")) * repair_efficiency()

func repair_efficiency() -> float:
	return lerpf(1.0, 0.30, clampf((elapsed - 300.0) / 180.0, 0.0, 1.0))

func risk_multiplier() -> float:
	return [1.0, 1.25, 1.6, 2.1][boundary_layer(player)]

func _risk_feedback(kind: String, amount: float) -> void:
	if amount <= 0.0:
		return
	# Aggregate rapid rewards into one readable cue per type; retain replay-compatible effect fields.
	for index in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[index]
		if effect.kind != kind:
			continue
		if float(effect.ttl) > 0.0 and is_equal_approx(Vector2(effect.end).x, risk_multiplier()):
			effect.radius += amount
			effect.ttl = effect.max_ttl
			return
		break
	_effect(player, kind, amount, 1.1, Vector2(risk_multiplier(), 0))

func _grant_xp(amount: float) -> void:
	var reward := amount * risk_multiplier() * (1.0 + buff_value("insight") / 100.0)
	xp += reward
	_risk_feedback("risk_xp", reward)

func _grant_score(amount: float) -> int:
	var reward := roundi(amount * (1.0 + buff_value("bounty") / 100.0))
	score += reward
	return reward

func enemy_strength() -> float:
	var equipment := 0
	for count: Variant in parts.values():
		equipment += int(count)
	return 1.0 + 1.8 * pow(clampf((elapsed - 150.0) / 450.0, 0.0, 1.0), 1.4) + minf(0.45, equipment * 0.025)

func _scale_enemy(enemy: Dictionary, strength: float = 0.0) -> void:
	if strength <= 0.0:
		strength = enemy_strength()
	var ratio := strength / float(enemy.get("strength", 1.0))
	if ratio > 1.0:
		enemy.hp *= ratio
		enemy.max_hp *= ratio
		enemy.damage *= pow(ratio, 0.25)
		enemy.speed *= pow(ratio, 0.12)
		enemy.strength = strength

func decay_rate() -> float:
	var heat := 1.0 + 0.65 * pow(clampf(elapsed / 480.0, 0.0, 1.0), 1.4) if sector_id == "forge" else 1.0
	if elapsed <= 300.0:
		return (0.25 + 6.0 * pow(elapsed / 300.0, 2.0)) * heat
	var overtime := elapsed - 300.0
	var base := 6.25 + 0.012 * overtime + 0.000035 * overtime * overtime
	# Each minute starts with a 20-second lull; victories also open a 25-second lull.
	return base * (0.55 if fmod(overtime, 60.0) < 20.0 or elapsed < relief_until else 1.0) * heat

func _update_vitals(dt: float) -> void:
	boundary_time = boundary_time + dt if boundary_depth(player) > 0.0 else 0.0
	_boundary_feedback = maxf(0.0, _boundary_feedback - dt)
	if boundary_damage_rate() >= 4.0 and _boundary_feedback <= 0.0:
		_effect(player, "impact_boundary", 45.0, 0.45, CENTER)
		_boundary_feedback = 0.65
		events.append("boundary_hit")
	# Environmental decay bypasses combat invulnerability and damage reduction.
	var loss := _absorb_damage((decay_rate() + boundary_damage_rate()) * dt)
	hp = clampf(hp + regeneration_rate() * dt - loss, 0.0, max_hp)
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
		return lerpf(0.9, 0.78, smoothstep(0.0, 1.0, layer_depth - 1.0))
	return lerpf(0.78, 0.30, smoothstep(0.0, 1.0, layer_depth - 2.0))

func boundary_current(position: Vector2) -> Vector2:
	var distance := maxf(0.0, position.distance_to(CENTER) - (ACTIVITY_RADIUS - PLAYER_RADIUS))
	var depth := distance / BOUNDARY_BUFFER
	var force := 40.0 * pow(minf(1.0, depth * 1.5), 2.0) + 1760.0 * pow(maxf(0.0, depth * 3.0 - 2.0), 3.0)
	return (CENTER - position).normalized() * force

func ranked_score() -> int:
	return int(score * float(_mode.score))

func boundary_damage_rate() -> float:
	var depth := boundary_depth(player) * 3.0
	if depth <= 1.0:
		return depth * (4.0 + 0.25 * boundary_time)
	if depth <= 2.0:
		return lerpf(4.0, 24.0, smoothstep(0.0, 1.0, depth - 1.0)) + boundary_time * lerpf(0.25, 0.6, depth - 1.0)
	return 24.0 + 96.0 * (depth - 2.0) + boundary_time * lerpf(0.6, 2.0, depth - 2.0)

func net_hull_rate() -> float:
	return regeneration_rate() - (0.0 if buff_value("shield") > 0.0 else decay_rate() + boundary_damage_rate())

func base_speed() -> float:
	return (float(_ship.speed) + float(upgrades.get("speed", 0)) * 28.0 + 8.0 * int(parts.get("drive", 0))) * (1.0 + buff_value("speed") / 100.0)

func _finish_run(reason: String) -> void:
	if not mission.is_empty() and mission.status == "active":
		_finish_mission(false)
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
	var angle := orbit_angle + TAU * float(index) / float(orbit_count)
	var offset := Vector2.from_angle(angle) * orbit_radius
	if evolutions.has("ellipse"):
		offset = Vector2(cos(angle) * orbit_radius * 1.8, sin(angle) * orbit_radius * 0.7).rotated(orbit_angle * 0.23)
	return player + offset

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
		var radius := ACTIVITY_RADIUS + (spawn_layer - 1) * LAYER_WIDTH + rng.randf_range(40.0, 130.0) * WORLD_SCALE
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
	health *= float(_mode.health)
	var enemy := {"pos": point, "hp": health, "max_hp": health, "speed": float(stats[1]) * (0.8 if mode == "relaxed" else 1.0), "radius": float(stats[2]), "damage": float(stats[3]), "value": float(stats[4]), "kind": kind, "flash": 0.0, "angle": 0.0, "orbit_timer": 0.0, "shot_timer": rng.randf_range(1.7, 3.0), "warn": 0.0, "aim": Vector2.RIGHT, "dash_id": -1, "elite_index": 1, "charge_time": 0.0, "phase": 1}
	enemy.flank_side = -1.0 if rng.randf() < 0.5 else 1.0
	_enemy_serial += 1
	enemy._combat_id = _enemy_serial
	var flank_roll := rng.randf()
	enemy.flanker = kind in (["chaser", "runner"] if sector_id == "ring" else ["chaser"]) and flank_roll < (0.85 if sector_id == "ring" else 0.6)
	if sector_id == "ring" and kind in ["chaser", "runner"]:
		enemy.speed *= 1.18 + 0.12 * hazard_pressure()
	enemies.append(enemy)
	enemy.spawn_layer = spawn_layer
	if spawn_layer == 4:
		_announce("심우주 침공 경보 · " + ("지휘체" if kind == "boss" else "정예") + " 접근 중", "invasion")
	enemy.speed *= float(_mode.speed)
	if elapsed >= 300.0:
		var pressure := (elapsed - 300.0) / 60.0
		enemy.speed *= 1.0 + 0.04 * pressure
		enemy.damage *= 1.0 + 0.08 * pressure
		enemy.late_pressure = pressure
	_scale_enemy(enemy)
	return enemy

func _update_enemies(dt: float, old_position: Vector2) -> void:
	var power := _power()
	var strength := enemy_strength()
	_orbit_positions.clear()
	for j in orbit_count:
		_orbit_positions.append(orbit_position(j))
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		if float(enemy.hp) <= 0.0:
			_kill_enemy(enemy)
			enemies.remove_at(i)
			continue
		_scale_enemy(enemy, strength)
		enemy.flash = maxf(0.0, float(enemy.flash) - dt)
		enemy.orbit_timer = maxf(0.0, float(enemy.orbit_timer) - dt)
		var toward: Vector2 = player - Vector2(enemy.pos)
		var direction := toward.normalized()
		var stunned := float(enemy.get("stun_time", 0.0)) > 0.0
		enemy.stun_time = maxf(0.0, float(enemy.get("stun_time", 0.0)) - dt)
		if not stunned:
			enemy.angle = direction.angle()
			var movement := direction
			if enemy.kind == "boss" and int(enemy.phase) == 1 and float(enemy.hp) <= float(enemy.max_hp) * 0.5 and float(enemy.hp) > 0.0:
				enemy.phase = 2
				_audio("boss_phase", enemy.pos)
				enemy.shot_timer = 0.8
				_announce("지휘체 격앙 · 탄막 강화", "phase")
			var tangent := direction.orthogonal() * float(enemy.flank_side)
			if bool(enemy.flanker) and toward.length() > 110.0:
				movement = (direction * 0.65 + tangent * 0.76).normalized()
			elif enemy.kind == "tank":
				movement = (player + (player - old_position) / maxf(dt, 0.001) * 0.7 - Vector2(enemy.pos)).normalized()
			elif enemy.kind == "shooter":
				var approach := 0.8 if toward.length() > 340.0 else (-0.9 if toward.length() < 240.0 else 0.0)
				movement = (direction * approach + tangent * 0.55).limit_length(1.0)
			if float(enemy.warn) > 0.0:
				enemy.warn = maxf(0.0, float(enemy.warn) - dt)
				movement *= 0.2
				if float(enemy.warn) <= 0.0:
					if enemy.kind == "runner":
						enemy.charge_time = 0.45
					else:
						_fire_enemy_shots(enemy)
			elif enemy.kind in ["shooter", "boss", "elite"] or (enemy.kind == "runner" and toward.length() < 400.0):
				enemy.shot_timer -= dt
				if float(enemy.shot_timer) <= 0.0:
					enemy.warn = 1.1 if enemy.kind == "elite" else 0.70
					_audio("enemy_attack_charge", enemy.pos)
					enemy.aim = (player + (player - old_position) / maxf(dt, 0.001) * 0.25 - Vector2(enemy.pos)).normalized() if enemy.kind == "runner" else direction
					enemy.shot_timer = (1.35 if int(enemy.phase) == 2 else 1.8) if enemy.kind == "boss" else 3.5
			if float(enemy.charge_time) > 0.0:
				enemy.charge_time = maxf(0.0, float(enemy.charge_time) - dt)
				movement = Vector2(enemy.aim) * 4.5
			enemy.slow_time = maxf(0.0, float(enemy.get("slow_time", 0.0)) - dt)
			var approach := 1.0
			if int(enemy.get("spawn_layer", 0)) == 4 and Vector2(enemy.pos).distance_to(CENTER) > ACTIVITY_RADIUS:
				approach = 2.8 if enemy.has("late_pressure") and toward.length() > 420.0 else 0.7
			enemy.pos += movement * float(enemy.speed) * approach * (float(enemy.get("slow_factor", 1.0)) if float(enemy.slow_time) > 0.0 else 1.0) * dt
		enemy.pos += gravity_pull(enemy.pos) * dt
		if dash_time > 0.0 and int(enemy.dash_id) != _dash_id:
			var closest := Geometry2D.get_closest_point_to_segment(enemy.pos, old_position, player)
			if closest.distance_to(enemy.pos) < float(enemy.radius) + 28.0:
				enemy.dash_id = _dash_id
				_mission_add("dash_hits", 1.0)
				_hit_enemy(enemy, (52.0 + float(upgrades.get("dash", 0)) * 15.0) * power * (1.75 * (1.0 + 0.25 * int(upgrades.get("scout_lance", 0))) if ship_id == "scout" else 1.0))
		var orbit_distance := player.distance_squared_to(enemy.pos)
		var orbit_contact := float(enemy.radius) + 17.0
		if float(enemy.orbit_timer) <= 0.0 and orbit_distance <= pow(orbit_radius * (1.8 if evolutions.has("ellipse") else 1.0) + orbit_contact, 2) and orbit_distance >= pow(maxf(0.0, orbit_radius * (0.7 if evolutions.has("ellipse") else 1.0) - orbit_contact), 2):
			for j in orbit_count:
				var orb := _orbit_positions[j]
				if orb.distance_squared_to(enemy.pos) <= pow(float(enemy.radius) + (17.0 if evolutions.has("superorbit") else 10.0), 2):
					var kind := orbit_kind(j)
					_audio("weapon_orbit_" + (kind if kind in ["blade", "frost"] else "normal"), enemy.pos)
					_hit_enemy(enemy, 25.0 * power * (1.2 if evolutions.has("ellipse") else 1.0) * (1.6 + 0.15 * evolution_mastery("superorbit") if evolutions.has("superorbit") else 1.0) * (1.0 + 0.35 * float(upgrades.get("blade", 0))) * ((1.12 + 0.12 * evolution_mastery("blizzard") if evolutions.has("blizzard") else 0.8) if kind == "frost" else 1.0))
					if kind == "frost":
						var rank := float(upgrades.get("frost", 0))
						enemy.slow_time = 0.7 + 0.4 * rank + 0.3 * evolution_mastery("blizzard")
						enemy.slow_factor = maxf(0.15, 0.7 - 0.1 * rank - (0.15 if evolutions.has("blizzard") else 0.0))
					enemy.orbit_timer = 0.23 if evolutions.has("superorbit") else 0.28
					break
		if float(enemy.hp) <= 0.0:
			_kill_enemy(enemy)
			enemies.remove_at(i)
		elif player.distance_to(enemy.pos) < PLAYER_RADIUS + float(enemy.radius):
			take_damage(float(enemy.damage), "combat", enemy.pos)
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
	var mastery := evolution_mastery("rail")
	var battery := hull_rank("battery")
	for barrel in (1 if battery == 0 else battery + 1):
		if shots.size() >= 240:
			break
		var aim := direction.rotated((barrel - battery * 0.5) * 0.16)
		shots.append({"pos": player, "velocity": aim * (780.0 if evolutions.has("rail") else 590.0), "friendly": true, "radius": 5.0, "damage": 19.0 * _power() * (1.0 + focus_bonus()) * (1.35 + 0.15 * mastery if evolutions.has("rail") else 1.0), "ttl": 1.45, "pierce": (3 + mastery if evolutions.has("rail") else 1) + (1 if battery == 2 else 0), "hit_ids": []})
	events.append("shot")
	_audio("weapon_rail" if evolutions.has("rail") else "weapon_cannon", player)

func _fire_enemy_shots(enemy: Dictionary) -> void:
	if enemy.kind == "elite" and int(enemy.elite_index) == 1:
		enemy.charge_time = 0.6
		_audio("enemy_attack_charge", enemy.pos)
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
		shots.append({"pos": Vector2(enemy.pos) + direction * float(enemy.radius), "velocity": direction * (148.0 if is_boss else 185.0) * (0.82 if mode == "relaxed" else 1.0) * (1.0 + 0.08 * float(enemy.get("boss_wave", 0))) * (1.0 + 0.025 * float(enemy.get("late_pressure", 0.0))), "friendly": false, "radius": 7.0, "damage": (13.0 if is_boss else 10.0) * (1.0 + 0.12 * float(enemy.get("boss_wave", 0))) * (1.0 + 0.08 * float(enemy.get("late_pressure", 0.0))), "ttl": 5.0})
	_effect(enemy.pos, "fire", float(enemy.radius) + 10.0, 0.25)

func _update_shots(dt: float) -> void:
	_shot_grid.clear()
	_collision_radius = 0.0
	collision_candidates = 0
	for index in enemies.size():
		var enemy: Dictionary = enemies[index]
		if float(enemy.hp) <= 0.0:
			continue
		var cell := Vector2i((Vector2(enemy.pos) / 128.0).floor())
		if not _shot_grid.has(cell):
			_shot_grid[cell] = []
		_shot_grid[cell].append(index)
		_collision_radius = maxf(_collision_radius, float(enemy.radius))
	for i in range(shots.size() - 1, -1, -1):
		var shot: Dictionary = shots[i]
		var kind: String = str(shot.get("kind", ""))
		if kind in ["sentry", "mine", "wake"]:
			_update_deployed(shot, dt)
			if float(shot.ttl) <= 0.0:
				shots.remove_at(i)
			continue
		var previous: Vector2 = shot.pos
		if kind == "axe" and float(shot.ttl) <= 3.2:
			if not bool(shot.get("returning", false)):
				shot.returning = true
				shot.hit_ids = []
				_audio("weapon_hatchet_return", shot.pos)
			shot.velocity = (player - Vector2(shot.pos)).normalized() * 540.0
		if shot.get("kind", "") == "missile":
			var target := _nearest_enemy(shot.pos, 700.0)
			if not target.is_empty():
				shot.velocity = Vector2(shot.velocity).move_toward((Vector2(target.pos) - Vector2(shot.pos)).normalized() * 350.0, 1700.0 * dt)
		shot.velocity += gravity_pull(shot.pos) * 4.0 * dt
		shot.pos += Vector2(shot.velocity) * dt
		shot.ttl -= dt
		if kind == "axe" and bool(shot.get("returning", false)) and Geometry2D.get_closest_point_to_segment(player, previous, shot.pos).distance_to(player) <= 25.0:
			axe_catches = mini(8, axe_catches + 1)
			_audio("weapon_hatchet_catch")
			_axe_timer = 0.0
			_effect(player, "reward", 48.0, 0.3)
			shots.remove_at(i)
			continue
		if bool(shot.friendly):
			var swept := Rect2(previous.min(shot.pos), (previous - Vector2(shot.pos)).abs()).grow(float(shot.radius))
			for index: int in _shot_candidates(previous, shot.pos, float(shot.radius)):
				var enemy: Dictionary = enemies[index]
				if not swept.grow(float(enemy.radius)).has_point(enemy.pos):
					continue
				if shot.get("hit_ids", []).has(enemy.get("_combat_id", index)):
					continue
				collision_candidates += 1
				var closest := Geometry2D.get_closest_point_to_segment(enemy.pos, previous, shot.pos)
				if float(enemy.hp) > 0.0 and closest.distance_squared_to(enemy.pos) < pow(float(enemy.radius) + float(shot.radius), 2):
					if shot.get("kind", "") == "missile":
						for splash: Dictionary in enemies:
							if Vector2(splash.pos).distance_to(enemy.pos) < float(shot.blast_radius) + float(splash.radius):
								_hit_enemy(splash, float(shot.damage))
						_effect(enemy.pos, "pulse", float(shot.blast_radius), 0.30)
						_audio("weapon_missile_impact", enemy.pos)
					else:
						_hit_enemy(enemy, float(shot.damage))
					shot.pierce = int(shot.get("pierce", 1)) - 1
					if shot.has("hit_ids"):
						shot.hit_ids.append(enemy.get("_combat_id", index))
					if int(shot.pierce) <= 0:
						shot.ttl = 0.0
						break
		else:
			var closest := Geometry2D.get_closest_point_to_segment(player, previous, shot.pos)
			if closest.distance_to(player) < PLAYER_RADIUS + float(shot.radius):
				take_damage(float(shot.damage), "combat", previous)
				shot.ttl = 0.0
		if float(shot.ttl) <= 0.0:
			if kind == "axe":
				axe_catches = 0
				_audio("weapon_hatchet_miss")
			shots.remove_at(i)

func _shot_candidates(start: Vector2, end: Vector2, radius: float) -> Array:
	var margin := Vector2.ONE * (radius + _collision_radius)
	var first := Vector2i(((start.min(end) - margin) / 128.0).floor())
	var last := Vector2i(((start.max(end) + margin) / 128.0).floor())
	var found: Array = []
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			found.append_array(_shot_grid.get(Vector2i(x, y), []))
	# Preserve existing hit ordering when several enemies overlap a swept shot.
	found.sort()
	return found

func take_damage(amount: float, source: String = "combat", origin: Vector2 = Vector2.INF) -> void:
	if state != "playing" or invulnerable > 0.0 or amount <= 0.0:
		return
	if ship_id == "bastion" and guard_stacks > 0:
		amount *= 0.4
		guard_stacks -= 1
		if guard_cooldown <= 0.0:
			guard_cooldown = 8.0
		var radius := 195.0 if evolutions.has("citadel") else 125.0
		for enemy: Dictionary in enemies:
			if float(enemy.hp) > 0.0 and player.distance_to(enemy.pos) <= radius + float(enemy.radius):
				_hit_enemy(enemy, 40.0 * _power() * (1.0 + 0.35 * int(upgrades.get("guard_pulse", 0))) * (2.0 + 0.15 * evolution_mastery("citadel") if evolutions.has("citadel") else 1.0))
				enemy.pos += (Vector2(enemy.pos) - player).normalized() * 45.0
		if evolutions.has("citadel"):
			for shot: Dictionary in shots:
				if not bool(shot.friendly) and player.distance_to(shot.pos) <= radius:
					shot.ttl = 0.0
		_effect(player, "guard", radius, 0.35)
		_audio("weapon_citadel" if evolutions.has("citadel") else "guard_block")
	var previous_hp := hp
	focus_time *= 0.65
	_mission_add("survive", 1.0)
	hp = maxf(0.0, hp - _absorb_damage(amount * (0.75 if mode == "relaxed" else 1.0) * float(_mode.damage) * (0.55 if overdrive_time > 0.0 else 1.0) * (1.0 - 0.04 * int(parts.get("shell", 0)))))
	invulnerable = 0.70
	combo = 0
	_effect(player, "hurt", 32.0, 0.3)
	_effect(player, "impact_" + source, 54.0, 0.45, origin)
	events.append("hurt")
	if hp < previous_hp: _audio("player_hurt")
	if hp <= 0.0:
		_finish_run("combat")

func _hit_enemy(enemy: Dictionary, damage: float) -> void:
	if float(enemy.hp) <= 0.0:
		return
	enemy.hp -= damage
	_audio("enemy_hit_heavy" if enemy.kind in ["tank", "elite", "boss"] else "enemy_hit_light", enemy.pos)
	enemy.flash = 0.12
	_effect(enemy.pos, "hit", 22.0, 0.20, player)
	if not events.has("hit"):
		events.append("hit")

func _kill_enemy(enemy: Dictionary) -> void:
	kills += 1
	_mission_add(str(enemy.kind), 1.0)
	if boundary_layer(player) > 0:
		_mission_add("outer_kills", 1.0)
	if overdrive_time <= 0.0:
		overdrive_meter = minf(100.0, overdrive_meter + (12.0 if enemy.kind == "elite" or enemy.kind == "boss" else 2.0))
	combo += 1
	peak_combo = maxi(peak_combo, combo)
	_combo_timer = 2.5
	var reward_score := _grant_score((float(enemy.value) * 20.0 + mini(combo, 30)) * risk_multiplier())
	_risk_feedback("risk_score", reward_score)
	var point: Vector2 = enemy.pos
	if enemy.kind in ["elite", "boss"]:
		spawn_item(point, "A" if enemy.kind == "boss" or item_rng.randf() < 0.2 else "B")
	elif _drop_cooldown <= 0.0 and item_rng.randf() < 0.006:
		spawn_item(point, roll_item_grade(boundary_layer(point)))
		_drop_cooldown = 14.0
	if gems.size() < 300:
		gems.append({"pos": point, "value": float(enemy.value), "kind": "xp"})
	else:
		_grant_xp(float(enemy.value))
	if enemy.kind == "boss":
		boss_defeated = true
		bosses_killed += 1
		if elapsed >= 300.0:
			relief_until = elapsed + 25.0
			var bonus := _grant_score((1800 + 600 * int(enemy.get("boss_wave", 0))) * risk_multiplier())
			_risk_feedback("risk_score", bonus)
			_grant_xp(35.0 + 10.0 * int(enemy.get("boss_wave", 0)))
			_announce("지휘체 격파 · 25초 붕괴 완화 · 점수/경험치 보너스", "relief")
		events.append("boss_down")
	elif enemy.kind == "elite":
		elites_killed += 1
		_grant_xp(12.0)
		var bonus := _grant_score(500 * risk_multiplier())
		_risk_feedback("risk_score", bonus)
		_announce("정예 격파 · 경험치 +%d · 점수 +%d" % [roundi(12 * risk_multiplier()), bonus], "elite_down")
	_effect(enemy.pos, "death", float(enemy.radius) * 1.7, 0.35)
	events.append("kill")
	_audio("boss_down" if enemy.kind == "boss" else ("enemy_destroy_elite" if enemy.kind == "elite" else ("enemy_destroy_heavy" if enemy.kind == "tank" else "enemy_destroy_small")), enemy.pos)

func _collect_gems(dt: float) -> void:
	var magnet := 86.0 + float(upgrades.get("magnet", 0)) * 38.0
	for i in range(gems.size() - 1, -1, -1):
		var gem: Dictionary = gems[i]
		gem.pos = _drift_loot(gem.pos, dt, XP_DRIFT_SPEED)
		var distance := player.distance_to(gem.pos)
		if distance < magnet:
			gem.pos = Vector2(gem.pos).move_toward(player, (300.0 + 2.0 * (magnet - distance)) * dt)
		if player.distance_to(gem.pos) < 19.0:
			if gem.get("kind", "xp") == "heal":
				hp = minf(max_hp, hp + float(gem.value) * repair_efficiency())
				events.append("heal")
			else:
				_grant_xp(float(gem.value))
				events.append("pickup")
			gems.remove_at(i)

func _check_level() -> void:
	if mission_bonus_choices > 0:
		mission_bonus_choices -= 1
		upgrade_source = "mission"
		state = "upgrade"
		_choices.clear()
		get_upgrade_choices()
		events.append("level")
		return
	if xp < xp_needed:
		return
	upgrade_source = "level"
	xp -= xp_needed
	level += 1
	xp_needed = 9.0 + float(level - 1) * 4.0 + 0.7 * pow(maxi(0, level - 10), 2)
	state = "upgrade"
	_choices.clear()
	get_upgrade_choices()
	events.append("level")

func activate_overdrive() -> bool:
	if state != "playing" or overdrive_meter < 100.0 or overdrive_time > 0.0:
		_audio("ui_denied")
		return false
	overdrive_meter = 0.0
	overdrive_time = 6.0
	_overdrives += 1
	_mission_add("overdrive", 1.0)
	_effect(player, "pulse", 135.0, 0.6)
	_announce("오버드라이브 · 화력 강화 / 받는 피해 감소", "overdrive")
	_update_run_stats()
	return true

func _power() -> float:
	return float(_ship.power) * (1.0 + float(upgrades.get("power", 0)) * 0.25) * (1.45 if overdrive_time > 0.0 else 1.0) * (1.0 + buff_value("power") / 100.0) * (1.0 + 0.06 * int(parts.get("core", 0))) * (1.0 + 0.12 * hull_rank("trinity"))

func _check_evolutions() -> void:
	for id: String in Content.EVOLUTION_IDS:
		if evolutions.has(id):
			continue
		var info := evolution_info(id)
		if elapsed < float(info.get("after", 0.0)) or str(info.get("ship", ship_id)) != ship_id:
			continue
		var ready := true
		for required: String in info.requirements:
			if int(upgrades.get(required, 0)) < int(info.requirements[required]):
				ready = false
		if ready:
			evolutions.append(id)
			_effect(player, "pulse", 155.0, 0.7)
			_announce("무기 진화 · " + str(info.name), "evolution")

func evolution_mastery(id: String) -> int:
	if not evolutions.has(id):
		return 0
	match id:
		"superorbit": return maxi(0, int(upgrades.get("power", 0)) - 2)
		"storm": return maxi(0, int(upgrades.get("chain", 0)) - 3)
		"salvo": return maxi(0, int(upgrades.get("missile", 0)) - 3)
		"rail": return maxi(0, int(upgrades.get("rapid", 0)) - 3)
		"blizzard": return maxi(0, int(upgrades.get("frost", 0)) - 3)
		"nova": return maxi(0, int(upgrades.get("pulse", 0)) - 3)
		_: return maxi(0, int(upgrades.get(str(evolution_info(id).get("mastery", "power")), 0)) - 3)
	return 0

func _nearest_enemy(origin: Vector2, distance: float, excluded: Array[Dictionary] = []) -> Dictionary:
	var nearest: Dictionary = {}
	distance *= distance
	for enemy: Dictionary in enemies:
		var candidate := origin.distance_squared_to(enemy.pos)
		if float(enemy.hp) > 0.0 and candidate < distance and not excluded.has(enemy):
			nearest = enemy
			distance = candidate
	return nearest

func _update_weapons(dt: float) -> void:
	_update_evolved_weapons(dt)
	var missile_rank := int(upgrades.get("missile", 0))
	var chain_rank := int(upgrades.get("chain", 0))
	var pulse_rank := int(upgrades.get("pulse", 0))
	_missile_timer -= dt
	_chain_timer -= dt
	_pulse_timer -= dt
	if missile_rank > 0 and _missile_timer <= 0.0:
		_missile_timer = 2.8 * (1.0 - 0.12 * evolution_mastery("salvo"))
		var target := _nearest_enemy(player, 720.0)
		if not target.is_empty():
			var count := 3 if evolutions.has("salvo") else 1
			for i in count:
				if shots.size() >= 240:
					break
				var direction := (Vector2(target.pos) - player).normalized().rotated((float(i) - float(count - 1) * 0.5) * 0.4)
				shots.append({"pos": player, "velocity": direction * 350.0, "friendly": true, "radius": 8.0, "damage": (40.0 + 18.0 * missile_rank) * _power(), "ttl": 3.0, "kind": "missile", "blast_radius": 38.0 + float(missile_rank) * 10.0 + (25.0 if count == 3 else 0.0) + 8.0 * evolution_mastery("salvo")})
				_effect(player, "missile", 8.0, 0.18, player + direction * 38.0)
	if chain_rank > 0 and _chain_timer <= 0.0:
		_chain_timer = 2.2 * (1.0 - 0.12 * evolution_mastery("storm"))
		var cursor := player
		var visited: Array[Dictionary] = []
		var count := 2 + chain_rank + (3 if evolutions.has("storm") else 0) + evolution_mastery("storm")
		for i in count:
			var target := _nearest_enemy(cursor, 335.0 if i == 0 else 190.0, visited)
			if target.is_empty():
				break
			_hit_enemy(target, (15.0 + 10.0 * chain_rank) * _power() * (1.4 if evolutions.has("storm") else 1.0))
			_effect(cursor, "lightning", 7.0, 0.25, target.pos)
			visited.append(target)
			cursor = target.pos
	if pulse_rank > 0 and _pulse_timer <= 0.0:
		_pulse_timer = 4.3 * (1.0 - 0.12 * evolution_mastery("nova"))
		var radius := 125.0 + float(pulse_rank) * 25.0 + (55.0 + 15.0 * evolution_mastery("nova") if evolutions.has("nova") else 0.0)
		_effect(player, "pulse", radius, 0.55)
		_audio("weapon_pulse", player)
		if evolutions.has("nova"):
			for i in range(shots.size() - 1, -1, -1):
				if not bool(shots[i].friendly) and player.distance_squared_to(shots[i].pos) <= radius * radius:
					shots.remove_at(i)
		for enemy: Dictionary in enemies:
			if player.distance_to(enemy.pos) < radius + float(enemy.radius):
				_hit_enemy(enemy, (12.0 + float(pulse_rank) * 8.0) * _power() * (2.0 if evolutions.has("nova") else 1.0))
				if enemy.kind != "boss":
					enemy.pos += (Vector2(enemy.pos) - player).normalized() * 36.0

func _add_blast(position: Vector2, radius: float) -> void:
	if hazards.size() >= 6:
		return
	radius *= 1.0 + 0.35 * hazard_pressure()
	var point := CENTER + (position - CENTER).limit_length(ACTIVITY_RADIUS - radius)
	_audio("hazard_charge_blast", point)
	hazards.append({"kind": "blast", "pos": point, "radius": radius, "rect": Rect2(), "warn": 1.6, "ttl": 0.35, "active": false})

func focus_bonus() -> float:
	if ship_id != "striker":
		return 0.0
	return 0.08 + 0.37 * clampf(focus_time / 1.2, 0.0, 1.0) + 0.08 * int(upgrades.get("focus_amp", 0))

func dash_distance_multiplier() -> float:
	return 1.0 + (0.15 * int(upgrades.get("scout_drive", 0)) if ship_id == "scout" else 0.0)

func guard_capacity() -> int:
	var rank := int(upgrades.get("guard_reserve", 0)) if ship_id == "bastion" else 0
	return 1 + rank + mini(rank, floori(elapsed / 120.0))

func _absorb_damage(amount: float) -> float:
	if buffs.has("shield"):
		var absorbed := minf(amount, buff_value("shield"))
		if absorbed > 0.0: _audio("shield_absorb")
		amount -= absorbed
		buffs.shield.value -= absorbed
		if float(buffs.shield.value) <= 0.0:
			buffs.erase("shield")
			loot_notices.append("붕괴 흡수막 소진")
			_audio("shield_break")
	return amount

func _deploy(kind: String, at: Vector2, lifetime: float, radius: float) -> void:
	var count := 0
	for shot: Dictionary in shots:
		count += int(shot.get("kind", "") == kind)
	if shots.size() >= 240 or count >= (3 if kind == "sentry" else (8 if kind == "mine" else 6)):
		return
	_audio({"sentry":"weapon_sentry_place", "mine":"weapon_mine_place", "wake":"weapon_wake"}[kind], at)
	shots.append({"kind": kind, "pos": at, "velocity": Vector2.ZERO, "radius": radius, "friendly": true, "damage": 0.0, "ttl": lifetime, "armed": 0.6 if kind == "mine" else 0.0, "fire_timer": 0.0})

func _update_evolved_weapons(dt: float) -> void:
	_sentry_timer -= dt
	_mine_timer -= dt
	_axe_timer -= dt
	if evolutions.has("sentry") and _sentry_timer <= 0.0:
		_sentry_timer = 5.0
		_deploy("sentry", player, 14.0, 14.0)
	if evolutions.has("minefield") and _mine_timer <= 0.0:
		_mine_timer = 2.0
		_deploy("mine", player, 18.0, 13.0)
	if evolutions.has("hatchet") and _axe_timer <= 0.0 and shots.size() < 240 and not shots.any(func(s: Dictionary) -> bool: return s.get("kind", "") == "axe"):
		var target := _nearest_enemy(player, 700.0)
		if not target.is_empty():
			_axe_timer = 2.8
			_audio("weapon_hatchet_throw", player)
			shots.append({"kind": "axe", "pos": player, "velocity": (Vector2(target.pos) - player).normalized() * 390.0, "friendly": true, "radius": 12.0, "damage": 58.0 * _power() * (1.0 + 0.15 * axe_catches + 0.1 * evolution_mastery("hatchet")), "ttl": 4.0, "pierce": 64, "hit_ids": [], "returning": false})

func _update_deployed(shot: Dictionary, dt: float) -> void:
	shot.ttl -= dt
	var previous_armed := float(shot.get("armed", 0.0))
	shot.armed = maxf(0.0, float(shot.get("armed", 0.0)) - dt)
	if shot.kind == "mine" and previous_armed > 0.0 and float(shot.armed) <= 0.0: _audio("weapon_mine_arm", shot.pos)
	shot.fire_timer = float(shot.get("fire_timer", 0.0)) - dt
	if float(shot.ttl) <= 0.0 or float(shot.armed) > 0.0 or float(shot.fire_timer) > 0.0:
		return
	var origin: Vector2 = shot.pos
	if shot.kind == "sentry":
		var target := _nearest_enemy(origin, 460.0)
		if not target.is_empty():
			_hit_enemy(target, 32.0 * _power() * (1.0 + focus_bonus()) * (1.0 + 0.15 * evolution_mastery("sentry")))
			_effect(origin, "lightning", 4.0, 0.12, target.pos)
		shot.fire_timer = 0.65
		return
	var radius := 145.0 if shot.kind == "mine" else 44.0
	if shot.kind == "mine" and _nearest_enemy(origin, 80.0).is_empty():
		return
	var damage := (100.0 + 15.0 * evolution_mastery("minefield")) if shot.kind == "mine" else (28.0 + 8.0 * int(upgrades.get("dash", 0)))
	for enemy: Dictionary in enemies:
		if origin.distance_squared_to(enemy.pos) <= pow(radius + float(enemy.radius), 2):
			_hit_enemy(enemy, damage * _power())
	_effect(origin, "pulse", radius, 0.28)
	shot.fire_timer = 0.35
	if shot.kind == "mine":
		_audio("weapon_mine_blast", origin)
		shot.ttl = 0.0

func hazard_pressure() -> float:
	return clampf(elapsed / 600.0, 0.0, 1.0)

func _add_lane(lateral: float = 0.0) -> void:
	if hazards.size() >= 6:
		return
	var vertical := rng.randf() < 0.5
	var width := (62.0 if mode == "relaxed" else 74.0) * (1.0 + 0.45 * hazard_pressure())
	var radius := ACTIVITY_RADIUS + BOUNDARY_BUFFER
	var target := ((player.x - CENTER.x) if vertical else (player.y - CENTER.y)) if lateral == 0.0 else lateral
	var offset := clampf(target, -radius + width, radius - width)
	var half_length := radius
	var rect := Rect2(CENTER + Vector2(offset - width * 0.5, -half_length), Vector2(width, half_length * 2.0)) if vertical else Rect2(CENTER + Vector2(-half_length, offset - width * 0.5), Vector2(half_length * 2.0, width))
	_audio("hazard_charge_lane", rect.get_center())
	hazards.append({"kind": "lane", "pos": rect.get_center(), "radius": 0.0, "rect": rect, "warn": 1.5, "ttl": 1.1, "active": false})

func _update_hazards(dt: float) -> void:
	if state != "playing":
		return
	_hazard_timer -= dt
	if sector_id != "ring" and _hazard_timer <= 0.0:
		_hazard_timer = (12.0 * (1.0 - 0.55 * hazard_pressure())) if sector_id == "storm" else 14.0 * (1.0 - 0.2 * hazard_pressure())
		if sector_id == "storm":
			for lane in mini(5, 1 + floori(elapsed / 120.0)):
				_add_lane([0.0, 190.0, -190.0, 380.0, -380.0][lane])
		else:
			_add_blast(player, 72.0)
			_add_blast(CENTER + Vector2.from_angle(rng.randf_range(0.0, TAU)) * sqrt(rng.randf()) * (ACTIVITY_RADIUS - 68.0), 68.0)
			if elapsed >= 300.0:
				_add_blast(CENTER - (player - CENTER).limit_length(ACTIVITY_RADIUS - 80.0), 68.0)
		_announce("전기 통로 충전 · 표시 구역 이탈" if sector_id == "storm" else "포격 경보 · 노란 예고 원 이탈", "hazard")
	for i in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[i]
		if not bool(hazard.active):
			var previous_warning := ceili(float(hazard.warn))
			hazard.warn = maxf(0.0, float(hazard.warn) - dt)
			if ENCOUNTERS.has(hazard.kind) and ceili(float(hazard.warn)) < previous_warning and previous_warning <= 4:
				events.append("event_warning")
				_audio("event_countdown")
			if float(hazard.warn) <= 0.0:
				hazard.active = true
				_audio("event_active_" + str(hazard.kind) if ENCOUNTERS.has(hazard.kind) else "hazard_strike_" + str(hazard.kind), hazard.pos)
				_effect(hazard.pos, "hazard_start", maxf(40.0, float(hazard.radius)), 0.5)
				events.append("event_start" if ENCOUNTERS.has(hazard.kind) else "hazard_start")
			continue
		var previous_ttl := float(hazard.ttl)
		hazard.ttl -= dt
		if ENCOUNTERS.has(hazard.kind):
			_update_encounter(hazard, dt, previous_ttl)
			if float(hazard.ttl) <= 0.0:
				_audio("event_end_" + str(hazard.kind))
				hazards.remove_at(i)
			continue
		var overlaps: bool = Rect2(hazard.rect).grow(PLAYER_RADIUS * 0.65).has_point(player) if hazard.kind == "lane" else player.distance_to(hazard.pos) < float(hazard.radius) + PLAYER_RADIUS
		if overlaps:
			take_damage((13.0 if hazard.kind == "lane" else 20.0) * (1.0 + 0.25 * hazard_pressure()), str(hazard.kind), hazard.pos)
		if float(hazard.ttl) <= 0.0:
			hazards.remove_at(i)
	if state != "playing":
		return
	if not hazards.any(func(h: Dictionary) -> bool: return ENCOUNTERS.has(h.kind)):
		_encounter_timer -= dt
		if _encounter_timer <= 0.0 and hazards.size() < 6:
			var pool: Array = ENCOUNTERS.keys().filter(func(id: String) -> bool: return id != _last_encounter and (id != "planet" or not _planet_seen))
			_add_encounter(str(pool[encounter_rng.randi_range(0, pool.size() - 1)]))

func encounter_interval() -> float:
	var bounds: Vector2 = {"relaxed": Vector2(140, 190), "normal": Vector2(100, 140), "veteran": Vector2(65, 90), "cataclysm": Vector2(38, 55)}[mode]
	return encounter_rng.randf_range(bounds.x, bounds.y)

func _add_encounter(kind: String, position: Vector2 = Vector2.INF) -> bool:
	if not ENCOUNTERS.has(kind) or hazards.size() >= 6 or (kind == "planet" and _planet_seen) or hazards.any(func(h: Dictionary) -> bool: return ENCOUNTERS.has(h.kind)):
		return false
	var point := position
	if not point.is_finite():
		point = CENTER + Vector2.from_angle(encounter_rng.randf_range(0.0, TAU)) * sqrt(encounter_rng.randf()) * (ACTIVITY_RADIUS - float(ENCOUNTERS[kind].radius))
	hazards.append({"kind": kind, "pos": point, "radius": ENCOUNTERS[kind].radius, "rect": Rect2(), "warn": 10.0, "ttl": ENCOUNTERS[kind].duration, "active": false, "hold": 0.0})
	_planet_seen = _planet_seen or kind == "planet"
	_last_encounter = kind
	_encounter_timer = encounter_interval()
	events.append("event_warning")
	_audio("event_warn_" + kind)
	return true

func gravity_pull(position: Vector2) -> Vector2:
	var pull := Vector2.ZERO
	for hazard: Dictionary in hazards:
		if hazard.kind == "black_hole" and bool(hazard.active):
			var toward: Vector2 = Vector2(hazard.pos) - position
			var strength := clampf(1.0 - toward.length() / float(hazard.radius), 0.0, 1.0)
			pull += toward.normalized() * 300.0 * strength * strength
	return pull

func gravity_drag(position: Vector2) -> float:
	var drag := 1.0
	for hazard: Dictionary in hazards:
		if hazard.kind == "black_hole" and bool(hazard.active):
			var distance := clampf(position.distance_to(hazard.pos) / float(hazard.radius), 0.0, 1.0)
			drag = minf(drag, lerpf(0.18, 1.0, smoothstep(0.0, 1.0, distance)))
	return drag

static func meteor_points(hazard: Dictionary) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in 5:
		points.append(Vector2(hazard.pos) + Vector2.from_angle(TAU * i / 5.0 - PI / 2.0) * 120.0)
	return points

func _update_encounter(hazard: Dictionary, dt: float, previous_ttl: float) -> void:
	match str(hazard.kind):
		"planet":
			var previous_hold := float(hazard.get("hold", 0.0))
			hazard.hold = float(hazard.get("hold", 0.0)) + dt if player.distance_to(hazard.pos) <= float(hazard.radius) + PLAYER_RADIUS else 0.0
			if previous_hold > 0.0 and float(hazard.hold) == 0.0: _audio("planet_reset")
			elif floori(float(hazard.hold)) > floori(previous_hold): _audio("planet_hold")
			if float(hazard.hold) >= 12.0:
				_grant_score(5000)
				xp += 45.0
				spawn_item(player, "A", "power")
				hazard.ttl = 0.0
				_effect(player, "reward", 110.0, 0.8)
				_announce("행성 방어 성공 · +5,000점 / 경험치 +45 / A급 출력 코어", "event_reward")
			elif float(hazard.ttl) <= 0.0:
				_announce("행성 방어 종료 · 연속 방어 시간 미달", "event_end")
		"meteor":
			var impact := floori((8.0 - previous_ttl) / 1.5) != floori((8.0 - float(hazard.ttl)) / 1.5) or previous_ttl == 8.0
			if impact:
				for point: Vector2 in meteor_points(hazard):
					_effect(point, "meteor_impact", 64.0, 0.55)
					if player.distance_to(point) < 64.0 + PLAYER_RADIUS:
						take_damage(24.0, "meteor", point)
				events.append("hazard_start")
		"flare":
			var front := float(hazard.radius) * clampf(1.0 - float(hazard.ttl) / 3.0, 0.0, 1.0)
			if absf(player.distance_to(hazard.pos) - front) <= 22.0 + PLAYER_RADIUS:
				take_damage(28.0, "flare", hazard.pos)

func _announce(title: String, event: String) -> void:
	event_title = title
	event_remaining = 3.3
	events.append(event)

func _update_run_stats() -> void:
	run_stats = {"kills": kills, "score": ranked_score(), "time": elapsed, "winner": state == "won", "level": level, "elites": elites_killed, "ship": ship_id, "sector": sector_id, "mode": mode, "evolutions": evolutions.duplicate(), "overdrives": _overdrives, "dashes": _dash_id, "returns": boundary_returns, "combo": peak_combo, "upgrades": upgrades.duplicate(), "items": items_collected}
	run_stats["missions"] = missions_completed
	run_stats["hull_forms"] = hull_forms.duplicate()

func _effect(position: Vector2, kind: String, radius: float, lifetime: float, end: Vector2 = Vector2.INF) -> void:
	if audio_enabled:
		match kind:
			"fire": _audio("enemy_attack_fire", position)
			"missile": _audio("weapon_missile_launch", position)
			"lightning": _audio("weapon_sentry_fire" if lifetime < 0.15 else "weapon_chain", position)
			"meteor_impact": _audio("hazard_strike_meteor", position)
	if effects.size() < 180:
		var effect := {"pos": position, "kind": kind, "ttl": lifetime, "max_ttl": lifetime, "radius": radius}
		if end.is_finite():
			effect["end"] = end
		effects.append(effect)

func buff_value(id: String) -> float:
	return float(buffs[id].value) if buffs.has(id) else 0.0

func roll_item_grade(layer: int) -> String:
	var roll := item_rng.randf()
	if layer >= 2:
		return "A" if roll < 0.4 else "B"
	if layer == 1:
		return "A" if roll < 0.15 else ("B" if roll < 0.8 else "C")
	return "A" if roll < 0.02 else ("B" if roll < 0.2 else "C")

func spawn_item(position: Vector2, grade: String, id: String = "") -> void:
	var selected := id if id in ItemCatalog.IDS else str(ItemCatalog.IDS[item_rng.randi_range(0, ItemCatalog.IDS.size() - 1)])
	if not grade in ItemCatalog.GRADES:
		return
	# Keep guaranteed strong-enemy rewards even when the field is full.
	if items.size() >= 12:
		loot_notices.append("보급 교체 · " + str(ItemCatalog.info(str(items[0].id)).name))
		items.pop_front()
	var point := CENTER + (position - CENTER).limit_length(ACTIVITY_RADIUS - PLAYER_RADIUS + LAYER_WIDTH * 1.75)
	items.append({"id": selected, "grade": grade, "pos": point, "ttl": 35.0})

func _update_items(dt: float) -> void:
	for id: String in buffs.keys():
		buffs[id].ttl = maxf(0.0, float(buffs[id].ttl) - dt)
		if float(buffs[id].ttl) <= 0.0:
			buffs.erase(id)
			_audio("buff_end")
	for i: int in range(items.size() - 1, -1, -1):
		items[i].pos = _drift_loot(items[i].pos, dt)
		var previous_ttl := float(items[i].ttl)
		items[i].ttl -= dt
		if previous_ttl > 10.0 and float(items[i].ttl) <= 10.0:
			_audio("loot_expire_soon")
			loot_notices.append("보급 소멸까지 10초 · %s %s" % [items[i].grade, ItemCatalog.info(str(items[i].id)).name])
		if float(items[i].ttl) <= 0.0:
			_audio("loot_expire_gone")
			loot_notices.append("보급 소멸 · %s %s" % [items[i].grade, ItemCatalog.info(str(items[i].id)).name])
			items.remove_at(i)
	_drop_cooldown = maxf(0.0, _drop_cooldown - dt)
	_supply_timer -= dt
	if _supply_timer <= 0.0:
		_supply_timer = item_rng.randf_range(55.0, 75.0)
		var radius := item_rng.randf_range(0.45, 0.85) * ACTIVITY_RADIUS
		if item_rng.randf() < 0.5:
			radius = ACTIVITY_RADIUS + LAYER_WIDTH * item_rng.randf_range(0.2, 1.6)
		var point := CENTER + Vector2.from_angle(item_rng.randf_range(0.0, TAU)) * radius
		spawn_item(point, roll_item_grade(boundary_layer(point)))
		_announce("희귀 보급 도착 · 방향 표시를 따라 회수", "supply")

func _collect_items(previous: Vector2) -> void:
	for i: int in range(items.size() - 1, -1, -1):
		var item: Dictionary = items[i]
		if Geometry2D.get_closest_point_to_segment(item.pos, previous, player).distance_to(item.pos) <= 30.0:
			apply_item(str(item.id), str(item.grade), boundary_layer(item.pos) > 0)
			items.remove_at(i)

func apply_item(id: String, grade: String, risky: bool = false) -> bool:
	var info := ItemCatalog.info(id, grade)
	if state != "playing" or info.is_empty():
		return false
	var previous_shield: Dictionary = buffs.get("shield", {}).duplicate()
	if float(info.duration) > 0.0:
		# Stronger effects replace weaker ones; weaker pickups cannot prolong an A buff.
		if not buffs.has(id) or (ItemCatalog.GRADES.find(grade) >= ItemCatalog.GRADES.find(str(buffs[id].grade)) if id == "shield" else float(info.value) >= float(buffs[id].value)):
			buffs[id] = {"value": info.value, "ttl": info.duration, "grade": grade}
	elif id == "heal":
		hp = minf(max_hp, hp + max_hp * float(info.value) / 100.0 * repair_efficiency())
	else:
		for enemy: Dictionary in enemies:
			if float(enemy.hp) <= 0.0 or player.distance_to(enemy.pos) > float(info.radius) + float(enemy.radius):
				continue
			if id == "stun":
				var duration_value := float(info.value) * (0.35 if enemy.kind in ["elite", "boss"] else 1.0)
				enemy.stun_time = maxf(float(enemy.get("stun_time", 0.0)), duration_value)
			else:
				_hit_enemy(enemy, float(info.value))
		if id == "emp":
			shots = shots.filter(func(shot: Dictionary) -> bool: return bool(shot.friendly) or player.distance_to(shot.pos) > float(info.radius))
		_effect(player, "pulse", float(info.radius), 0.6)
	_audio("loot_item_" + id + "_" + grade if id != "shield" or previous_shield != buffs.get("shield", {}) else "loot_score_bonus")
	items_collected += 1
	pending_items.append({"id": id, "grade": grade, "risky": risky})
	_effect(player, "pickup", 38.0, 0.4)
	_announce("%s등급 %s · 즉시 발동" % [grade, info.name], "item")
	_update_run_stats()
	return true

func _drift_loot(position: Vector2, dt: float, speed: float = LOOT_DRIFT_SPEED) -> Vector2:
	var safe_radius := ACTIVITY_RADIUS - PLAYER_RADIUS - 24.0
	if position.distance_to(CENTER) <= safe_radius:
		return position
	var target := CENTER + (position - CENTER).normalized() * safe_radius
	return position.move_toward(target, speed * dt)

func _tick_mission_clock() -> void:
	if not mission.is_empty():
		if mission.status == "preview" and elapsed >= float(mission.start):
			mission.status = "active"
			events.append("mission_start")
		if mission.status == "active" and elapsed >= float(mission.start) + 50.0:
			_finish_mission(mission.id == "survive" and float(mission.progress) < float(mission.target))
	if elapsed >= _next_mission_at - 10.0 and _next_mission_at < duration:
		var pool: Array = Expedition.MISSION_IDS.duplicate()
		pool.erase(_last_mission)
		# Ranged enemies are scarce before the second mission.
		if _next_mission_at <= 60.0:
			pool.erase("shooter")
		var id: String = pool[mission_rng.randi_range(0, pool.size() - 1)]
		mission = Expedition.mission(id, str(["C", "B", "A"][mission_rng.randi_range(0, 2)]))
		mission.merge({"start": _next_mission_at, "progress": 0.0, "status": "preview"})
		_last_mission = id
		_next_mission_at += 60.0
		events.append("mission_preview")

func _mission_add(id: String, amount: float) -> void:
	if mission.is_empty() or mission.status != "active" or mission.id != id or elapsed < float(mission.start) or elapsed >= float(mission.start) + 50.0:
		return
	mission.progress = float(mission.progress) + amount
	if id == "survive":
		if float(mission.progress) >= float(mission.target):
			_finish_mission(false)
	elif id != "outer" and float(mission.progress) >= float(mission.target):
		_finish_mission(true)

func _finish_mission(success: bool) -> void:
	if mission.is_empty() or mission.status != "active":
		return
	mission.status = "success" if success else "failed"
	mission_result = [mission.id, mission.grade, success]
	if success:
		missions_completed += 1
		mission_bonus_choices += int(mission.upgrades)
		pending_tech.append({"kind": "mission", "id": mission.id})
		for i in int(mission.parts):
			spawn_part(player + Vector2.from_angle(i * PI) * 48.0, "mission")
		_effect(player, "reward", 130.0, 0.8)
	events.append("mission_success" if success else "mission_failed")

func spawn_part(position: Vector2, source: String, id: String = "") -> void:
	if not source in ["explore", "mission"] or not position.is_finite():
		return
	var selected: String = id if id in Expedition.PART_IDS else str(Expedition.PART_IDS[mission_rng.randi_range(0, 2)])
	var point := CENTER + (position - CENTER).limit_length(ACTIVITY_RADIUS - PLAYER_RADIUS + LAYER_WIDTH * 1.85)
	if part_drops.size() >= 9:
		part_drops.pop_front()
	part_drops.append({"id": selected, "pos": point, "ttl": 45.0, "locked": source == "explore", "source": source})
	events.append("part_spawn")

func collect_part(id: String) -> bool:
	if state != "playing" or not id in Expedition.PART_IDS:
		return false
	parts[id] = mini(6, int(parts.get(id, 0)) + 1)
	if int(parts[id]) == 6:
		_grant_score(200)
	pending_tech.append({"kind": "part", "id": id})
	for recipe_id: String in Expedition.RECIPE_IDS:
		if hull_rank(recipe_id) > 0 and not recipe_id in hull_forms:
			hull_forms.append(recipe_id)
			pending_tech.append({"kind": "hull", "id": recipe_id})
			events.append("hull_evolution")
			_audio("growth_hull_II" if hull_rank(recipe_id) >= 2 else "growth_hull_I")
	_effect(player, "reward", 85.0, 0.6)
	events.append("part_pickup")
	_audio("loot_part_" + id)
	if int(parts.get(id, 0)) >= 6: _audio("loot_part_overflow")
	_update_run_stats()
	return true

func hull_rank(id: String) -> int:
	var info := Expedition.recipe(id)
	if info.is_empty():
		return 0
	var rank := 2
	for required: String in info.needs:
		rank = mini(rank, int(parts.get(required, 0)))
	return rank

func _update_expedition(dt: float, previous: Vector2) -> void:
	if boundary_layer(player) > 0:
		_mission_add("outer", dt)
	elif not mission.is_empty() and mission.status == "active" and mission.id == "outer" and float(mission.progress) >= float(mission.target):
		_finish_mission(true)
	for i in range(part_drops.size() - 1, -1, -1):
		var drop: Dictionary = part_drops[i]
		var previous_ttl := float(drop.ttl)
		drop.ttl -= dt
		if previous_ttl > 10.0 and float(drop.ttl) <= 10.0:
			_audio("loot_expire_soon")
			loot_notices.append("파츠 소멸까지 10초 · " + str(Expedition.part(str(drop.id)).name))
		var reachable := not bool(drop.locked) or boundary_layer(player) >= 2
		if reachable and Geometry2D.get_closest_point_to_segment(drop.pos, previous, player).distance_to(drop.pos) <= 30.0:
			collect_part(str(drop.id))
			part_drops.remove_at(i)
		elif float(drop.ttl) <= 0.0:
			_audio("loot_expire_gone")
			loot_notices.append("파츠 소멸 · " + str(Expedition.part(str(drop.id)).name))
			part_drops.remove_at(i)
	if elapsed >= _explore_at:
		_explore_at = elapsed + 105.0
		if not part_drops.any(func(p: Dictionary) -> bool: return bool(p.locked)):
			var outward := (player - CENTER).normalized() if player != CENTER else facing
			spawn_part(CENTER + outward.rotated(mission_rng.randf_range(-0.65, 0.65)) * (ACTIVITY_RADIUS - PLAYER_RADIUS + LAYER_WIDTH * 1.8), "explore")
	var aegis := hull_rank("aegis")
	if aegis > 0:
		_barrier_timer -= dt
		if _barrier_timer <= 0.0:
			_barrier_timer = 5.0 if aegis == 1 else 3.5
			var radius := 110.0 if aegis == 1 else 150.0
			shots = shots.filter(func(s: Dictionary) -> bool: return bool(s.friendly) or player.distance_to(s.pos) > radius)
			_effect(player, "guard", radius, 0.5)

func expedition_snapshot() -> Dictionary:
	var drops: Array = []
	for drop: Dictionary in part_drops:
		drops.append([drop.id, snappedf(drop.pos.x, 0.01), snappedf(drop.pos.y, 0.01), snappedf(drop.ttl, 0.001), drop.locked, drop.source])
	return {"parts": [int(parts.get("core", 0)), int(parts.get("drive", 0)), int(parts.get("shell", 0))], "drops": drops, "mission": [] if mission.is_empty() else [mission.id, mission.grade, mission.start, snappedf(mission.progress, 0.001), mission.status], "result": mission_result.duplicate()}

func restore_expedition(value: Dictionary) -> void:
	parts = {"core": 0, "drive": 0, "shell": 0}
	part_drops.clear()
	mission.clear()
	mission_result.clear()
	hull_forms.clear()
	if not Expedition.valid_snapshot(value):
		return
	for i in 3:
		parts[Expedition.PART_IDS[i]] = int(value.parts[i])
	for row: Array in value.drops:
		part_drops.append({"id": row[0], "pos": Vector2(row[1], row[2]), "ttl": row[3], "locked": row[4], "source": row[5]})
	if not value.mission.is_empty():
		var m: Array = value.mission
		mission = Expedition.mission(str(m[0]), str(m[1]))
		mission.merge({"start": m[2], "progress": m[3], "status": m[4]})
	mission_result = value.result.duplicate()
	for id: String in Expedition.RECIPE_IDS:
		if hull_rank(id) > 0:
			hull_forms.append(id)
