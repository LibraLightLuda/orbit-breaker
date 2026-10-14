extends SceneTree

var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run_checks")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("COMBAT: " + label)

func fresh(ship: String = "striker", sector: String = "ring") -> RunModel:
	var run := RunModel.new()
	run.reset(1919, "normal", ship, sector)
	run.audio_enabled = true
	return run

func run_checks() -> void:
	_test_branches()
	_test_bosses()
	_test_environment()
	_test_finale()
	_test_replay()
	_test_save()
	_test_weapon_targets()
	print("COMBAT SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func _test_branches() -> void:
	for id: String in GameContent.BRANCH_IDS:
		var info := GameContent.branch_info(id)
		var run := fresh(info.ship)
		run.elapsed = 301.0
		run.evolutions.append({"striker":"sentry", "scout":"wake", "bastion":"citadel"}[info.ship])
		run.branch_pending = true
		run.guard_cooldown = 4.0
		run._check_level()
		check(run.state == "branch", id + " queues choice without consuming XP")
		var before := [run.elapsed, run.hp, run.guard_cooldown, run.level, run.xp, run.parts.duplicate()]
		run.step(0.05, Vector2.RIGHT, true)
		check(before == [run.elapsed, run.hp, run.guard_cooldown, run.level, run.xp, run.parts], id + " freezes combat")
		check(not run.choose_branch("invalid"), id + " rejects unknown choice")
		var other: String = "trail" if info.ship != "scout" else "focus"
		check(not run.choose_branch(other), id + " rejects other ship")
		check(run.choose_branch(id), id + " accepts valid choice")
		check(run.branch_id == id and run.state == "playing" and not run.branch_pending, id + " applies once")
		check(run.guard_stacks == 1 and is_equal_approx(run.guard_cooldown, 4.0 * run.branch_value("guard_period", 8.0) / 8.0), id + " preserves charge proportion and stacks")
		check(not run.choose_branch(id), id + " cannot choose twice")
		check(before[3] == run.level and before[4] == run.xp and before[5] == run.parts, id + " no growth cost")
		run.reset(1919, "normal", info.ship, "ring")
		check(run.branch_id == "" and not run.branch_pending and run.finale_status == "none", id + " resets per run")
	var run := fresh()
	run.branch_id = "focus"
	for i in 4: run._deploy("sentry", run.player + Vector2(i * 10, 0), 6, 14)
	check(run.shots.size() == 1, "Focus maintains one replacement turret")
	var boss := run.spawn_enemy("boss", run.player + Vector2(220, 0))
	var small := run.spawn_enemy("chaser", run.player + Vector2(20, 0))
	var boss_hp := float(boss.hp)
	run._update_deployed(run.shots[0], 0.01)
	check(float(boss.hp) < boss_hp and float(small.hp) == float(small.max_hp), "Focus turret prefers boss")
	run = fresh("scout")
	run.branch_id = "trail"
	for i in 9: run._deploy("wake", run.player + Vector2(i * 10, 0), 3.6, 44)
	check(run.shots.size() == 6 and run.shots.back().pos == run.player + Vector2(80, 0), "Wake retains newest six path segments")
	run = fresh()
	run.branch_pending = true
	run.mission_bonus_choices = 2
	run.xp = 100
	run._check_level()
	check(run.state == "branch" and run.mission_bonus_choices == 2 and run.level == 1, "Branch waits ahead of growth without consuming queued choices")

func _test_bosses() -> void:
	for sector: String in GameContent.SECTOR_IDS:
		var run := fresh("striker", sector)
		var boss := run.spawn_enemy("boss", run.player + Vector2(230, 0))
		check(run._fire_enemy_shots(boss), sector + " actual attack")
		run._fire_enemy_shots(boss)
		check(float(boss.get("weakpoint", 0.0)) == 0, sector + " closed after two attacks")
		run._fire_enemy_shots(boss)
		check(is_equal_approx(float(boss.weakpoint), 2.25), sector + " opens after three attacks")
		var before := float(boss.hp)
		boss.env_vulnerable = 4.0
		run._hit_enemy(boss, 20)
		check(is_equal_approx(before - float(boss.hp), 30), sector + " vulnerability uses maximum once")
		boss.stun_time = 2.0
		run._update_enemies(0.05, run.player)
		check(is_equal_approx(float(boss.weakpoint), 2.2), sector + " stun does not prolong opening")
		boss.weakpoint = 0.0
		boss.phase = 2
		boss.volleys = 2
		run._fire_enemy_shots(boss)
		check(is_equal_approx(float(boss.weakpoint), 1.8), sector + " enraged opening")
	var run := fresh()
	var a := run.spawn_enemy("boss", run.player + Vector2(200, 0))
	var b := run.spawn_enemy("boss", run.player - Vector2(200, 0))
	a.volleys = 2
	run._fire_enemy_shots(a)
	check(float(a.weakpoint) > 0 and float(b.get("weakpoint", 0)) == 0, "Two bosses keep independent attack counters")
	run.shots.clear()
	for i in 220: run.shots.append({})
	b.volleys = 2
	check(not run._fire_enemy_shots(b) and int(b.volleys) == 2, "Blocked attack does not advance opening")

func _test_environment() -> void:
	var run := fresh("striker", "storm")
	var small := run.spawn_enemy("chaser", run.player + Vector2(100, 0))
	var elite := run.spawn_enemy("elite", run.player + Vector2(100, 10))
	var boss := run.spawn_enemy("boss", run.player + Vector2(100, -10))
	var lane := {"kind":"lane", "source":"sector", "active":false, "ttl":1.0, "rect":Rect2(run.player - Vector2(20, 50), Vector2(200, 100)), "pos":run.player, "radius":0.0}
	run._apply_environment(lane)
	check(float(small.hp) == float(small.max_hp), "Warning never damages enemies")
	lane.active = true
	run._apply_environment(lane)
	check(is_equal_approx(float(small.hp) / float(small.max_hp), 0.8), "Lane chips normal enemy 20 percent")
	check(is_equal_approx(float(elite.hp) / float(elite.max_hp), 0.95), "Lane chips elite 5 percent")
	check(is_equal_approx(float(boss.hp) / float(boss.max_hp), 0.98), "Lane chips boss 2 percent")
	var before := float(small.hp)
	run._apply_environment(lane)
	check(float(small.hp) == before, "Same activation cannot hit same enemy twice")
	var late := run.spawn_enemy("chaser", run.player + Vector2(100, 0))
	run._apply_environment(lane)
	check(float(late.hp) < float(late.max_hp), "Late entrant receives one hit")
	small.hp = 1.5
	run._hit_enemy(small, 1000, -1, true)
	run._finish_deaths()
	check(float(small.hp) == 1.0 and run.kills == 0 and run.score == 0 and run.overdrive_meter == 0, "Environment cannot kill or create rewards")
	run._hit_enemy(small, 1)
	run._finish_deaths()
	var kills := run.kills
	run._finish_deaths()
	check(kills == 1 and run.kills == 1, "Player finisher awards exactly once in same frame")
	var blast := {"kind":"blast", "source":"enemy", "active":true, "ttl":0.3, "rect":Rect2(), "pos":elite.pos, "radius":100.0}
	run._apply_environment(blast)
	check(float(elite.get("env_vulnerable", 0)) == 0, "Enemy blast cannot weaken allies")
	blast.source = "sector"
	run._apply_environment(blast)
	check(float(elite.env_vulnerable) == 4.0, "Sector blast exposes armor")
	before = float(elite.hp)
	run._hit_enemy(elite, 10)
	check(is_equal_approx(before - float(elite.hp), 12), "Armor break affects player damage")

func arm_finale() -> RunModel:
	var run := fresh()
	run.survival_cleared = true
	run.elapsed = 530
	run._tick_finale()
	check(run.finale_offered and run.finale_status == "preview", "Final offer at 8:50")
	check(run.select_finale(true), "Accept final operation")
	run.elapsed = 540
	run._tick_finale()
	return run

func _test_finale() -> void:
	var run := arm_finale()
	var boss := run.final_commander()
	check(not boss.is_empty() and run.finale_status == "active" and run.enemies.size() == 1, "Final boss uses one normal enemy slot")
	check(run.mission.is_empty(), "Final replaces minute-nine mission")
	check(not run.select_finale(false), "Choice locks at 9:00")
	var hp := float(boss.hp)
	var part_hp := float(boss.relays[0])
	var target := run.relay_position(boss, 0)
	check(run.target_position(boss, target) == target and run.combat_radius(boss) == 88.0 and float(boss.radius) == 39.0, "Target envelope includes relays without expanding body")
	check(not run._hit_area(boss, 50, boss.pos, 5), "Protected center is not an area target")
	check(run._hit_area(boss, 50, target, 5), "Area weapon can hit a relay")
	check(float(boss.hp) == hp and float(boss.relays[0]) == part_hp - 50, "Relay absorbs hit without core leakage")
	var part := run._segment_part(boss, target - Vector2(100, 0), target + Vector2(100, 0), 5)
	check(part >= 0, "Swept projectile intersects attachment")
	check(run._segment_part(boss, Vector2(boss.pos) + Vector2(200, 200), Vector2(boss.pos) + Vector2(210, 200), 5) == -2, "Swept miss stays a miss")
	run._hit_enemy(boss, 100000, -1, true)
	check(float(boss.hp) == hp, "Environment cannot bypass protection")
	run._hit_enemy(boss, 100000, 0)
	check(run.kills == 0 and run.score == 0, "Relay destruction has no farming reward")
	run._hit_enemy(boss, 100000, 1)
	check(not run._shielded(boss) and float(boss.weakpoint) == 3.0, "Second relay opens core for three seconds")
	run.elapsed = 599.99
	run._hit_enemy(boss, 100000)
	run._finish_deaths()
	check(run.finale_status == "success" and run.finale_success_at == 599.99, "Final blow committed before deadline")
	check(run.kills == 1 and run.bosses_killed == 1, "Core rewards one boss kill")
	run.elapsed = 600
	run._update_vitals(0.01)
	check(run.state == "won" and run.hp == 0 and run.finale_status == "success", "Collapse preserves prior operation success and breakthrough")
	run = fresh()
	run.survival_cleared = true
	run.elapsed = 530
	run._tick_finale()
	run.elapsed = 540
	run._tick_finale()
	check(run.finale_status == "declined" and run.enemies.is_empty(), "Unanswered offer keeps normal survival")
	run = fresh()
	run.elapsed = 530
	run._tick_finale()
	check(not run.finale_offered and not run.select_finale(true), "No offer before breakthrough")
	run = arm_finale()
	run.elapsed = 600
	run._update_vitals(0.01)
	check(run.finale_status == "failed" and run.state == "won", "Failed operation never revokes breakthrough")

func _test_replay() -> void:
	var run := arm_finale()
	run.branch_id = "focus"
	var boss := run.final_commander()
	boss.env_vulnerable = 2.0
	var ghost := GhostReplay.new()
	ghost.capture(run, true)
	check(GhostReplay.valid(ghost.frames, 540.0), "Extended world passes validation")
	var restored := fresh()
	GhostReplay.restore(restored, ghost.frames[0])
	check(restored.branch_id == "focus" and restored.finale_status == "active", "Replay restores selected tactic and operation")
	check(restored.final_commander().relays == boss.relays, "Replay restores both component health values")
	var legacy := ghost.frames.duplicate(true)
	legacy[0][13].erase("combat")
	check(GhostReplay.valid(legacy, 540.0), "Older world without extension remains valid")
	GhostReplay.restore(restored, legacy[0])
	check(restored.branch_id == "" and restored.finale_status == "none" and restored.final_commander().is_empty(), "Backward seek clears newer visual state")
	var corrupt := ghost.frames.duplicate(true)
	corrupt[0][13].combat.statuses[0][5] = [INF, 1]
	check(not GhostReplay.valid(corrupt, 540.0), "Nonfinite attachment health rejected")
	corrupt = ghost.frames.duplicate(true)
	corrupt[0][13].combat.branch = "unknown"
	check(not GhostReplay.valid(corrupt, 540.0), "Unknown recorded branch rejected")
	for cue: String in ["combat_branch", "combat_core_open", "combat_relay_down", "combat_final_offer", "combat_final_start", "combat_final_success"]:
		check(SoundBank.CUES.has(SoundBank.ALIASES.get(cue, cue)), "Existing preloaded sound for " + cue)

func _test_save() -> void:
	var store := SaveStore.new()
	var path := "user://combat_save_%d.json" % Time.get_ticks_usec()
	store.load_data(path)
	var details := {"name":"확장 검사", "ship":"striker", "sector":"ring", "mode":"normal", "rules":"combat-v1", "branch":"focus", "finale":"success", "finale_time":575.0, "time":580.0, "kills":10, "level":3}
	check(store.record_run(100, 580, true, details), "New record saved")
	check(store.data.recent_runs[0].branch == "focus" and store.data.recent_runs[0].finale == "success", "Tactic and final operation recorded")
	check("final_op" in store.data.achievements, "Final operation medal awarded")
	var points := Achievements.points(store.data.achievements)
	var other := SaveStore.new()
	other.load_data(path)
	check(other.data.recent_runs[0].rules == "combat-v1" and "final_op" in other.data.achievements, "New fields survive disk roundtrip")
	check(other.record_run(101, 580, true, details) and Achievements.points(other.data.achievements) == points, "Medal is never awarded twice")
	var old := other._run_entry(10, 300, true, {"ship":"scout", "sector":"ring", "mode":"normal"})
	check(old.branch == "" and old.finale == "none" and old.rules == "3.1", "Old entries get neutral new fields")
	details.branch = "unknown"
	details.finale_time = INF
	var bad := other._run_entry(10, 580, true, details)
	check(bad.branch == "" and bad.finale == "none", "Corrupt new metadata does not erase valid old record")

func _test_weapon_targets() -> void:
	for weapon: String in ["cannon", "missile", "axe", "chain", "pulse", "sentry", "mine", "wake", "dash", "orbit", "guard"]:
		var run := arm_finale()
		var boss := run.final_commander()
		boss.pos = run.player + Vector2(160, 0)
		boss.relay_axis = Vector2.UP
		boss.relay_max = 10000.0
		boss.relays = [10000.0, 10000.0]
		var hp := float(boss.hp)
		var at := run.relay_position(boss, 0)
		match weapon:
			"cannon":
				run._fire_player_shot()
				for i in 20: run._update_shots(0.05)
			"missile", "axe":
				run.shots.append({"kind":weapon, "pos":at - Vector2(20, 0), "velocity":Vector2(400, 0), "friendly":true, "radius":8.0, "damage":20.0, "ttl":4.0, "blast_radius":50.0, "pierce":1, "hit_ids":[]})
				run._update_shots(0.05)
			"chain", "pulse":
				run.upgrades[weapon] = 1
				if weapon == "pulse": run.player = boss.pos
				run._update_weapons(0.01)
			"sentry", "mine", "wake":
				var shot := {"kind":weapon, "pos":at, "ttl":5.0, "armed":0.0, "fire_timer":0.0}
				run._update_deployed(shot, 0.01)
			"dash":
				run.orbit_count = 0
				run.dash_time = 0.2
				run._dash_id = 8
				run.player = at + Vector2(60, 0)
				run._update_enemies(0, at - Vector2(60, 0))
			"orbit":
				run.orbit_count = 1
				run.orbit_angle = 0.0
				run.player = at - Vector2(run.orbit_radius, 0)
				run._update_enemies(0, run.player)
			"guard":
				run.ship_id = "bastion"
				run.player = at
				run.guard_stacks = 1
				run.take_damage(10)
		check(float(boss.relays[0]) + float(boss.relays[1]) < 20000.0, weapon + " damages a valid attachment")
		check(float(boss.hp) == hp, weapon + " cannot leak into protected core")
		check(float(boss.relays[0]) == 10000.0 or float(boss.relays[1]) == 10000.0, weapon + " does not double hit both attachments")
